-- =====================================================================
-- 03_consultas.sql — Consultas para revisar el modelo y calcular KPIs
-- =====================================================================
-- Cada SELECT de este archivo se muestra en la terminal al ejecutar
-- run_sql.py. Usalo para:
--   * comprobar que las tablas se cargaron bien (cantidad de filas, nulos...)
--   * escribir las consultas clave de los KPIs que pide la consigna
--     (ventas, usuarios activos, ticket promedio, NPS, ventas por provincia,
--     ranking mensual por producto) usando las tablas del modelo estrella.
-- =====================================================================


-- Ejemplo: revisar la dimensión producto
SELECT product_key, name, category, family, list_price
FROM dim_product
ORDER BY product_key;


-- TU TURNO: agregá acá tus consultas.

-- =====================================================================
-- 03_consultas.sql — Consultas clave para el análisis y KPIs de EcoBottle
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. VENTAS TOTALES ($M) Y TICKET PROMEDIO ($K) POR CANAL Y MES
-- ---------------------------------------------------------------------
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


-- ---------------------------------------------------------------------
-- 2. USUARIOS ACTIVOS (nK) POR MES Y FUENTE DE TRÁFICO
-- ---------------------------------------------------------------------
SELECT 
    d.year,
    d.month,
    s.source AS traffic_source,
    COUNT(DISTINCT ws.customer_id) AS usuarios_registrados_activos,
    COUNT(ws.session_id) AS total_sesiones
FROM fact_web_session ws
JOIN dim_date d ON ws.date_id = d.date_id
JOIN dim_traffic_source s ON ws.traffic_source_key = s.traffic_source_key
GROUP BY d.year, d.month, s.source
ORDER BY d.year, d.month, total_sesiones DESC;


-- ---------------------------------------------------------------------
-- 3. NPS (NET PROMOTER SCORE) MENSUAL POR CANAL
-- Fórmula: ((% Promotores [9-10] - % Detractores [0-6]) * 100)[cite: 7]
-- ---------------------------------------------------------------------
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


-- ---------------------------------------------------------------------
-- 4. VENTAS POR PROVINCIA
-- ---------------------------------------------------------------------
SELECT 
    l.province_name,
    SUM(f.total_amount) AS total_ventas,
    COUNT(f.order_id) AS cantidad_pedidos
FROM fact_sales f
JOIN dim_location l ON f.location_id = l.location_id
WHERE f.status IN ('PAID', 'FULFILLED')
GROUP BY l.province_name
ORDER BY total_ventas DESC;


-- ---------------------------------------------------------------------
-- 5. RANKING MENSUAL POR PRODUCTO (Top productos por ingresos)
-- ---------------------------------------------------------------------
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