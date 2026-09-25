-- This runs the same independently aggregated payment-summary access pattern as
-- database/queries/05_payment_summary.sql under EXPLAIN (ANALYZE, BUFFERS). Only the rental
-- parameter changes: the fixture rental has 401 charges and 501 payment attempts so the aggregate
-- is representative. FAILED and PENDING payments are present but must not reduce amount paid.
-- Expected helpers: rentals_pkey, charges_rental_currency_idx, and payments_rental_status_idx.
-- Review aggregate/index nodes, SUCCEEDED-only aggregate FILTER behavior, buffers, execution time, and any
-- Seq Scan nodes. PostgreSQL remains free to choose sequential scans when they are estimated cheaper;
-- this script does not disable or force any planner feature.

EXPLAIN (ANALYZE, BUFFERS)
WITH parameters AS (
    SELECT '55000000-0000-4000-8000-000000000001'::UUID AS rental_id
),
charge_totals AS (
    SELECT
        c.rental_id,
        SUM(c.amount) AS additional_charge_amount
    FROM charges AS c
    JOIN parameters AS p
      ON p.rental_id = c.rental_id
    GROUP BY c.rental_id
),
payment_totals AS (
    SELECT
        pay.rental_id,
        SUM(pay.amount) FILTER (WHERE pay.status = 'SUCCEEDED') AS amount_paid
    FROM payments AS pay
    JOIN parameters AS p
      ON p.rental_id = pay.rental_id
    GROUP BY pay.rental_id
)
SELECT
    r.id AS rental_id,
    r.base_amount,
    COALESCE(ct.additional_charge_amount, 0::BIGINT) AS additional_charge_amount,
    r.base_amount + COALESCE(ct.additional_charge_amount, 0::BIGINT) AS amount_owed,
    COALESCE(pt.amount_paid, 0::BIGINT) AS amount_paid,
    (
        r.base_amount
        + COALESCE(ct.additional_charge_amount, 0::BIGINT)
        - COALESCE(pt.amount_paid, 0::BIGINT)
    ) AS balance,
    r.currency
FROM rentals AS r
JOIN parameters AS p
  ON p.rental_id = r.id
LEFT JOIN charge_totals AS ct
  ON ct.rental_id = r.id
LEFT JOIN payment_totals AS pt
  ON pt.rental_id = r.id;
