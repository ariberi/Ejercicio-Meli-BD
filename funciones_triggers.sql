-- ==============================================================
-- FUNCIONES Y TRIGGERS
-- ==============================================================

-- ==============================================================
-- Función para actualizar el stock del item al realizarse una transaccion
-- ==============================================================
CREATE OR REPLACE FUNCTION validate_transation_status_stock()
    RETURNS TRIGGER AS $$
DECLARE
    current_stock ITEM.STOCK_QUANTITY%TYPE;
        item_status ITEM.STATUS%TYPE;
BEGIN
    -- Obtener stock actual del ítem
    SELECT STOCK_QUANTITY, STATUS
    INTO current_stock, item_status
    FROM ITEM
    WHERE ITEM_ID = NEW.ITEM_ID
        FOR UPDATE;
    -- Lock para evitar race conditions,
    -- es decir, que otro usuario también intente comprar el mismo item al mismo tiempo

    -- Validar si el estado item está activo y se puede comprar
    IF item_status != 'ACTIVE' THEN
        RAISE EXCEPTION 'No se puede comprar un item que no está activo. Item_ID=%, estado actual=%',
            NEW.ITEM_ID, item_status;
END IF;

-- Validar stock suficiente
IF NEW.QUANTITY > current_stock THEN
        RAISE EXCEPTION 'No hay stock suficiente para el ítem %. Stock disponible: %, cantidad solicitada: %',
            NEW.ITEM_ID, current_stock, NEW.QUANTITY;
END IF;

-- Actualizar en caso de que haya stock suficiente
UPDATE ITEM
SET STOCK_QUANTITY = current_stock - NEW.QUANTITY
WHERE ITEM_ID = NEW.ITEM_ID;

RETURN NEW;

END;
$$ LANGUAGE plpgsql;

-- ==============================================================
-- Función para actualizar UPDATED_AT automáticamente cuando se modifica cualquier campo de un registro
-- ==============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
    RETURNS TRIGGER AS $$
BEGIN
    NEW.UPDATED_AT = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================
-- Función para soft delete: actualizar DELETED_AT y UPDATED_AT
-- Cuando se elimina un registro también se actualiza el UPDATED_AT
-- ==============================================================
CREATE OR REPLACE FUNCTION set_deleted_at()
    RETURNS TRIGGER AS $$
BEGIN
    IF NEW.DELETED_AT IS DISTINCT FROM OLD.DELETED_AT THEN
        NEW.UPDATED_AT = CURRENT_TIMESTAMP;
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- Trigger para ejecutar la validación antes de INSERT
-- ==========================================
CREATE TRIGGER trg_check_stock_before_order
    BEFORE INSERT ON ORDER_TABLE
                     FOR EACH ROW
EXECUTE FUNCTION validate_transation_status_stock();

-- ==============================================================
-- Triggers para UPDATED_AT
-- ==============================================================
-- CUSTOMER
CREATE TRIGGER trg_customer_updated
    BEFORE UPDATE ON CUSTOMER
               FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- ADDRESS
CREATE TRIGGER trg_address_updated
    BEFORE UPDATE ON ADDRESS
               FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- PHONE
CREATE TRIGGER trg_phone_updated
    BEFORE UPDATE ON PHONE
               FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- CATEGORY
CREATE TRIGGER trg_category_updated
    BEFORE UPDATE ON CATEGORY
               FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- ITEM
CREATE TRIGGER trg_item_updated
    BEFORE UPDATE ON ITEM
               FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- ORDER_TABLE
CREATE TRIGGER trg_order_updated
    BEFORE UPDATE ON ORDER_TABLE
               FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- ==============================================================
-- Triggers para DELETED_AT (y UPDATED_AT)
-- ==============================================================
-- CUSTOMER
CREATE TRIGGER trg_customer_deleted
    BEFORE UPDATE ON CUSTOMER
               FOR EACH ROW
               WHEN (OLD.DELETED_AT IS DISTINCT FROM NEW.DELETED_AT)
EXECUTE FUNCTION set_deleted_at();

-- ADDRESS
CREATE TRIGGER trg_address_deleted
    BEFORE UPDATE ON ADDRESS
               FOR EACH ROW
               WHEN (OLD.DELETED_AT IS DISTINCT FROM NEW.DELETED_AT)
EXECUTE FUNCTION set_deleted_at();

-- PHONE
CREATE TRIGGER trg_phone_deleted
    BEFORE UPDATE ON PHONE
               FOR EACH ROW
               WHEN (OLD.DELETED_AT IS DISTINCT FROM NEW.DELETED_AT)
EXECUTE FUNCTION set_deleted_at();

-- ITEM
CREATE TRIGGER trg_item_deleted
    BEFORE UPDATE ON ITEM
               FOR EACH ROW
               WHEN (OLD.DELETED_AT IS DISTINCT FROM NEW.DELETED_AT)
EXECUTE FUNCTION set_deleted_at();