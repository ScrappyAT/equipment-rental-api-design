-- Invalid operation: insert a rental whose exclusive end is equal to its start.
-- Expected mechanism: rentals_period_valid, the CHECK constraint requiring end_at > start_at.
-- Domain impact: a zero-length or reversed rental period is not a valid equipment reservation.
-- The rejected INSERT occurs inside a nested PL/pgSQL block, so PostgreSQL rolls back that failed
-- subtransaction. The outer transaction is also rolled back, leaving no evidence data behind.

SELECT
    'EVIDENCE 01: INVALID RENTAL PERIOD' AS evidence_test,
    'INSERT a rental with start_at = end_at' AS attempted_operation,
    'rentals_period_valid CHECK (end_at > start_at)' AS expected_database_mechanism;

BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

DO $evidence$
DECLARE
    v_sqlstate TEXT;
    v_constraint_name TEXT;
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
            '50000000-0000-4000-8000-000000000001',
            '10000000-0000-4000-8000-000000000001',
            'PENDING',
            TIMESTAMPTZ '2030-04-01 09:00:00+00',
            TIMESTAMPTZ '2030-04-01 09:00:00+00',
            100000,
            'NGN'
        );
    EXCEPTION
        WHEN check_violation THEN
            GET STACKED DIAGNOSTICS
                v_sqlstate = RETURNED_SQLSTATE,
                v_constraint_name = CONSTRAINT_NAME,
                v_message = MESSAGE_TEXT;

            RAISE NOTICE
                'EXPECTED POSTGRESQL REJECTION: SQLSTATE %, constraint %, message %',
                v_sqlstate,
                v_constraint_name,
                v_message;
    END;
END
$evidence$;

SELECT COUNT(*) AS invalid_date_rows_visible_before_rollback
FROM rentals
WHERE id = '50000000-0000-4000-8000-000000000001';

ROLLBACK;
