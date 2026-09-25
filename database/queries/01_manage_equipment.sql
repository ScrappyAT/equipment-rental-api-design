-- Important user action: A1. Staff manage equipment and physical units.
-- Question: What is each equipment model's catalogue status within its category, and what is the current operational status of every non-deleted physical unit?
-- Support: equipment_category_id_idx, equipment_units_equipment_id_idx, equipment_status_idx, equipment_units_status_idx, plus the Equipment -> Category and Equipment -> EquipmentUnit foreign keys.
-- Expected: Six models. EcoPower has four units (two AVAILABLE, one MAINTENANCE, one RETIRED); each active camera and power-tool model has one AVAILABLE unit; Legacy Film Camera is INACTIVE with zero units.

WITH unit_summary AS (
    SELECT
        u.equipment_id,
        COUNT(*) AS physical_unit_count,
        COUNT(*) FILTER (WHERE u.status = 'AVAILABLE') AS available_unit_count,
        jsonb_agg(
            jsonb_build_object(
                'equipment_unit_id', u.id,
                'asset_tag', u.asset_tag,
                'serial_number', u.serial_number,
                'status', u.status
            )
            ORDER BY u.asset_tag
        ) AS physical_units
    FROM equipment_units AS u
    WHERE u.deleted_at IS NULL
    GROUP BY u.equipment_id
)
SELECT
    e.id AS equipment_id,
    e.name AS equipment_name,
    e.status AS equipment_status,
    c.id AS category_id,
    c.name AS category_name,
    c.slug AS category_slug,
    e.daily_rate_amount,
    e.currency,
    COALESCE(us.physical_unit_count, 0) AS physical_unit_count,
    COALESCE(us.available_unit_count, 0) AS available_unit_count,
    COALESCE(us.physical_units, '[]'::jsonb) AS physical_units
FROM equipment AS e
JOIN categories AS c
  ON c.id = e.category_id
LEFT JOIN unit_summary AS us
  ON us.equipment_id = e.id
WHERE e.deleted_at IS NULL
ORDER BY c.name, e.name;
