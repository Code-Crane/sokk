-- Run only against a disposable/local Supabase database AFTER the pet migration.
-- Not executed against the live project. All fixture changes are rolled back.
begin;
do $$
declare u uuid := gen_random_uuid(); total bigint; n integer;
begin
  insert into auth.users(id) values (u);
  begin
    insert into public.user_pets(user_id, pet_type) values (u, 'invalid');
    raise exception 'Invalid pet type was accepted';
  exception when check_violation then null;
  end;
  insert into public.user_pets(user_id, pet_type) values (u, 'healthy');
  begin
    insert into public.user_pets(user_id, pet_type) values (u, 'night');
    raise exception 'Duplicate pet was accepted';
  exception when unique_violation then null;
  end;
  if not public.award_pet_xp(u, 'matching_completed', 'test-one', 30) then
    raise exception 'Initial award failed';
  end if;
  if public.award_pet_xp(u, 'matching_completed', 'test-one', 30) then
    raise exception 'Duplicate award succeeded';
  end if;
  begin
    insert into public.pet_xp_events(user_id,source_type,source_id,xp_amount)
      values (u,'matching_completed','test-one',30);
    raise exception 'Duplicate event was accepted';
  exception when unique_violation then null;
  end;
  perform public.award_pet_xp(u,'matching_completed','test-two',30);
  select xp into total from public.user_pets where user_id=u;
  select count(*) into n from public.pet_xp_events where user_id=u;
  if total <> 60 or n <> 2 then raise exception 'Ledger and total mismatch'; end if;
  begin
    update public.user_pets set xp=-1 where user_id=u;
    raise exception 'Negative XP accepted';
  exception when check_violation then null;
  end;
  -- A failed total update must also roll back the newly inserted ledger event.
  update public.user_pets set xp=9007199254740991 where user_id=u;
  begin
    perform public.award_pet_xp(u,'matching_completed','test-overflow',30);
    raise exception 'Overflow accepted';
  exception when check_violation then null;
  end;
  if exists(select 1 from public.pet_xp_events where user_id=u and source_id='test-overflow') then
    raise exception 'Failed award left an orphan event';
  end if;
  if has_function_privilege('authenticated','public.award_pet_xp(uuid,text,text,integer)','EXECUTE')
    or has_function_privilege('anon','public.award_pet_xp(uuid,text,text,integer)','EXECUTE') then
    raise exception 'Client can execute award function';
  end if;
  if has_table_privilege('authenticated','public.user_pets','INSERT')
    or has_table_privilege('authenticated','public.pet_xp_events','INSERT') then
    raise exception 'Client can write pet state';
  end if;
end;
$$;
rollback;
