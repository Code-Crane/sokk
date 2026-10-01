-- Run as an administrative test connection after the permission migration.
-- Real users are untouched; generated regression fixtures are rolled back.
-- Any unexpected successful call is rolled back by the exception subtransaction.
BEGIN;
DO $test$
DECLARE
  target record;
  test_role text;
  denied_count integer := 0;
BEGIN
  FOR target IN
    SELECT * FROM (VALUES
      ('public.accept_join_request(text)',
       'SELECT public.accept_join_request(''__rpc_permission_fixture_missing__'')', 'P0002'),
      ('public.create_or_reuse_chat_room(text,text,text,uuid[],text)',
       'SELECT public.create_or_reuse_chat_room(''__rpc_permission_fixture_missing__'', ''__rpc_permission_fixture_missing__'', ''TEST permission'', ARRAY[]::uuid[], ''active'')', '23514'),
      ('public.submit_manner_rating(text,text,text,uuid,uuid,smallint,text[],numeric,text)',
       'SELECT public.submit_manner_rating(''__rpc_permission_fixture_missing__'', ''__rpc_permission_fixture_missing__'', ''__rpc_permission_fixture_missing__'', ''00000000-0000-0000-0000-000000000000''::uuid, ''00000000-0000-0000-0000-000000000001''::uuid, 5::smallint, ARRAY[]::text[], 0::numeric, ''meeting_review'')', 'P0002')
    ) AS fixtures(signature, invocation, expected_service_error)
  LOOP
    IF EXISTS (
      SELECT 1 FROM pg_proc p,
        LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
      WHERE p.oid = target.signature::regprocedure
        AND a.grantee = 0 AND a.privilege_type = 'EXECUTE'
    ) THEN
      RAISE EXCEPTION 'PUBLIC can execute %', target.signature;
    END IF;
    FOREACH test_role IN ARRAY ARRAY['anon', 'authenticated'] LOOP
      IF has_function_privilege(test_role, target.signature, 'EXECUTE') THEN
        RAISE EXCEPTION '% can execute %', test_role, target.signature;
      END IF;
      EXECUTE format('SET LOCAL ROLE %I', test_role);
      BEGIN
        EXECUTE target.invocation;
        RAISE EXCEPTION 'Unexpected execution success: %', target.signature;
      EXCEPTION WHEN insufficient_privilege THEN
        denied_count := denied_count + 1;
      END;
      RESET ROLE;
    END LOOP;
    IF NOT has_function_privilege('service_role', target.signature, 'EXECUTE') THEN
      RAISE EXCEPTION 'service_role cannot execute %', target.signature;
    END IF;
    EXECUTE 'SET LOCAL ROLE service_role';
    BEGIN
      EXECUTE target.invocation;
      RAISE EXCEPTION 'Sentinel unexpectedly succeeded: %', target.signature;
    EXCEPTION WHEN OTHERS THEN
      IF SQLSTATE <> target.expected_service_error THEN RAISE; END IF;
    END;
    RESET ROLE;
  END LOOP;
  IF denied_count <> 6 THEN RAISE EXCEPTION 'Expected six denied calls'; END IF;
  RAISE NOTICE 'PASS: six denied RPC calls, three service-role sentinel calls';
END;
$test$;

-- Isolated real-RPC regression fixtures. All rows are removed by ROLLBACK.
DO $regression$
DECLARE
  host_id uuid := gen_random_uuid();
  guest_id uuid := gen_random_uuid();
  other_id uuid := gen_random_uuid();
  marker text := '__rpc_security_fixture_' || gen_random_uuid()::text;
  accepted record;
  first_room jsonb;
  reused_room jsonb;
  rated jsonb;
BEGIN
  INSERT INTO auth.users(id, email) VALUES
    (host_id, host_id::text || '@rpc-fixture.invalid'),
    (guest_id, guest_id::text || '@rpc-fixture.invalid'),
    (other_id, other_id::text || '@rpc-fixture.invalid');
  INSERT INTO public.matching_posts(id, author_id, restaurant_name, address,
    scheduled_at, max_participants, intro)
  VALUES (marker, host_id, 'TEST RPC fixture', 'TEST fixture address',
    now() + interval '1 day', 1, 'TEST rollback only');
  INSERT INTO public.join_requests(id, post_id, requester_id) VALUES
    (marker || '_join', marker, guest_id),
    (marker || '_other_join', marker, other_id);
  INSERT INTO public.pending_evaluations(id, matching_post_id, reviewer_id, reviewee_id)
  VALUES (marker || '_evaluation', marker, host_id, guest_id);

  SET LOCAL ROLE service_role;
  SELECT * INTO accepted FROM public.accept_join_request(marker || '_join');
  IF accepted.request->>'status' <> 'accepted' OR accepted.post->>'status' <> 'closed' THEN
    RAISE EXCEPTION 'Acceptance state regression';
  END IF;
  BEGIN
    PERFORM public.accept_join_request(marker || '_other_join');
    RAISE EXCEPTION 'Full party unexpectedly accepted another request';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  IF (SELECT status FROM public.join_requests WHERE id = marker || '_other_join') <> 'pending' THEN
    RAISE EXCEPTION 'Rejected capacity check changed request state';
  END IF;
  first_room := public.create_or_reuse_chat_room(marker || '_room', marker,
    'TEST RPC room', ARRAY[host_id, guest_id], 'active');
  reused_room := public.create_or_reuse_chat_room(marker || '_room_retry', marker,
    'TEST RPC room', ARRAY[host_id, guest_id], 'active');
  IF first_room->>'id' <> reused_room->>'id' OR
    (SELECT count(*) FROM public.chat_room_participants
      WHERE room_id = first_room->>'id') <> 2 OR
    EXISTS (SELECT 1 FROM public.chat_room_participants
      WHERE room_id = first_room->>'id' AND user_id = other_id) THEN
    RAISE EXCEPTION 'Room reuse/membership regression';
  END IF;
  BEGIN
    PERFORM public.submit_manner_rating(marker || '_bad_rating', marker || '_evaluation',
      marker, host_id, guest_id, 6::smallint, ARRAY[]::text[], 1::numeric, 'meeting_review');
    RAISE EXCEPTION 'Invalid score unexpectedly accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  rated := public.submit_manner_rating(marker || '_rating', marker || '_evaluation',
    marker, host_id, guest_id, 5::smallint, ARRAY['kind'], 1::numeric, 'meeting_review');
  IF (rated->>'next_score')::numeric <> 37.5 OR
    (SELECT manner_score FROM public.user_manner_profiles WHERE user_id = guest_id) <> 37.5 THEN
    RAISE EXCEPTION 'Rating score update regression';
  END IF;
  BEGIN
    PERFORM public.submit_manner_rating(marker || '_duplicate', marker || '_evaluation',
      marker, host_id, guest_id, 5::smallint, ARRAY[]::text[], 1::numeric, 'meeting_review');
    RAISE EXCEPTION 'Duplicate rating unexpectedly accepted';
  EXCEPTION WHEN no_data_found THEN NULL;
  END;
  RESET ROLE;
  RAISE NOTICE 'PASS: service-role acceptance/capacity, room reuse/membership, rating/score/duplicate';
END;
$regression$;
ROLLBACK;
