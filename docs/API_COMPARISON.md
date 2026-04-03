# API vs App – Comparison

## api.php (Laravel API – Flutter app in use)

| Method | Route | api.php | App use |
|--------|--------|---------|---------|
| POST | `/auth/register` | ✅ | ✅ |
| POST | `/auth/login` | ✅ | ✅ |
| POST | `/lists/join-code` | ✅ | ✅ |
| GET | `/auth/me` | ✅ (auth:sanctum) | ✅ |
| POST | `/auth/logout` | ✅ (auth:sanctum) | ✅ |
| GET | `/lists` | ✅ (auth:sanctum) | ✅ |
| POST | `/lists` | ✅ (auth:sanctum) | ✅ |
| PUT/PATCH | `/lists/{list}` | ✅ (auth:sanctum) | ✅ (PATCH) |
| DELETE | `/lists/{list}` | ✅ (auth:sanctum) | ✅ |
| POST | `/lists/{list}/archive` | ✅ (auth:sanctum) | ✅ |
| POST | `/lists/{list}/restore` | ✅ (auth:sanctum) | ✅ |
| POST | `/lists/{list}/share` | ✅ (auth:sanctum) | ❌ app abhi use nahi karti |
| DELETE | `/lists/{list}/share/{user}` | ✅ (auth:sanctum) | ❌ app abhi use nahi karti |
| GET | `/suggestions` | ✅ (auth:sanctum) | ❌ app abhi use nahi karti |
| GET | `/lists/{list}` | ✅ (list.access.api) | ✅ |
| POST | `/lists/{list}/reset-items` | ✅ (list.access.api) | ❌ app abhi use nahi karti |
| POST | `/lists/{list}/items` | ✅ (list.access.api) | ✅ |
| PUT/PATCH | `/lists/{list}/items/{item}` | ✅ (list.access.api) | ✅ (PATCH) |
| DELETE | `/lists/{list}/items/{item}` | ✅ (list.access.api) | ✅ |

---

## api.php mein koi route missing nahi

Jo bhi APIs Flutter app abhi call karti hain, wo sab **api.php** mein maujood hain. Koi **missing API** nahi hai.

---

## App mein kya add ho chuka hai (implemented)

- **Auth:** Register, Login, Me, Logout  
- **Join by code:** POST `/lists/join-code` (guest token + list)  
- **Lists:** Index (GET `/lists`), Create (POST `/lists`), Update (PATCH), Delete, Archive, Restore  
- **List detail:** GET `/lists/{list}` (auth ya guest token dono se)  
- **Items:** Add (POST), Update (PATCH – name, quantity, completed), Delete  

---

## App mein abhi use nahi ho raha (baaki)

| API | api.php | App | Note |
|-----|---------|-----|------|
| `POST /lists/{list}/share` | ✅ | ❌ | List share karne ka UI/flow app mein nahi |
| `DELETE /lists/{list}/share/{user}` | ✅ | ❌ | Unshare ka UI/flow app mein nahi |
| `GET /suggestions` | ✅ | ❌ | Suggestions (common items) app mein nahi |
| `POST /lists/{list}/reset-items` | ✅ | ❌ | Reset items (sab clear) app mein nahi |

Jab ye features app mein add karoge tab in routes ko use kar sakte ho; backend ready hai.

---

## web.php vs api.php (difference)

- **web.php** = browser / Laravel web app (session, views, invite link, join form, poll, guest-name session).
- **api.php** = Flutter/mobile app ke liye JSON API (Sanctum token, guest token from join-code).

Web-only (web.php) jo api.php mein nahi, aur app ko zaroori nahi:

| web.php | api.php | App need |
|---------|---------|----------|
| `GET /lists/join/{token}` | N/A | N/A (app join by **code** use karti hai) |
| `GET/POST /join` (form) | N/A | N/A (app direct POST `/api/lists/join-code` call karti hai) |
| `POST /lists/{list}/guest-name` | N/A | N/A (guest name join-code request mein bhejti hai) |
| `GET /lists/{list}/poll` | N/A | N/A (app abhi poll use nahi karti) |

---

## Short summary

1. **Missing API:** Koi nahi – app jo use karti hai sab api.php mein hai.  
2. **App mein add ho chuka:** Auth, join-by-code, lists CRUD, list detail, items CRUD (add/update/delete).  
3. **Baaki (backend ready, app mein abhi nahi):** Share/Unshare, Suggestions, Reset items.  
4. **web.php:** Web app ke liye; Flutter app ke liye sirf **api.php** use ho rahi hai, dono ka comparison above table se clear hai.
