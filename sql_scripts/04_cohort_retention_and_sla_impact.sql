-- =============================================================================
-- PROYECTO 2: AUDITORÍA OPERATIVA Y FINANCIERA E-COMMERCE (OLIST)
-- Archivo: 04_cohort_retention_and_sla_impact.sql
-- Autor: Juan E. Lund — Business & Operations Data Analyst
-- Propósito: 
--   1. Segmentar clientes One-Shot vs. Recurrentes usando ROW_NUMBER() y LAG().
--   2. Cuantificar la caída en tasa de recompra cuando la 1.ª orden incumple SLA.
-- =============================================================================

-- A. SEGMENTACIÓN DE FIDELIDAD Y CICLO DE RECOMPRA CON WINDOW FUNCTIONS
WITH pedidos_por_cliente AS (
  SELECT 
    c.customer_unique_id,
    o.order_id,
    o.order_purchase_timestamp,
    o.cumple_sla,
    ROW_NUMBER() OVER(
      PARTITION BY c.customer_unique_id 
      ORDER BY o.order_purchase_timestamp
    ) AS numero_pedido_cliente,
    LAG(o.order_purchase_timestamp) OVER(
      PARTITION BY c.customer_unique_id 
      ORDER BY o.order_purchase_timestamp
    ) AS fecha_pedido_anterior
  FROM `olist_ecommerce.vw_orders_clean` o
  INNER JOIN `olist_ecommerce.customers` c ON o.customer_id = c.customer_id
),
resumen_frecuencia AS (
  SELECT 
    customer_unique_id,
    MAX(numero_pedido_cliente) AS total_pedidos_cliente,
    MAX(CASE WHEN numero_pedido_cliente = 1 THEN cumple_sla END) AS sla_primera_orden,
    ROUND(AVG(DATETIME_DIFF(order_purchase_timestamp, fecha_pedido_anterior, DAY)), 1) AS dias_promedio_entre_compras
  FROM pedidos_por_cliente
  GROUP BY customer_unique_id
)
SELECT 
  CASE 
    WHEN total_pedidos_cliente = 1 THEN '1 Compra (Cliente Único / One-Shot)'
    WHEN total_pedidos_cliente = 2 THEN '2 Compras (Recurrente Inicial)'
    ELSE '3+ Compras (Cliente Fiel / Recurrente)'
  END AS segmento_fidelidad,
  COUNT(1) AS total_clientes,
  ROUND(COUNT(1) * 100.0 / SUM(COUNT(1)) OVER(), 2) AS pct_base_clientes,
  ROUND(AVG(dias_promedio_entre_compras), 1) AS dias_promedio_recompra
FROM resumen_frecuencia
GROUP BY segmento_fidelidad
ORDER BY total_clientes DESC;
