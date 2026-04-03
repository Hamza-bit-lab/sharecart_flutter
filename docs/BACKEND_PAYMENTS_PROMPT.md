# Backend prompt: List payments (ShareCart)

Copy the section below and use it as a prompt for implementing the payments feature.

---

## Prompt start

Implement list payments for the Share Cart app (Laravel).

### 1. Database

- Create table **`list_payments`** (or equivalent name) with:
  - `id` (primary key)
  - `list_id` (foreign key to lists table)
  - `user_id` (nullable; foreign key to users if you have users; for guest lists can be null and track another way if needed)
  - `amount` (decimal, e.g. 10,2)
  - `currency` (string, nullable, e.g. "EUR", "USD")
  - `paid_at` (timestamp, nullable; default to created_at if not set)
  - `created_at`, `updated_at`
- Add migration and model. Ensure only list members (or guest with access to that list) can add/view payments.

### 2. APIs

**POST /api/lists/{list}/payments**

- **Auth:** Same as other list endpoints (Sanctum for logged-in user, or guest token for that list).
- **Body (JSON):**
  ```json
  { "amount": 45.50, "currency": "EUR" }
  ```
  - `amount`: required, numeric, > 0.
  - `currency`: optional string (e.g. "EUR").
- **Logic:** Create a payment row for this list and current user (or guest). Set `paid_at` to now if not sent.
- **Response:** 201 with created payment (id, list_id, user_id, amount, currency, paid_at, created_at). Or 422 for validation/authorization errors.

**GET /api/lists/{list}/payments**

- **Auth:** Same as list endpoints (member or guest with list access).
- **Response:** 200 with list of payments for this list. Each: id, list_id, user_id (if any), amount, currency, paid_at, created_at. Optionally include user name for each. Order e.g. by paid_at desc or created_at desc.

### 3. Summary

- Table `list_payments` with list_id, user_id, amount, currency, paid_at, timestamps.
- POST /api/lists/{list}/payments — add payment (auth + validate amount).
- GET /api/lists/{list}/payments — list payments for that list (auth).

---

## Prompt end
