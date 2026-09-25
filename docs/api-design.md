# API Design

## Status and scope of this document

This is a design contract, not an implementation. No server, framework, dependency, or request handler exists in this repository. The document is written so that a team could implement the MVP without re-deciding product or database semantics.

Everything here is subordinate to three existing sources of truth:

- `docs/requirements.md` for product scope, roles, and the five important user actions.
- `docs/data-model.md` and `database/migrations/001_initial_schema.sql` for fields, constraints, indexes, and triggers.
- `docs/state-machine.md` for the rental lifecycle.

Where this document states a rule that the database does not enforce, the rule is labelled **API-layer rule**. Where the database is the authority, the rule is labelled **database-enforced** and cites the exact object.

Out of scope for this contract: implementation, authentication implementation, frontend, refunds, a general ledger, and a payment-provider integration.

## Resource map

| Method and path | Role | Purpose |
| --- | --- | --- |
| `GET /api/v1/me` | any authenticated | Resolve the calling principal and role. |
| `GET /api/v1/users` | `STAFF`, `ADMIN` | List user accounts. |
| `GET /api/v1/users/{userId}` | self, `STAFF`, `ADMIN` | Read one user. |
| `POST /api/v1/users` | `ADMIN` | Create a user in a single role. |
| `PATCH /api/v1/users/{userId}` | self, `ADMIN` | Update `displayName`; `role` for `ADMIN` only. |
| `DELETE /api/v1/users/{userId}` | `ADMIN` | Soft-delete a user account. |
| `GET /api/v1/categories` | any authenticated | List categories. |
| `POST /api/v1/categories` | `STAFF`, `ADMIN` | Create a category. |
| `GET /api/v1/categories/{categoryId}` | any authenticated | Read one category. |
| `PATCH /api/v1/categories/{categoryId}` | `STAFF`, `ADMIN` | Update category name or slug. |
| `GET /api/v1/equipment` | any authenticated | Browse the catalogue. |
| `GET /api/v1/equipment/availability` | any authenticated | Action A2. Equipment with units free for `[startAt, endAt)`. |
| `GET /api/v1/equipment/{equipmentId}` | any authenticated | Equipment detail, optionally with a period availability summary. |
| `POST /api/v1/equipment` | `STAFF`, `ADMIN` | Action A1. Create a rentable model. |
| `PATCH /api/v1/equipment/{equipmentId}` | `STAFF`, `ADMIN` | Update descriptive fields, rate, or catalogue status. |
| `DELETE /api/v1/equipment/{equipmentId}` | `STAFF`, `ADMIN` | Soft-delete a model. |
| `GET /api/v1/equipment-units` | any authenticated | Search physical units across models. |
| `GET /api/v1/equipment-units/{unitId}` | `STAFF`, `ADMIN` | Read one unit. |
| `POST /api/v1/equipment/{equipmentId}/units` | `STAFF`, `ADMIN` | Action A1. Register a physical unit. |
| `PATCH /api/v1/equipment-units/{unitId}` | `STAFF`, `ADMIN` | Change unit operational status or serial number. |
| `DELETE /api/v1/equipment-units/{unitId}` | `STAFF`, `ADMIN` | Soft-delete a unit. |
| `GET /api/v1/rentals` | `CUSTOMER` (own), `STAFF`, `ADMIN` | List rentals. |
| `GET /api/v1/rentals/{rentalId}` | owner, `STAFF`, `ADMIN` | Read a rental with selective `include` expansion. |
| `POST /api/v1/rentals` | `CUSTOMER`; `STAFF`, `ADMIN` may name a `customerId` | Action A3. Reserve units for a period. |
| `POST /api/v1/rentals/{rentalId}/transitions` | see transition matrix | Action A4. Advance the lifecycle by one legal edge. |
| `GET /api/v1/rentals/{rentalId}/operations` | `STAFF`, `ADMIN` | Action A4. Checkout and return working view. |
| `GET /api/v1/rental-items` | owner, `STAFF`, `ADMIN` | Unit-centric or rental-centric item lookup. |
| `GET /api/v1/inspections` | owner, `STAFF`, `ADMIN` | List inspections. |
| `POST /api/v1/rentals/{rentalId}/items/{rentalItemId}/inspections` | `STAFF`, `ADMIN` | Action A4. Record a `CHECK_OUT` or `RETURN` inspection. |
| `PATCH /api/v1/inspections/{inspectionId}` | `STAFF`, `ADMIN` | Correct condition or notes. |
| `GET /api/v1/charges` | owner, `STAFF`, `ADMIN` | List additional charges. |
| `POST /api/v1/rentals/{rentalId}/charges` | `STAFF`, `ADMIN` | Record a `DAMAGE` charge. |
| `GET /api/v1/payments` | owner, `STAFF`, `ADMIN` | List payment records. |
| `POST /api/v1/rentals/{rentalId}/payments` | owner, `ADMIN` | Action A5. Record a payment. |
| `GET /api/v1/rentals/{rentalId}/payment-summary` | owner, `STAFF`, `ADMIN` | Action A5. Derived money summary. |

### Operations deliberately not offered

| Operation | Decision |
| --- | --- |
| `PATCH /api/v1/rentals/{rentalId}` for status | Never. `POST /transitions` is the only lifecycle mutation. |
| `PATCH /api/v1/rentals/{rentalId}` for `startAt`, `endAt`, `baseAmount`, `customerId` | Never. These are immutable after creation. Cancellation is the alternative. |
| `DELETE /api/v1/rentals/{rentalId}` | Never. `PENDING`/`CONFIRMED`/`READY_FOR_PICKUP` to `CANCELLED` through `/transitions`. |
| `POST` or `PATCH` on `/api/v1/rental-items` | Never. Items exist only as the output of the reservation transaction. |
| `DELETE /api/v1/inspections`, `/charges`, `/payments` | Never. Financial and condition records are historical. |
| `PATCH /api/v1/payments/{paymentId}` | Never. `Payment.status` changes only through a future provider-reconciliation contract. |
| `DELETE /api/v1/categories/{categoryId}` | Never. `categories` has no soft-delete column, and product scope does not require category removal. |
| `POST /api/v1/rentals/{rentalId}/charges` with `type = LATE_FEE` | Rejected with `UNSUPPORTED_CHARGE_TYPE`. Late fees belong to the future overdue job. |
| Restore endpoints for soft-deleted rows | Out of scope. See soft-deletion rules. |

## Conventions

### Transport

- Base path `/api/v1`. Version lives in the path; breaking changes create `/api/v2`.
- Request and response media type `application/json; charset=utf-8`. No cookies, no HTML.
- UUID identifiers are lowercase hyphenated strings matching `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`.
- JSON field names are camelCase and map one-to-one to the snake_case columns in `docs/data-model.md`.
- Unknown request properties are rejected with `400 INVALID_REQUEST`, so client typos and idempotency fingerprints fail loudly.
- Every response carries `X-Request-Id`. The server generates it when the client omits it, echoes it in error bodies, and includes it in logs.

### Time

- Timestamps are ISO 8601 with an explicit offset, normalized to UTC and serialized as `2030-03-01T09:00:00Z`.
- Requests may send any valid offset; the server converts to `TIMESTAMPTZ` and returns UTC.
- Fractional seconds are accepted and stored, but responses drop microseconds for readability.
- Rental periods are half-open `[startAt, endAt)`. A period where `endAt <= startAt` is `422 INVALID_PERIOD`.
- No wall-clock arithmetic happens in the API for overlap decisions. The database trigger is the authority.

### Money

- Money is an integer count of minor units, serialized as a JSON integer, always paired with `currency`.
- JSON integers are capped at `9007199254740991` (2^53-1) so JavaScript clients cannot silently lose precision. Larger or fractional values are `400 INVALID_REQUEST`.
- `currency` is an uppercase three-letter code, matching database-enforced `currency ~ '^[A-Z]{3}$'`.
- `baseAmount`, `dailyRateAmount`, and charge amounts are non-negative; charge and payment amounts are strictly positive. All are database-enforced `CHECK` constraints.
- No stored total exists. Totals are derived on read, exactly as in `database/queries/05_payment_summary.sql`.

### Base amount policy

The schema stores an authoritative `Rental.baseAmount` but does not define a billing period arithmetic, so the API must. This contract adopts:

```text
billableDays  = max(1, ceil((endAt - startAt) / 24 hours))
baseAmount    = billableDays * equipment.dailyRateAmount * quantity
```

- Rounding is always up to the next whole 24-hour block, never down, and never less than one day, so a period of a few minutes is not free. There is no half-day or half-up rule: a block either counts or does not.
- The currency is taken from the equipment catalogue record. Clients never send `currency` on `POST /api/v1/rentals`, which makes cross-currency rentals unrepresentable.
- A quantity of `2` for one model produces two `rental_items` rows, two distinct units, and a doubled `baseAmount`.
- The literal `550000` in `database/queries/03_create_rental.sql` is a demonstration value inserted directly, not a computed result of this policy. Any team that needs a different billing rule (calendar days, 24-hour blocks with a different rounding, per-model minimums) must change this section, not the schema.

### Field-level validation limits

These are API-layer limits for predictable payloads. The database columns are unbounded `TEXT`.

| Field | Maximum length | Rejection |
| --- | --- | --- |
| `displayName` | 200 | `400 INVALID_REQUEST` |
| `category.name` | 200 | `400 INVALID_REQUEST` |
| `equipment.name` | 200 | `400 INVALID_REQUEST` |
| `equipment.description` | 5000 | `400 INVALID_REQUEST` |
| `inspection.notes` | 5000 | `400 INVALID_REQUEST` |
| `charge.description` | 5000 | `400 INVALID_REQUEST` |
| `assetTag` | 100 | `400 INVALID_REQUEST` |
| `serialNumber` | 100 | `400 INVALID_REQUEST` |
| `Idempotency-Key` | 255 | `400 IDEMPOTENCY_KEY_INVALID` |

Request bodies are limited to 64 KiB. `quantity` is limited to `1..50` as an API-layer guard against oversized reservations; the effective ceiling is always availability.

### Response shapes

Single resource:

```json
{
  "data": {
    "id": "a0000000-0000-4000-8000-000000000001",
    "name": "Generators",
    "slug": "generators",
    "createdAt": "2030-01-05T08:00:00Z",
    "updatedAt": "2030-01-05T08:00:00Z"
  }
}
```

Collection:

```json
{
  "data": [ { "id": "..." } ],
  "page": {
    "limit": 20,
    "nextCursor": "eyJ2IjoxLCJzIjoibmFtZSIsImQiOiI5MDAuLi4ifQ",
    "hasMore": true
  }
}
```

`nextCursor` is `null` on the last page. `hasMore` lets a client distinguish "exactly at the end" from "cursor expired" without an extra request.

### Error envelope

```json
{
  "error": {
    "code": "EQUIPMENT_UNAVAILABLE",
    "message": "Only 1 of 2 requested units is free for the requested period.",
    "status": 409,
    "requestId": "0f9c1f7e-6a1b-4f0e-9a52-6b1d2c4e8a10",
    "details": [
      { "field": "quantity", "issue": "only 1 unit is available" }
    ]
  }
}
```

- `code` is a stable machine-readable constant. Clients branch on `code`, never on `message`.
- `message` is human-readable English and may change without notice.
- `details` is optional and always an array of `{ field, issue }`.
- No stack trace, SQL fragment, or constraint name is ever returned.

### HTTP status policy

| Status | Meaning here |
| --- | --- |
| `200` | Successful read or update. |
| `201` | Resource created. `Location` header plus the created representation. |
| `204` | Successful soft delete with no body. |
| `400` | Malformed or unreadable request: bad JSON, unknown property, bad type, missing `Idempotency-Key`, out-of-range value, malformed period syntax. |
| `401` | No authenticated principal. |
| `403` | Authenticated but not permitted, including calling a role-forbidden transition. |
| `404` | Resource absent, or soft-deleted and therefore invisible to this caller. |
| `409` | Current state or concurrency conflict: illegal transition, overlap, duplicate unique value, idempotency replay conflict, delete of a resource still in use. |
| `422` | Well-formed request that violates a business rule: impossible period, currency mismatch, unsupported charge type. |
| `500` | Unexpected fault. Body carries `code: INTERNAL_ERROR` and a `requestId` only. |
| `503` | Transient database contention that survived internal retries. Includes `Retry-After`. |

The dividing line is deliberate: `409` means "the world has moved since you read it, re-read and decide", `422` means "your request is well-formed but this business cannot be satisfied".

## Error catalog

| Code | Status | Raised when | Database origin |
| --- | --- | --- | --- |
| `INVALID_REQUEST` | 400 | Body, query, or path fails schema validation. | none |
| `INVALID_PERIOD` | 422 | `endAt <= startAt`. This is the only period rule the contract defines; the model sets no booking horizon, lead-time, or maximum-length limit, and none should be inferred. | mirrors `rentals_period_valid` |
| `INVALID_CURSOR` | 400 | Cursor is unreadable, of an unknown version, or does not match the request's filters and sort. | none |
| `IDEMPOTENCY_KEY_REQUIRED` | 400 | A required endpoint was called without the header. | none |
| `IDEMPOTENCY_KEY_INVALID` | 400 | Header is empty, malformed, or too long. | none |
| `IDEMPOTENCY_KEY_CONFLICT` | 409 | The same key is still in flight for a concurrent request. | none |
| `IDEMPOTENCY_KEY_REUSED` | 409 | The same key was replayed with a materially different request. | none |
| `UNAUTHENTICATED` | 401 | No principal. | none |
| `FORBIDDEN` | 403 | Role or ownership check fails. | none |
| `NOT_FOUND` | 404 | Row absent or invisible because of soft deletion. | none |
| `EQUIPMENT_UNAVAILABLE` | 409 | Fewer than `quantity` units are free for `[startAt, endAt)`. | `rental_items_enforce_availability` raising `23P01` |
| `INVALID_RENTAL_TRANSITION` | 409 | Requested edge is not in `docs/state-machine.md`. | `rentals_enforce_status_transition` raising `23514` |
| `DUPLICATE_INSPECTION` | 409 | A `CHECK_OUT` or `RETURN` inspection already exists for the item. | `inspections_rental_item_type_key` |
| `DUPLICATE_PROVIDER_REFERENCE` | 409 | `providerReference` already recorded. | `payments_provider_reference_key` |
| `DUPLICATE_VALUE` | 409 | A unique identifier is taken: email, slug, asset tag, serial number, or a repeated unit in one rental. | `users_email_lower_uidx`, `categories_slug_lower_uidx`, `equipment_units_asset_tag_key`, `equipment_units_serial_number_key`, `rental_items_rental_equipment_unit_key` |
| `CURRENCY_MISMATCH` | 422 | A child currency does not equal the parent rental currency. | composite `(rental_id, currency)` foreign keys |
| `EQUIPMENT_IN_USE` | 409 | Soft delete attempted while a reserving rental still needs the model or its units. | none, API-layer rule |
| `UNSUPPORTED_CHARGE_TYPE` | 422 | `LATE_FEE` submitted through the charges endpoint. | `charge_type` enum |
| `INVALID_STATUS_VALUE` | 400 | An enum-valued field is outside the defined domain. | `rental_status`, `payment_status`, and other enums |
| `SERVICE_UNAVAILABLE` | 503 | Retries of serialization or deadlock failures were exhausted. | SQLSTATE `40001`, `40P01` |
| `INTERNAL_ERROR` | 500 | Unmapped fault. | any |

### Translating database failures

The current triggers use generic SQLSTATE codes: the overlap function raises `23P01` (`exclusion_violation`) and the status trigger raises `23514` (`check_violation`), both with plain-text messages. Mapping by SQLSTATE alone is ambiguous, because `23514` also covers ordinary `CHECK` violations, and message text is not a stable contract.

The API therefore maps failures by constraint name from `pg_constraint` context, falling back to message matching, and it must:

1. Retry serialization failures (`40001`) and deadlocks (`40P01`) up to three times as whole transactions, then return `503`.
2. Run allocation and item writes in one `READ COMMITTED` transaction, as the trigger requires. A different isolation level raises a plain exception and must never be used.
3. Translate `23505` unique violations by constraint name to the specific `DUPLICATE_*` code.
4. Translate `23P01` from overlap enforcement to `EQUIPMENT_UNAVAILABLE`, and `23514` from the rental status trigger to `INVALID_RENTAL_TRANSITION`.
5. Translate composite currency foreign-key violations (`23503` on `*_rental_currency_fk`) to `CURRENCY_MISMATCH`.

**Required follow-up migration.** The first implementation migration should raise stable custom SQLSTATEs (for example `R001` for overlap and `R002` for a forbidden transition) so error mapping does not depend on English message text. This contract does not change the existing migration.

## Pagination and list conventions

Every collection endpoint uses opaque keyset pagination. Offset pagination is not offered.

| Aspect | Rule |
| --- | --- |
| Parameters | `limit` and `cursor`. `limit` default `20`, range `1..100`; out of range is `400 INVALID_REQUEST`. |
| Cursor content | base64url of a signed, versioned tuple of the sort field value and the `id` UUID. |
| Opaqueness | Clients must not parse or construct cursors. The signature prevents tampering. |
| Sort | One `sort` value from a fixed per-endpoint allowlist. |
| Tie-break | Every query appends `id` ascending as the final sort term, so ordering is total and stable. |
| Filter coupling | A cursor is bound to the filter set. Reusing a cursor with different filters is `400 INVALID_CURSOR` rather than silently wrong results. |
| Insertion during paging | Keyset paging does not skip or repeat rows when rows are inserted later in the sort order. Rows inserted before the cursor position are not seen in that pass, which is the accepted trade-off. |
| Envelope | `page.limit`, `page.nextCursor`, `page.hasMore`. |

`hasMore` is computed by requesting `limit + 1` rows and discarding the extra.

### Per-entity list contracts

| Endpoint | Filters | Allowed sorts (default first) | Soft-deleted rows |
| --- | --- | --- | --- |
| `GET /api/v1/users` | `role`, `q` (case-insensitive substring of `displayName`) | `createdAt` (default, desc), `displayName`, `email` | Hidden unless `includeDeleted=true`, which requires `ADMIN`. |
| `GET /api/v1/categories` | `q` (substring of `name`) | `name` (default), `createdAt` | Not applicable; no soft-delete column. |
| `GET /api/v1/equipment` | `categoryId`, `categorySlug`, `status`, `currency`, `minDailyRate`, `maxDailyRate`, `q` (name and description), `availableFrom` with `availableTo` | `name` (default), `dailyRate`, `createdAt` | Hidden unless `includeDeleted=true` (`STAFF` or `ADMIN`). |
| `GET /api/v1/equipment/availability` | `startAt` and `endAt` required, `categorySlug`, `currency`, `includeUnits` | `equipmentName` (default), `availableUnitCount`, `dailyRate` | Never; deleted equipment and units are excluded by definition. |
| `GET /api/v1/equipment-units` | `equipmentId`, `status`, `assetTag`, `serialNumber` | `assetTag` (default), `status`, `createdAt` | Hidden unless `includeDeleted=true` (`STAFF` or `ADMIN`). |
| `GET /api/v1/rentals` | `status` (repeatable), `customerId`, `equipmentId`, `overlapsFrom` with `overlapsTo`, `createdFrom` with `createdTo`, `outstanding` (`true` means `balance > 0`) | `createdAt` (default, desc), `startAt`, `endAt`, `status` | Not applicable. |
| `GET /api/v1/rental-items` | `rentalId`, `equipmentUnitId`, `equipmentId` | `createdAt` (default), `equipmentName` (the snapshot) | Not applicable. |
| `GET /api/v1/inspections` | `rentalId`, `rentalItemId`, `type`, `condition`, `inspectedBy`, `inspectedFrom` with `inspectedTo` | `inspectedAt` (default, desc), `type` | Not applicable. |
| `GET /api/v1/charges` | `rentalId`, `type` | `createdAt` (default, desc), `amount` | Not applicable. |
| `GET /api/v1/payments` | `rentalId`, `status`, `providerReference`, `paidFrom` with `paidTo` | `createdAt` (default, desc), `paidAt` | Not applicable. |

Notes on the harder filters:

- `availableFrom` with `availableTo` on `/api/v1/equipment` is the same predicate set as `/api/v1/equipment/availability`; it exists so a catalogue browser can show a badge without a second request. Supplying only one of the pair is `400 INVALID_REQUEST`.
- `overlapsFrom` with `overlapsTo` on `/api/v1/rentals` matches any rental whose period intersects the window, using `startAt < overlapsTo` and `overlapsFrom < endAt`. Supplying only one is `400 INVALID_REQUEST`.
- `outstanding=true` is computed from the payment summary and is therefore not index-only. It is acceptable for an MVP and should become a materialised view or a denormalised column only if measurement demands it.
- Sorting by `availableUnitCount` sorts on a derived value, so it cannot use a plain b-tree index. The derived `outstanding` filter has the same cost even though it is not sortable.

## Idempotency

`POST /api/v1/rentals` and `POST /api/v1/rentals/{rentalId}/payments` require the `Idempotency-Key` request header. Other POSTs are already protected by natural uniqueness and only need it defensively.

| Property | Rule |
| --- | --- |
| Header | `Idempotency-Key`, 1 to 255 printable ASCII characters. |
| Scope | The unique key is `(actorId, method, routeTemplate, idempotencyKey)`. Two different users may reuse the same key value safely. |
| Fingerprint | SHA-256 over canonical JSON of the path parameters, the relevant query parameters, and the body, with object keys sorted. |
| Same key, same fingerprint, completed | The stored status code, body, and `Location` are replayed verbatim, with `Idempotency-Replayed: true` added. |
| Same key, different fingerprint | `409 IDEMPOTENCY_KEY_REUSED`. The stored response is untouched. |
| Same key, still in flight | `409 IDEMPOTENCY_KEY_CONFLICT` with `Retry-After`. |
| Retention, success | Default 7 days, configurable. A replay after expiry is treated as a new request. |
| Retention, server fault | 24 hours for 5xx outcomes, so a client that fixed nothing can retry with the same key. |
| Key lifetime rules | Keys are never reused for a different intent by the server. Clients should generate one key per logical operation and keep it across retries of that operation. |

What idempotency does not do:

- It does not replace `payments_provider_reference_key`. A key stops duplicate API calls; provider-reference uniqueness stops duplicate transaction records reaching the database. Both are required.
- It does not protect `PATCH` or `DELETE`, which are naturally repeatable in effect.
- It does not make a replayed non-idempotent side effect safe after the retention window.

**Storage gap.** The schema in `database/migrations/001_initial_schema.sql` has no idempotency table. Implementing this contract requires a new table, for example `api_idempotency_keys(actor_id, method, route, key, request_fingerprint, response_status, response_body, created_at, completed_at)`, with a unique index on the first four columns, written in the same transaction as the business change so a committed mutation always has a recorded response. This is the first implementation migration; it is specified here so the endpoints are not designed around an unstated assumption.

## Authorization

Authentication is not implemented. This table is the contract the future server must enforce, based on the single `users.role` column.

| Operation | `CUSTOMER` | `STAFF` | `ADMIN` |
| --- | --- | --- | --- |
| `GET /api/v1/me` | own record | own record | own record |
| `GET` catalogue, availability, and the unit list | allowed | allowed | allowed |
| `GET /api/v1/equipment-units/{unitId}` | `403 FORBIDDEN` | allowed | allowed |
| `POST`/`PATCH`/`DELETE` equipment, units, categories | `403 FORBIDDEN` | allowed | allowed |
| `GET /api/v1/users` | `403 FORBIDDEN` | allowed | allowed |
| `POST /api/v1/users`, role changes | `403 FORBIDDEN` | `403 FORBIDDEN` | allowed |
| `PATCH` own `displayName` | allowed | allowed | allowed |
| `DELETE /api/v1/users/{userId}` | `403 FORBIDDEN` | `403 FORBIDDEN` | allowed |
| `GET /api/v1/rentals`, rental detail, items, inspections, charges, payments, summary | own rentals only | all rentals | all rentals |
| `POST /api/v1/rentals` | allowed | allowed on behalf of a `customerId` they name | allowed on behalf of a `customerId` they name |
| `POST /api/v1/rentals/{rentalId}/transitions` | cancellation edges on own rental only | all edges except `-> OVERDUE` | all edges except `-> OVERDUE` |
| `POST` inspections, charges | `403 FORBIDDEN` | allowed | allowed |
| `POST` payments | own rental | `403 FORBIDDEN` | any rental |
| `GET /api/v1/rentals/{rentalId}/operations` | `403 FORBIDDEN` | allowed | allowed |

Ownership is `rentals.customer_id`. A `CUSTOMER` passing another customer's rental id receives `404 NOT_FOUND`, not `403`, so the API does not confirm the existence of other customers' rentals.

### Transition authorization

| From | To | Customer (owner) | Staff and admin |
| --- | --- | --- | --- |
| `PENDING` | `CONFIRMED` | no | yes |
| `PENDING` | `CANCELLED` | yes | yes |
| `CONFIRMED` | `READY_FOR_PICKUP` | no | yes |
| `CONFIRMED` | `CANCELLED` | yes | yes |
| `READY_FOR_PICKUP` | `ACTIVE` | no | yes |
| `READY_FOR_PICKUP` | `CANCELLED` | yes | yes |
| `ACTIVE` | `RETURNED` | no | yes |
| `ACTIVE` | `OVERDUE` | no | **no, system only** |
| `OVERDUE` | `RETURNED` | no | yes |
| `RETURNED` | `COMPLETED` | no | yes |

`-> OVERDUE` is refused with `403 FORBIDDEN` for every human caller, because the schema derives nothing from the passage of time and a client must not be able to declare a rental overdue early. A future scheduled job performs that update through internal service code that reuses the same database path. Every other forbidden combination, including `RETURNED -> ACTIVE`, is `409 INVALID_RENTAL_TRANSITION`.

## Soft deletion

- `users`, `equipment`, and `equipment_units` are soft-deleted by setting `deleted_at`; no row is ever removed.
- Deleted rows are excluded from all reads by default and are only visible with `includeDeleted=true`. The required role is per list, exactly as the list contracts table states it: `ADMIN` on `GET /api/v1/users`, and `STAFF` or `ADMIN` on `GET /api/v1/equipment` and `GET /api/v1/equipment-units`.
- A `GET` for a soft-deleted resource returns `404 NOT_FOUND` to ordinary callers, so asset tags and serial numbers are not enumerable.
- Asset-tag and serial uniqueness is permanent and does not exclude deleted rows, so a tag can never be reissued. **API-layer rule:** reusing a retired `assetTag` is always `409 DUPLICATE_VALUE`.
- **API-layer rule:** `DELETE` on equipment or a unit is refused with `409 EQUIPMENT_IN_USE` while any rental in a reserving status (`PENDING`, `CONFIRMED`, `READY_FOR_PICKUP`, `ACTIVE`, `OVERDUE`) references the model or the unit, because those rentals still need the asset. `RETURNED`, `COMPLETED`, and `CANCELLED` rentals are not a conflict: they hold history, the row stays resolvable for past invoices, and the asset is free for new allocation.
- Deleting an `INACTIVE` model with no live rentals is the normal retirement path.
- Restoration is deliberately not exposed. Un-deleting equipment is an audited back-office action that should be designed with its own approval and reason trail, not a public `PATCH`.

## The five important user actions

### A1. Staff add and manage rental equipment and physical units

`POST /api/v1/equipment`

```json
{
  "categoryId": "a0000000-0000-4000-8000-000000000001",
  "name": "EcoPower 5kVA Generator",
  "description": "5 kVA petrol generator with two 230V sockets.",
  "dailyRateAmount": 2500000,
  "currency": "NGN",
  "status": "ACTIVE"
}
```

- `categoryId` must reference a live category.
- `status` defaults to `ACTIVE`; `INACTIVE` may be supplied at creation.
- Database-enforced: non-blank `name` and `description`, `daily_rate_amount >= 0`, `currency ~ '^[A-Z]{3}$'`, and the restrictive `equipment_category_fk`.
- Responds `201`, `Location: /api/v1/equipment/{id}`, and the created record.
- Unlike rentals, catalogue creation is not a financial or allocation event, so no `Idempotency-Key` is required; a duplicate submission is visible as a duplicate row and is the operator's problem to notice.

`POST /api/v1/equipment/{equipmentId}/units`

```json
{
  "assetTag": "GEN-005",
  "serialNumber": "EP5KVA-2030-0005",
  "status": "AVAILABLE"
}
```

- `status` defaults to `AVAILABLE` and may be `AVAILABLE`, `MAINTENANCE`, or `RETIRED`.
- `serialNumber` is optional but must be non-blank when present.
- Database-enforced: `equipment_units_asset_tag_key`, `equipment_units_serial_number_key` (multiple nulls permitted), non-blank text checks, and `equipment_units_equipment_fk`.
- A repeated tag is `409 DUPLICATE_VALUE`, and the message must not reveal whether the existing row is soft-deleted.
- Responds `201` with `Location: /api/v1/equipment-units/{id}`.

`PATCH /api/v1/equipment/{equipmentId}` accepts any subset of `name`, `description`, `dailyRateAmount`, `status`, and `categoryId`. **API-layer rule:** a rate change applies only to rentals created afterwards. Existing `rental_items.daily_rate_amount` snapshots and `rentals.base_amount` never change, and the response should say so, because staff must be able to explain a price difference.

`PATCH /api/v1/equipment-units/{unitId}` accepts `status`, `serialNumber`. `assetTag` is immutable once issued, and the API rejects attempts to change it with `400 INVALID_REQUEST`. Changing status to `MAINTENANCE` or `RETIRED` does not by itself release an existing future reservation; only cancellation changes a rental's reserving status. That asymmetry is deliberate and matches the database.

`DELETE /api/v1/equipment/{equipmentId}` and `DELETE /api/v1/equipment-units/{unitId}` return `204` after the in-use check, or `409 EQUIPMENT_IN_USE`.

Support: `database/queries/01_manage_equipment.sql` demonstrates the catalogue-and-units read that backs the staff screens, using `equipment_status_idx`, `equipment_units_status_idx`, and the equipment-to-category and equipment-to-unit foreign keys.

### A2. Customer searches for available equipment

`GET /api/v1/equipment/availability?startAt=2030-02-11T09:00:00Z&endAt=2030-02-12T17:00:00Z&categorySlug=generators&includeUnits=true`

- `startAt` and `endAt` are both required. Omitting either is `400 INVALID_REQUEST`; `endAt <= startAt` is `422 INVALID_PERIOD`.
- The result is paginated over equipment, not over units.
- Support: `database/queries/02_search_availability.sql` returns one row per eligible unit. The API aggregates those rows into `availableUnitCount` per equipment, matching the `unit_summary` pattern in `database/queries/01_manage_equipment.sql`, then paginates on `(equipmentName, id)`. `includeUnits=true` expands the asset tags and unit identifiers that are free, so a staff member can see exactly which physical unit a customer would get. It does not let a client reserve a specific unit: allocation stays server-side, as the next section explains.

```json
{
  "data": [
    {
      "equipmentId": "b0000000-0000-4000-8000-000000000001",
      "name": "EcoPower 5kVA Generator",
      "description": "5 kVA petrol generator with two 230V sockets.",
      "category": { "id": "a0000000-0000-4000-8000-000000000001", "slug": "generators" },
      "dailyRateAmount": 2500000,
      "currency": "NGN",
      "availableUnitCount": 1,
      "units": [
        { "id": "c0000000-0000-4000-8000-000000000001", "assetTag": "GEN-001", "serialNumber": "NG-GEN-001" }
      ]
    }
  ],
  "page": { "limit": 20, "nextCursor": null, "hasMore": false }
}
```

Eligibility, all enforced in the query rather than in application code:

- `equipment_units.status = 'AVAILABLE'` and `deleted_at IS NULL`, supported by `equipment_units_available_idx`.
- `equipment.status = 'ACTIVE'` and `deleted_at IS NULL`, supported by `equipment_status_idx`.
- No `rental_items` row for that unit joined to a `rentals` row in `PENDING`, `CONFIRMED`, `READY_FOR_PICKUP`, `ACTIVE`, or `OVERDUE` whose period overlaps, using `existing.start_at < requestedEnd` and `requestedStart < existing.end_at` so a shared boundary is not an overlap. Supported by `rental_items_equipment_unit_rental_idx` and `rentals_reserving_period_idx`.

Plan evidence for this predicate set is in `database/evidence/04_availability_explain.sql`.

### A3. Customer creates a rental reservation

`POST /api/v1/rentals` with header `Idempotency-Key: 8f1c...`

```json
{
  "equipmentId": "b0000000-0000-4000-8000-000000000001",
  "quantity": 2,
  "startAt": "2030-03-01T09:00:00Z",
  "endAt": "2030-03-03T17:00:00Z"
}
```

The client sends a model and a count. It never sends a unit id, a price, or a currency. This keeps a requester from racing a search result and keeps the catalogue rate authoritative at the moment of booking. A `STAFF` or `ADMIN` caller may additionally send `customerId` to reserve on a customer's behalf; a `CUSTOMER` may not send it, because the rental is always their own.

Server behaviour, in one `READ COMMITTED` database transaction:

1. Lock the equipment row and read `name`, `daily_rate_amount`, and `currency`. Reject non-`ACTIVE` or soft-deleted equipment with `404 NOT_FOUND`.
2. Compute `billableDays`, then `baseAmount = billableDays * dailyRateAmount * quantity` using the base-amount policy above.
3. Insert the rental with `status = 'PENDING'` explicitly. Database-enforced: `rentals_enforce_status_transition` rejects any other initial status.
4. Select `quantity` distinct units of that model that are `AVAILABLE`, not soft-deleted, and not blocked by an overlapping reserving rental. Choose them ordered by `asset_tag` so allocation is deterministic, then take row locks in ascending UUID order to match the order the trigger itself uses. Because every writer for one model serializes on the equipment row locked in step 1, two reservations for the same model cannot select and lock the same unit concurrently.
5. Insert one `rental_items` row per unit with `equipment_name_snapshot` and `daily_rate_amount` copied from step 1 and `currency` copied from the rental.
6. Commit and return `201` with the rental, its items, and `Location`. `rentals.base_amount` is stored as the agreed amount at this point and is immutable from here on, so the `CONFIRMED` transition confirms the agreement rather than recalculating it.

Responses and failures:

- Fewer than `quantity` eligible units at step 4 is `409 EQUIPMENT_UNAVAILABLE` with `details` reporting the count actually available. If availability changes between the check and the insert, the overlap trigger fires instead and the transaction aborts; the server rolls back the whole transaction and returns the same code. Both paths leave no partial rental and no orphan item.
- `endAt <= startAt` is `422 INVALID_PERIOD` from `rentals_period_valid`.
- Currency inconsistency is impossible from this payload, but the composite foreign keys remain the authority: `CURRENCY_MISMATCH` on any attempted divergence.
- A single unit appearing twice in one rental is `409 DUPLICATE_VALUE` from `rental_items_rental_equipment_unit_key`.
- Missing `Idempotency-Key` is `400 IDEMPOTENCY_KEY_REQUIRED`.

```json
{
  "data": {
    "id": "d0000000-0000-4000-8000-000000000005",
    "customerId": "10000000-0000-4000-8000-000000000001",
    "status": "PENDING",
    "startAt": "2030-03-01T09:00:00Z",
    "endAt": "2030-03-03T17:00:00Z",
    "baseAmount": 15000000,
    "currency": "NGN",
    "items": [
      { "id": "e0000000-0000-4000-8000-000000000007", "equipmentUnitId": "c0000000-0000-4000-8000-000000000001", "assetTag": "GEN-001", "equipmentNameSnapshot": "EcoPower 5kVA Generator", "dailyRateAmount": 2500000, "currency": "NGN" },
      { "id": "e0000000-0000-4000-8000-000000000008", "equipmentUnitId": "c0000000-0000-4000-8000-000000000002", "assetTag": "GEN-002", "equipmentNameSnapshot": "EcoPower 5kVA Generator", "dailyRateAmount": 2500000, "currency": "NGN" }
    ]
  }
}
```

Three billable days at `2500000` per unit, times a quantity of two, is the `15000000` in the response.

Database support: `rentals_pkey`, `rentals_period_valid`, `rentals_base_amount_nonnegative`, `rentals_id_currency_key`, `rental_items_rental_equipment_unit_key`, and the `rental_items_enforce_availability` trigger invoking `assert_rental_unit_available`, which locks the parent rental and then each unit before re-checking overlap. `database/queries/03_create_rental.sql` is the minimal proof; `database/evidence/02_overlapping_reservation.sql` shows the real `23P01` rejection for a competing overlap.

### A4. Staff check equipment out and back in

`GET /api/v1/rentals/{rentalId}/operations` returns the staff working view: rental status and period, the customer, and one row per item with the agreed snapshot rate, the unit's asset tag, serial number, and current operational status, the model's current equipment name, and the `CHECK_OUT` and `RETURN` inspections with condition, notes, time, and inspector. It is the read model behind `database/queries/04_checkout_return.sql`, ordered by `asset_tag` so staff scan units in a fixed order. No free-text staff note is included, because the schema has no column to store one.

`POST /api/v1/rentals/{rentalId}/transitions`

```json
{ "targetStatus": "READY_FOR_PICKUP" }
```

- `targetStatus` is the only mutable field. The request intentionally carries no free-text reason, because the schema has nowhere to store one, and inventing a comment column would be scope creep.
- The server updates one rental row in a transaction. The `BEFORE INSERT OR UPDATE OF status` trigger compares the persisted `OLD.status` with the requested value and is the sole authority on legality.
- No-op requests are not errors: repeating `{"targetStatus":"PENDING"}` on a `PENDING` rental returns `200` with the unchanged rental, because the trigger permits no-op status updates and the schema requires it. This is what makes a retried transition safe.
- A forbidden edge is `409 INVALID_RENTAL_TRANSITION` with the current and requested status in `details`. The database message `invalid rental status transition: X -> Y` is never returned verbatim.
- A concurrent transition wins the row lock; the loser's update is evaluated against the fresh row version at `READ COMMITTED` and either succeeds as a no-op or fails as a conflict. There is no lost update.
- `-> OVERDUE` is `403 FORBIDDEN` for human callers, as described in the transition authorization matrix.

`POST /api/v1/rentals/{rentalId}/items/{rentalItemId}/inspections`

```json
{
  "type": "CHECK_OUT",
  "condition": "GOOD",
  "notes": "Fuel full, cable undamaged.",
  "inspectedAt": "2030-03-03T16:40:00Z"
}
```

- `type` is `CHECK_OUT` or `RETURN`; `condition` is `GOOD`, `FAIR`, or `DAMAGED`; both are validated against the enum domains.
- `inspectedBy` is the authenticated staff member. It is not client-supplied, so an inspection cannot be attributed to another user.
- `inspectedAt` is optional and defaults to server time. A supplied value in the future is `400 INVALID_REQUEST`, which allows a staff member to record an observation that happened shortly beforehand without permitting invented history.
- `rentalItemId` must belong to `rentalId`, otherwise `404 NOT_FOUND`.
- A second inspection of the same type for the same item is `409 DUPLICATE_INSPECTION` from `inspections_rental_item_type_key`, which also makes a retried POST safe.
- `PATCH /api/v1/inspections/{inspectionId}` lets `STAFF` and `ADMIN` correct `condition` and `notes`. The migration does not impose an append-only policy, so the endpoint is permitted today, but the design should expect to tighten this; `createdAt`, `updatedAt`, and the shared `set_updated_at` trigger already record when a correction happened.

**Deliberate omission.** The API does not require a `CHECK_OUT` inspection before `READY_FOR_PICKUP -> ACTIVE`, nor a `RETURN` inspection before `-> RETURNED`. Neither the requirements nor the schema states that rule, and inventing it here would add a business rule that the database does not share. If the business wants it, it should be added to the requirements first and enforced consistently in both layers.

Support: `rentals_pkey`, `users_pkey`, the rental, customer, item, unit, and inspection foreign keys, and `inspections_rental_item_type_key`. `database/evidence/03_invalid_state_transition.sql` shows the real `23514` rejection for a forbidden edge.

### A5. Customer pays

`GET /api/v1/rentals/{rentalId}/payment-summary`

```json
{
  "data": {
    "rentalId": "d0000000-0000-4000-8000-000000000001",
    "baseAmount": 9300000,
    "additionalChargeAmount": 750000,
    "amountOwed": 10050000,
    "amountPaid": 6000000,
    "balance": 4050000,
    "currency": "NGN",
    "isSettled": false
  },
  "pollAfterSeconds": 30
}
```

- Every figure is derived on read. Nothing is cached in a column, because there is no `amount_owed`, `amount_paid`, or `balance` column in the schema.
- `amountPaid` sums only `SUCCEEDED` payments. `PENDING` and `FAILED` rows are listed by `GET /api/v1/payments` but never reduce the balance.
- The aggregation follows `database/queries/05_payment_summary.sql`: charges and payments are aggregated independently before joining, so the one-to-many multiplication bug is structurally impossible.
- `isSettled` is `balance <= 0`. Overpayment is possible and is not an error, because the schema has no overpayment constraint and refunds are out of scope.
- Support: `rentals_pkey`, `charges_rental_id_idx` and `charges_rental_currency_idx`, `payments_rental_status_idx` and `payments_rental_currency_idx`, the positive-amount checks, and the composite currency foreign keys. `database/evidence/05_payment_summary_explain.sql` records the plan.

`POST /api/v1/rentals/{rentalId}/payments` with header `Idempotency-Key: 2ab9...`

```json
{
  "providerReference": "PSP-7F3A2C11",
  "amount": 6000000,
  "status": "SUCCEEDED",
  "paidAt": "2030-03-01T10:12:00Z"
}
```

- Only the owner or an `ADMIN` may record a payment.
- `providerReference` is required and globally unique, so a repeated reference is `409 DUPLICATE_PROVIDER_REFERENCE` from `payments_provider_reference_key`. This is the second line of defence behind the `Idempotency-Key`.
- `amount` must be strictly positive, matching the database `CHECK`. A client may pay less than the balance, in several instalments, or more; the API records what happened and does not judge it.
- `status` defaults to `PENDING`. `paidAt` is required when `status` is `SUCCEEDED` and forbidden otherwise, and it defaults to server time when omitted. **API-layer rule**, because the schema does not enforce it.
- A `FAILED` payment must carry no `paidAt`.
- A wrong `currency` is not possible from this payload; the rental's currency is copied server-side. The composite foreign keys still reject any divergence as `CURRENCY_MISMATCH`.
- There is no `PATCH` for `status`. A payment that was recorded as `PENDING` becomes `SUCCEEDED` only through the future provider-reconciliation contract listed in the open questions.

## Entity coverage

All nine entities in `docs/data-model.md` are reachable through the contract. The catalogue below is the single place to check that nothing was left behind and that no meaningless CRUD was invented.

| Entity | Read | Create | Update | Delete | Notes |
| --- | --- | --- | --- | --- | --- |
| `User` | `GET /me`, `GET /users`, `GET /users/{userId}` | `POST /users` (`ADMIN`) | `PATCH /users/{userId}` for `displayName`; `role` for `ADMIN` | `DELETE /users/{userId}` soft, `ADMIN` | `role` is single-valued; there is no multi-role model. A `CUSTOMER` can read only itself. |
| `Category` | list, detail | `POST /categories` | `PATCH /categories/{categoryId}` | none | No soft-delete column, so no delete. Renaming a slug changes URLs, so clients must resolve slugs through the list endpoint. |
| `Equipment` | list, availability, detail | `POST /equipment` | `PATCH /equipment/{equipmentId}` | `DELETE` soft, guarded | Rate edits never alter historical snapshots. |
| `EquipmentUnit` | list, detail | `POST /equipment/{equipmentId}/units` | `PATCH /equipment-units/{unitId}` | `DELETE` soft, guarded | `assetTag` immutable; `serialNumber` correctable. |
| `Rental` | list, detail, operations view, summary | `POST /rentals` | `/transitions` only | none, cancel instead | Period, `baseAmount`, `customerId`, and item composition are immutable. |
| `RentalItem` | embedded in rental detail; `GET /rental-items` | none | none | none | Created only by the reservation transaction. The flat endpoint exists for unit-centric history lookups such as "all reservations of GEN-001". |
| `Inspection` | list, embedded in the operations view | `POST` under a rental item | `PATCH /inspections/{inspectionId}` | none | One per item and type, database-enforced. |
| `Charge` | list, embedded in rental detail | `POST /rentals/{rentalId}/charges` (`DAMAGE` only) | none | none | Voiding an erroneous charge is unresolved and deliberately absent; see open questions. |
| `Payment` | list, embedded in rental detail, summary | `POST /rentals/{rentalId}/payments` | none | none | Status changes await the provider-reconciliation contract. |

### Nested expansion instead of extra endpoints

`GET /api/v1/rentals/{rentalId}` accepts `include` to avoid both under-fetching and over-fetching:

| `include` value | Adds |
| --- | --- |
| `items` (default) | `rental_items` with `equipmentNameSnapshot`, the unit asset tag, and the serial number. |
| `items.unit` | Full unit record including operational status and the model's current equipment name. |
| `items.inspections` | Both inspections per item. |
| `charges` | All additional charges. |
| `payments` | All payment records, not only the aggregate. |
| `summary` | The payment-summary object from A5. |

Unknown `include` values are `400 INVALID_REQUEST`. Because the customer, staff, and finance screens of one rental need different subsets, a single fat rental response would over-fetch; because a REST client cannot shape a response, expansion parameters are the honest MVP answer. This is the concrete problem the GraphQL question below is about.

## GraphQL analysis

**Decision: REST stays the MVP interface. No user-count threshold.**

A traffic threshold would be a guess. The number of users says nothing about whether the clients need different shapes of the same data, and the real cost driver here is interface count, not user count.

Reconsider GraphQL when one or more of these is observed:

| Trigger | Why it matters |
| --- | --- |
| Materially different clients, for example a customer app, a partner integration, and an internal operations console | Each client needs a different projection of the same rental, and `include` parameters start multiplying. |
| Endpoint proliferation past roughly fifteen resources, or fan-out endpoints such as `/operations` and `/payment-summary` | Each new screen adds a path, a permission rule, and a cache key to maintain. |
| Measurable over-fetching: more than about 30% of columns returned by list endpoints unused, or three or more round trips per screen | A wide, cached, field-level contract pays for itself. |
| Composition or fragmentation: a client needs rental, customer, unit, inspection, and summary data in one round trip | This is the strongest signal, and it is already visible in the operations view. |
| Read-only use cases that would otherwise force many versioned REST paths | One additive read schema avoids a `/v2` per field. |

If it is adopted, the mutation surface stays REST. GraphQL would be read-only, mounted alongside `/api/v1`, with the same authorization, pagination, and error envelope. The rental creation and payment commands keep their idempotency keys, because GraphQL does not improve that problem.

### Concrete comparison

The equipment detail screen needs the model, its availability for a period, and the units that are free. Under this REST contract:

```http
GET /api/v1/equipment/b0000000-0000-4000-8000-000000000001?startAt=2030-02-11T09:00:00Z&endAt=2030-02-12T17:00:00Z&includeUnits=true
```

```json
{
  "data": {
    "id": "b0000000-0000-4000-8000-000000000001",
    "name": "EcoPower 5kVA Generator",
    "description": "5 kVA petrol generator with two 230V sockets.",
    "dailyRateAmount": 2500000,
    "currency": "NGN",
    "status": "ACTIVE",
    "category": { "id": "a0000000-0000-4000-8000-000000000001", "name": "Generators", "slug": "generators" },
    "availability": {
      "startAt": "2030-02-11T09:00:00Z",
      "endAt": "2030-02-12T17:00:00Z",
      "availableUnitCount": 1,
      "units": [ { "id": "c0000000-0000-4000-8000-000000000001", "assetTag": "GEN-001", "serialNumber": "NG-GEN-001", "status": "AVAILABLE" } ]
    }
  }
}
```

The search-results screen, by contrast, needs name, rate, category, and a count, and never needs descriptions, unit ids, or serial numbers. So the same entity has at least two legitimate shapes: one fat `GET /equipment/{id}` over-fetches for the list-adjacent card, and one thin one under-fetches for the detail screen. The REST design above resolves this with an explicit `availability` block and a separate compact list shape, which is workable for exactly two shapes and degrades as a third client appears.

The equivalent GraphQL query expresses the intent directly:

```graphql
query EquipmentDetail($id: ID!, $period: PeriodInput!) {
  equipment(id: $id) {
    id
    name
    description
    dailyRateAmount
    currency
    status
    category { id name slug }
    availability(period: $period) {
      startAt
      endAt
      availableUnitCount
      units { id assetTag serialNumber status }
    }
  }
}
```

Each client asks for the fields it renders, so the card view omits the `availability` block entirely and the detail view keeps it. That is the real advantage, and it is the reason the decision is deferred rather than dismissed: the benefit grows with the number of distinct clients, and this repository has exactly one customer-facing and one staff-facing surface.

The costs are equally concrete: a second interface to version, persisted queries for safety, normalised caching at the HTTP layer, a resolver layer that can reintroduce N+1 queries unless every list field is batch-loaded, and a schema that must be kept backward compatible for a year. Two interfaces and two clients do not justify that yet.

## Real-time analysis

**Decision: the MVP uses polling. Server-sent events are the preferred evolution for server-to-client updates. WebSockets are out of scope until a genuinely bidirectional feature exists.**

### Polling for the MVP

- Time-sensitive read endpoints add a top-level `pollAfterSeconds` beside `data`, as in the summary example above. Rental and payment reads suggest `15`; the summary suggests `30`. The value is a hint, not a contract.
- Clients poll only what their screen shows, and stop polling when the screen is hidden.
- No long-polling, no fan-out table, no broker. The database is already the source of truth and the read paths are index-backed, so polling is cheap and operationally trivial.
- This is sufficient because the product has no latency requirement: a customer checking whether a return was processed can wait fifteen seconds.

### Server-sent events as the preferred evolution

A rental status change, a new charge, and a payment record are all server-to-client facts. The client never needs to push anything except the commands it already sends over `POST`, so a full-duplex socket would be unused capacity.

Proposed evolution, not implemented:

| Aspect | Design |
| --- | --- |
| Endpoint | `GET /api/v1/events` for a tenant-wide stream, `GET /api/v1/rentals/{rentalId}/events` for one rental. |
| Media type | `text/event-stream`. |
| Event types | `rental.status_changed`, `rental.payment_recorded`, `rental.charge_recorded`, `equipment.availability_changed`, `rental.operations_updated`. |
| Payload | The changed entity identifier plus the fields the client must refresh. Events carry identifiers and deltas, never whole aggregates, so a client still reads through the versioned REST endpoints. |
| Resumption | `Last-Event-ID` with a bounded replay window, for example the last 100 events per stream. |
| Authorization | A short-lived, single-use stream ticket exchanged for the token, passed in a header. Never a token in the query string, because URLs leak into logs and history. |
| Publication | A `NOTIFY` trigger or transactional outbox in PostgreSQL, fanned out by the API tier. The current migration has no publication mechanism, so this requires a follow-up migration. |
| Load balancers | Sticky sessions or a shared fan-out tier; SSE over plain HTTP/1.1 suffers per-connection browser limits. |

### When to reconsider WebSockets

Move to WebSockets when a real bidirectional requirement appears, for example a live staff floor board where several staff members annotate the same checkout, or a customer watching availability update while typing a filter. Until a feature needs client-to-server messages outside the normal command set, WebSockets add reconnection, backpressure, and load-balancing cost for no gain.

## Traceability

Every endpoint above maps to real database objects. The table names the actual constraints, indexes, and triggers from `database/migrations/001_initial_schema.sql` and the actual scripts in `database/queries/` and `database/evidence/`.

| Action | Endpoints | Model elements | Database proof |
| --- | --- | --- | --- |
| A1. Manage equipment and units | `POST/PATCH/DELETE /equipment`, `POST /equipment/{equipmentId}/units`, `PATCH/DELETE /equipment-units/{unitId}` | `Category`, `Equipment`, `EquipmentUnit` | `database/queries/01_manage_equipment.sql`; `equipment_status_idx`, `equipment_units_status_idx`, `equipment_category_fk`, `equipment_units_equipment_fk`, `equipment_units_asset_tag_key`, `equipment_units_serial_number_key` |
| A2. Search availability | `GET /equipment/availability` | `Equipment`, `EquipmentUnit`, `Rental`, `RentalItem` | `database/queries/02_search_availability.sql`, `database/evidence/04_availability_explain.sql`; `equipment_units_available_idx`, `equipment_status_idx`, `rental_items_equipment_unit_rental_idx`, `rentals_reserving_period_idx` |
| A3. Create a reservation | `POST /rentals` | `Rental`, `RentalItem`, `User`, `EquipmentUnit` | `database/queries/03_create_rental.sql`, `database/evidence/02_overlapping_reservation.sql`; `rentals_period_valid`, `rental_items_rental_equipment_unit_key`, `rental_items_enforce_availability` invoking `assert_rental_unit_available` |
| A4. Checkout and return | `GET /rentals/{id}/operations`, `POST /rentals/{id}/transitions`, `POST /rentals/{id}/items/{rentalItemId}/inspections`, `PATCH /inspections/{id}` | `Rental`, `RentalItem`, `Inspection`, `User` | `database/queries/04_checkout_return.sql`, `database/evidence/03_invalid_state_transition.sql`; `rentals_enforce_status_transition` invoking `enforce_rental_status_transition`, `inspections_rental_item_type_key` |
| A5. Pay | `POST /rentals/{id}/payments`, `GET /rentals/{id}/payment-summary` | `Rental`, `Charge`, `Payment` | `database/queries/05_payment_summary.sql`, `database/evidence/05_payment_summary_explain.sql`; `charges_rental_currency_idx`, `payments_rental_status_idx`, `payments_provider_reference_key` |
| Period validity | every endpoint accepting a period | `Rental` | `database/evidence/01_invalid_date_range.sql`; `rentals_period_valid` |
| Currency integrity | rentals, items, charges, payments | `Rental`, `RentalItem`, `Charge`, `Payment` | `rentals_id_currency_key` and the composite `(rental_id, currency)` foreign keys |
| Lifecycle legality | `POST /rentals/{id}/transitions` | `Rental` | `docs/state-machine.md`, `database/evidence/03_invalid_state_transition.sql` |
| History preservation | every entity | all nine tables | restrictive foreign keys with `ON UPDATE RESTRICT ON DELETE RESTRICT`; soft deletion on `users`, `equipment`, `equipment_units` |

## Concurrency and retry contract

- Rental allocation, item insertion, transitions, inspections, and payments each run in a single database transaction at `READ COMMITTED`, as `assert_rental_unit_available` requires. A different isolation level raises an exception by design.
- `40001` serialization failures and `40P01` deadlocks are retried up to three times as complete transaction restarts, with small jittered backoff. Because the work is retried as a whole, a partial effect is impossible.
- After exhausted retries the API returns `503 SERVICE_UNAVAILABLE` with `Retry-After: 1`.
- Overlap and transition conflicts are never retried automatically. They are reported to the caller, because retrying would produce the same answer.
- Allocation locks a parent rental and then each unit in ascending UUID order, matching the trigger's ordering, so application code cannot deadlock against itself.
- Idempotent endpoints remain safe under client retry storms; non-idempotent ones are limited to the guarded set in the resource map.

## Open questions carried forward

These are decisions this contract deliberately does not make.

| Question | Status |
| --- | --- |
| Storage and implementation of the idempotency-key table | Contract defined above; no table exists yet. First implementation migration. |
| Stable custom SQLSTATEs for the overlap and transition triggers | Required follow-up migration so error mapping does not depend on message text. |
| Overdue detection job | `-> OVERDUE` is refused to human callers. The job's schedule, retry policy, and whether it also emits an SSE event are still open. |
| Payment-provider reconciliation | Nothing changes `Payment.status` after creation. Webhook authentication, duplicate-event handling, and `PENDING` to `SUCCEEDED` or `FAILED` transitions are undefined. |
| Voiding an incorrect charge | No field can represent a void. A new `Charge.type` value or a void flag is a schema decision. |
| Charge duplication rules | Nothing prevents two identical `DAMAGE` charges for one rental. |
| Automatic `RETURNED -> COMPLETED` | Currently staff-triggered. Whether it becomes automatic is undecided. |
| Inspection append-only policy | Corrections are permitted today because the schema permits them. |
| Restoring soft-deleted equipment, units, and users | Not exposed; designed as a later audited action. |
| Timezone presentation | The API stores and returns UTC. Whether a client may request a preferred display zone is undecided. |
| Authentication mechanism | Role expectations are specified; tokens, sessions, and identity providers are out of scope. |
| Read replicas and caching | Everything currently reads the primary. Cache invalidation for the SSE evolution is undecided. |
