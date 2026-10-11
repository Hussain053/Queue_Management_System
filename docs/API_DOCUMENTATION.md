# QueueLess API reference

Base path: `/api/v1`. The API returns JSON except for report downloads, which return CSV. Errors use `{ "error": { "code": "...", "message": "...", "details": {} } }`.

## Routes

| Method | Path | Access | Purpose |
| --- | --- | --- | --- |
| `GET` | `/health` | Public | Check API and database connectivity. |
| `POST` | `/auth/login` | Public | Create a staff bearer session. |
| `GET` | `/auth/me` | Staff | Return the signed-in staff profile. |
| `DELETE` | `/auth/logout` | Staff | Revoke the current session. |
| `GET` | `/queues` | Staff | List active queues. Admins can request inactive queues with `include_inactive=true`. |
| `GET` | `/queues/:id` | Staff | Return queue details. |
| `GET` | `/queues/:id/dashboard` | Staff | Return today's totals, currently serving and next waiting visit, average duration, and recent activity. |
| `GET` | `/queues/:id/tokens` | Staff | Return today's visits in queue order. Doctors do not receive contact numbers or staff notes. |
| `POST` | `/queues/:id/tokens` | Admin/receptionist | Register a visit. |
| `POST` | `/queues/:id/call_next` | Admin/receptionist | Call the first waiting visit. |
| `PATCH` | `/tokens/:id/complete` | Admin/receptionist | Complete a serving visit. |
| `PATCH` | `/tokens/:id/skip` | Admin/receptionist | Skip a serving visit. |
| `PATCH` | `/tokens/:id/return_to_waiting` | Admin/receptionist | Return a skipped visit to the end of the line. |
| `PATCH` | `/tokens/:id/cancel` | Admin/receptionist | Cancel a waiting visit. |
| `PATCH` | `/queues/:id/settings` | Admin | Update queue name, service type, average duration, or availability. |
| `GET` | `/queues/:id/reports?period=daily\|weekly\|yearly` | Admin | Download current day, week, or year as CSV. |
| `GET` | `/tokens/:public_lookup_token` | Public | Return a privacy-limited customer token status. |
| `GET` | `/display/:queue_id` | Public | Return token numbers and estimates for a waiting-room screen. |

All staff endpoints require `Authorization: Bearer <session-token>`. Login accepts JSON `{ "username": "...", "password": "..." }`. The login response includes a session token and the safe staff profile. Staff roles are `admin`, `doctor`, and `receptionist`.

## Register a visit

Send a JSON request:

```json
{
  "queue_token": {
    "customer_name": "Example Patient",
    "service_type": "Consultation",
    "contact_number": "optional",
    "visit_requirements": "optional",
    "note": "optional staff-only note"
  }
}
```

Registration returns `201 Created` with the new staff visit object and an opaque `public_lookup_token`. Share only the generated customer status link with that customer. A visit name is required; service type is required and limited to 100 characters. Customer name length is 2 to 120 characters.

## Public customer status

`GET /tokens/:public_lookup_token` returns token number, service type, status, people ahead, estimated wait, estimated service time, and current serving token. It does not return the database ID, customer name, contact number, visit requirements, or staff note. Treat lookup tokens as private links because possession of a token grants access to that token's status.

## Public waiting-room display

`GET /display/:queue_id` is unauthenticated so a wall display can load without a staff session. Its response includes the queue/service labels, current serving token number, waiting count, up to six upcoming token numbers, position, estimated wait/time, and update timestamp. It does not include patient names, phone numbers, visit requirements, staff notes, or sequential database IDs. The frontend polls this route every five seconds.

## Responses and errors

| Status | Meaning |
| --- | --- |
| `200` | Request succeeded. |
| `201` | Visit registered. |
| `401` | Missing, expired, or invalid staff session. |
| `403` | Signed-in role is not allowed to perform this action. |
| `404` | Queue or public lookup was not found. |
| `409` | Queue lifecycle conflict, such as calling an empty queue. |
| `422` | Validation error or unsupported report period. |

For a more detailed overview of role boundaries and deployment assumptions, see [Architecture](ARCHITECTURE.md) and [Hosting guide](DEPLOYMENT_GUIDE.md).
