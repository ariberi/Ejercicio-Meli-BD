-- ==============================================================
-- FUNCIONES Y TRIGGERS
-- ==============================================================

-- ==============================================================
-- Función para actualizar el validar que se puede realizar una compra/venta
-- ==============================================================
CREATE OR REPLACE FUNCTION fn_validate_purchase()
    RETURNS TRIGGER AS $$
DECLARE
    item_current_stock ITEM.STOCK_QUANTITY%TYPE;
    item_status ITEM.STATUS%TYPE;
    item_price ITEM.PRICE%TYPE;
    item_currency ITEM.CURRENCY%TYPE;
BEGIN

    -- Primero validar que la cantidad que se esté comprando sea mayor a 0
    IF NEW.QUANTITY <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser mayor a 0 (cantidad solicitada: %)', NEW.QUANTITY;
    END IF;

    -- Obtener stock actual del ítem
    SELECT STOCK_QUANTITY, STATUS, PRICE, CURRENCY
    INTO item_current_stock, item_status, item_price, item_currency
    FROM ITEM
    WHERE ITEM_ID = NEW.ITEM_ID
    FOR UPDATE;
    -- Lock para evitar race conditions,
    -- es decir, se bloquea por si otro usuario también intenta comprar el mismo item al mismo tiempo

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el item %', NEW.ITEM_ID;
    END IF;

    -- Validar si el estado item está activo y se puede comprar
    -- Esto podría hacerse en el backend, manejando lógica de negocios,
    -- incluso si un item no está activo, no se debería permitir comprarlo desde el frontend,
    -- pero para este ejercicio se deja para probarlo
    IF item_status != 'ACTIVE' THEN
        RAISE EXCEPTION 'No se puede comprar un item que no está activo %. Estado actual=%',
            NEW.ITEM_ID, item_status;
    END IF;

    -- Validar un usuario no pueda comprar su propio producto
    -- Esto también se podría manejar desde el backend,
    -- y directamente no debería existir la opción dentro del frontend
    IF NEW.SELLER_ID = NEW.BUYER_ID THEN
        RAISE EXCEPTION 'El usuario no puede comprar su propio item %. Vendedor=%, comprador=%',
            NEW.ITEM_ID, NEW.SELLER_ID, NEW.BUYER_ID;
    END IF;

    -- Validar que hay stock suficiente para comprar el item
    IF NEW.QUANTITY > item_current_stock THEN
            RAISE EXCEPTION 'No hay stock suficiente para el ítem %. Stock disponible: %, cantidad solicitada: %',
                NEW.ITEM_ID, item_current_stock, NEW.QUANTITY;
    END IF;

    -- Setear precio y moneda según el ítem
    NEW.UNIT_PRICE := item_price;
    NEW.CURRENCY := item_currency;

    -- Actualizar en stock del item caso de que haya stock suficiente
    UPDATE ITEM
    SET STOCK_QUANTITY = item_current_stock - NEW.QUANTITY
    WHERE ITEM_ID = NEW.ITEM_ID;

    -- Si el stock queda en 0, cambiar el estado a SOLD_OUT
    IF (item_current_stock - NEW.QUANTITY) = 0 THEN
        UPDATE ITEM
        SET STATUS = 'SOLD_OUT'
        WHERE ITEM_ID = NEW.ITEM_ID;
    END IF;

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
-- Trigger para ejecutar la validación de compra/venta antes de INSERT
-- ==========================================
CREATE TRIGGER trg_validate_purchase
    BEFORE INSERT ON ORDER_TABLE
                     FOR EACH ROW
EXECUTE FUNCTION fn_validate_purchase();

-- ==============================================================
-- Triggers para agregar la fecha en que se actualiza algún registro UPDATED_AT
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
-- Triggers para agregar la fecha en que se elimina (y actualiza) algún registro DELETED_AT (y UPDATED_AT)
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