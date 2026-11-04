-- =====================================================================
-- 04_data_marts.sql — Tablas pre-calculadas para el Dashboard (Sin DAX)
-- =====================================================================

CREATE TABLE dim_mes (
    mes DATE NOT NULL PRIMARY KEY,
    anio INTEGER NOT NULL,
    nro_mes INTEGER NOT NULL
);

INSERT INTO dim_mes 
SELECT DISTINCT 
    MAKE_DATE(year, month, 1), 
    year, 
    month 
FROM dim_date;


CREATE TABLE mart_ventas_mensual (
    mes DATE NOT NULL,
    canal VARCHAR(50) NOT NULL,
    provincia VARCHAR(50) NOT NULL,
    ventas DECIMAL(14,2) NOT NULL,
    pedidos INTEGER NOT NULL,
    ticket_promedio DECIMAL(12,2),
    PRIMARY KEY (mes, canal, provincia)
);

INSERT INTO mart_ventas_mensual 
SELECT 
    MAKE_DATE(d.year, d.month, 1), 
    c.name, 
    COALESCE(l.province_name, 'Sin provincia'), 
    SUM(f.total_amount), 
    COUNT(*), 
    ROUND(SUM(f.total_amount) / COUNT(*), 2) 
FROM fact_sales AS f 
JOIN dim_date AS d ON d.date_id = f.date_id 
JOIN dim_channel AS c ON c.channel_id = f.channel_id 
LEFT JOIN dim_location AS l ON l.location_id = f.location_id 
WHERE f.status IN ('PAID', 'FULFILLED') 
GROUP BY MAKE_DATE(d.year, d.month, 1), c.name, COALESCE(l.province_name, 'Sin provincia');


CREATE TABLE mart_producto_mensual (
    mes DATE NOT NULL,
    producto VARCHAR(80) NOT NULL,
    ventas DECIMAL(14,2) NOT NULL,
    unidades INTEGER NOT NULL,
    ranking INTEGER NOT NULL,
    PRIMARY KEY (mes, producto)
);

INSERT INTO mart_producto_mensual 
SELECT 
    mes, 
    producto, 
    ventas, 
    unidades, 
    RANK() OVER (PARTITION BY mes ORDER BY ventas DESC) 
FROM ( 
    SELECT 
        MAKE_DATE(d.year, d.month, 1) AS mes, 
        p.name AS producto, 
        SUM(i.line_total) AS ventas, 
        SUM(i.quantity) AS unidades 
    FROM fact_sales_item AS i 
    JOIN dim_date AS d ON d.date_id = i.date_id 
    JOIN dim_product AS p ON p.product_key = i.product_key 
    JOIN fact_sales AS f ON f.order_id = i.order_id
    WHERE f.status IN ('PAID', 'FULFILLED') 
    GROUP BY MAKE_DATE(d.year, d.month, 1), p.name 
);


CREATE TABLE mart_nps_mensual (
    mes DATE NOT NULL,
    canal VARCHAR(50) NOT NULL,
    respuestas INTEGER NOT NULL,
    promotores INTEGER NOT NULL,
    detractores INTEGER NOT NULL,
    nps DECIMAL(5,1),
    PRIMARY KEY (mes, canal)
);

INSERT INTO mart_nps_mensual 
SELECT 
    MAKE_DATE(d.year, d.month, 1), 
    c.name, 
    COUNT(*), 
    SUM(CASE WHEN n.score >= 9 THEN 1 ELSE 0 END), 
    SUM(CASE WHEN n.score <= 6 THEN 1 ELSE 0 END), 
    ROUND(100.0 * (SUM(CASE WHEN n.score >= 9 THEN 1 ELSE 0 END) - SUM(CASE WHEN n.score <= 6 THEN 1 ELSE 0 END)) / COUNT(*), 1) 
FROM fact_nps AS n 
JOIN dim_date AS d ON d.date_id = n.date_id 
JOIN dim_channel AS c ON c.channel_id = n.channel_id 
GROUP BY MAKE_DATE(d.year, d.month, 1), c.name;


CREATE TABLE mart_usuarios_mensual (
    mes DATE NOT NULL PRIMARY KEY,
    usuarios_activos INTEGER NOT NULL,
    sesiones INTEGER NOT NULL,
    sesiones_anonimas INTEGER NOT NULL
);

INSERT INTO mart_usuarios_mensual 
SELECT 
    MAKE_DATE(d.year, d.month, 1), 
    COUNT(DISTINCT w.customer_id), 
    COUNT(*), 
    SUM(CASE WHEN w.customer_id IS NULL THEN 1 ELSE 0 END) 
FROM fact_web_session AS w 
JOIN dim_date AS d ON d.date_id = w.date_id 
GROUP BY MAKE_DATE(d.year, d.month, 1);
