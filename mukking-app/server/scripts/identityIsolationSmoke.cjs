// Isolated fixtures only: never load local credentials or contact Supabase.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
require('dotenv').config = () => ({});
const mode = process.argv[2];
const production = {
  NODE_ENV: 'production', AUTH_PROVIDER: 'supabase', REPOSITORY_PROVIDER: 'supabase',
  SUPABASE_URL: 'https://identity-fixture.invalid', SUPABASE_ANON_KEY: 'fixture-public',
  SUPABASE_SERVICE_ROLE_KEY: 'fixture-private', ADMIN_REQUIRE_MFA: 'true',
  MOCK_VERIFICATION_ENABLED: 'false'
};
function child(mode, config) {
  const env = { ...process.env };
  for (const key of Object.keys(production)) delete env[key];
  return spawnSync(process.execPath, [__filename, mode], {
    env: { ...env, ...config }, encoding: 'utf8', timeout: 30000
  });
}
async function main() {
  if (!mode) {
    let count = 0;
    for (const [key, value] of [
      ['AUTH_PROVIDER', 'signed_mock'], ['AUTH_PROVIDER', 'unknown'], ['AUTH_PROVIDER', ''],
      ['REPOSITORY_PROVIDER', 'memory'], ['REPOSITORY_PROVIDER', 'unknown'], ['REPOSITORY_PROVIDER', ''],
      ['MOCK_VERIFICATION_ENABLED', 'true'], ['MOCK_VERIFICATION_ENABLED', 'invalid'],
      ['ADMIN_REQUIRE_MFA', 'false'], ['SUPABASE_URL', ''], ['SUPABASE_URL', 'http://invalid'],
      ['SUPABASE_ANON_KEY', ''], ['SUPABASE_SERVICE_ROLE_KEY', ''], ['NODE_ENV', 'prod']
    ]) {
      const result = child('config', { ...production, [key]: value });
      assert.equal(result.status, 1, key);
      assert.match(result.stderr, /Invalid server configuration/);
      count++;
    }
    for (const key of ['AUTH_PROVIDER', 'REPOSITORY_PROVIDER']) {
      const config = { ...production }; delete config[key];
      assert.equal(child('config', config).status, 1); count++;
    }
    for (const [name, config] of [
      ['production', production],
      ['development', { NODE_ENV: 'development', AUTH_PROVIDER: 'signed_mock', REPOSITORY_PROVIDER: 'memory' }],
      ['test', { NODE_ENV: 'test', AUTH_PROVIDER: 'signed_mock', REPOSITORY_PROVIDER: 'memory' }]
    ]) {
      const result = child(name, config);
      assert.equal(result.status, 0, `${name}: ${result.stderr}`);
      console.log(result.stdout.trim()); count++;
    }
    console.log(`[IDENTITY] PASS ${count} isolated configuration/runtime scenarios`);
    return;
  }
  const { environment } = require('../dist/server/config/environment');
  if (mode === 'config') return;
  // Any accidental external network attempt fails, rather than reaching a live database.
  const realFetch = global.fetch;
  global.fetch = (url, options) => {
    assert.equal(new URL(String(url)).hostname, '127.0.0.1', 'external network forbidden');
    return realFetch(url, options);
  };
  const { repositories } = require('../dist/server/repositories');
  const { memoryRepositories } = require('../dist/server/repositories/memory');
  Object.assign(repositories, memoryRepositories);
  const verification = require('../dist/server/services/verification/verification.service');
  const auth = require('../dist/server/services/auth/auth.service');
  const matching = require('../dist/server/services/matching/matching.service');
  const chat = require('../dist/server/services/chat/chat.service');
  const { isVerificationAcceptedForEnvironment } = require('../dist/server/services/verification/verification-policy');
  const { app } = require('../dist/server/app');
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  const input = { legalName: 'fixture', birthDate: '2000-01-01', gender: 'other', phoneNumber: 'fixture' };
  const denied = task => assert.rejects(task, error => error.statusCode === 403);
  try {
    for (const suffix of ['', '/start', '/complete']) {
      const response = await fetch(`${base}/api/auth/verification/mock${suffix}`, { method: 'POST' });
      assert.equal(response.status, mode === 'production' ? 404 : 401);
    }
    if (mode === 'production') {
      const jwt = require('../dist/server/services/auth/jwt.service');
      assert.throws(() => jwt.createSignedJwt({ userId: 'fixture' }), /Mock authentication is unavailable/);
      assert.throws(() => jwt.verifySignedJwt('e30.e30.fixture'), /Mock authentication is unavailable/);
      await denied(() => verification.startMockVerification('missing'));
      await denied(() => verification.completeMockVerification('missing', input));
      await denied(() => verification.submitMockVerification('missing', input));
      const user = await repositories.users.create({ id: 'production-fixture', email: 'fixture@example.invalid', nickname: 'fixture', phoneNumber: '', verificationStatus: 'verified', mannerScore: 45, mannerGrade: 'mukking' });
      const claim = { userId: user.id, provider: 'pass_mock', status: 'verified', verifiedAt: new Date().toISOString() };
      await repositories.verification.upsertClaim(claim);
      await denied(() => auth.assertCanUseMatching(user.id));
      await denied(() => chat.listChatRooms(user.id));
      await denied(() => chat.sendMessage(user.id, 'missing', { text: 'fixture' }));
      assert.equal((await verification.getVerificationStatusSnapshot(user.id)).canUseMatching, false);
      for (const invalid of [null, { ...claim, provider: 'unknown' }, { ...claim, provider: 'pass', status: 'pending' }, { ...claim, provider: 'pass', userId: 'other' }, { ...claim, provider: 'pass', verifiedAt: undefined }]) {
        assert.equal(isVerificationAcceptedForEnvironment(user, invalid), false);
      }
      await repositories.verification.upsertClaim({ ...claim, provider: 'pass' });
      await auth.assertCanUseMatching(user.id);
      const { requireAdminMfaMiddleware } = require('../dist/server/middleware/adminOnly.middleware');
      let error;
      requireAdminMfaMiddleware({ authClaims: { aal: 'aal1' } }, {}, e => { error = e; });
      assert.equal(error.statusCode, 403);
      requireAdminMfaMiddleware({ authClaims: { aal: 'aal2' } }, {}, e => { error = e; });
      assert.equal(error, undefined);
      const { adminOnlyMiddleware } = require('../dist/server/middleware/adminOnly.middleware');
      environment.adminEmailWhitelist = ['admin@example.invalid'];
      environment.adminUidWhitelist = ['admin-fixture'];
      adminOnlyMiddleware({ user: { email: 'admin@example.invalid' }, userId: 'other' }, {}, e => { error = e; });
      assert.equal(error.statusCode, 403);
      adminOnlyMiddleware({ user: { email: 'admin@example.invalid' }, userId: 'admin-fixture' }, {}, e => { error = e; });
      assert.equal(error, undefined);
    } else {
      const users = [];
      for (const name of ['host', 'guest']) {
        const session = await auth.signup({ email: `${name}@example.invalid`, nickname: name, phoneNumber: 'fixture' });
        await verification.submitMockVerification(session.user.id, input);
        await auth.assertCanUseMatching(session.user.id);
        assert.ok((await auth.login({ email: `${name}@example.invalid` })).token);
        users.push(session.user.id);
      }
      const [host, guest] = users;
      const post = await matching.createMatchingPost(host, { restaurantName: 'fixture', address: 'fixture', scheduledAt: new Date(Date.now() + 86400000).toISOString(), maxParticipants: 2, intro: 'fixture' });
      const request = await matching.createJoinRequest(guest, post.id);
      await repositories.users.setVerificationStatus(guest, 'unverified');
      await denied(() => matching.respondToJoinRequest(host, request.id, { decision: 'accepted' }));
      assert.equal((await repositories.matching.findJoinRequestById(request.id)).status, 'pending');
      await repositories.users.setVerificationStatus(guest, 'verified');
      const originalRestriction = repositories.sanctions.hasActiveRestriction;
      repositories.sanctions.hasActiveRestriction = async id => id === guest;
      await denied(() => matching.respondToJoinRequest(host, request.id, { decision: 'accepted' }));
      repositories.sanctions.hasActiveRestriction = originalRestriction;
      const accepted = await matching.respondToJoinRequest(host, request.id, { decision: 'accepted' });
      await repositories.users.setVerificationStatus(guest, 'unverified');
      const recovered = await matching.respondToJoinRequest(host, request.id, { decision: 'accepted' });
      assert.equal(recovered.chatRoom.id, accepted.chatRoom.id);
    }
    console.log(`[IDENTITY] PASS ${mode}: routes, service policy, eligibility and recovery`);
  } finally { await new Promise(resolve => server.close(resolve)); }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
