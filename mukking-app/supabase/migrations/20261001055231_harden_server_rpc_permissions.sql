-- Server-only RPCs trust IDs supplied by server authorization, not end-user JWTs.
-- PUBLIC revocation alone does not remove explicit anon/authenticated grants.
-- Function bodies, owners, signatures and application data remain unchanged.
REVOKE EXECUTE ON FUNCTION public.accept_join_request(text)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.create_or_reuse_chat_room(text, text, text, uuid[], text)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.submit_manner_rating(text, text, text, uuid, uuid, smallint, text[], numeric, text)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.accept_join_request(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.create_or_reuse_chat_room(text, text, text, uuid[], text) TO service_role;
GRANT EXECUTE ON FUNCTION public.submit_manner_rating(text, text, text, uuid, uuid, smallint, text[], numeric, text)
  TO service_role;
