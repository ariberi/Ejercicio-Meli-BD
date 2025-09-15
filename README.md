# Ejercicio Base de Datos 2025 - MELI

Este proyecto implementa un modelo de base de datos para un marketplace similar a Mercado Libre (MELI).

Incluye el esquema de la base de datos y consultas SQL para resolver preguntas de negocio específicas.

El mismo fue desarrollado utilizando la última versión de **PostgreSQL**.

## Esquema de la Base de Datos

El modelo de datos está compuesto por las siguientes tablas:

-   `CUSTOMER`: Almacena la información de los usuarios, tanto compradores como vendedores.
-   `ADDRESS`: Guarda las direcciones asociadas a cada usuario.
-   `PHONE`: Almacena los números de teléfono de los usuarios.
-   `CATEGORY`: Define la jerarquía de categorías de productos, permitiendo una estructura de varios niveles.
-   `ITEM`: Contiene la información detallada de los productos publicados por los vendedores.
-   `ORDER_TABLE`: Registra todas las transacciones u órdenes de compra realizadas en la plataforma.
-   `ITEM_DAILY_SNAPSHOT`: Tabla desnormalizada para almacenar un snapshot diario del precio y estado de los ítems, con el fin de realizar análisis históricos.

## Archivos del Proyecto

-   `create_tables.sql`: Contiene las sentencias DDL para definir la estructura completa de la base de datos.
-   `respuestas_negocio.sql`: Incluye las consultas responden a los requerimientos de negocio planteados.
-   `funciones_triggers.sql`: Incluye funciones y triggers adicionales para facilitar el manejo y validación de datos.
-   `DER.drawio.png`: Es el gráfico de relaciones entre las tablas.

## Preguntas de Negocio Resueltas

En el archivo `respuestas_negocio.sql` se pueden encontrar las soluciones a los siguientes requerimientos:

1.  **Listar usuarios que cumplen años hoy y tuvieron más de 1500 ventas en enero de 2020.**

2.  **Top 5 de vendedores en la categoría "Celulares y Smartphones" para cada mes de 2020.**

3.  **Poblar una tabla con el estado y precio diario de los ítems.**