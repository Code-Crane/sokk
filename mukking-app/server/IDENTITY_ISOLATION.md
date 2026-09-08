# Identity isolation: Phase 2-A

Production must explicitly use `NODE_ENV=production`, `AUTH_PROVIDER=supabase`
and `REPOSITORY_PROVIDER=supabase`. Missing/empty/unknown providers fail startup.
Unknown explicit provider or runtime values also fail in development/test to
prevent typo-driven fallback; omitted development/test settings retain defaults.

Production requires an HTTPS `SUPABASE_URL`, nonempty `SUPABASE_ANON_KEY` and
`SUPABASE_SERVICE_ROLE_KEY`. These checks do not establish key validity or replace
deployment secret management. Do not put actual credentials in this document.
`ADMIN_REQUIRE_MFA` defaults to true and cannot be disabled in production.
Existing read-only administrator MFA policy is unchanged.

`MOCK_VERIFICATION_ENABLED` defaults to true only in development/test. Explicit
true in production fails startup. Production does not mount any verification/mock
POST routes, and all three mock service methods independently reject execution.
Signed mock JWT signing/verification also rejects production use.

The shared verification policy permits existing development/test mock profiles.
Production requires a verified profile plus a same-user, verified `pass` claim
with a valid verification timestamp. Missing, mock and unknown claims fail closed.
`pass` is an existing schema value reserved for future real integration: accepting
a controlled fixture is not proof that a real provider is currently integrated.
No real-provider endpoint is added and no stored mock claim is converted.

New approvals recheck the requester's matching eligibility, including verification,
sanctions, pending evaluations and manner score. Existing block, request-state and
repository capacity checks remain. Already-accepted requests retain idempotent
chat recovery; this does not bypass the verification checks on chat access/send.
Eligibility reads and acceptance remain separate operations; transactional policy
revalidation under concurrent revocation is a future hardening consideration.

The verification status API retains the stored status for backward compatibility;
its canUseMatching/canUseChat flags now apply environment-specific verification
policy. These flags do not represent a complete sanctions/interaction assessment.
The existing Flutter badge may still describe stored mock status as verified;
real-provider UX must distinguish that before production release.

## Local validation (no live data)

Run server typecheck/build, then `pnpm --filter @mukking/server run smoke:identity-isolation`.
The smoke prevents dotenv loading, uses synthetic configuration in child processes,
substitutes memory repositories only inside its test process, and refuses external
fetches. It exercises production startup failures, HTTP 404, direct service guards,
provider eligibility, admin MFA/whitelist, and revoked-requester approval/recovery.
Run existing memory profile/matching/chat/recovery/notification/pet/rating smokes
for regression. No Supabase rows or A/B account states are changed.
