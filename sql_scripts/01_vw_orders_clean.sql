-- =============================================================================
-- PROYECTO 2: AUDITORÍA OPERATIVA Y FINANCIERA E-COMMERCE (OLIST)
-- Archivo: 01_vw_orders_clean.sql
-- Autor: Juan E. Lund — Business & Operations Data Analyst
-- Propósito: Vista maestra certificada (96,470 órdenes entregadas válidas)
--            con resolución horaria para cálculo exacto de SLAs.
-- =============================================================================

CREATE OR REPLACE VIEW `olist_ecommerce.vw_orders_clean` AS
SELECT 
  order_id,
  customer_id,
  order_status,
  order_purchase_timestamp,
  order_approved_at,
  order_delivered_carrier_date,
  order_delivered_customer_date,
  order_estimated_delivery_date,
  
  -- Cálculo de tiempos logísticos en días decimales exactos (resolución horaria)
  ROUND(DATETIME_DIFF(order_delivered_customer_date, order_purchase_timestamp, HOUR) / 24.0, 2) AS dias_entrega_real,
  ROUND(DATETIME_DIFF(order_estimated_delivery_date, order_purchase_timestamp, HOUR) / 24.0, 2) AS dias_entrega_estimada,
  ROUND(DATETIME_DIFF(order_delivered_customer_date, order_estimated_delivery_date, HOUR) / 24.0, 2) AS dias_retraso_sla,
  
  -- Bandera binaria de cumplimiento de SLA
  CASE 
    WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 1 
    ELSE 0 
  END AS cumple_sla,
  
  -- Dimensiones de partición temporal
  DATE(order_purchase_timestamp) AS fecha_compra,
  FORMAT_DATE('%Y-%m', DATE(order_purchase_timestamp)) AS anio_mes_compra
FROM `olist_ecommerce.orders`
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;
