# Backend prompt: List settlement (ShareCart)

Copy the section below and use it as a prompt for implementing the settlement API.

---

## Prompt start

Implement the **settlement** endpoint for the Share Cart app (Laravel). This uses existing list payments to compute who paid how much and who owes whom (equal split).

### 1. Endpoint

**GET /api/lists/{list}/settlement**

- **Auth:** Same as other list endpoints (Sanctum user or guest token with access to that list).
- **Logic:**
  - Load all payments for this list (with user/guest_name).
  - Participants = list owner + all users shared with the list + any guest names that appear in payments.
  - For each participant, sum the amount they paid (from payments where user_id or guest_name matches).
  - Total spent = sum of all payment amounts.
  - Fair share = total_spent / number of participants.
  - For each participant: balance = (amount they paid) − fair_share.  
    Positive balance = they should get money back; negative = they owe.
- **Response:** 200, JSON:
  ```json
  {
    "success": true,
    "data": {
      "total_spent": 85.50,
      "fair_share": 42.75,
      "participants": [
        { "name": "Ali", "spent": 50.00, "balance": 7.25 },
        { "name": "Sara", "spent": 35.50, "balance": -7.25 }
      ]
    }
  }
  ```
  - `total_spent`: total of all payments for this list (float).
  - `fair_share`: total_spent / count(participants) (float).
  - `participants`: array of objects with `name` (string), `spent` (float), `balance` (float).  
    Order does not matter; the app will show “X owes Y” or “X gets back” from balance.

### 2. Participant rules

- Include the **list owner** (user_id of the list) with spent = 0 if they have no payments.
- Include each **shared user** (user_id in list’s shared relationship) with spent = 0 if they have no payments.
- For payments with **user_id**, add that user’s spent to the matching participant.
- For payments with **guest_name** (user_id null), treat as a participant keyed by guest name (e.g. `guest_John`); create one participant per distinct guest_name and sum their payments.

### 3. Edge cases

- If there are no participants, return total_spent = 0, fair_share = 0, participants = [].
- If there are no payments, total_spent = 0, fair_share = 0, each participant has spent = 0 and balance = 0 (or −fair_share if you compute 0/0 as 0).

### 4. Summary

- Add **GET /api/lists/{list}/settlement**.
- Auth: same as GET list / payments (list member or guest token).
- Response: total_spent, fair_share, participants (name, spent, balance).
- You can reuse or refactor your existing `calculateSettlement(GroceryList $list)` if it already implements this logic.

---

## Prompt end
