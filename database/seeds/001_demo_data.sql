BEGIN;

INSERT INTO users (id, email, display_name, role)
VALUES
    ('10000000-0000-4000-8000-000000000001', 'ada.nwosu@example.com', 'Ada Nwosu', 'CUSTOMER'),
    ('10000000-0000-4000-8000-000000000002', 'tunde.bakare@example.com', 'Tunde Bakare', 'CUSTOMER'),
    ('20000000-0000-4000-8000-000000000001', 'ngozi.eze@staff.example.com', 'Ngozi Eze', 'STAFF'),
    ('20000000-0000-4000-8000-000000000002', 'musa.bello@staff.example.com', 'Musa Bello', 'STAFF'),
    ('30000000-0000-4000-8000-000000000001', 'lami.adeyemi@admin.example.com', 'Lami Adeyemi', 'ADMIN');

INSERT INTO categories (id, name, slug)
VALUES
    ('a0000000-0000-4000-8000-000000000001', 'Generators', 'generators'),
    ('a0000000-0000-4000-8000-000000000002', 'Cameras', 'cameras'),
    ('a0000000-0000-4000-8000-000000000003', 'Power Tools', 'power-tools');

INSERT INTO equipment (
    id,
    category_id,
    name,
    description,
    daily_rate_amount,
    currency,
    status
)
VALUES
    (
        'b0000000-0000-4000-8000-000000000001',
        'a0000000-0000-4000-8000-000000000001',
        'EcoPower 5kVA Generator',
        'Low-noise petrol generator suitable for small events and light commercial work.',
        2500000,
        'NGN',
        'ACTIVE'
    ),
    (
        'b0000000-0000-4000-8000-000000000002',
        'a0000000-0000-4000-8000-000000000002',
        'CineShot 4K Camera',
        'Mirrorless 4K camera with interchangeable lenses for events and production work.',
        1200000,
        'NGN',
        'ACTIVE'
    ),
    (
        'b0000000-0000-4000-8000-000000000003',
        'a0000000-0000-4000-8000-000000000002',
        'ActionCam Pro',
        'Water-resistant action camera for sports, outdoor, and documentary footage.',
        750000,
        'NGN',
        'ACTIVE'
    ),
    (
        'b0000000-0000-4000-8000-000000000004',
        'a0000000-0000-4000-8000-000000000003',
        'Cordless Impact Drill',
        'Brushless cordless impact drill with two batteries and a carrying case.',
        350000,
        'NGN',
        'ACTIVE'
    ),
    (
        'b0000000-0000-4000-8000-000000000005',
        'a0000000-0000-4000-8000-000000000003',
        'Circular Saw 1900W',
        'Reliable 1900W circular saw for timber and general construction work.',
        275000,
        'NGN',
        'ACTIVE'
    ),
    (
        'b0000000-0000-4000-8000-000000000006',
        'a0000000-0000-4000-8000-000000000002',
        'Legacy Film Camera',
        'Retired analogue film camera retained as a discontinued catalogue record.',
        600000,
        'NGN',
        'INACTIVE'
    );

INSERT INTO equipment_units (
    id,
    equipment_id,
    asset_tag,
    serial_number,
    status
)
VALUES
    (
        'c0000000-0000-4000-8000-000000000001',
        'b0000000-0000-4000-8000-000000000001',
        'GEN-001',
        'NG-GEN-001',
        'AVAILABLE'
    ),
    (
        'c0000000-0000-4000-8000-000000000002',
        'b0000000-0000-4000-8000-000000000001',
        'GEN-002',
        'NG-GEN-002',
        'AVAILABLE'
    ),
    (
        'c0000000-0000-4000-8000-000000000003',
        'b0000000-0000-4000-8000-000000000001',
        'GEN-003',
        'NG-GEN-003',
        'MAINTENANCE'
    ),
    (
        'c0000000-0000-4000-8000-000000000004',
        'b0000000-0000-4000-8000-000000000001',
        'GEN-004',
        'NG-GEN-004',
        'RETIRED'
    ),
    (
        'c0000000-0000-4000-8000-000000000005',
        'b0000000-0000-4000-8000-000000000002',
        'CAM-001',
        'NG-CAM-001',
        'AVAILABLE'
    ),
    (
        'c0000000-0000-4000-8000-000000000006',
        'b0000000-0000-4000-8000-000000000003',
        'CAM-002',
        'NG-CAM-002',
        'AVAILABLE'
    ),
    (
        'c0000000-0000-4000-8000-000000000007',
        'b0000000-0000-4000-8000-000000000004',
        'DRILL-001',
        'NG-DRILL-001',
        'AVAILABLE'
    ),
    (
        'c0000000-0000-4000-8000-000000000008',
        'b0000000-0000-4000-8000-000000000005',
        'SAW-001',
        'NG-SAW-001',
        'AVAILABLE'
    );

INSERT INTO rentals (
    id,
    customer_id,
    start_at,
    end_at,
    base_amount,
    currency
)
VALUES
    (
        'd0000000-0000-4000-8000-000000000001',
        '10000000-0000-4000-8000-000000000001',
        TIMESTAMPTZ '2025-11-10 08:00:00+00',
        TIMESTAMPTZ '2025-11-13 17:00:00+00',
        9300000,
        'NGN'
    ),
    (
        'd0000000-0000-4000-8000-000000000002',
        '10000000-0000-4000-8000-000000000002',
        TIMESTAMPTZ '2026-09-20 09:00:00+00',
        TIMESTAMPTZ '2026-09-30 18:00:00+00',
        3500000,
        'NGN'
    ),
    (
        'd0000000-0000-4000-8000-000000000003',
        '10000000-0000-4000-8000-000000000001',
        TIMESTAMPTZ '2030-02-10 08:00:00+00',
        TIMESTAMPTZ '2030-02-14 18:00:00+00',
        14800000,
        'NGN'
    ),
    (
        'd0000000-0000-4000-8000-000000000004',
        '10000000-0000-4000-8000-000000000002',
        TIMESTAMPTZ '2030-02-14 18:00:00+00',
        TIMESTAMPTZ '2030-02-16 18:00:00+00',
        5000000,
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
VALUES
    (
        'e0000000-0000-4000-8000-000000000001',
        'd0000000-0000-4000-8000-000000000001',
        'c0000000-0000-4000-8000-000000000001',
        'EcoPower 5kVA Generator',
        2200000,
        'NGN'
    ),
    (
        'e0000000-0000-4000-8000-000000000002',
        'd0000000-0000-4000-8000-000000000001',
        'c0000000-0000-4000-8000-000000000005',
        'CineShot 4K Camera',
        900000,
        'NGN'
    ),
    (
        'e0000000-0000-4000-8000-000000000003',
        'd0000000-0000-4000-8000-000000000002',
        'c0000000-0000-4000-8000-000000000007',
        'Cordless Impact Drill',
        350000,
        'NGN'
    ),
    (
        'e0000000-0000-4000-8000-000000000004',
        'd0000000-0000-4000-8000-000000000003',
        'c0000000-0000-4000-8000-000000000002',
        'EcoPower 5kVA Generator',
        2500000,
        'NGN'
    ),
    (
        'e0000000-0000-4000-8000-000000000005',
        'd0000000-0000-4000-8000-000000000003',
        'c0000000-0000-4000-8000-000000000005',
        'CineShot 4K Camera',
        1200000,
        'NGN'
    ),
    (
        'e0000000-0000-4000-8000-000000000006',
        'd0000000-0000-4000-8000-000000000004',
        'c0000000-0000-4000-8000-000000000002',
        'EcoPower 5kVA Generator',
        2500000,
        'NGN'
    );

INSERT INTO inspections (
    id,
    rental_item_id,
    inspected_by,
    type,
    condition,
    notes,
    inspected_at
)
VALUES
    (
        'f0000000-0000-4000-8000-000000000001',
        'e0000000-0000-4000-8000-000000000001',
        '20000000-0000-4000-8000-000000000001',
        'CHECK_OUT',
        'GOOD',
        'Generator started successfully; fuel and safety checks passed.',
        TIMESTAMPTZ '2025-11-10 08:20:00+00'
    );

UPDATE rentals
SET status = 'CONFIRMED'
WHERE id = 'd0000000-0000-4000-8000-000000000001';

UPDATE rentals
SET status = 'READY_FOR_PICKUP'
WHERE id = 'd0000000-0000-4000-8000-000000000001';

UPDATE rentals
SET status = 'ACTIVE'
WHERE id = 'd0000000-0000-4000-8000-000000000001';

INSERT INTO inspections (
    id,
    rental_item_id,
    inspected_by,
    type,
    condition,
    notes,
    inspected_at
)
VALUES
    (
        'f0000000-0000-4000-8000-000000000002',
        'e0000000-0000-4000-8000-000000000001',
        '20000000-0000-4000-8000-000000000002',
        'RETURN',
        'DAMAGED',
        'Damaged starter cable; battery terminal was loose at return.',
        TIMESTAMPTZ '2025-11-13 16:10:00+00'
    ),
    (
        'f0000000-0000-4000-8000-000000000003',
        'e0000000-0000-4000-8000-000000000002',
        '20000000-0000-4000-8000-000000000002',
        'CHECK_OUT',
        'GOOD',
        'Camera body, lens, battery, and storage card checked.',
        TIMESTAMPTZ '2025-11-10 08:30:00+00'
    ),
    (
        'f0000000-0000-4000-8000-000000000004',
        'e0000000-0000-4000-8000-000000000002',
        '20000000-0000-4000-8000-000000000002',
        'RETURN',
        'FAIR',
        'Minor cosmetic wear; all camera functions passed.',
        TIMESTAMPTZ '2025-11-13 16:25:00+00'
    );

UPDATE rentals
SET status = 'RETURNED'
WHERE id = 'd0000000-0000-4000-8000-000000000001';

UPDATE rentals
SET status = 'COMPLETED'
WHERE id = 'd0000000-0000-4000-8000-000000000001';

UPDATE rentals
SET status = 'CONFIRMED'
WHERE id = 'd0000000-0000-4000-8000-000000000002';

UPDATE rentals
SET status = 'READY_FOR_PICKUP'
WHERE id = 'd0000000-0000-4000-8000-000000000002';

UPDATE rentals
SET status = 'ACTIVE'
WHERE id = 'd0000000-0000-4000-8000-000000000002';

INSERT INTO inspections (
    id,
    rental_item_id,
    inspected_by,
    type,
    condition,
    notes,
    inspected_at
)
VALUES
    (
        'f0000000-0000-4000-8000-000000000005',
        'e0000000-0000-4000-8000-000000000003',
        '20000000-0000-4000-8000-000000000001',
        'CHECK_OUT',
        'GOOD',
        'Drill, batteries, charger, and case checked before issue.',
        TIMESTAMPTZ '2026-09-20 09:15:00+00'
    );

UPDATE rentals
SET status = 'CONFIRMED'
WHERE id = 'd0000000-0000-4000-8000-000000000003';

INSERT INTO charges (id, rental_id, type, description, amount, currency)
VALUES
    (
        'a1000000-0000-4000-8000-000000000001',
        'd0000000-0000-4000-8000-000000000001',
        'DAMAGE',
        'Replacement and repair cost for the damaged generator starter cable.',
        750000,
        'NGN'
    );

INSERT INTO payments (
    id,
    rental_id,
    provider_reference,
    amount,
    currency,
    status,
    paid_at
)
VALUES
    (
        'a2000000-0000-4000-8000-000000000001',
        'd0000000-0000-4000-8000-000000000001',
        'PAY-HIST-SUCCEEDED-001',
        6000000,
        'NGN',
        'SUCCEEDED',
        TIMESTAMPTZ '2025-11-10 08:45:00+00'
    ),
    (
        'a2000000-0000-4000-8000-000000000002',
        'd0000000-0000-4000-8000-000000000001',
        'PAY-HIST-FAILED-001',
        500000,
        'NGN',
        'FAILED',
        NULL
    ),
    (
        'a2000000-0000-4000-8000-000000000003',
        'd0000000-0000-4000-8000-000000000001',
        'PAY-HIST-PENDING-001',
        4000000,
        'NGN',
        'PENDING',
        NULL
    ),
    (
        'a2000000-0000-4000-8000-000000000004',
        'd0000000-0000-4000-8000-000000000002',
        'PAY-ACTIVE-SUCCEEDED-001',
        3500000,
        'NGN',
        'SUCCEEDED',
        TIMESTAMPTZ '2026-09-20 08:50:00+00'
    ),
    (
        'a2000000-0000-4000-8000-000000000005',
        'd0000000-0000-4000-8000-000000000003',
        'PAY-FUTURE-PENDING-001',
        5000000,
        'NGN',
        'PENDING',
        NULL
    );

COMMIT;
