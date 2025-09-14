-- =============================================
-- MARKETPLACE MELI - DDL
-- =============================================

-- ==============================
-- 1. CUSTOMER
-- ==============================
CREATE TABLE CUSTOMER (
    CUSTOMER_ID     BIGINT NOT NULL,
    FIRST_NAME      VARCHAR(50) NOT NULL,
    LAST_NAME       VARCHAR(50) NOT NULL,
    DNI             VARCHAR(10) NOT NULL,
    GENDER          VARCHAR(10) CHECK (GENDER IN ('M', 'F', 'OTHER')),
    EMAIL           VARCHAR(254) NOT NULL, -- 254 caracteres según el estándar RFC 5322
    BIRTH_DATE      DATE NOT NULL,
    CREATED_AT      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_AT      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_BY      VARCHAR(50),
    -- UPDATED_BY Puede parecer redundante,
    -- pero en caso de bloqueo o problemas con la cuenta, algún soporte podría realizar cambios
    DELETED_AT      TIMESTAMP NULL, -- Soft delete

    -- Restricciones
    CONSTRAINT PK_CUSTOMER PRIMARY KEY (CUSTOMER_ID),
    CONSTRAINT UQ_CUSTOMER_EMAIL UNIQUE (EMAIL),
    CONSTRAINT UQ_CUSTOMER_DNI UNIQUE (DNI),
    CONSTRAINT CK_CUSTOMER_DNI CHECK (DNI ~ '^[0-9]{7,8}$'),
    CONSTRAINT CK_CUSTOMER_EMAIL CHECK (EMAIL ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

CREATE INDEX IDX_CUSTOMER_BIRTH_DATE ON CUSTOMER (BIRTH_DATE); -- Para usar en la query de cumpleaños
CREATE PARTIAL INDEX IDX_CUSTOMER_ACTIVE ON CUSTOMER (CUSTOMER_ID) WHERE DELETED_AT IS NULL;
-- faltaría índices para nombre y apellido?

-- ==============================
-- 2. ADDRESS
-- ==============================
CREATE TABLE ADDRESS (
    ADDRESS_ID      BIGINT NOT NULL,
    CUSTOMER_ID     BIGINT NOT NULL,
    STREET          VARCHAR(30) NOT NULL,
    NUMBER          VARCHAR(20) NOT NULL, /* podria ser nulo? */
    APARTMENT       VARCHAR(20),
    CITY            VARCHAR(30) NOT NULL,
    STATE           VARCHAR(50),
    COUNTRY         VARCHAR(30) NOT NULL,
    ZIP_CODE        VARCHAR(10),
    IS_PRIMARY      BOOLEAN DEFAULT FALSE, /* para saber si es la direccion principal actual, puede variar */
    CREATED_AT      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_AT      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_BY      VARCHAR(50),
    DELETED_AT      TIMESTAMP NULL,

    -- Restricciones
    CONSTRAINT PK_ADDRESS PRIMARY KEY (ADDRESS_ID), /* no pongo PK compuesta porque 2 personas pueden tener la misma direc */
    CONSTRAINT FK_ADDRESS_CUSTOMER FOREIGN KEY (CUSTOMER_ID)
        REFERENCES CUSTOMER(CUSTOMER_ID) ON DELETE CASCADE,
    -- Si se elimina un registro de la tabla principal customer, también se elimina acá
    CONSTRAINT CK_ADDRESS_ZIP CHECK (ZIP_CODE ~ '^[0-9]{4,10}$')
);

-- Creo un índice para que un customer no pueda tener más de una dirreción principal
CREATE UNIQUE INDEX UQ_CUSTOMER_PRIMARY_ADDRESS
    ON ADDRESS (CUSTOMER_ID)
    WHERE IS_PRIMARY = TRUE AND DELETED_AT IS NULL;

-- ==============================
-- 3. PHONE
-- ==============================
CREATE TABLE PHONE (
    PHONE_ID        BIGINT NOT NULL,
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
    CONSTRAINT PK_PHONE PRIMARY KEY (PHONE_ID),
    CONSTRAINT UQ_PHONE_CUSTOMER UNIQUE (CUSTOMER_ID, PHONE_NUMBER),
    CONSTRAINT CK_PHONE_TYPE CHECK (TYPE IN ('MOBILE','HOME','WORK')),
    CONSTRAINT CK_PHONE_NUMBER CHECK (PHONE_NUMBER ~ '^[0-9]{8,15}$'),
    CONSTRAINT FK_PHONE_CUSTOMER FOREIGN KEY (CUSTOMER_ID)
        REFERENCES CUSTOMER(CUSTOMER_ID) ON DELETE CASCADE
);

-- Creo un índice para que un customer no pueda tener más de un teléfono principal
CREATE UNIQUE INDEX UQ_CUSTOMER_PRIMARY_PHONE
    ON PHONE (CUSTOMER_ID)
    WHERE IS_PRIMARY = TRUE AND DELETED_AT IS NULL;


-- ==============================
-- 4. CATEGORY
-- ==============================
CREATE TABLE CATEGORY (
    CATEGORY_ID     BIGINT NOT NULL,
    PARENT_ID       BIGINT NULL,
    -- PARENT_ID: funciona como una referencia recursiva a la misma tabla
    -- Se utiliza para jerarquías de categorías, por ejemplo:
    -- Tecnología > Celulares y Teléfonos > Celulares y Smartphones
    -- Si el valor es null es porque es una categoría raíz, y no hay otra por encima
    LEVEL           INT DEFAULT 0,
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
    CONSTRAINT PK_CATEGORY PRIMARY KEY (CATEGORY_ID),
    CONSTRAINT FK_CATEGORY_PARENT FOREIGN KEY (PARENT_ID)
        REFERENCES CATEGORY(CATEGORY_ID),
    CONSTRAINT CK_CATEGORY_LEVEL CHECK (LEVEL >= 0),
    -- unique name
    CONSTRAINT UQ_CATEGORY_NAME UNIQUE (NAME),
);

-- Indices
CREATE INDEX IDX_CATEGORY_NAME ON CATEGORY (NAME);


-- ==============================
-- 5. ITEM
-- ==============================
CREATE TABLE ITEM (
    ITEM_ID         BIGINT NOT NULL,
    SELLER_ID       BIGINT NOT NULL,
    CATEGORY_ID     BIGINT NOT NULL,
    TITLE           VARCHAR(255) NOT NULL, -- Unique?
    DESCRIPTION     TEXT,
    PRICE           DECIMAL(12,2) NOT NULL, -- Precio original de venta
    CURRENCY        VARCHAR(3) NOT NULL, -- Siguiendo el estándar ISO 4217, que define códigos de 3 letras para monedas
    STOCK_QUANTITY  INT DEFAULT 0,
    STATUS          VARCHAR(20) DEFAULT 'DRAFT',
    PUBLISHED_AT    DATE, -- Cuando se publica el item al marketplace
    END_DATE        DATE,
    CREATED_AT      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_AT      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_BY      VARCHAR(50),
    DELETED_AT      TIMESTAMP NULL,

    -- Restricciones
    CONSTRAINT PK_ITEM PRIMARY KEY (ITEM_ID),
    CONSTRAINT FK_ITEM_SELLER FOREIGN KEY (SELLER_ID) REFERENCES CUSTOMER(CUSTOMER_ID),
    CONSTRAINT FK_ITEM_CATEGORY FOREIGN KEY (CATEGORY_ID) REFERENCES CATEGORY(CATEGORY_ID),
    CONSTRAINT CK_ITEM_PRICE CHECK (PRICE >= 0),
    CONSTRAINT CK_ITEM_STOCK CHECK (STOCK_QUANTITY >= 0),
    CONSTRAINT CK_ITEM_STATUS CHECK (STATUS IN ('DRAFT','ACTIVE','INACTIVE','SOLD','DELETED')),
    CONSTRAINT CK_ITEM_DATES CHECK (END_DATE IS NULL OR END_DATE > PUBLISHED_AT),
);

-- Indices
CREATE INDEX IDX_ITEM_SELLER ON ITEM (SELLER_ID);
CREATE INDEX IDX_ITEM_CATEGORY ON ITEM (CATEGORY_ID);


-- ==============================
-- 6. ORDER
-- ==============================
CREATE TABLE ORDER (
    ORDER_ID        BIGINT NOT NULL,
    ORDER_NUMBER    VARCHAR(20) NOT NULL, -- Para que el comprador identifique la orden
    BUYER_ID        BIGINT NOT NULL,
    SELLER_ID       BIGINT NOT NULL,
    -- SELLER_ID: Si bien se puede asociar el vendedor del el ITEM_ID,
    -- se puede desnormalizar para poder realizar consultas más rápidas,
    -- mejorando performance y también preservar historial de compras
    ITEM_ID         BIGINT NOT NULL,
    QUANTITY        INT NOT NULL,
    UNIT_PRICE      DECIMAL(12,2) NOT NULL,
    TOTAL_AMOUNT    DECIMAL(14,2) NOT NULL GENERATED ALWAYS AS (QUANTITY * UNIT_PRICE) STORED,
    DISCOUNT        DECIMAL(12,2) DEFAULT 0,
    TAXES           DECIMAL(12,2) DEFAULT 0,
    SHIPPING_COST   DECIMAL(12,2) DEFAULT 0,
    FINAL_PRICE     DECIMAL(14,2) GENERATED ALWAYS AS (
        TOTAL_AMOUNT - DISCOUNT + TAXES + SHIPPING_COST -- Usar TOTAL_AMOUNT o recalcularlo?
    ) STORED,
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
    CONSTRAINT PK_ORDER PRIMARY KEY (ORDER_ID),
    CONSTRAINT UQ_ORDER_NUMBER UNIQUE (ORDER_NUMBER),
    CONSTRAINT FK_ORDER_BUYER FOREIGN KEY (BUYER_ID) REFERENCES CUSTOMER(CUSTOMER_ID),
    CONSTRAINT FK_ORDER_SELLER FOREIGN KEY (SELLER_ID) REFERENCES CUSTOMER(CUSTOMER_ID),
    CONSTRAINT FK_ORDER_ITEM FOREIGN KEY (ITEM_ID) REFERENCES ITEM(ITEM_ID),
    CONSTRAINT CK_ORDER_QTY CHECK (QUANTITY > 0),
    CONSTRAINT CK_ORDER_PRICE CHECK (UNIT_PRICE >= 0),
    CONSTRAINT CK_ORDER_STATUS CHECK
        (STATUS IN ('CREATED','PENDING','PROCESSING','SHIPPED','DELIVERED','RETURNED','CANCELLED')),
    CONSTRAINT CK_PAYMENT_STATUS CHECK
        (PAYMENT_STATUS IN ('PENDING','PROCESSING','PAID','FAILED','REFUNDED','PARTIALLY_REFUNDED')),
    CONSTRAINT CK_SHIPPING_STATUS CHECK
        (SHIPPING_STATUS IN ('PENDING','PREPARING','SHIPPED','IN_TRANSIT','DELIVERED','RETURNED'))
);

-- Indices
CREATE INDEX IDX_ORDER_SELLER ON ORDER (SELLER_ID);
CREATE INDEX IDX_ORDER_ITEM ON ORDER (ITEM_ID);
CREATE INDEX IDX_ORDER_STATUS ON ORDER (STATUS);



































