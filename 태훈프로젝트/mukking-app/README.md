# Mukking

Mukking is a neighborhood-based meal companion matching app.

This monorepo contains:

- `mobile`: Expo React Native mobile client
- `server`: Node.js + Express API
- `admin`: Next.js admin web
- `shared`: shared types and utilities

## Phase 1 Scope

- Mock signup/login
- Matching post create/list
- Join request flow
- Accepted join request creates a chat room

## Phase 2 Security Decisions

- New users start as `unverified`; mock PASS verification moves them through `pending` to `verified`.
- Matching creation, join requests, and chat APIs are blocked on the server unless the user is `verified`.
- Completed meetings create pending peer evaluations. A user with pending evaluations cannot create or join a new match.
- Manner score calculation is shared for consistency, but the server is the final authority. Client-side rating helpers are display-only and cannot mutate score.

## Local Development

Install dependencies from the repo root:

```bash
npm install
```

Run the API:

```bash
npm run dev:server
```

Run the mobile app:

```bash
npm run dev:mobile
```

Run the admin web scaffold:

```bash
npm run dev:admin
```
