# Eco Bottle — Mini-Ecosistema de Datos Comercial (OLTP a DW)

Proyecto final desarrollado para la materia **Introducción al Marketing Online y los Negocios Digitales** de la Universidad Austral. El proyecto implementa un pipeline de datos completo (ETL/ELT con DuckDB y Python), el modelado dimensional bajo la metodología Kimball y la construcción de un tablero ejecutivo interactivo en Power BI para monitorear las métricas comerciales de la empresa **EcoBottle AR** (ventas online y offline, 4 tiendas físicas, tráfico web y satisfacción NPS).

---

## 📁 Estructura del Repositorio

```text
raw/               Datos de origen (archivos CSV transaccionales del sistema OLTP)
sql/               Scripts DDL y DML de transformación en SQL (modelo estrella y data marts)
dw/                Data Warehouse resultante (tablas procesadas en formato CSV para Power BI)
assets/            Recursos visuales y diagrama entidad-relación de origen (DER)
venv/              Entorno virtual de Python con las dependencias del proyecto
requirements.txt   Lista de librerías requeridas (DuckDB)
run_sql.py         Script Python de automatización para construir el Data Warehouse
warehouse.duckdb   Base de datos analítica local creada al ejecutar el pipeline
README.md          Documentación técnica del proyecto y diccionario de datos
```
---

## 🚀 Instrucciones de Ejecución

Para levantar el pipeline y generar la base de datos analítica local (`warehouse.duckdb`) junto con los data marts en CSV, sigue estos pasos:

1. **Clona el repositorio** y abre la terminal en la carpeta raíz del proyecto.
2. **Activa el entorno virtual** de Python:
   - En Windows (PowerShell): `.\venv\Scripts\Activate`
   - En Mac/Linux: `source venv/bin/activate`
3. **Verifica las dependencias** requeridas ejecutando:

   `pip install -r requirements.txt`
4. **Ejecuta el script de automatización del pipeline ETL/ELT**

  `python run_sql.py`
5. **Conecta Power BI a los archivos procesados en la carpeta `dw/` o directamente a la base `warehouse.duckdb` para visualizar el tablero ejecutivo.**

---

## 💡 Supuestos de Negocio

* **Ventas y Facturación:** Solo se consideran válidas para el cálculo de ingresos netos, unidades vendidas y ticket promedio aquellas órdenes cuyo estado sea `PAID` (Pagada) o `FULFILLED` (Entregada/Completada). Se excluyen órdenes en estado `CREATED`, `CANCELLED` o `REFUNDED`.
* **Usuarios Activos:** Se computan desde `fact_web_session`. Las sesiones con `customer_id` nulo corresponden a visitantes anónimos, mientras que la métrica de usuarios activos mensuales se calcula mediante `COUNT(DISTINCT customer_id)`.
* **Net Promoter Score (NPS):** Las encuestas enviadas se asocian al canal de venta (`ONLINE` u `OFFLINE`). Se consideran *Promotores* a las calificaciones de 9 a 10 y *Detractores* a las de 0 a 6. El score se determina mediante la fórmula:
  $$\text{NPS} = (\% \text{ Promotores} - \% \text{ Detractores}) \times 100$$
* **Geografía:** Las transacciones se consolidan por provincia según la dirección de envío (`shipping_address_id`) vinculada a la dimensión de localización (`dim_location`).

---

## 📖 Diccionario de Datos (Modelo Estrella - Kimball)

El Data Warehouse `warehouse.duckdb` está estructurado en un modelo dimensional estrella que separa claramente atributos descriptivos y métricas de negocio:

### 1. Tablas de Dimensiones (`dim_`)
* **`dim_date`**: Dimensión de tiempo con grano diario (claves numéricas `YYYYMMDD`, día, mes, trimestre, año).
* **`dim_channel`**: Canales de comercialización (`ONLINE`, `OFFLINE`).
* **`dim_customer`**: Maestro de clientes con datos de contacto y estado de la cuenta.
* **`dim_product`**: Maestro de productos desnormalizado con su categoría y familia de artículos (*Classic A* y *Sport B*).
* **`dim_location`**: Direcciones normalizadas con localidad, provincia y código postal.
* **`dim_store`**: Puntos de venta físicos (sucursales Buenos Aires, Córdoba, Santa Fe y Mendoza).
* **`dim_traffic_source`** / **`dim_device`**: Atributos analíticos de navegación web.
* **`dim_payment_method`** / **`dim_carrier`**: Dimensiones de soporte para medios de pago y transportistas de envío.

### 2. Tablas de Hechos (`fact_`)
* **`fact_sales`**: Cabecera de pedidos (`order_id`). Registra importes de subtotal, impuestos, envío y total general.
* **`fact_sales_item`**: Detalle de líneas de pedido (`order_item_id`). Registra producto, cantidad, precio unitario y total por línea.
* **`fact_nps`**: Respuestas a la encuesta de satisfacción por cliente, canal y puntaje obtenido.
* **`fact_web_session`**: Registro de sesiones de navegación en el sitio web con sello de tiempo y duración.
* **`fact_payment`** / **`fact_shipment`**: Transacciones de cobro y trazabilidad logística de entregas.

### 3. Data Marts Pre-calculados (`mart_`)
Para optimizar el rendimiento y la carga directa en Power BI, se generan tablas agregadas mensuales en `04_data_marts.sql`:
* `mart_ventas_mensual`, `mart_producto_mensual`, `mart_nps_mensual` y `mart_usuarios_mensual`.

---

## 🔍 Consultas Clave (SQL)

Consultas principales utilizadas para validar las métricas requeridas por el negocio:

### 1. Ventas Totales ($M) y Ticket Promedio ($K) por Canal y Mes
```sql
SELECT 
    d.year,
    d.month,
    c.name AS channel_name,
    SUM(f.total_amount) AS total_ventas,
    COUNT(f.order_id) AS total_pedidos,
    AVG(f.total_amount) AS ticket_promedio
FROM fact_sales f
JOIN dim_date d ON f.date_id = d.date_id
JOIN dim_channel c ON f.channel_id = c.channel_id
WHERE f.status IN ('PAID', 'FULFILLED')
GROUP BY d.year, d.month, c.name
ORDER BY d.year, d.month, c.name;

2. Cálculo Mensual del Net Promoter Score (NPS) por Canal
WITH nps_categorized AS (
    SELECT 
        d.year,
        d.month,
        c.name AS channel_name,
        CASE WHEN n.score >= 9 THEN 1 ELSE 0 END AS is_promoter,
        CASE WHEN n.score <= 6 THEN 1 ELSE 0 END AS is_detractor
    FROM fact_nps n
    JOIN dim_date d ON n.date_id = d.date_id
    JOIN dim_channel c ON n.channel_id = c.channel_id
)
SELECT 
    year,
    month,
    channel_name,
    COUNT(*) AS total_respuestas,
    ROUND(
        (SUM(is_promoter::FLOAT) / COUNT(*) - SUM(is_detractor::FLOAT) / COUNT(*)) * 100, 
        2
    ) AS nps_score
FROM nps_categorized
GROUP BY year, month, channel_name
ORDER BY year, month, channel_name;

3. Ranking Mensual De Productos por Ventas
SELECT 
    d.year,
    d.month,
    p.name AS product_name,
    SUM(i.quantity) AS total_unidades_vendidas,
    SUM(i.line_total) AS total_ingresos
FROM fact_sales_item i
JOIN fact_sales f ON i.order_id = f.order_id
JOIN dim_product p ON i.product_key = p.product_key
JOIN dim_date d ON f.date_id = d.date_id
WHERE f.status IN ('PAID', 'FULFILLED')
GROUP BY d.year, d.month, p.name
ORDER BY d.year, d.month, total_ingresos DESC;
```
---

* **Autoría:** Bianca Rossi — Universidad Austral
* **Contacto:** brossi@mail.austral.edu.ar



