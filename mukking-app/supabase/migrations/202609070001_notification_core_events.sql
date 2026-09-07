begin;

alter table public.notifications
  add column chat_room_id text references public.chat_rooms(id) on delete set null,
  add column event_key text;

-- Preserve the identity of existing favorite notifications, including read state.
update public.notifications set event_key = matching_post_id
where type = 'favorite_restaurant_party_created';

alter table public.notifications drop constraint notifications_type_check;
alter table public.notifications add constraint notifications_type_check check (
  type in ('favorite_restaurant_party_created', 'join_request_received',
    'join_request_accepted', 'join_request_rejected', 'chat_message_created')
);
alter table public.notifications drop constraint notifications_user_event_unique;
alter table public.notifications add constraint notifications_user_event_unique
  unique (user_id, type, event_key);
alter table public.notifications add constraint notifications_event_key_required
  check (event_key is not null and length(trim(event_key)) > 0);
create index idx_notifications_chat_room_id on public.notifications(chat_room_id);

comment on column public.notifications.event_key is
  'Source event identity: matching post for favorite, join request for join events, message for chat. No message text.';
commit;
