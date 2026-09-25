# Product Requirements

## Product purpose

The Equipment Rental Platform connects customers who need equipment for a defined period with staff who operate the equipment catalogue and physical inventory. Customers can discover available equipment, reserve units, pay the agreed base amount and applicable additional charges, collect the equipment, and return it. Staff manage catalogue records and physical units, control availability, perform checkout and return, and record inspections.

`Equipment` represents a rentable model or type. `EquipmentUnit` represents one individual physical asset. Observed physical condition belongs to inspection history rather than a permanent condition field on a unit.

## Users and roles

Each user has one database role:

| Role | Responsibilities in scope |
| --- | --- |
| `CUSTOMER` | Search availability, create rentals, pay, collect equipment, and return it. |
| `STAFF` | Manage equipment and units, manage rentals, perform checkout and return, and record inspections. |
| `ADMIN` | Perform platform-administrative operations in a later authorization contract. |

Authentication and permission checks are not implemented. The schema records the role but does not provide a multi-role assignment model.

## Five important user actions

1. **Staff add and manage rental equipment and physical units.** Staff create and maintain equipment records and the individual units that fulfill rentals.
2. **Customer search for available equipment.** A customer supplies a period and finds equipment with physical units available for that period.
3. **Customer create a rental reservation.** A customer reserves one or more physical units for one shared period.
4. **Staff check equipment out and back in.** Staff record `CHECK_OUT` and `RETURN` inspections and advance the rental lifecycle.
5. **Customer pay for the rental.** A customer pays the agreed base rental amount and applicable late-fee or damage charges.

## In-scope design and database proof

- Categories, equipment models, individual equipment units, and users.
- `Equipment.status` values `ACTIVE` and `INACTIVE`.
- `EquipmentUnit.status` values `AVAILABLE`, `MAINTENANCE`, and `RETIRED`; only `AVAILABLE` units are candidates for new allocation.
- Half-open rental periods using `[startAt, endAt)`.
- A rental containing one or more `RentalItem` rows, each representing exactly one physical unit.
- UUID primary keys, restrictive foreign keys, permanent equipment identifiers, and soft deletion for users, equipment, and units.
- Current catalogue pricing and historical rental pricing snapshots.
- `Inspection.type` values `CHECK_OUT` and `RETURN`; `Inspection.condition` values `GOOD`, `FAIR`, and `DAMAGED`; at most one inspection of each type per rental item.
- `Charge.type` values `LATE_FEE` and `DAMAGE` only. `Rental.baseAmount` is the authoritative agreed base amount; total amount owed is derived and is not stored.
- `Payment.status` values `PENDING`, `SUCCEEDED`, and `FAILED`; globally unique provider references; no refunds or negative payments.
- `Rental.status` beginning at `PENDING`, exact lifecycle transition enforcement, reserving and non-reserving status groups, and database-enforced overlap prevention.
- One currency per rental, represented as an uppercase `CHAR(3)`, with database-enforced equality for child currency values.
- Whole-number minor-unit money in `BIGINT`. Catalogue and rental rates and base amounts are non-negative; charge and payment amounts are strictly positive.
- `createdAt` and `updatedAt` on every entity, with database triggers maintaining `updatedAt`.

The first PostgreSQL migration is `database/migrations/001_initial_schema.sql`. A deterministic one-transaction demo seed and five database queries demonstrate the important actions without implementing an API. A separate deterministic plan fixture and five database evidence scripts exercise the actual rejection mechanisms and the two heavy query plans without changing product scope.

The proposed HTTP contract for those actions is `docs/api-design.md`. It is a design only: no server, framework, dependency, or request handler exists in this repository, and it changes no product or database decision.

## Explicitly out of scope

- API implementation, server code, request handlers, persistence code, or automated tests. The design in `docs/api-design.md` stays unbuilt.
- A frontend, customer interface, staff interface, or presentation layer.
- Authentication, authorization implementation, sessions, tokens, or identity-provider integration.
- Automated screenshot tooling or evidence packaging beyond the seven captured screenshots and the executable SQL proof. The screenshots exist and are documented in `evidence/README.md`; what is out of scope is generating or maintaining them automatically. GitHub publishing is also out of scope.
- Application dependencies or server scaffolding.
- GraphQL or a real-time push channel. Both are analysed in `docs/api-design.md` and deliberately deferred; REST plus polling is the MVP interface.
- Refund processing, general credits, or a payment-ledger model.
- Automatic overdue scheduling, payment-provider integration, and business workflows not stated here.

## Traceability

| Action | Requirements to preserve | Primary model elements | Proposed API endpoint |
| --- | --- | --- | --- |
| A1. Staff manage equipment and units | Catalogue models are separate from physical assets. Units use `AVAILABLE`, `MAINTENANCE`, or `RETIRED`; asset tags and present serial numbers remain globally unique after soft deletion. | `Category`, `Equipment`, `EquipmentUnit`, `Inspection` | `POST /api/v1/equipment`; `POST /api/v1/equipment/{equipmentId}/units` |
| A2. Customer searches for availability | A requested period uses `[startAt, endAt)`. `PENDING`, `CONFIRMED`, `READY_FOR_PICKUP`, `ACTIVE`, and `OVERDUE` rentals block overlapping allocation; a new rental may start when another ends. | `Equipment`, `EquipmentUnit`, `Rental`, `RentalItem` | `GET /api/v1/equipment/availability` |
| A3. Customer creates a reservation | A rental records one customer, one period, an authoritative base amount, and one row per physical unit. Quantity `2` means two different units and two rows. | `Rental`, `RentalItem`, `User`, `EquipmentUnit` | `POST /api/v1/rentals` |
| A4. Staff checks out and returns equipment | Exact lifecycle transitions are enforced. Checkout and return inspections use the required types and conditions. `RETURNED -> ACTIVE` is forbidden. | `Rental`, `RentalItem`, `Inspection`, `User` | `POST /api/v1/rentals/{rentalId}/transitions`; `POST /api/v1/rentals/{rentalId}/items/{rentalItemId}/inspections` |
| A5. Customer pays | Base pricing is separate from `LATE_FEE` and `DAMAGE` charges. Payment statuses and provider-reference uniqueness are defined; refunds remain out of scope. | `Rental`, `Charge`, `Payment` | `POST /api/v1/rentals/{rentalId}/payments`; `GET /api/v1/rentals/{rentalId}/payment-summary` |

Each proposed endpoint is specified in full, with request and response shapes, error codes, and the database objects that enforce it, in `docs/api-design.md`.

## Cross-cutting requirements

### Availability and concurrency

A physical unit cannot appear in overlapping reserving rentals. Because the period is stored on `Rental` and the unit is stored on `RentalItem`, this is a cross-table invariant rather than a row-level `CHECK` or a direct simple exclusion constraint.

The migration uses row-level database triggers at `READ COMMITTED` isolation:

- An item insert or identity change locks its parent rental and then its equipment unit.
- A rental period or status change locks the parent rental and then all affected equipment units in UUID order.
- After those locks are acquired, the trigger performs a fresh conflict-query statement using the half-open overlap predicates.
- Concurrent writers targeting the same unit serialize on the unit row, so the later writer sees the earlier committed allocation before succeeding.

An isolation level other than `READ COMMITTED` is rejected by the allocation functions. A future API must keep rental allocation, item creation, and relevant rental updates in database transactions and retry transaction-level serialization or deadlock failures as complete units.

### Currency

`RentalItem.currency`, `Charge.currency`, and `Payment.currency` must equal the parent `Rental.currency`. Composite foreign keys reference `rentals(id, currency)` with `ON UPDATE RESTRICT` and `ON DELETE RESTRICT`. This rejects a mismatched child immediately and prevents changing a parent currency while dependent financial or item rows exist.

### State transitions

Status enums validate allowed values. A separate `BEFORE INSERT OR UPDATE` trigger requires explicit inserts to start at `PENDING` and validates every update against the persisted `OLD.status` and requested `NEW.status`. The `UPDATE` row lock serializes competing transitions for the same rental.

### Deletion and history

`User`, `Equipment`, and `EquipmentUnit` support soft deletion. Equipment asset tags and present serial numbers use permanent unique constraints without filtering soft-deleted rows. `Rental`, `RentalItem`, `Inspection`, `Charge`, and `Payment` are historical records. Every foreign key uses restrictive update and delete actions; there are no destructive cascades.

### Idempotency

`docs/api-design.md` defines idempotency for the mutations that can create duplicate business effects. Rental creation and payment recording require an `Idempotency-Key`; key scope is the actor, method, and route, and the stored response is replayed for an identical repeat. Reusing a key with a materially different request is a conflict, retention is configurable, and expiry is defined. The contract also records that the required key table does not yet exist in the migration.

`Payment.providerReference` uniqueness protects provider transactions but does not replace API-level idempotency.

## Remaining contract questions

The core domain and database decisions are resolved, and `docs/api-design.md` now resolves the API shape: list filters, sort fields, the cursor contract, command payloads, error mapping, idempotency behaviour, soft-delete visibility, and per-role authorization rules. The following remain genuinely open:

- Storage and implementation of the idempotency-key table, and stable custom SQLSTATEs for the overlap and transition triggers. Both are first implementation migrations.
- Automatic overdue detection and the worker or scheduled-job contract. The design refuses `-> OVERDUE` to human callers but does not define the job.
- Payment-provider status-update rules and reconciliation behavior, including how a recorded `PENDING` payment later becomes `SUCCEEDED` or `FAILED`.
- Whether an incorrect charge can be voided, since no field can represent a void and nothing prevents duplicate charges.
- Whether `RETURNED -> COMPLETED` becomes automatic and whether inspections become append-only.
- Restoring soft-deleted equipment, units, and users.
- The authentication mechanism, which stays out of scope even though role expectations are now specified.
