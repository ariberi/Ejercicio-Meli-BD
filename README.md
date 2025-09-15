# Ejercicio Base de Datos 2025 - MELI

Este proyecto implementa un modelo de base de datos para un marketplace similar a Mercado Libre (MELI).

Incluye el esquema de la base de datos y consultas SQL para resolver preguntas de negocio específicas.

Tener en cuenta que el mismo fue desarrollado utilizando la última versión del motor de base de datos de **PostgreSQL**, 
por lo que las sintaxis puede variar en otros motores.

## Esquema de la Base de Datos

El modelo de datos está compuesto por las siguientes tablas:

-   `CUSTOMER`: Almacena la información de los usuarios, tanto compradores como vendedores.
-   `ADDRESS`: Guarda las direcciones asociadas a cada usuario.
-   `PHONE`: Almacena los números de teléfono de los usuarios.
-   `CATEGORY`: Define la jerarquía de categorías de productos, permitiendo una estructura de varios niveles.
-   `ITEM`: Contiene la información detallada de los productos publicados por los vendedores.
-   `ORDER_TABLE`: Registra todas las transacciones u órdenes de compra realizadas en la plataforma.
-   `ITEM_DAILY_SNAPSHOT`: Tabla para almacenar un snapshot diario del precio y estado de los ítems, 
     con el fin de realizar análisis históricos.

## Archivos del Proyecto

-   `create_tables.sql`: Contiene las sentencias DDL para definir la estructura completa de la base de datos.
-   `respuestas_negocio.sql`: Incluye las consultas que responden a los requerimientos de negocio planteados.
-   `funciones_triggers.sql`: Incluye algunas funciones y triggers adicionales que podrían usarse 
                para facilitar el manejo y validación de datos.
-   `DER.drawio.png`: Es el gráfico de relaciones entre las tablas.

## Preguntas de Negocio Resueltas

En el archivo `respuestas_negocio.sql` se pueden encontrar las soluciones a los siguientes requerimientos:

1.  **Listar los usuarios que cumplan años el día de hoy cuya cantidad de ventas realizadas en enero 2020 sea superior a 1500.**

2.  **Por cada mes del 2020, se solicita el top 5 de usuarios que más vendieron($) en la categoría Celulares. 
     Se requiere el mes y año de análisis, nombre y apellido del vendedor, cantidad de ventas realizadas, 
     cantidad de productos vendidos y el monto total transaccionado.**

3.  **Se solicita poblar una nueva tabla con el precio y estado de los Ítems a fin del día. 
     Tener en cuenta que debe ser reprocesable. Vale resaltar que en la tabla Item, 
      vamos a tener únicamente el último estado informado por la PK definida. (Se puede resolver a través de StoredProcedure)**
