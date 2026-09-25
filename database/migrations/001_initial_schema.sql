BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE user_role AS ENUM (
    'CUSTOMER',
    'STAFF',
    'ADMIN'
);

CREATE TYPE equipment_status AS ENUM (
    'ACTIVE',
    'INACTIVE'
);

CREATE TYPE equipment_unit_status AS ENUM (
    'AVAILABLE',
    'MAINTENANCE',
    'RETIRED'
);

CREATE TYPE rental_status AS ENUM (
    'PENDING',
    'CONFIRMED',
    'READY_FOR_PICKUP',
    'ACTIVE',
    'OVERDUE',
    'RETURNED',
    'COMPLETED',
    'CANCELLED'
);

CREATE TYPE inspection_type AS ENUM (
    'CHECK_OUT',
    'RETURN'
);

CREATE TYPE inspection_condition AS ENUM (
    'GOOD',
    'FAIR',
    'DAMAGED'
);

CREATE TYPE charge_type AS ENUM (
    'LATE_FEE',
    'DAMAGE'
);

CREATE TYPE payment_status AS ENUM (
    'PENDING',
    'SUCCEEDED',
    'FAILED'
);

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL,
    display_name TEXT NOT NULL,
    role user_role NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT users_email_not_blank CHECK (btrim(email) <> ''),
    CONSTRAINT users_display_name_not_blank CHECK (btrim(display_name) <> '')
);

CREATE UNIQUE INDEX users_email_lower_uidx ON users (lower(email));
CREATE INDEX users_role_idx ON users (role);

CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT categories_name_not_blank CHECK (btrim(name) <> ''),
    CONSTRAINT categories_slug_not_blank CHECK (btrim(slug) <> '')
);

CREATE UNIQUE INDEX categories_slug_lower_uidx ON categories (lower(slug));

CREATE TABLE equipment (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID NOT NULL,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    daily_rate_amount BIGINT NOT NULL,
    currency CHAR(3) NOT NULL,
    status equipment_status NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT equipment_category_fk
        FOREIGN KEY (category_id)
        REFERENCES categories (id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,
    CONSTRAINT equipment_name_not_blank CHECK (btrim(name) <> ''),
    CONSTRAINT equipment_description_not_blank CHECK (btrim(description) <> ''),
    CONSTRAINT equipment_daily_rate_nonnegative CHECK (daily_rate_amount >= 0),
    CONSTRAINT equipment_currency_format CHECK (currency ~ '^[A-Z]{3}$')
);

CREATE INDEX equipment_category_id_idx ON equipment (category_id);
CREATE INDEX equipment_status_idx ON equipment (status);

CREATE TABLE equipment_units (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    equipment_id UUID NOT NULL,
    asset_tag TEXT NOT NULL,
    serial_number TEXT,
    status equipment_unit_status NOT NULL DEFAULT 'AVAILABLE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT equipment_units_equipment_fk
        FOREIGN KEY (equipment_id)
        REFERENCES equipment (id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,
    CONSTRAINT equipment_units_asset_tag_key UNIQUE (asset_tag),
    CONSTRAINT equipment_units_serial_number_key UNIQUE (serial_number),
    CONSTRAINT equipment_units_asset_tag_not_blank CHECK (btrim(asset_tag) <> ''),
    CONSTRAINT equipment_units_serial_number_not_blank
        CHECK (serial_number IS NULL OR btrim(serial_number) <> '')
);

CREATE INDEX equipment_units_equipment_id_idx ON equipment_units (equipment_id);
CREATE INDEX equipment_units_available_idx
    ON equipment_units (equipment_id, id)
    WHERE status = 'AVAILABLE' AND deleted_at IS NULL;
CREATE INDEX equipment_units_status_idx ON equipment_units (status);

CREATE TABLE rentals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    status rental_status NOT NULL DEFAULT 'PENDING',
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,
    base_amount BIGINT NOT NULL,
    currency CHAR(3) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT rentals_customer_fk
        FOREIGN KEY (customer_id)
        REFERENCES users (id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,
    CONSTRAINT rentals_period_valid CHECK (end_at > start_at),
    CONSTRAINT rentals_base_amount_nonnegative CHECK (base_amount >= 0),
    CONSTRAINT rentals_currency_format CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT rentals_id_currency_key UNIQUE (id, currency)
);

CREATE INDEX rentals_customer_id_idx ON rentals (customer_id);
CREATE INDEX rentals_status_end_at_idx ON rentals (status, end_at);
CREATE INDEX rentals_reserving_period_idx
    ON rentals (start_at, end_at)
    WHERE status IN ('PENDING', 'CONFIRMED', 'READY_FOR_PICKUP', 'ACTIVE', 'OVERDUE');

CREATE TABLE rental_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rental_id UUID NOT NULL,
    equipment_unit_id UUID NOT NULL,
    equipment_name_snapshot TEXT NOT NULL,
    daily_rate_amount BIGINT NOT NULL,
    currency CHAR(3) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT rental_items_rental_fk
        FOREIGN KEY (rental_id)
        REFERENCES rentals (id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,
    CONSTRAINT rental_items_rental_currency_fk
        FOREIGN KEY (rental_id, currency)
        REFERENCES rentals (id, currency)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,
    CONSTRAINT rental_items_equipment_unit_fk
        FOREIGN KEY (equipment_unit_id)
        REFERENCES equipment_units (id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,
    CONSTRAINT rental_items_rental_equipment_unit_key
        UNIQUE (rental_id, equipment_unit_id),
    CONSTRAINT rental_items_equipment_name_not_blank
        CHECK (btrim(equipment_name_snapshot) <> ''),
    CONSTRAINT rental_items_daily_rate_nonnegative CHECK (daily_rate_amount >= 0),
    CONSTRAINT rental_items_currency_format CHECK (currency ~ '^[A-Z]{3}$')
);

CREATE INDEX rental_items_equipment_unit_rental_idx
    ON rental_items (equipment_unit_id, rental_id);
CREATE INDEX rental_items_rental_currency_idx
    ON rental_items (rental_id, currency);

CREATE TABLE inspections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rental_item_id UUID NOT NULL,
    inspected_by UUID NOT NULL,
    type inspection_type NOT NULL,
    condition inspection_condition NOT NULL,
    notes TEXT,
    inspected_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT inspections_rental_item_fk
        FOREIGN KEY (rental_item_id)
        REFERENCES rental_items (id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,
    CONSTRAINT inspections_inspected_by_fk
        FOREIGN KEY (inspected_by)
        REFERENCES users (id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,
    CONSTRAINT inspections_rental_item_type_key UNIQUE (rental_item_id, type)
);

CREATE INDEX inspections_inspected_by_idx ON inspections (inspected_by);
CREATE INDEX inspections_type_idx ON inspections (type);
CREATE INDEX inspections_inspected_at_idx ON inspections (inspected_at);

CREATE TABLE charges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rental_id UUID NOT NULL,
    type charge_type NOT NULL,
    description TEXT NOT NULL,
    amount BIGINT NOT NULL,
    currency CHAR(3) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT charges_rental_fk
        FOREIGN KEY (rental_id)
        REFERENCES rentals (id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,
    CONSTRAINT charges_rental_currency_fk
        FOREIGN KEY (rental_id, currency)
        REFERENCES rentals (id, currency)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,
    CONSTRAINT charges_description_not_blank CHECK (btrim(description) <> ''),
    CONSTRAINT charges_amount_positive CHECK (amount > 0),
    CONSTRAINT charges_currency_format CHECK (currency ~ '^[A-Z]{3}$')
);

CREATE INDEX charges_rental_id_idx ON charges (rental_id);
CREATE INDEX charges_rental_currency_idx ON charges (rental_id, currency);
CREATE INDEX charges_type_idx ON charges (type);

CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rental_id UUID NOT NULL,
    provider_reference TEXT NOT NULL,
    amount BIGINT NOT NULL,
    currency CHAR(3) NOT NULL,
    status payment_status NOT NULL,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT payments_rental_fk
        FOREIGN KEY (rental_id)
        REFERENCES rentals (id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,
    CONSTRAINT payments_rental_currency_fk
        FOREIGN KEY (rental_id, currency)
        REFERENCES rentals (id, currency)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,
    CONSTRAINT payments_provider_reference_key UNIQUE (provider_reference),
    CONSTRAINT payments_provider_reference_not_blank
        CHECK (btrim(provider_reference) <> ''),
    CONSTRAINT payments_amount_positive CHECK (amount > 0),
    CONSTRAINT payments_currency_format CHECK (currency ~ '^[A-Z]{3}$')
);

CREATE INDEX payments_rental_id_idx ON payments (rental_id);
CREATE INDEX payments_rental_currency_idx ON payments (rental_id, currency);
CREATE INDEX payments_rental_status_idx ON payments (rental_id, status);
CREATE INDEX payments_paid_at_idx ON payments (paid_at) WHERE status = 'SUCCEEDED';

CREATE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := clock_timestamp();
    RETURN NEW;
END;
$$;

CREATE FUNCTION enforce_rental_status_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.status <> 'PENDING' THEN
            RAISE EXCEPTION 'a rental must be created with PENDING status'
                USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
    END IF;

    IF NEW.status = OLD.status THEN
        RETURN NEW;
    END IF;

    IF NOT (CASE OLD.status
        WHEN 'PENDING' THEN NEW.status IN ('CONFIRMED', 'CANCELLED')
        WHEN 'CONFIRMED' THEN NEW.status IN ('READY_FOR_PICKUP', 'CANCELLED')
        WHEN 'READY_FOR_PICKUP' THEN NEW.status IN ('ACTIVE', 'CANCELLED')
        WHEN 'ACTIVE' THEN NEW.status IN ('RETURNED', 'OVERDUE')
        WHEN 'OVERDUE' THEN NEW.status = 'RETURNED'
        WHEN 'RETURNED' THEN NEW.status = 'COMPLETED'
        ELSE FALSE
    END) THEN
        RAISE EXCEPTION 'invalid rental status transition: % -> %', OLD.status, NEW.status
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE FUNCTION is_reserving_rental(p_status rental_status)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
    SELECT p_status IN (
        'PENDING'::rental_status,
        'CONFIRMED'::rental_status,
        'READY_FOR_PICKUP'::rental_status,
        'ACTIVE'::rental_status,
        'OVERDUE'::rental_status
    );
$$;

CREATE FUNCTION assert_rental_unit_available(
    p_rental_id UUID,
    p_equipment_unit_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_at TIMESTAMPTZ;
    v_end_at TIMESTAMPTZ;
    v_status rental_status;
BEGIN
    IF current_setting('transaction_isolation') <> 'read committed' THEN
        RAISE EXCEPTION 'rental allocation changes require READ COMMITTED isolation'
            USING ERRCODE = '0A000';
    END IF;

    SELECT r.start_at, r.end_at, r.status
    INTO v_start_at, v_end_at, v_status
    FROM rentals AS r
    WHERE r.id = p_rental_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'rental % does not exist', p_rental_id
            USING ERRCODE = '23503';
    END IF;

    PERFORM 1
    FROM equipment_units AS u
    WHERE u.id = p_equipment_unit_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'equipment unit % does not exist', p_equipment_unit_id
            USING ERRCODE = '23503';
    END IF;

    IF NOT is_reserving_rental(v_status) THEN
        RETURN;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM rental_items AS ri
        JOIN rentals AS conflicting_rental
          ON conflicting_rental.id = ri.rental_id
        WHERE ri.equipment_unit_id = p_equipment_unit_id
          AND ri.rental_id <> p_rental_id
          AND is_reserving_rental(conflicting_rental.status)
          AND conflicting_rental.start_at < v_end_at
          AND v_start_at < conflicting_rental.end_at
    ) THEN
        RAISE EXCEPTION 'equipment unit % has an overlapping reservation', p_equipment_unit_id
            USING ERRCODE = '23P01';
    END IF;
END;
$$;

CREATE FUNCTION enforce_rental_item_availability()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'UPDATE'
       AND OLD.rental_id IS NOT DISTINCT FROM NEW.rental_id
       AND OLD.equipment_unit_id IS NOT DISTINCT FROM NEW.equipment_unit_id THEN
        RETURN NEW;
    END IF;

    PERFORM assert_rental_unit_available(NEW.rental_id, NEW.equipment_unit_id);
    RETURN NEW;
END;
$$;

CREATE FUNCTION enforce_rental_availability_on_update()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_equipment_unit_id UUID;
BEGIN
    IF OLD.start_at IS NOT DISTINCT FROM NEW.start_at
       AND OLD.end_at IS NOT DISTINCT FROM NEW.end_at
       AND OLD.status IS NOT DISTINCT FROM NEW.status THEN
        RETURN NEW;
    END IF;

    FOR v_equipment_unit_id IN
        SELECT ri.equipment_unit_id
        FROM rental_items AS ri
        WHERE ri.rental_id = NEW.id
        ORDER BY ri.equipment_unit_id
    LOOP
        PERFORM assert_rental_unit_available(NEW.id, v_equipment_unit_id);
    END LOOP;

    RETURN NEW;
END;
$$;

CREATE TRIGGER users_set_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER categories_set_updated_at
BEFORE UPDATE ON categories
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER equipment_set_updated_at
BEFORE UPDATE ON equipment
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER equipment_units_set_updated_at
BEFORE UPDATE ON equipment_units
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER rentals_set_updated_at
BEFORE UPDATE ON rentals
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER rentals_enforce_status_transition
BEFORE INSERT OR UPDATE OF status ON rentals
FOR EACH ROW
EXECUTE FUNCTION enforce_rental_status_transition();

CREATE TRIGGER rentals_enforce_availability_on_update
AFTER UPDATE OF start_at, end_at, status ON rentals
FOR EACH ROW
EXECUTE FUNCTION enforce_rental_availability_on_update();

CREATE TRIGGER rental_items_set_updated_at
BEFORE UPDATE ON rental_items
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER rental_items_enforce_availability
AFTER INSERT OR UPDATE ON rental_items
FOR EACH ROW
EXECUTE FUNCTION enforce_rental_item_availability();

CREATE TRIGGER inspections_set_updated_at
BEFORE UPDATE ON inspections
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER charges_set_updated_at
BEFORE UPDATE ON charges
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER payments_set_updated_at
BEFORE UPDATE ON payments
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

COMMIT;
