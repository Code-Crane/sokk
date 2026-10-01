-- Prepared only. Do not apply without explicit approval.
-- Preserve all existing pets, XP, ownership and policies; expand types only.
begin;
alter table public.user_pets
  drop constraint user_pets_pet_type_check,
  add constraint user_pets_pet_type_check
    check (pet_type in ('healthy', 'night', 'hearty', 'dog', 'cat'));
commit;
