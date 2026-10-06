# Equipment Rental Platform — API & Database Design

A backend system design and PostgreSQL data modelling project for an equipment rental platform.

The project explores how equipment availability, reservations, rental lifecycle transitions, inspections, payments and historical records can be modelled reliably before building the application layer.

It includes a proposed REST API contract, an executable PostgreSQL schema, database constraints and triggers, deterministic test data, rejection tests, query-plan analysis and architecture evidence.

> **Project boundary:** This repository contains the API design and database implementation. It does not contain an API server, frontend or authentication implementation.

## What This Project Demonstrates

- REST API design
- Relational data modelling
- PostgreSQL schema design
- Database constraints and triggers
- Rental availability modelling
- Prevention of overlapping reservations
- State-machine design
- Transaction and lifecycle reasoning
- Historical data preservation
- Database indexing
- Query-plan analysis
- API error modelling
- Idempotency design
- Cursor pagination design
- Architecture documentation

## Product Overview

The platform is designed for an equipment rental business where customers can:

1. Search for equipment available during a requested period.
2. Reserve one or more physical equipment units.
3. Pay for a rental and applicable additional charges.
4. Collect rented equipment.
5. Return equipment for inspection.

Staff can manage:

- Equipment catalogue entries
- Individual physical units
- Availability
- Reservations
- Checkouts
- Returns
- Inspections
- Payments and additional charges

A key modelling decision is the separation between:

```text
Equipment
```

and:

```text
EquipmentUnit
```

`Equipment` represents the rentable model or type, while `EquipmentUnit` represents an individual physical asset.

For example:

```text
Equipment
Excavator Model X
       │
       ├── Unit 001
       ├── Unit 002
       └── Unit 003
```

This allows availability and rental history to be tracked against the actual physical asset rather than only the catalogue item.

## System Design

The system is divided conceptually into:

```text
Client
   │
   ▼
REST API
   │
   ▼
Business Rules
   │
   ▼
PostgreSQL
```

This repository focuses primarily on the bottom two layers:

```text
API Contract
     +
Database Model
```

The HTTP API is specified in:

```text
docs/api-design.md
```

while the executable database design lives under:

```text
database/
```

## Core User Actions

The design maps five important product actions to API operations and database queries.

| Action | Proposed API |
| --- | --- |
| Manage equipment and physical units | `POST /api/v1/equipment` and `POST /api/v1/equipment/{equipmentId}/units` |
| Search available equipment | `GET /api/v1/equipment/availability` |
| Create a rental reservation | `POST /api/v1/rentals` |
| Check equipment out and back in | Rental transition and inspection endpoints |
| Record and summarize payments | Payment and payment-summary endpoints |

Each action also has a corresponding SQL query under:

```text
database/queries/
```

This creates traceability between the product requirements, API design and database implementation.

## Data Model

The database contains nine core entities covering:

- Users
- Equipment
- Physical equipment units
- Rentals
- Rental items
- Inspections
- Charges
- Payments
- Supporting rental data

The complete model, constraints and design rationale are documented in:

```text
docs/data-model.md
```

### Entity Relationship Diagram

![Equipment rental entity relationship diagram](./evidence/01-er-diagram.png)

> The Mermaid source in `evidence/01-er-diagram.mmd` is the authoritative diagram source. If the source and screenshot differ, the screenshot should be regenerated from the current source.

## Rental Lifecycle

A rental follows an explicitly modelled state machine.

![Rental lifecycle state machine](./evidence/02-rental-state-machine.png)

The model contains eight rental statuses and ten permitted transitions.

Instead of allowing arbitrary status changes, lifecycle transitions are constrained by database rules.

For example, a completed rental should not be able to return to an active state.

A transition such as:

```text
COMPLETED → ACTIVE
```

is rejected.

The complete lifecycle is documented in:

```text
docs/state-machine.md
```

## Availability Modelling

Availability is period-based.

Rental periods use the half-open interval:

```text
[startAt, endAt)
```

This means a rental ending at a particular time does not conflict with another rental beginning at exactly that time.

Conceptually:

```text
Rental A
10:00 ├──────────────┤ 12:00

Rental B
                       12:00 ├──────────────┤ 14:00
```

These periods do not overlap.

The database includes enforcement designed to prevent a physical equipment unit from being reserved for conflicting periods.

## Database-Level Protection

Important business rules are not left entirely to a future application server.

The PostgreSQL layer includes:

- Check constraints
- Foreign keys
- Indexes
- Triggers
- Rental-period validation
- Availability enforcement
- Rental-state transition enforcement

This provides a second layer of protection for important data invariants.

## Rejection Testing

The repository contains executable tests demonstrating that invalid database operations are rejected.

### Invalid Rental Period

A rental where:

```text
startAt = endAt
```

is rejected by the database.

![Invalid rental period rejection](./evidence/03-invalid-date-range.png)

### Overlapping Reservation

An attempt to reserve a physical unit during an already occupied period is rejected.

![Overlapping reservation rejection](./evidence/04-overlapping-reservation.png)

### Invalid State Transition

A forbidden rental lifecycle transition is also rejected.

![Invalid rental state transition](./evidence/05-invalid-state-transition.png)

The corresponding SQL scripts are located in:

```text
database/evidence/
```

## REST API Design

The proposed API contract is documented in:

```text
docs/api-design.md
```

It covers:

- Endpoint design
- Request and response payloads
- Error catalogue
- Authorization boundaries
- Idempotency
- Cursor pagination
- Resource modelling
- GraphQL evaluation
- Real-time communication evaluation
- Traceability to product requirements

REST with polling was selected for the proposed MVP rather than introducing GraphQL or real-time push prematurely.

The API remains a design in this repository; no HTTP server is implemented here.

## Idempotency

The API design considers operations where retrying the same request could otherwise produce duplicate effects.

Idempotency is therefore part of the proposed API contract for relevant write operations.

The supporting persistence required for full idempotency enforcement is identified as future database work rather than presented as already implemented.

## Historical Data

Rental systems need to preserve what was agreed at the time of a transaction.

For example, if an equipment price changes later, an existing rental should not suddenly appear to have been created at the new price.

The model therefore considers historical preservation of information such as:

- Equipment names
- Agreed rental rates

This is an intentional use of denormalisation where preserving historical business truth is more important than always referencing the latest catalogue value.

## Query Design

Five SQL query workflows correspond to the major product actions:

```text
database/queries/01_manage_equipment.sql
database/queries/02_search_availability.sql
database/queries/03_create_rental.sql
database/queries/04_checkout_return.sql
database/queries/05_payment_summary.sql
```

The reservation demonstration runs inside a transaction and rolls back so the demonstration does not permanently modify the seeded state.

## Query-Plan Analysis

Two heavier database operations were analysed using:

```sql
EXPLAIN (ANALYZE, BUFFERS)
```

The repository includes a larger deterministic fixture specifically for this purpose.

### Availability Query

![Availability query plan](./evidence/06-availability-explain.png)

### Payment Summary Query

![Payment summary query plan](./evidence/07-payment-summary-explain.png)

An important lesson from this analysis is that defining an index does not guarantee PostgreSQL will use it.

The query planner makes a cost-based decision based on factors including:

- Table size
- Data distribution
- Selectivity
- Estimated cost
- Available access paths

A sequential scan can therefore be a legitimate query plan rather than evidence that an index is broken.

## Database Seeds

Two deterministic seed datasets serve different purposes.

### Demo Seed

```text
database/seeds/001_demo_data.sql
```

A small, readable dataset used for the main queries and rejection tests.

### Query-Plan Fixture

```text
database/seeds/002_query_plan_fixture.sql
```

A larger dataset generated specifically to make query-plan analysis more meaningful.

The fixture is optional and does not replace the demo dataset.

## Repository Structure

```text
.
├── README.md
│
├── docs/
│   ├── requirements.md
│   ├── data-model.md
│   ├── state-machine.md
│   └── api-design.md
│
├── database/
│   ├── migrations/
│   │   └── 001_initial_schema.sql
│   │
│   ├── seeds/
│   │   ├── 001_demo_data.sql
│   │   └── 002_query_plan_fixture.sql
│   │
│   ├── queries/
│   │   ├── 01_manage_equipment.sql
│   │   ├── 02_search_availability.sql
│   │   ├── 03_create_rental.sql
│   │   ├── 04_checkout_return.sql
│   │   └── 05_payment_summary.sql
│   │
│   └── evidence/
│       ├── 01_invalid_date_range.sql
│       ├── 02_overlapping_reservation.sql
│       ├── 03_invalid_state_transition.sql
│       ├── 04_availability_explain.sql
│       └── 05_payment_summary_explain.sql
│
└── evidence/
    ├── README.md
    ├── 01-er-diagram.mmd
    ├── 01-er-diagram.png
    ├── 02-rental-state-machine.png
    ├── 03-invalid-date-range.png
    ├── 04-overlapping-reservation.png
    ├── 05-invalid-state-transition.png
    ├── 06-availability-explain.png
    └── 07-payment-summary-explain.png
```

## Documentation

The repository includes detailed engineering documentation:

### Product Requirements

```text
docs/requirements.md
```

Defines the product purpose, roles, important user actions, scope and open decisions.

### Data Model

```text
docs/data-model.md
```

Documents the entities, relationships, normalization decisions, deliberate denormalization, identifiers, constraints, indexes and database rules.

### Rental State Machine

```text
docs/state-machine.md
```

Documents the rental statuses and permitted lifecycle transitions.

### API Design

```text
docs/api-design.md
```

Defines the proposed REST contract, payloads, errors, pagination, idempotency and architecture decisions.

### Evidence Guide

```text
evidence/README.md
```

Documents how the database evidence and screenshots were reproduced.

## Reproducing the Database

The database proof targets PostgreSQL 17.

A disposable PostgreSQL container can be used for local verification.

Example:

```powershell
$Container = "equipment-rental-pg"
$Db = "equipment_rental"
$PgUser = "evidence"

docker run --rm -d --name $Container `
    -e POSTGRES_USER=$PgUser `
    -e POSTGRES_PASSWORD=local_evidence_only `
    -e POSTGRES_DB=$Db `
    postgres:17
```

Check readiness:

```powershell
docker exec $Container pg_isready -U $PgUser -d $Db
```

Apply the migration followed by the demo seed.

The full reproducibility workflow and evidence-capture procedure are documented in:

```text
evidence/README.md
```

The credentials shown above are disposable local development values and are not production credentials.

## Design Decisions

Several decisions shaped this system.

### Separate Equipment From Physical Units

A catalogue item and a physical rentable asset have different responsibilities and therefore use separate entities.

### Enforce Critical Rules in PostgreSQL

Rules such as valid rental periods, conflicting reservations and lifecycle transitions benefit from database-level enforcement rather than relying entirely on application code.

### Preserve Historical Business Values

Selected rental information is intentionally preserved so later catalogue changes do not rewrite historical transactions.

### REST for the MVP

REST provides a simpler API surface for the identified workflows.

GraphQL and real-time communication were evaluated but deliberately deferred rather than added without a demonstrated product requirement.

### Measure Query Plans

Database indexes are treated as hypotheses to evaluate rather than automatic performance guarantees.

## What I Learned

This project reinforced that API design and database modelling are closely connected.

Some of the main lessons were:

- API resources should map clearly to the underlying business model.
- Physical inventory and catalogue data often require different entities.
- Time-range availability becomes significantly more complex when physical units can be reserved independently.
- Database constraints can protect important invariants even when application logic fails.
- State machines make lifecycle rules explicit and testable.
- Historical transactional data sometimes requires deliberate denormalisation.
- Idempotency should be considered during API design, not only after duplicate requests become a production problem.
- Query optimization should be based on actual query plans rather than the existence of indexes.
- A technically valid sequential scan can be the correct PostgreSQL decision.
- Architecture decisions should include what **not** to build yet.

Most importantly, the project helped me approach backend development by defining the data model, invariants and API contract before implementation.

## Project Context

This project was created as part of my **Product Design & Engineering** training and focuses specifically on **API design and data modelling**.

Unlike my implementation-focused projects, this repository deliberately stops before building the application server.

The goal is to demonstrate the reasoning that should happen before implementation:

```text
Requirements
     ↓
Domain Model
     ↓
Database Design
     ↓
Business Invariants
     ↓
API Contract
     ↓
Performance Analysis
     ↓
Implementation
```

This repository covers the stages leading up to implementation.

## License

This project is intended to be released under the MIT License.
