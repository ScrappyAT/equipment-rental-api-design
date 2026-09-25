-- Invalid operation: change the seeded COMPLETED rental back to ACTIVE.
-- Expected mechanism: rentals_enforce_status_transition calls enforce_rental_status_transition;
-- the BEFORE UPDATE trigger rejects this terminal-state transition with check_violation
-- (SQLSTATE 23514).
-- Domain impact: a closed rental cannot silently reopen and permit checkout or further activity.
-- PostgreSQL rolls back the rejected UPDATE subtransaction, and the outer transaction is rolled
-- back, leaving the seeded rental COMPLETED.

SELECT
    'EVIDENCE 03: INVALID RENTAL STATE TRANSITION' AS evidence_test,
    'Update the seeded COMPLETED rental to ACTIVE' AS attempted_operation,
    'rentals_enforce_status_transition -> enforce_rental_status_transition' AS expected_database_mechanism;

BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

DO $evidence$
DECLARE
    v_sqlstate TEXT;
    v_message TEXT;
BEGIN
    BEGIN
        UPDATE rentals
        SET status = 'ACTIVE'
        WHERE id = 'd0000000-0000-4000-8000-000000000001';
    EXCEPTION
        WHEN check_violation THEN
            GET STACKED DIAGNOSTICS
                v_sqlstate = RETURNED_SQLSTATE,
                v_message = MESSAGE_TEXT;

            RAISE NOTICE
                'EXPECTED POSTGRESQL REJECTION: SQLSTATE %, mechanism rentals_enforce_status_transition -> enforce_rental_status_transition, message %',
                v_sqlstate,
                v_message;
    END;
END
$evidence$;

SELECT
    status,
    status = 'COMPLETED'::rental_status AS completed_status_preserved
FROM rentals
WHERE id = 'd0000000-0000-4000-8000-000000000001';

ROLLBACK;
