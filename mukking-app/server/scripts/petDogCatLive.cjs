// Explicit manual validation only. No migration or existing-row writes.
const crypto = require('node:crypto');
require('dotenv').config({ quiet: true });
process.env.AUTH_PROVIDER = 'supabase';
process.env.REPOSITORY_PROVIDER = 'supabase';
const { createClient } = require('@supabase/supabase-js');
const { app } = require('../dist/server/app');
const service = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { persistSession: false, autoRefreshToken: false } });
const users = [];
let server;
function check(ok, label) { if (!ok) throw Error(label); console.log('[PET_DOG_CAT] PASS ' + label); }
async function main() {
  const legacy = await service.from('user_pets').select('*').in('pet_type', ['healthy','night','hearty']).limit(3);
  check(!legacy.error, 'legacy snapshot read');
  console.log('[PET_DOG_CAT] legacy rows inspected=' + legacy.data.length);
  server = await new Promise(resolve => { const s = app.listen(0, '127.0.0.1', () => resolve(s)); });
  const base = 'http://127.0.0.1:' + server.address().port;
  async function api(token, body) {
    const r = await fetch(base + '/api/pets/me', { method: body ? 'POST' : 'GET',
      headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' },
      body: body ? JSON.stringify(body) : undefined });
    return { status: r.status, data: await r.json() };
  }
  try {
    for (const type of ['dog','cat']) {
      const email = 'pet-dogcat-' + crypto.randomUUID() + '@example.com';
      const password = crypto.randomBytes(32).toString('base64url') + 'a1!';
      const created = await service.auth.admin.createUser({ email, password, email_confirm: true,
        user_metadata: { nickname: '[TEST][PET_DOG_CAT]' } });
      check(!created.error && created.data.user, type + ' disposable account');
      const id = created.data.user.id; users.push(id);
      const auth = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY,
        { auth: { persistSession: false, autoRefreshToken: false } });
      const login = await auth.auth.signInWithPassword({ email, password });
      check(!login.error && login.data.session, type + ' login');
      const token = login.data.session.access_token;
      const profile = await fetch(base + '/api/auth/me', { headers: { Authorization: 'Bearer ' + token } });
      check(profile.status === 200, type + ' profile');
      const empty = await api(token);
      check(empty.status === 200 && empty.data === null, type + ' initially empty');
      const selected = await api(token, { petType: type });
      check(selected.status === 201 && selected.data.petType === type, type + ' API saved');
      const before = await service.from('user_pets').select('*').eq('user_id', id).single();
      check(!before.error && before.data.pet_type === type && before.data.user_id === id, type + ' DB type and owner');
      const reload = await api(token);
      check(reload.status === 200 && JSON.stringify(reload.data) === JSON.stringify(selected.data), type + ' fresh GET restored all fields');
      check(!(await auth.auth.signOut()).error, type + ' logout');
      const again = await auth.auth.signInWithPassword({ email, password });
      check(!again.error && again.data.session, type + ' relogin');
      const restored = await api(again.data.session.access_token);
      check(restored.status === 200 && JSON.stringify(restored.data) === JSON.stringify(selected.data), type + ' relogin preserves XP level owner timestamps');
      const after = await service.from('user_pets').select('*').eq('user_id', id).single();
      check(!after.error && JSON.stringify(after.data) === JSON.stringify(before.data), type + ' DB row unchanged after restore');
      await auth.auth.signOut();
    }
    for (const row of legacy.data) {
      const after = await service.from('user_pets').select('*').eq('id', row.id).single();
      check(!after.error && JSON.stringify(after.data) === JSON.stringify(row), 'existing legacy row unchanged');
    }
  } finally {
    console.log('[PET_DOG_CAT] cleanup disposable account IDs=' + JSON.stringify(users));
    try {
      for (const id of users) {
        for (const table of ['pet_xp_events', 'user_pets', 'user_manner_profiles']) {
          const removed = await service.from(table).delete().eq('user_id', id);
          check(!removed.error, 'temporary ' + table + ' cleanup');
        }
        const result = await service.auth.admin.deleteUser(id);
        check(!result.error, 'disposable account cleanup');
      }
      if (users.length) {
        const left = await service.from('user_pets').select('id', { count: 'exact', head: true }).in('user_id', users);
        check(!left.error && left.count === 0, 'temporary pets cleanup zero');
      }
    } finally { await new Promise(resolve => server.close(resolve)); }
  }
}
main().catch(() => { console.error('[PET_DOG_CAT] FAIL; credentials omitted'); process.exitCode = 1; if (server) server.close(); });
