# Backend requirements prompt (Laravel / Share Cart app)

Copy the section below and use it as a prompt for implementing the backend changes.

---

## Prompt start

Implement the following backend changes for the Share Cart app (Laravel).

### 1. Item order / position in database

- Ensure the **list_items** table (or whatever table stores list items) has a column for order, e.g. **`position`** or **`sort_order`** (integer).
- If it does not exist, add a migration:
  - Add `position` (or `sort_order`) as an integer, default e.g. `0`.
  - Optionally backfill existing rows so items keep their current order (e.g. by `id` or `created_at`).

### 2. Reorder API endpoint

Add a new route and controller method:

- **Route:** `POST /api/lists/{list}/items/reorder`
- **Auth:** Same as other list endpoints (Sanctum user or guest token for that list).
- **Request body (JSON):**
  ```json
  {
    "item_ids": [3, 1, 2, 5, 4]
  }
  ```
  `item_ids` = full ordered list of item IDs belonging to that list (no extra IDs, no missing IDs).

- **Validation:**
  - `item_ids` is required and must be an array of integers.
  - Every ID must belong to the given list (authorize / validate).
  - No duplicates allowed.

- **Logic:**
  - Update each item so its `position` (or `sort_order`) equals its index in `item_ids` (e.g. first id → 0, second → 1, …).
  - Return a success response. Optionally return the updated list (e.g. same structure as `GET /api/lists/{list}`) so the app can refresh in one call.

- **Response (example):**
  - Status: `200`
  - Body: `{ "success": true, "message": "Items reordered." }`  
  - Or include `data.list` with the full list detail (same as show endpoint).

### 3. List detail / items in order

- In **GET /api/lists/{list}** (show list with items), ensure items are always returned ordered by `position` (or `sort_order`) ascending, e.g. `orderBy('position')` (or `orderBy('sort_order')`).
- So after reorder, the app gets items in the correct order when it fetches the list.

### 4. Summary

- Add/ensure **position** (or **sort_order**) on list items.
- Add **POST /api/lists/{list}/items/reorder** with body `{ "item_ids": [ ... ] }`.
- Validate and authorize; update positions by index in `item_ids`.
- Return 200 and optionally the updated list.
- Ensure GET list detail returns items ordered by position.

No other new endpoints or backend changes are required for the app’s current pull-to-refresh, search, or offline cache features.

---

## Prompt end
