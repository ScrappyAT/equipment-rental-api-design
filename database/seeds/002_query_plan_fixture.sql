BEGIN;

INSERT INTO users (id, email, display_name, role)
SELECT
    ('54000000-0000-4000-8000-' || lpad(i::TEXT, 12, '0'))::UUID,
    format('plan.customer.%s@example.test', lpad(i::TEXT, 6, '0')),
    format('Plan Customer %s', lpad(i::TEXT, 6, '0')),
    'CUSTOMER'::user_role
FROM generate_series(1, 1000) AS s(i);

INSERT INTO equipment (
    id,
    category_id,
    name,
    description,
    daily_rate_amount,
    currency,
    status
)
SELECT
    ('52000000-0000-4000-8000-' || lpad(i::TEXT, 12, '0'))::UUID,
    CASE
        WHEN i <= 10 THEN 'a0000000-0000-4000-8000-000000000001'::UUID
        WHEN i <= 20 THEN 'a0000000-0000-4000-8000-000000000002'::UUID
        ELSE 'a0000000-0000-4000-8000-000000000003'::UUID
    END,
    CASE
        WHEN i <= 10 THEN format('Plan Generator %s', lpad(i::TEXT, 2, '0'))
        WHEN i <= 20 THEN format('Plan Camera %s', lpad((i - 10)::TEXT, 2, '0'))
        ELSE format('Plan Power Tool %s', lpad((i - 20)::TEXT, 2, '0'))
    END,
    format('Deterministic query-plan fixture model %s.', lpad(i::TEXT, 2, '0')),
    (100000 + i * 1000)::BIGINT,
    'NGN'::CHAR(3),
    'ACTIVE'::equipment_status
FROM generate_series(1, 30) AS s(i);

INSERT INTO equipment_units (
    id,
    equipment_id,
    asset_tag,
    serial_number,
    status
)
SELECT
    ('53000000-0000-4000-8000-' || lpad(i::TEXT, 12, '0'))::UUID,
    ('52000000-0000-4000-8000-' || lpad((((i - 1) % 30) + 1)::TEXT, 12, '0'))::UUID,
    format('PLAN-%s', lpad(i::TEXT, 6, '0')),
    format('PLAN-SERIAL-%s', lpad(i::TEXT, 6, '0')),
    CASE
        WHEN i % 10 IN (7, 8) THEN 'MAINTENANCE'::equipment_unit_status
        WHEN i % 10 = 9 THEN 'RETIRED'::equipment_unit_status
        ELSE 'AVAILABLE'::equipment_unit_status
    END
FROM generate_series(1, 30000) AS s(i);

INSERT INTO rentals (
    id,
    customer_id,
    status,
    start_at,
    end_at,
    base_amount,
    currency
)
SELECT
    ('55000000-0000-4000-8000-' || lpad(i::TEXT, 12, '0'))::UUID,
    ('54000000-0000-4000-8000-' || lpad((((i - 1) % 1000) + 1)::TEXT, 12, '0'))::UUID,
    'PENDING'::rental_status,
    TIMESTAMPTZ '2028-06-01 08:00:00+00' + ((i % 30) * INTERVAL '1 day'),
    TIMESTAMPTZ '2028-06-03 08:00:00+00' + ((i % 30) * INTERVAL '1 day'),
    ((100000 + ((((i - 1) % 30) + 1) * 1000)) * 2)::BIGINT,
    'NGN'::CHAR(3)
FROM generate_series(1, 30000) AS s(i);

INSERT INTO rental_items (
    id,
    rental_id,
    equipment_unit_id,
    equipment_name_snapshot,
    daily_rate_amount,
    currency
)
SELECT
    ('56000000-0000-4000-8000-' || lpad(i::TEXT, 12, '0'))::UUID,
    ('55000000-0000-4000-8000-' || lpad(i::TEXT, 12, '0'))::UUID,
    ('53000000-0000-4000-8000-' || lpad(i::TEXT, 12, '0'))::UUID,
    format(
        'Plan %s %s',
        CASE
            WHEN ((i - 1) % 30) + 1 <= 10 THEN 'Generator'
            WHEN ((i - 1) % 30) + 1 <= 20 THEN 'Camera'
            ELSE 'Power Tool'
        END,
        lpad((((i - 1) % 30) + 1)::TEXT, 2, '0')
    ),
    (100000 + ((((i - 1) % 30) + 1) * 1000))::BIGINT,
    'NGN'::CHAR(3)
FROM generate_series(1, 30000) AS s(i);

INSERT INTO rentals (
    id,
    customer_id,
    status,
    start_at,
    end_at,
    base_amount,
    currency
)
SELECT
    ('55100000-0000-4000-8000-' || lpad(i::TEXT, 12, '0'))::UUID,
    ('54000000-0000-4000-8000-' || lpad((((i - 1) % 1000) + 1)::TEXT, 12, '0'))::UUID,
    'PENDING'::rental_status,
    TIMESTAMPTZ '2030-02-11 08:00:00+00',
    TIMESTAMPTZ '2030-02-12 18:00:00+00',
    ((100000 + ((((i - 1) % 30) + 1) * 1000)) * 2)::BIGINT,
    'NGN'::CHAR(3)
FROM generate_series(1, 30000) AS s(i)
WHERE i % 10 < 7;

INSERT INTO rental_items (
    id,
    rental_id,
    equipment_unit_id,
    equipment_name_snapshot,
    daily_rate_amount,
    currency
)
SELECT
    ('56100000-0000-4000-8000-' || lpad(i::TEXT, 12, '0'))::UUID,
    ('55100000-0000-4000-8000-' || lpad(i::TEXT, 12, '0'))::UUID,
    ('53000000-0000-4000-8000-' || lpad(i::TEXT, 12, '0'))::UUID,
    format(
        'Plan %s %s',
        CASE
            WHEN ((i - 1) % 30) + 1 <= 10 THEN 'Generator'
            WHEN ((i - 1) % 30) + 1 <= 20 THEN 'Camera'
            ELSE 'Power Tool'
        END,
        lpad((((i - 1) % 30) + 1)::TEXT, 2, '0')
    ),
    (100000 + ((((i - 1) % 30) + 1) * 1000))::BIGINT,
    'NGN'::CHAR(3)
FROM generate_series(1, 30000) AS s(i)
WHERE i % 10 < 7;

INSERT INTO charges (
    id,
    rental_id,
    type,
    description,
    amount,
    currency
)
SELECT
    ('57000000-0000-4000-8000-' || lpad(i::TEXT, 12, '0'))::UUID,
    ('55000000-0000-4000-8000-' || lpad(i::TEXT, 12, '0'))::UUID,
    'LATE_FEE'::charge_type,
    format('Plan baseline charge %s.', lpad(i::TEXT, 6, '0')),
    (1000 + (i % 1000))::BIGINT,
    'NGN'::CHAR(3)
FROM generate_series(1, 30000) AS s(i);

INSERT INTO payments (
    id,
    rental_id,
    provider_reference,
    amount,
    currency,
    status,
    paid_at
)
SELECT
    ('58000000-0000-4000-8000-' || lpad(i::TEXT, 12, '0'))::UUID,
    ('55000000-0000-4000-8000-' || lpad(i::TEXT, 12, '0'))::UUID,
    format('PLAN-BASELINE-SUCCEEDED-%s', lpad(i::TEXT, 6, '0')),
    1000::BIGINT,
    'NGN'::CHAR(3),
    'SUCCEEDED'::payment_status,
    TIMESTAMPTZ '2028-05-20 10:00:00+00' + (i * INTERVAL '1 minute')
FROM generate_series(1, 30000) AS s(i);

INSERT INTO charges (
    id,
    rental_id,
    type,
    description,
    amount,
    currency
)
SELECT
    ('57100000-0000-4000-8000-' || lpad(i::TEXT, 12, '0'))::UUID,
    '55000000-0000-4000-8000-000000000001'::UUID,
    'DAMAGE'::charge_type,
    format('Plan summary charge %s.', lpad(i::TEXT, 4, '0')),
    1000::BIGINT,
    'NGN'::CHAR(3)
FROM generate_series(1, 400) AS s(i);

INSERT INTO payments (
    id,
    rental_id,
    provider_reference,
    amount,
    currency,
    status,
    paid_at
)
SELECT
    ('58100000-0000-4000-8000-' || lpad(i::TEXT, 12, '0'))::UUID,
    '55000000-0000-4000-8000-000000000001'::UUID,
    format('PLAN-SUMMARY-SUCCEEDED-%s', lpad(i::TEXT, 4, '0')),
    1000::BIGINT,
    'NGN'::CHAR(3),
    'SUCCEEDED'::payment_status,
    TIMESTAMPTZ '2028-05-21 10:00:00+00' + (i * INTERVAL '1 minute')
FROM generate_series(1, 400) AS s(i);

INSERT INTO payments (
    id,
    rental_id,
    provider_reference,
    amount,
    currency,
    status,
    paid_at
)
SELECT
    ('58200000-0000-4000-8000-' || lpad(i::TEXT, 12, '0'))::UUID,
    '55000000-0000-4000-8000-000000000001'::UUID,
    format('PLAN-SUMMARY-FAILED-%s', lpad(i::TEXT, 4, '0')),
    1000::BIGINT,
    'NGN'::CHAR(3),
    'FAILED'::payment_status,
    NULL
FROM generate_series(1, 50) AS s(i);

INSERT INTO payments (
    id,
    rental_id,
    provider_reference,
    amount,
    currency,
    status,
    paid_at
)
SELECT
    ('58300000-0000-4000-8000-' || lpad(i::TEXT, 12, '0'))::UUID,
    '55000000-0000-4000-8000-000000000001'::UUID,
    format('PLAN-SUMMARY-PENDING-%s', lpad(i::TEXT, 4, '0')),
    1000::BIGINT,
    'NGN'::CHAR(3),
    'PENDING'::payment_status,
    NULL
FROM generate_series(1, 50) AS s(i);

INSERT INTO payments (
    id,
    rental_id,
    provider_reference,
    amount,
    currency,
    status,
    paid_at
)
SELECT
    ('58400000-0000-4000-8000-' || lpad(i::TEXT, 12, '0'))::UUID,
    ('55100000-0000-4000-8000-' || lpad(i::TEXT, 12, '0'))::UUID,
    format('PLAN-TARGET-PENDING-%s', lpad(i::TEXT, 6, '0')),
    1000::BIGINT,
    'NGN'::CHAR(3),
    'PENDING'::payment_status,
    NULL
FROM generate_series(1, 21000) AS s(i)
WHERE i % 10 = 0;

COMMIT;

ANALYZE users;
ANALYZE categories;
ANALYZE equipment;
ANALYZE equipment_units;
ANALYZE rentals;
ANALYZE rental_items;
ANALYZE inspections;
ANALYZE charges;
ANALYZE payments;
