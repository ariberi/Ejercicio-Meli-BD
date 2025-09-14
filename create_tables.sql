-- ==============================================================
-- MARKETPLACE MELI - DDL
-- Ariel Berinstein
-- ==============================================================

-- ==============================================================
-- TABLAS
-- ==============================================================

-- ==============================================================
-- 1. CUSTOMER
-- ==============================================================
CREATE TABLE IF NOT EXISTS CUSTOMER (
    CUSTOMER_ID     BIGSERIAL PRIMARY KEY,
    FIRST_NAME      VARCHAR(50) NOT NULL,
    LAST_NAME       VARCHAR(50) NOT NULL,
    DNI             VARCHAR(10) NOT NULL,
    GENDER          VARCHAR(10) NOT NULL,
    EMAIL           VARCHAR(254) NOT NULL, -- 254 caracteres según el estándar RFC 5322
    BIRTH_DATE      DATE NOT NULL,
    CREATED_AT      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_AT      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_BY      VARCHAR(50),
    -- UPDATED_BY Puede parecer redundante,
    -- pero en caso de bloqueo o problemas con la cuenta, algún soporte podría realizar cambios
    DELETED_AT      TIMESTAMP NULL, -- Soft delete

    -- Restricciones
    CONSTRAINT UQ_CUSTOMER_EMAIL UNIQUE (EMAIL),
    CONSTRAINT UQ_CUSTOMER_DNI UNIQUE (DNI),
    CONSTRAINT CK_CUSTOMER_DNI CHECK (DNI ~ '^[0-9]{7,8}$'),
    CONSTRAINT CK_CUSTOMER_EMAIL CHECK (EMAIL ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT CK_CUSTOMER_GENDER CHECK (GENDER IN ('M','F', 'OTHER'))
);

-- Indices
CREATE INDEX IDX_CUSTOMER_BIRTH_DATE_MD ON CUSTOMER (EXTRACT(MONTH FROM BIRTH_DATE), EXTRACT(DAY FROM BIRTH_DATE));
-- Para usar en la query de cumpleaños
CREATE INDEX IDX_CUSTOMER_NAME ON CUSTOMER (FIRST_NAME, LAST_NAME); -- Para búsquedas por nombre

-- ==============================================================
-- 2. ADDRESS
-- ==============================================================
CREATE TABLE IF NOT EXISTS ADDRESS (
    ADDRESS_ID      BIGSERIAL PRIMARY KEY,
    CUSTOMER_ID     BIGINT NOT NULL,
    STREET          VARCHAR(30) NOT NULL,
    NUMBER          VARCHAR(20) NOT NULL,
    APARTMENT       VARCHAR(20),
    CITY            VARCHAR(30) NOT NULL,
    STATE           VARCHAR(50),
    COUNTRY         VARCHAR(30) NOT NULL,
    ZIP_CODE        VARCHAR(10),
    IS_PRIMARY      BOOLEAN DEFAULT FALSE,
    CREATED_AT      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_AT      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_BY      VARCHAR(50),
    DELETED_AT      TIMESTAMP NULL,

    -- Restricciones
    CONSTRAINT FK_ADDRESS_CUSTOMER FOREIGN KEY (CUSTOMER_ID)
        REFERENCES CUSTOMER(CUSTOMER_ID) ON DELETE CASCADE,
    -- Si se elimina un registro de la tabla principal customer, también se elimina acá
    CONSTRAINT CK_ADDRESS_ZIP CHECK (ZIP_CODE ~ '^[0-9]{4,10}$')
);

-- Indices
CREATE UNIQUE INDEX UQ_CUSTOMER_PRIMARY_ADDRESS
    ON ADDRESS (CUSTOMER_ID)
    WHERE IS_PRIMARY = TRUE AND DELETED_AT IS NULL;
-- Creo un índice para que un customer no pueda tener más de una dirección principal

-- ==============================================================
-- 3. PHONE
-- ==============================================================
CREATE TABLE IF NOT EXISTS PHONE (
    PHONE_ID        BIGSERIAL PRIMARY KEY,
    CUSTOMER_ID     BIGINT NOT NULL,
    PHONE_NUMBER    VARCHAR(20) NOT NULL,
    COUNTRY_CODE    VARCHAR(5) NOT NULL,
    AREA_CODE       VARCHAR(5),
    TYPE            VARCHAR(20),
    IS_PRIMARY      BOOLEAN DEFAULT FALSE,
    CREATED_AT      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_AT      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_BY      VARCHAR(50),
    DELETED_AT      TIMESTAMP NULL,

    -- Restricciones
    CONSTRAINT UQ_PHONE_CUSTOMER UNIQUE (CUSTOMER_ID, PHONE_NUMBER),
    CONSTRAINT CK_PHONE_TYPE CHECK (TYPE IN ('MOBILE','HOME','WORK')),
    CONSTRAINT CK_PHONE_NUMBER CHECK (PHONE_NUMBER ~ '^[0-9]{8,15}$'),
    CONSTRAINT FK_PHONE_CUSTOMER FOREIGN KEY (CUSTOMER_ID)
        REFERENCES CUSTOMER(CUSTOMER_ID) ON DELETE CASCADE
);

-- Indices
CREATE UNIQUE INDEX UQ_CUSTOMER_PRIMARY_PHONE
    ON PHONE (CUSTOMER_ID)
    WHERE IS_PRIMARY = TRUE AND DELETED_AT IS NULL;
-- Creo un índice para que un customer no pueda tener más de un teléfono principal

-- ==============================================================
-- 4. CATEGORY
-- ==============================================================
CREATE TABLE IF NOT EXISTS CATEGORY (
    CATEGORY_ID     BIGSERIAL PRIMARY KEY,
    PARENT_ID       BIGINT NULL,
    -- PARENT_ID: funciona como una referencia recursiva a la misma tabla
    -- Se utiliza para jerarquías de categorías, por ejemplo:
    -- Tecnología > Celulares y Teléfonos > Celulares y Smartphones
    -- Si el valor es null es porque es una categoría raíz, y no hay otra por encima
    LEVEL           INTEGER DEFAULT 0,
    -- LEVEL: funciona como el nivel en la jerarquía
    -- Tecnología (LEVEL 0) > Celulares y Teléfonos (LEVEL 1) > Celulares y Smartphones (LEVEL 2)
    NAME            VARCHAR(60) NOT NULL,
    DESCRIPTION     VARCHAR(255) NOT NULL,
    PATH            VARCHAR(500),
    IS_ACTIVE       BOOLEAN DEFAULT TRUE,
    -- IS_ACTIVE: para saber si la categoría está activa o desactivada,
    -- pero sin borrarlas (sirve para relaciones históricas)
    CREATED_AT      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_AT      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_BY      VARCHAR(50),

    -- Restricciones
    CONSTRAINT FK_CATEGORY_PARENT FOREIGN KEY (PARENT_ID)
        REFERENCES CATEGORY(CATEGORY_ID),
    CONSTRAINT CK_CATEGORY_LEVEL CHECK (LEVEL >= 0),
    CONSTRAINT UQ_CATEGORY_NAME UNIQUE (NAME) -- No puede haber dos categorías con el mismo nombre
);

-- Indices
CREATE INDEX IDX_CATEGORY_NAME ON CATEGORY (NAME);
CREATE INDEX IDX_CATEGORY_PARENT ON CATEGORY (PARENT_ID);
CREATE INDEX IDX_CATEGORY_LEVEL ON CATEGORY (LEVEL);

-- ==============================================================
-- 5. ITEM
-- ==============================================================
CREATE TABLE IF NOT EXISTS ITEM (
    ITEM_ID         BIGSERIAL PRIMARY KEY,
    SELLER_ID       BIGINT NOT NULL,
    CATEGORY_ID     BIGINT NOT NULL,
    TITLE           VARCHAR(255) NOT NULL, -- Unique?
    DESCRIPTION     TEXT,
    PRICE           DECIMAL(12,2) NOT NULL, -- Precio original de venta
    CURRENCY        VARCHAR(3) NOT NULL, -- Siguiendo el estándar ISO 4217, que define códigos de 3 letras para monedas
    STOCK_QUANTITY  INTEGER DEFAULT 0,
    STATUS          VARCHAR(20) DEFAULT 'DRAFT',
    PUBLISHED_AT    DATE, -- Cuando se publica el item al marketplace
    END_DATE        DATE,
    CREATED_AT      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_AT      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_BY      VARCHAR(50),
    DELETED_AT      TIMESTAMP NULL,

    -- Restricciones
    CONSTRAINT FK_ITEM_SELLER FOREIGN KEY (SELLER_ID) REFERENCES CUSTOMER(CUSTOMER_ID),
    CONSTRAINT FK_ITEM_CATEGORY FOREIGN KEY (CATEGORY_ID) REFERENCES CATEGORY(CATEGORY_ID),
    CONSTRAINT CK_ITEM_PRICE CHECK (PRICE >= 0),
    CONSTRAINT CK_ITEM_STOCK CHECK (STOCK_QUANTITY >= 0),
    CONSTRAINT CK_ITEM_STATUS CHECK (STATUS IN ('DRAFT','ACTIVE','INACTIVE','SOLD','DELETED')),
    CONSTRAINT CK_ITEM_DATES CHECK (END_DATE IS NULL OR END_DATE > PUBLISHED_AT)
);

-- Indices
CREATE INDEX IDX_ITEM_SELLER ON ITEM (SELLER_ID);
CREATE INDEX IDX_ITEM_CATEGORY ON ITEM (CATEGORY_ID);
CREATE INDEX IDX_ITEM_STATUS ON ITEM (STATUS);
CREATE INDEX IDX_ITEM_PUBLISHED ON ITEM (PUBLISHED_AT);

-- ==============================================================
-- 6. ORDER_TABLE
-- ORDER es palabra reservada, asi que le agrego un diferenciador _TABLE
-- ==============================================================
CREATE TABLE IF NOT EXISTS ORDER_TABLE (
    ORDER_ID        BIGSERIAL PRIMARY KEY,
    ORDER_NUMBER    VARCHAR(20) NOT NULL, -- Para que el comprador identifique la orden
    BUYER_ID        BIGINT NOT NULL,
    SELLER_ID       BIGINT NOT NULL,
    ITEM_ID         BIGINT NOT NULL,
    QUANTITY        INTEGER NOT NULL,
    UNIT_PRICE      DECIMAL(12,2) NOT NULL,
    TOTAL_AMOUNT    DECIMAL(14,2) GENERATED ALWAYS AS (QUANTITY * UNIT_PRICE) STORED,
    DISCOUNT        DECIMAL(12,2) DEFAULT 0,
    TAXES           DECIMAL(12,2) DEFAULT 0,
    SHIPPING_COST   DECIMAL(12,2) DEFAULT 0,
    FINAL_PRICE     DECIMAL(14,2) GENERATED ALWAYS AS ((QUANTITY * UNIT_PRICE) + SHIPPING_COST + TAXES - DISCOUNT) STORED,
    CURRENCY        VARCHAR(3) NOT NULL,
    STATUS          VARCHAR(20) DEFAULT 'CREATED',
    PAYMENT_STATUS  VARCHAR(20) DEFAULT 'PENDING',
    SHIPPING_STATUS VARCHAR(20) DEFAULT 'PENDING',
    PAYMENT_METHOD  VARCHAR(20) DEFAULT 'CREDIT_CARD',
    DELIVERED_AT    TIMESTAMP, -- Para identificar cuándo se entregó
    CREATED_AT      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_AT      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_BY      VARCHAR(50),

    -- Restricciones
    CONSTRAINT UQ_ORDER_NUMBER UNIQUE (ORDER_NUMBER),
    CONSTRAINT FK_ORDER_BUYER FOREIGN KEY (BUYER_ID) REFERENCES CUSTOMER(CUSTOMER_ID),
    CONSTRAINT FK_ORDER_SELLER FOREIGN KEY (SELLER_ID) REFERENCES CUSTOMER(CUSTOMER_ID),
    CONSTRAINT FK_ORDER_ITEM FOREIGN KEY (ITEM_ID) REFERENCES ITEM(ITEM_ID),
    CONSTRAINT CK_ORDER_QTY CHECK (QUANTITY > 0),
    CONSTRAINT CK_ORDER_PRICE CHECK (UNIT_PRICE >= 0),
    CONSTRAINT CK_ORDER_STATUS CHECK
        (STATUS IN
         ('CREATED','PENDING','PROCESSING','SHIPPED','DELIVERED','RETURNED','CANCELLED','COMPLETED')),
    CONSTRAINT CK_PAYMENT_STATUS CHECK
        (PAYMENT_STATUS IN ('PENDING','PROCESSING','PAID','FAILED','REFUNDED')),
    CONSTRAINT CK_SHIPPING_STATUS CHECK
        (SHIPPING_STATUS IN ('PENDING','PREPARING','IN_TRANSIT','DELIVERED','CANCELLED','RETURNED')),
    CONSTRAINT CK_PAYMENT_METHOD CHECK
        (PAYMENT_METHOD IN ('CREDIT_CARD','DEBIT_CARD','TRANSFER'))
);

-- Indices
CREATE INDEX IDX_ORDER_BUYER ON ORDER_TABLE (BUYER_ID);
CREATE INDEX IDX_ORDER_SELLER ON ORDER_TABLE (SELLER_ID);
CREATE INDEX IDX_ORDER_ITEM ON ORDER_TABLE (ITEM_ID);
CREATE INDEX IDX_ORDER_STATUS ON ORDER_TABLE (STATUS);
CREATE INDEX IDX_ORDER_CREATED_YEAR_MONTH ON ORDER_TABLE
    (EXTRACT(YEAR FROM CREATED_AT), EXTRACT(MONTH FROM CREATED_AT));
-- Para filtrar las órdenes realizadas por año y mes (usada para calcular ventas por año y mes)
CREATE INDEX IDX_ORDER_SELLER_STATUS ON ORDER_TABLE (SELLER_ID, STATUS);
-- Para filtar por órdenes realizadas por un vendedor en un determinado estado (usada para calcular ventas terminadas)
CREATE INDEX IDX_ORDER_CATEGORY_DATE_SELLER ON ORDER_TABLE
    (EXTRACT(YEAR FROM CREATED_AT), EXTRACT(MONTH FROM CREATED_AT), SELLER_ID)
    INCLUDE (FINAL_PRICE, QUANTITY)
    WHERE STATUS = 'COMPLETED' AND PAYMENT_STATUS = 'PAID';
-- Para filtrar ventas por categoría y fecha

-- ==============================================================
-- 6. ITEM_DAILY_SNAPSHOT
-- Tabla para almacenar el histórico de precios y estados por día
-- ==============================================================
CREATE TABLE IF NOT EXISTS ITEM_DAILY_SNAPSHOT (
    SNAPSHOT_ID     BIGSERIAL PRIMARY KEY,
    ITEM_ID         BIGINT NOT NULL,
    SNAPSHOT_DATE   DATE NOT NULL,
    PRICE           DECIMAL(12,2) NOT NULL,
    STATUS          VARCHAR(20) NOT NULL,
    CURRENCY        VARCHAR(3) NOT NULL,
    CREATED_AT      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Restricciones
    CONSTRAINT FK_SNAPSHOT_ITEM FOREIGN KEY (ITEM_ID) REFERENCES ITEM(ITEM_ID),
    CONSTRAINT UQ_ITEM_SNAPSHOT_DATE UNIQUE (ITEM_ID, SNAPSHOT_DATE),
    CONSTRAINT CK_SNAPSHOT_PRICE CHECK (PRICE >= 0),
    CONSTRAINT CK_SNAPSHOT_STATUS CHECK (STATUS IN ('DRAFT','ACTIVE','INACTIVE','SOLD','DELETED'))
);

-- Índices para optimizar consultas
CREATE INDEX IDX_SNAPSHOT_DATE ON ITEM_DAILY_SNAPSHOT (SNAPSHOT_DATE);
CREATE INDEX IDX_SNAPSHOT_ITEM_DATE ON ITEM_DAILY_SNAPSHOT (ITEM_ID, SNAPSHOT_DATE);

-- ==============================================================
-- Funciones y triggers
-- ==============================================================

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