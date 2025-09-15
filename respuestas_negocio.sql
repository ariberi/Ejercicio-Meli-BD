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
-- CTE para obtener el ID de la categoría
WITH celulares_category AS (
    SELECT CATEGORY_ID
    FROM CATEGORY
    WHERE NAME = 'Celulares y Smartphones'
),
-- CTE para obtener las ventas completadas mensuales de cada vendedor del 2020
-- Se calcula la cantidad de ventas, la cantidad de productos vendidos y cuánto recaudó el vendedor en cada mes del 2020
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
      -- AND o.CURRENCY = 'ARS'
      -- Se podria filtrar por moneda, pero voy a asumir por el momento que hay una sola para simplificar
    GROUP BY
        EXTRACT(YEAR FROM o.CREATED_AT),
        EXTRACT(MONTH FROM o.CREATED_AT),
        o.SELLER_ID
),
-- CTE para hacer un ranking de las de las ventas de cada vendedor del por mes del 2020
ranked_sellers AS (
    SELECT
        ms.*,
        ROW_NUMBER() OVER (
            PARTITION BY ms.mes
            ORDER BY ms.monto_total DESC, ms.cantidad_productos DESC
        ) as ranking
    FROM monthly_sales ms
)
-- Por último, se seleccionan los datos que se piden del top 5 que más vendieron
SELECT
    rs.mes,
    rs.anio,
    c.FIRST_NAME as nombre_vendedor,
    c.LAST_NAME as apellido_vendedor,
    rs.cantidad_ventas,
    rs.cantidad_productos,
    rs.monto_total
FROM ranked_sellers rs
    -- Obtengo el nombre y apellido del vendedor
    INNER JOIN CUSTOMER c ON rs.SELLER_ID = c.CUSTOMER_ID
WHERE rs.ranking <= 5
  -- Excluyo los clientes que ya no están activos
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
    -- Iniciar la transacción para evitar errores
    BEGIN

        -- Para hacerlo más escalable, mejorar performance e identificar posibles errores,
        -- se podría utilizar un procesamiento en lotes, definir un rango cantidad de items,
        -- y luego con un bucle ir procesando cada lote.
        -- Por simplicidad, en este caso se procesa todo de una vez.

        -- Insertar o actualizar (dado que se puede reprocesar) el snapshot de cada ítem
        INSERT INTO ITEM_DAILY_SNAPSHOT (
            ITEM_ID,
            SNAPSHOT_DATE,
            PRICE,
            STATUS,
            CURRENCY
        )
        SELECT
            ITEM_ID,
            p_snapshot_date AS SNAPSHOT_DATE,
            PRICE,
            STATUS,
            CURRENCY
        FROM ITEM
        ON CONFLICT (ITEM_ID, SNAPSHOT_DATE)
            DO UPDATE SET
                          -- Se actualizan parámetros necesarios
                          PRICE = EXCLUDED.PRICE,
                          STATUS = EXCLUDED.STATUS,
                          CURRENCY = EXCLUDED.CURRENCY;
        -- Finalizar la transaccion
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            -- En caso de error, deshacer la transacción
            ROLLBACK;
            RAISE EXCEPTION 'Error al poblar ITEM_DAILY_SNAPSHOT para la fecha %, error: %',
                p_snapshot_date, SQLERRM;
    END;
END;
$$;

-- Cómo ejecutar:
-- Poblar el snapshot del día de hoy
CALL sp_populate_item_daily_snapshot();

-- Poblar un snapshot de una fecha específica
CALL sp_populate_item_daily_snapshot('2025-09-14');
CALL sp_populate_item_daily_snapshot('2025-09-15');

-- SELECT * FROM ITEM_DAILY_SNAPSHOT; -- Para verificar si se cargó