-- Important user action: A5. Customer pays the rental and applicable additional charges.
-- Question: For the supplied rental, what are the authoritative base amount, additional charges, total amount owed, successful amount paid, outstanding balance, and currency?
-- Support: rentals_pkey, charges_rental_currency_idx, payments_rental_status_idx, the positive-amount checks, and the composite rental/child currency foreign keys. charges_rental_id_idx is a narrower sibling with the same leading column and also supports this lookup; the wider charges_rental_currency_idx is the helper named by database/evidence/05_payment_summary_explain.sql. Charges and payments are aggregated independently before joining, preventing one-to-many multiplication. Which index the planner actually uses is reported by the EXPLAIN evidence, not asserted here.
-- Expected: base 9,300,000; charges 750,000; amount owed 10,050,000; successful payments 6,000,000; balance 4,050,000; currency NGN. FAILED and PENDING payments do not reduce the balance.
-- Plan note: Prefix this statement with EXPLAIN (ANALYZE, BUFFERS) when collecting later evidence. PostgreSQL may correctly choose sequential scans on the tiny seed; do not disable sequential scans merely to force an index.

WITH parameters AS (
    SELECT 'd0000000-0000-4000-8000-000000000001'::UUID AS rental_id
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
