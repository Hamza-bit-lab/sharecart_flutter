# Backend: Join List by Code – Logged-in User Support

## Problem

Right now **POST /api/lists/join-code** only supports **guest** flow: it returns the list + a guest `access_token` and the message "No account required." When the **mobile app** sends the same request **with Authorization: Bearer &lt;user token&gt;** (logged-in user), the backend should **add that user to the list as a member** instead of returning a guest token. Currently it does not; so when the app then calls **GET /api/lists/{id}** with the user's token, the backend returns **401** because that user was never added to the list.

## Required behaviour

**Endpoint:** `POST /api/lists/join-code`  
**Body:** `{ "code": "XXXXX" }` (optional: `"name"` for guest)

### Case 1: Request **with** Authorization header (logged-in user)

1. Validate the Bearer token and resolve the user.
2. Find the list by the given `code` (e.g. `join_code`).
3. If list not found or code invalid → return 4xx with appropriate message.
4. **Add this user as a member of the list** (same as when you add someone via “share by email” – e.g. attach user to the list’s members/collaborators so they have access).
5. Return **200** with:
   - `success: true`
   - `data: { "list": { ... list object ... } }`
   - **Do not** include `access_token` in the response (the app will keep using the existing user token).
6. After this, **GET /api/lists/{id}** with the same user’s token must return **200** (user is now a member).

### Case 2: Request **without** Authorization (guest)

- Keep current behaviour: create a guest token for that list, return **200** with `data.list` and `data.access_token` so the app can use the guest token for that list only.

## Summary

- **With auth:** add the authenticated user to the list as a member; return list only, no `access_token`.
- **Without auth:** return list + guest `access_token` (current behaviour).

Once this is implemented, a logged-in user can join a list by code from the app and then open that list without getting 401.
