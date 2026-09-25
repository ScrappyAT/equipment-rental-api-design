-- Important user action: A4. Staff check equipment out and back in.
-- Question: What customer, rental, physical-unit, model, period, and inspection information does staff need for the supplied rental's checkout/return view?
-- Read model only: this script is a read-only projection and performs no checkout, return, transition, or inspection write. The commands that advance the rental are the lifecycle transition and the CHECK_OUT/RETURN inspection insert specified in docs/api-design.md, and their database enforcement is proved separately by database/evidence/03_invalid_state_transition.sql and the inspections_rental_item_type_key constraint.
-- Support: rentals_pkey, users_pkey, rental_items_rental_equipment_unit_key (also usable via rental_items_rental_currency_idx, both leading with rental_id), equipment_units_pkey, equipment_pkey, and inspections_rental_item_type_key, together with the rental/customer/item/unit/inspection foreign keys. Note that rental_items_equipment_unit_rental_idx does not serve this pattern because its leading column is equipment_unit_id.
-- Expected: One row for the ACTIVE rental d0000000-0000-4000-8000-000000000002, customer Tunde Bakare, DRILL-001, a GOOD CHECK_OUT inspection by Ngozi Eze, and no RETURN inspection yet.

WITH parameters AS (
    SELECT 'd0000000-0000-4000-8000-000000000002'::UUID AS rental_id
)
SELECT
    r.id AS rental_id,
    r.status AS rental_status,
    r.start_at,
    r.end_at,
    customer.id AS customer_id,
    customer.display_name AS customer_name,
    customer.email AS customer_email,
    ri.id AS rental_item_id,
    ri.equipment_name_snapshot,
    ri.daily_rate_amount AS agreed_daily_rate_amount,
    ri.currency,
    eu.id AS equipment_unit_id,
    eu.asset_tag,
    eu.serial_number,
    eu.status AS equipment_unit_status,
    e.id AS equipment_id,
    e.name AS current_equipment_name,
    checkout_inspection.id AS checkout_inspection_id,
    checkout_inspection.condition AS checkout_condition,
    checkout_inspection.notes AS checkout_notes,
    checkout_inspection.inspected_at AS checkout_inspected_at,
    checkout_inspector.display_name AS checkout_inspected_by,
    return_inspection.id AS return_inspection_id,
    return_inspection.condition AS return_condition,
    return_inspection.notes AS return_notes,
    return_inspection.inspected_at AS return_inspected_at,
    return_inspector.display_name AS return_inspected_by
FROM rentals AS r
JOIN users AS customer
  ON customer.id = r.customer_id
JOIN rental_items AS ri
  ON ri.rental_id = r.id
JOIN equipment_units AS eu
  ON eu.id = ri.equipment_unit_id
JOIN equipment AS e
  ON e.id = eu.equipment_id
LEFT JOIN inspections AS checkout_inspection
  ON checkout_inspection.rental_item_id = ri.id
 AND checkout_inspection.type = 'CHECK_OUT'
LEFT JOIN users AS checkout_inspector
  ON checkout_inspector.id = checkout_inspection.inspected_by
LEFT JOIN inspections AS return_inspection
  ON return_inspection.rental_item_id = ri.id
 AND return_inspection.type = 'RETURN'
LEFT JOIN users AS return_inspector
  ON return_inspector.id = return_inspection.inspected_by
JOIN parameters AS p
  ON p.rental_id = r.id
ORDER BY eu.asset_tag;
