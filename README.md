# Equipment Rental Platform

## Assessment purpose

This repository is the design and database proof for Task 3: API Design and Data Modeling. It records product requirements, the logical and PostgreSQL data model, the rental lifecycle, a proposed HTTP API contract, executable database queries, rejection tests, query-plan evidence, and seven captured evidence screenshots.

No API server exists in this repository. The API is designed, not built.

## Product overview

The Equipment Rental Platform lets customers find rentable equipment for a requested period, reserve it, pay the rental and applicable additional charges, collect the equipment, and return it. Staff manage the equipment catalogue, individual physical assets, availability, reservations, checkouts, returns, and inspections.

The model distinguishes a rentable equipment model or type (`Equipment`) from each individual physical asset (`EquipmentUnit`).

## Documents

| Document | What it answers |
| --- | --- |
| [`docs/requirements.md`](docs/requirements.md) | Product purpose, roles, the five important user actions, in-scope and out-of-scope decisions, and what is still open. |
| [`docs/data-model.md`](docs/data-model.md) | The nine entities, normalisation and deliberate denormalisation, per-entity deletion and retention, identifier rationale, the action/query/index mapping, constraints, triggers, and the ER diagrams. |
| [`docs/state-machine.md`](docs/state-machine.md) | The eight rental statuses, the ten permitted transitions, the reserving-status group, and the forbidden edges. |
| [`docs/api-design.md`](docs/api-design.md) | The proposed REST contract: endpoint inventory, payloads, error catalog, idempotency, cursor pagination, authorization, GraphQL and real-time analysis, and traceability. It is a design; nothing in it is implemented. |
| [`evidence/README.md`](evidence/README.md) | The seven screenshots, the reproducible PostgreSQL 17 workflow, the manual capture order, and when a screenshot must be recaptured. |

## Scope

The design and database proof cover:

- Equipment catalogue and physical-unit management.
- Period-based availability and reservations using half-open `[startAt, endAt)`.
- Rental lifecycle transitions enforced by a database trigger.
- Checkout and return inspections.
- Late-fee and damage charges, plus payments.
- Historical preservation of equipment names and agreed rates.
- Database constraints, indexes, and cross-table enforcement for those decisions.
- A small deterministic demo seed and five database queries mapped to the important user actions.
- Database rejection evidence for invalid periods, overlapping physical-unit reservations, and forbidden lifecycle transitions.
- A separate, optional deterministic volume fixture and two `EXPLAIN (ANALYZE, BUFFERS)` scripts for the two heavy assessment queries.
- A proposed REST contract in `docs/api-design.md`, plus GraphQL and real-time analyses that both recommend deferral in favour of REST plus polling for the MVP.
- Seven captured evidence screenshots in `evidence/`.

The following remain outside this step:

- API or server implementation.
- Frontend implementation.
- Authentication or authorization implementation.
- GraphQL or real-time push, which are analysed but deliberately not adopted; refunds and a general payment ledger remain out of product scope.
- Business features not stated in the assessment brief.
- GitHub publishing and commits.

## Five important user actions

| # | Action | Proposed endpoint | Assessment query |
| --- | --- | --- | --- |
| A1 | Staff add and manage rental equipment and physical units. | `POST /api/v1/equipment`, `POST /api/v1/equipment/{equipmentId}/units` | `database/queries/01_manage_equipment.sql` |
| A2 | Customers search for equipment available during a specified rental period. | `GET /api/v1/equipment/availability` | `database/queries/02_search_availability.sql` |
| A3 | Customers create a reservation for one or more equipment items. | `POST /api/v1/rentals` | `database/queries/03_create_rental.sql` |
| A4 | Staff check equipment out and back in while recording condition inspections. | `POST /api/v1/rentals/{rentalId}/transitions`, `POST /api/v1/rentals/{rentalId}/items/{rentalItemId}/inspections` | `database/queries/04_checkout_return.sql` |
| A5 | Customers pay for the rental and any applicable additional charges. | `POST /api/v1/rentals/{rentalId}/payments`, `GET /api/v1/rentals/{rentalId}/payment-summary` | `database/queries/05_payment_summary.sql` |

## Repository structure

```text
.
├── README.md
├── docs/
│   ├── requirements.md
│   ├── data-model.md
│   ├── state-machine.md
│   └── api-design.md
├── database/
│   ├── migrations/
│   │   ├── .gitkeep
│   │   └── 001_initial_schema.sql
│   ├── seeds/
│   │   ├── .gitkeep
│   │   ├── 001_demo_data.sql
│   │   └── 002_query_plan_fixture.sql
│   ├── queries/
│   │   ├── .gitkeep
│   │   ├── 01_manage_equipment.sql
│   │   ├── 02_search_availability.sql
│   │   ├── 03_create_rental.sql
│   │   ├── 04_checkout_return.sql
│   │   └── 05_payment_summary.sql
│   └── evidence/
│       ├── 01_invalid_date_range.sql
│       ├── 02_overlapping_reservation.sql
│       ├── 03_invalid_state_transition.sql
│       ├── 04_availability_explain.sql
│       └── 05_payment_summary_explain.sql
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

The three `.gitkeep` files exist only so their directories survive in version control; they hold no content.

The migration creates the PostgreSQL schema, enums, keys, constraints, indexes, and database triggers.

The two seeds are not interchangeable:

| Seed | Size | Purpose |
| --- | --- | --- |
| `database/seeds/001_demo_data.sql` | Small, hand-written, deterministic | The readable dataset behind the five assessment queries and the three rejection scripts. Intended for one clean load into an empty database. Not a reset script. |
| `database/seeds/002_query_plan_fixture.sql` | Large, generated with `generate_series` | Optional. Loaded only to give the two `EXPLAIN` scripts enough rows to produce a meaningful plan. It leaves the demo seed untouched and runs `ANALYZE`. |

`evidence/01-er-diagram.mmd` is the Mermaid source of the compact relationship diagram in `docs/data-model.md`. It is kept as a separate file so the screenshot and the document can be compared directly.

## Reproduce the database proof

PostgreSQL 17 is required. Neither PostgreSQL nor Docker is bundled with this repository; both must already be installed on your machine. The workflow below uses a disposable `postgres:17` container with no host port, so nothing is exposed to your network and nothing survives the session.

The container name, database name, and password below are throwaway local values. They are not credentials for anything real, and no real credential belongs in this repository or in a screenshot.

```powershell
$Container = "equipment-rental-pg"
$Db = "equipment_rental"
$PgUser = "evidence"

docker run --rm -d --name $Container `
    -e POSTGRES_USER=$PgUser `
    -e POSTGRES_PASSWORD=local_evidence_only `
    -e POSTGRES_DB=$Db `
    postgres:17

docker exec $Container pg_isready -U $PgUser -d $Db

function Invoke-Psql([string[]]$Sql) {
    $Sql -join "`n" | docker exec -i $Container psql -X -U $PgUser -d $Db -v ON_ERROR_STOP=1 -f -
    if ($LASTEXITCODE -ne 0) { throw "psql failed with exit code $LASTEXITCODE." }
}

Invoke-Psql @("$(Get-Content -Raw -LiteralPath 'database\migrations\001_initial_schema.sql')")
Invoke-Psql @("$(Get-Content -Raw -LiteralPath 'database\seeds\001_demo_data.sql')")
```

If you already have a PostgreSQL 17 instance and prefer to use it, apply the same files with a normal `psql` connection instead. The order below is the same in both cases.

The block above is PowerShell: it uses backtick line continuations, `$Container`/`$Db`/`$PgUser` variables, a `function` definition, and backslash file paths, so run it from PowerShell in the repository root. Nothing in the procedure depends on PowerShell otherwise. The container is created with the same `docker run` arguments in any shell, and the equivalent on a POSIX shell is `docker exec -i <container> psql -X -U evidence -d equipment_rental -v ON_ERROR_STOP=1 -f - < database/migrations/001_initial_schema.sql`, substituting the container, user, and database names you chose.

### Assessment queries

```text
database/queries/01_manage_equipment.sql
database/queries/02_search_availability.sql
database/queries/03_create_rental.sql
database/queries/04_checkout_return.sql
database/queries/05_payment_summary.sql
```

`03_create_rental.sql` performs its demonstration inserts inside a transaction and ends with `ROLLBACK`, so it leaves the loaded state unchanged.

### Rejection evidence

Run these against the database holding the demo seed. Each script triggers the real database rejection, reports the returned SQLSTATE and PostgreSQL message, prints the post-test state, and rolls back:

```text
database/evidence/01_invalid_date_range.sql
database/evidence/02_overlapping_reservation.sql
database/evidence/03_invalid_state_transition.sql
```

| Script | Mechanism | SQLSTATE |
| --- | --- | --- |
| `01_invalid_date_range.sql` | `rentals_period_valid` | `23514` |
| `02_overlapping_reservation.sql` | `rental_items_enforce_availability` invoking `assert_rental_unit_available` | `23P01` |
| `03_invalid_state_transition.sql` | `rentals_enforce_status_transition` invoking `enforce_rental_status_transition` | `23514` |

### Query-plan evidence

Load the optional volume fixture once, after the rejection scripts, then run the two read-only plan statements:

```text
database/seeds/002_query_plan_fixture.sql
database/evidence/04_availability_explain.sql
database/evidence/05_payment_summary_explain.sql
```

These scripts use `EXPLAIN (ANALYZE, BUFFERS)` and do not change planner settings. Report the plan PostgreSQL actually produces, including any sequential scan it reasonably chooses: an index defined in the migration is not evidence that any query used it, and a sequential scan is a legitimate cost-based decision rather than a failure.

### Clean up

```powershell
docker stop $Container
```

## Evidence screenshots

The seven screenshots are embedded, with per-screenshot detail, in [`evidence/README.md`](evidence/README.md):

| Screenshot | Shows |
| --- | --- |
| [`01-er-diagram.png`](evidence/01-er-diagram.png) | Nine-entity relationship view and cardinalities. |
| [`02-rental-state-machine.png`](evidence/02-rental-state-machine.png) | Eight rental statuses and ten permitted transitions. |
| [`03-invalid-date-range.png`](evidence/03-invalid-date-range.png) | `23514` rejection of a zero-length rental period (`start_at = end_at`). |
| [`04-overlapping-reservation.png`](evidence/04-overlapping-reservation.png) | `23P01` rejection of an overlapping unit reservation. |
| [`05-invalid-state-transition.png`](evidence/05-invalid-state-transition.png) | `23514` rejection of `COMPLETED -> ACTIVE`. |
| [`06-availability-explain.png`](evidence/06-availability-explain.png) | Availability query plan against the volume fixture. |
| [`07-payment-summary-explain.png`](evidence/07-payment-summary-explain.png) | Payment-summary query plan against the volume fixture. |

If you change a diagram or an evidence script, follow the recapture table in `evidence/README.md`. Note that `evidence/01-er-diagram.mmd` was recently corrected so the rental-to-item edge reads zero-or-more, which matches what the migration enforces, so `01-er-diagram.png` still needs to be recaptured from the updated source.

Capture them in this order, so each screenshot is reproducible from the state the previous step left behind:

| Order | Screenshot | Produced from | Database state required |
| --- | --- | --- | --- |
| 1 | `01-er-diagram.png` | Rendering `evidence/01-er-diagram.mmd` | none, it is a diagram |
| 2 | `02-rental-state-machine.png` | `docs/state-machine.md` | none, it is a diagram |
| 3 | `03-invalid-date-range.png` | `database/evidence/01_invalid_date_range.sql` | migration plus demo seed |
| 4 | `04-overlapping-reservation.png` | `database/evidence/02_overlapping_reservation.sql` | migration plus demo seed |
| 5 | `05-invalid-state-transition.png` | `database/evidence/03_invalid_state_transition.sql` | migration plus demo seed |
| 6 | `06-availability-explain.png` | `database/evidence/04_availability_explain.sql` | migration, demo seed, then the volume fixture |
| 7 | `07-payment-summary-explain.png` | `database/evidence/05_payment_summary_explain.sql` | migration, demo seed, then the volume fixture |

Screenshots 6 and 7 require the volume fixture, so load it before capturing them. Screenshots 3 to 5 do not need it: each rejection script targets explicit seeded identifiers and rolls back, so it produces the same output whether or not the fixture is loaded. All three rejection scripts can be re-run in any order against the demo-seeded database.

## Boundary

This repository is a design and database proof, not a full application. It contains no API code, frontend, authentication, or application dependencies. The migration, the two seeds, the five assessment queries, the five evidence scripts, and the screenshots are included, and `docs/api-design.md` specifies the intended HTTP surface without implementing it. Several decisions that need a database change, such as an idempotency-key table and stable custom SQLSTATE codes for the triggers, are named in that document as future migrations rather than applied here. GitHub publishing and commits are not part of this step.
