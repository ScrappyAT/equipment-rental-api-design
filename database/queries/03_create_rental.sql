-- Important user action: A3. Customer creates a rental reservation.
-- Question: What database transaction creates a PENDING rental and allocates one specific available unit while preserving the agreed commercial snapshot?
-- Support: rentals_customer_fk, rentals_period_valid, rentals_id_currency_key, rental_items_rental_currency_fk, rental_items_equipment_unit_fk, and rental_items_rental_equipment_unit_key. The rental_items_enforce_availability trigger invokes assert_rental_unit_available, which locks the parent rental and then the equipment unit under READ COMMITTED before checking overlap.
-- Expected: psql reports one inserted rental and one inserted rental item, then ROLLBACK. Neither row remains, so repeated execution leaves the seed unchanged. A competing overlap would abort the transaction and PostgreSQL would roll it back.

BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

INSERT INTO rentals (
    id,
    customer_id,
    status,
    start_at,
    end_at,
    base_amount,
    currency
)
VALUES (
    '40000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    'PENDING',
    TIMESTAMPTZ '2030-03-01 09:00:00+00',
    TIMESTAMPTZ '2030-03-03 17:00:00+00',
    550000,
    'NGN'
);

INSERT INTO rental_items (
    id,
    rental_id,
    equipment_unit_id,
    equipment_name_snapshot,
    daily_rate_amount,
    currency
)
VALUES (
    '40000000-0000-4000-8000-000000000002',
    '40000000-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000008',
    'Circular Saw 1900W',
    275000,
    'NGN'
);

ROLLBACK;
