# Pet MVP

## Contract

Authenticated GET /api/pets/me returns null or a pet profile.
POST accepts only petType (healthy/night/hearty); subsequent selections return 409.
Pet profiles include xp, level, growthStage, levelXp, nextLevelXp,
remainingXp and progress. Level 30 has nextLevelXp=null and progress=1.
Species has no effect on rewards or matching.

## Rewards

PET_XP_REWARDS in pet.service.ts is the only reward configuration.
Closed-to-completed matching awards the author 50 and other participants 30.
A reviewer's first submitted manner rating for a match awards 15.
Other reviews for that same match use the same deduplication key.
No pet means no event is recorded; there is no automatic retroactive backfill.
First-ever join/create bonuses are deferred until a reliable first-ever event
policy (including historical records and retries) is defined.

## Persistence and limitations

Supabase award_pet_xp locks the pet row, inserts a unique event and updates XP
in one transaction. Memory mode records the same event fields, without awaits
inside its mutation. Only the server service role can access the SQL writer.

Existing completion is a participant-authorized status transition, not an
attendance proof. This MVP does not introduce attendance verification.
XP errors are logged without identifiers and do not undo primary actions.
There is no outbox or automatic retry yet; a failed reward can therefore be
missing. A future internal retry must reuse the exact source type/id.
Pet selection cannot be changed or reset through this API.

## Validation and deployment gate

Run server build then smoke:pets (memory-only HTTP and domain tests).
The 202609070002_pet_mvp.sql migration was applied to the development Supabase
project via SQL Editor on 2026-09-08, after checking both tables were absent.
supabase/tests/pet_mvp.sql is a rollback-only SQL test for a disposable/local
Supabase database after migration; live DB constraint and A/B persistence
validation can be repeated locally. Live API/constraint smoke passed using
three disposable accounts via scripts/petSupabasePersistence.cjs, including
matching completion, rating rewards, dedup and level boundaries. Its temporary
data was cleaned up; A/B accounts were not modified. A/B Flutter manual
selection and F5 checks still require the user's confirmation.
Until deployment, real-provider pet requests can fail safely in the pet card;
the app must not substitute a mock pet for a failed real request.
