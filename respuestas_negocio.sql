-- ==============================================================
-- 1. Listar los usuarios que cumplan años el día de hoy,
-- cuya cantidad de ventas realizadas en enero 2020 sea superior a 1500.
-- ==============================================================
SELECT
    c.CUSTOMER_ID,
    c.FIRST_NAME,
    c.LAST_NAME,
    c.EMAIL,
    c.BIRTH_DATE,
    COUNT(o.ORDER_ID) as ventas_enero_2020
FROM CUSTOMER c
         INNER JOIN ORDER_TABLE o ON c.CUSTOMER_ID = o.SELLER_ID
WHERE
  -- Cumple años hoy (usa índice IDX_CUSTOMER_BIRTH_DATE_MD)
    EXTRACT(MONTH FROM c.BIRTH_DATE) = EXTRACT(MONTH FROM CURRENT_DATE)
  AND EXTRACT(DAY FROM c.BIRTH_DATE) = EXTRACT(DAY FROM CURRENT_DATE)
  -- Ventas en enero 2020 (usa el índice IDX_ORDER_CREATED_YEAR_MONTH)
  AND EXTRACT(YEAR FROM o.CREATED_AT) = 2020
  AND EXTRACT(MONTH FROM o.CREATED_AT) = 1
  -- Solo órdenes completas (usa el índice IDX_ORDER_SELLER_STATUS)
  AND o.STATUS = 'COMPLETED'
  -- Cliente activo
  AND c.DELETED_AT IS NULL
GROUP BY c.CUSTOMER_ID, c.FIRST_NAME, c.LAST_NAME, c.EMAIL, c.BIRTH_DATE
HAVING COUNT(o.ORDER_ID) > 1500
ORDER BY ventas_enero_2020 DESC;

-- ==============================================================
-- 2. Por cada mes del 2020, se solicita el top 5 de usuarios que más vendieron($) en la categoría Celulares.
-- Se requiere el mes y año de análisis, nombre y apellido del vendedor, cantidad de ventas realizadas,
-- cantidad de productos vendidos y el monto total transaccionado.
-- ==============================================================
WITH celulares_category AS (
    SELECT CATEGORY_ID
    FROM CATEGORY
    WHERE NAME = 'Celulares y Smartphones'
),
     monthly_sales AS (
         SELECT
             EXTRACT(YEAR FROM o.CREATED_AT)::INTEGER as anio,
             EXTRACT(MONTH FROM o.CREATED_AT)::INTEGER as mes,
             o.SELLER_ID,
             COUNT(o.ORDER_ID) as cantidad_ventas,
             SUM(o.QUANTITY) as cantidad_productos,
             SUM(o.FINAL_PRICE) as monto_total
         FROM ORDER_TABLE o
                  INNER JOIN ITEM i ON o.ITEM_ID = i.ITEM_ID
                  INNER JOIN celulares_category cc ON i.CATEGORY_ID = cc.CATEGORY_ID
         WHERE
             EXTRACT(YEAR FROM o.CREATED_AT) = 2020
           AND o.STATUS = 'COMPLETED'
           AND o.PAYMENT_STATUS = 'PAID'
           AND i.DELETED_AT IS NULL
         GROUP BY
             EXTRACT(YEAR FROM o.CREATED_AT),
             EXTRACT(MONTH FROM o.CREATED_AT),
             o.SELLER_ID
     ),
     ranked_sellers AS (
         SELECT
             ms.*,
             ROW_NUMBER() OVER (
                 PARTITION BY ms.mes
                 ORDER BY ms.monto_total DESC, ms.cantidad_productos DESC
                 ) as ranking
         FROM monthly_sales ms
     )
SELECT
    rs.mes,
    rs.anio,
    c.FIRST_NAME as nombre_vendedor,
    c.LAST_NAME as apellido_vendedor,
    rs.cantidad_ventas,
    rs.cantidad_productos,
    rs.monto_total
FROM ranked_sellers rs
         INNER JOIN CUSTOMER c ON rs.SELLER_ID = c.CUSTOMER_ID
WHERE rs.ranking <= 5
  AND c.DELETED_AT IS NULL
ORDER BY rs.mes, rs.ranking;

-- ==============================================================
-- 3. Se solicita poblar una nueva tabla con el precio y estado de los Ítems a fin del día.
-- Tener en cuenta que debe ser reprocesable. Vale resaltar que en la tabla Item,
-- vamos a tener únicamente el último estado informado por la PK definida.
-- (Se puede resolver a través de StoredProcedure)
-- ==============================================================
CREATE OR REPLACE PROCEDURE sp_populate_item_daily_snapshot(p_snapshot_date DATE DEFAULT CURRENT_DATE)
    LANGUAGE plpgsql AS $$
BEGIN
    -- Insertar o actualizar el snapshot de cada ítem
    INSERT INTO ITEM_DAILY_SNAPSHOT (ITEM_ID, SNAPSHOT_DATE, PRICE, STATUS, CURRENCY)
    SELECT
        ITEM_ID,
        p_snapshot_date AS SNAPSHOT_DATE,
        PRICE,
        STATUS,
        CURRENCY
    FROM ITEM
    ON CONFLICT (ITEM_ID, SNAPSHOT_DATE)
        DO UPDATE SET
                      PRICE = EXCLUDED.PRICE,
                      STATUS = EXCLUDED.STATUS,
                      CURRENCY = EXCLUDED.CURRENCY,
                      CREATED_AT = CURRENT_TIMESTAMP;
END;
$$;

-- Cómo ejecutar:
-- Llenar el snapshot del día de hoy
CALL sp_populate_item_daily_snapshot();

-- SELECT * FROM ITEM_DAILY_SNAPSHOT;

-- Llenar un snapshot de una fecha específica
CALL sp_populate_item_daily_snapshot('2025-09-14');
CALL sp_populate_item_daily_snapshot('2025-09-15');