-- Invalid operation: allocate seeded GEN-002 to a new rental overlapping GEN-002's seeded
-- CONFIRMED reservation. Both rentals reserve within the half-open intervals that overlap.
-- Expected mechanism: rental_items_enforce_availability calls enforce_rental_item_availability
-- and assert_rental_unit_available, which locks the parent rental and physical unit before
-- raising exclusion_violation (SQLSTATE 23P01) for the conflict.
-- Domain impact: one physical asset cannot be promised to two customers for overlapping periods.
-- PostgreSQL rolls back the rejected nested subtransaction, including its temporary parent rental;
-- the outer transaction is rolled back as well.

SELECT
    'EVIDENCE 02: OVERLAPPING RESERVATION' AS evidence_test,
    'Allocate seeded GEN-002 to a second overlapping rental' AS attempted_operation,
    'rental_items_enforce_availability -> assert_rental_unit_available' AS expected_database_mechanism;

BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

DO $evidence$
DECLARE
    v_sqlstate TEXT;
    v_message TEXT;
BEGIN
    BEGIN
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
            '50000000-0000-4000-8000-000000000002',
            '10000000-0000-4000-8000-000000000001',
            'PENDING',
            TIMESTAMPTZ '2030-02-12 09:00:00+00',
            TIMESTAMPTZ '2030-02-13 10:00:00+00',
            2500000,
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
            '50000000-0000-4000-8000-000000000003',
            '50000000-0000-4000-8000-000000000002',
            'c0000000-0000-4000-8000-000000000002',
            'EcoPower 5kVA Generator',
            2500000,
            'NGN'
        );
    EXCEPTION
        WHEN exclusion_violation THEN
            GET STACKED DIAGNOSTICS
                v_sqlstate = RETURNED_SQLSTATE,
                v_message = MESSAGE_TEXT;

            RAISE NOTICE
                'EXPECTED POSTGRESQL REJECTION: SQLSTATE %, mechanism rental_items_enforce_availability -> assert_rental_unit_available, message %',
                v_sqlstate,
                v_message;
    END;
END
$evidence$;

SELECT
    (SELECT COUNT(*)
     FROM rentals
     WHERE id = '50000000-0000-4000-8000-000000000002') AS overlap_rental_rows_visible_before_rollback,
    (SELECT COUNT(*)
     FROM rental_items
     WHERE id = '50000000-0000-4000-8000-000000000003') AS overlap_item_rows_visible_before_rollback;

ROLLBACK;
