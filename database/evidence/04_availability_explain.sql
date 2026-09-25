-- This runs the same half-open availability search as database/queries/02_search_availability.sql
-- under EXPLAIN (ANALYZE, BUFFERS). It examines available active equipment in one category and
-- removes units blocked by any overlapping reserving rental.
-- Expected helpers: categories_slug_lower_uidx, equipment_category_id_idx,
-- equipment_units_available_idx, rental_items_equipment_unit_rental_idx, and rentals_pkey.
-- Review the anti-join/index nodes, estimated versus actual rows, shared/local buffer counts,
-- execution time, and any Seq Scan nodes. A sequential scan is acceptable when PostgreSQL judges
-- it cheaper; this script does not disable or force any planner feature.

EXPLAIN (ANALYZE, BUFFERS)
WITH parameters AS (
    SELECT
        TIMESTAMPTZ '2030-02-11 09:00:00+00' AS requested_start_at,
        TIMESTAMPTZ '2030-02-12 17:00:00+00' AS requested_end_at,
        'generators'::TEXT AS category_slug
),
eligible_units AS (
    SELECT
        u.id AS equipment_unit_id,
        u.asset_tag,
        u.serial_number,
        e.id AS equipment_id,
        e.name AS equipment_name,
        e.description,
        e.daily_rate_amount,
        e.currency,
        c.id AS category_id,
        c.name AS category_name,
        c.slug AS category_slug
    FROM equipment_units AS u
    JOIN equipment AS e
      ON e.id = u.equipment_id
    JOIN categories AS c
      ON c.id = e.category_id
    CROSS JOIN parameters AS p
    WHERE u.status = 'AVAILABLE'
      AND u.deleted_at IS NULL
      AND e.status = 'ACTIVE'
      AND e.deleted_at IS NULL
      AND (p.category_slug IS NULL OR c.slug = lower(p.category_slug))
      AND NOT EXISTS (
          SELECT 1
          FROM rental_items AS ri
          JOIN rentals AS r
            ON r.id = ri.rental_id
          WHERE ri.equipment_unit_id = u.id
            AND r.status IN (
                'PENDING',
                'CONFIRMED',
                'READY_FOR_PICKUP',
                'ACTIVE',
                'OVERDUE'
            )
            AND r.start_at < p.requested_end_at
            AND p.requested_start_at < r.end_at
      )
)
SELECT
    equipment_id,
    equipment_name,
    description,
    daily_rate_amount,
    currency,
    equipment_unit_id,
    asset_tag,
    serial_number,
    category_id,
    category_name,
    category_slug
FROM eligible_units
ORDER BY category_name, equipment_name, asset_tag;
