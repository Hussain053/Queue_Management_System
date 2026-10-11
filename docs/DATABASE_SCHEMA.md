# Database schema

## queues

`id`, `name`, `service_type`, `average_service_duration_minutes` (positive, default 10), `active`, timestamps.

Rails maps this table to the `ServiceQueue` model to avoid a collision with Ruby's built-in `Queue` constant.

## queue_tokens

`id`, `queue_id` (foreign key), `service_date` (ISO date), `sequence_number` (positive daily sequence), `token_number`, `customer_name`, optional `contact_number`, unique random `public_lookup_token`, `service_type`, `status`, `joined_at`, optional `called_at`, `service_started_at`, `completed_at`, optional private `note`, timestamps.

Unique index on `(queue_id, service_date, sequence_number)` protects daily token allocation. A unique lookup index protects public identifiers. Status and positive average duration have database check constraints. Queue deletion is restricted when tokens exist. Daily values currently follow the application server date/time zone.
