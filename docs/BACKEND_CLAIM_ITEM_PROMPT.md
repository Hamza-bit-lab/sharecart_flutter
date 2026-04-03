# Claim item – feature explanation & backend prompt

## What is “Claim item”?

When several people share one list (e.g. family, roommates), the same item can get bought twice (e.g. both buy “Milk”).

**Claim item** = someone taps **“I’ll buy this”** on an item. That item is then **claimed** by that person. Others see e.g. “Ali will buy this” and don’t buy the same thing. One person per item; no duplicate buying.

- **Claim:** user (or guest) says “I’ll buy this” → we store who claimed it.
- **Unclaim:** that person (or maybe list owner) can clear the claim so someone else can take it or it’s unassigned again.

So: backend needs to store **who claimed which item** (and optionally when), and expose **claim** / **unclaim** APIs. List detail (with items) should return claim info so the app can show “X will buy this”.

---

## Backend prompt (Laravel)

Copy the section below and use it as a prompt for implementing the claim-item feature.

---

## Prompt start

Implement **claim item** for the Share Cart app (Laravel): a list item can be “claimed” by one user (or guest) so others know who will buy it.

### 1. Database (list items table)

On the **list items** table (e.g. `list_items` or `items`), add:

- **`claimed_by_user_id`** – nullable, foreign key to `users`. Set when a logged-in user claims the item; null when unclaimed.
- **`claimed_by_name`** – nullable string. For **guests** (no user_id), store a display name here when they claim; null when unclaimed.
- **`claimed_at`** – nullable timestamp. When the item was claimed (optional but useful).

Only one of `claimed_by_user_id` or `claimed_by_name` is set at a time (logged-in user sets user_id and leaves name null; guest sets name and leaves user_id null). When unclaiming, clear both and set `claimed_at` to null.

### 2. APIs

**Claim an item**

- **Route:** `POST /api/lists/{list}/items/{item}/claim`
- **Auth:** Same as other list item endpoints (Sanctum user or guest token for that list).
- **Body:** Empty, or optional `{}`. The backend uses the current user (or guest token’s display name) as the claimer.
- **Logic:**
  - Ensure the item belongs to the list.
  - Set `claimed_by_user_id` = current user’s id (if logged in), else null.
  - Set `claimed_by_name` = guest display name (if guest), else null.
  - Set `claimed_at` = now().
  - Save and return the updated item (or 200 with message).
- **Response:** 200 with updated item in the usual list-item shape, including `claimed_by_user_id`, `claimed_by_name`, `claimed_at` so the app can show “X will buy this”.

**Unclaim an item**

- **Route:** `POST /api/lists/{list}/items/{item}/unclaim` or `DELETE /api/lists/{list}/items/{item}/claim`
- **Auth:** Same as above.
- **Logic:**
  - Ensure the item belongs to the list.
  - Optional: only the user who claimed it (or the list owner) can unclaim. Otherwise any list member can unclaim.
  - Set `claimed_by_user_id` = null, `claimed_by_name` = null, `claimed_at` = null. Save.
- **Response:** 200 with updated item (or success message).

### 3. List detail (GET list with items)

In **GET /api/lists/{list}** (or wherever list items are returned), include claim info on each item, for example:

- **`claimed_by_user_id`** – nullable int.
- **`claimed_by_name`** – nullable string (for guests, or resolved user name for display).
- **`claimed_at`** – nullable ISO timestamp.

So the app can show “Ali will buy this” (using `claimed_by_name` or the user’s name from `claimed_by_user_id`).

### 4. Summary

- Add columns to list items: `claimed_by_user_id`, `claimed_by_name`, `claimed_at`.
- **POST …/items/{item}/claim** – set claim to current user or guest.
- **POST …/items/{item}/unclaim** (or DELETE …/claim) – clear claim.
- Return claim fields in list detail (items) so the app can show who claimed each item.

---

## Prompt end
