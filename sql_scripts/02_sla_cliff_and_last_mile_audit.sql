-- =============================================================================
-- PROYECTO 2: AUDITORÍA OPERATIVA Y FINANCIERA E-COMMERCE (OLIST)
-- Archivo: 02_sla_cliff_and_last_mile_audit.sql
-- Autor: Juan E. Lund — Business & Operations Data Analyst
-- Propósito: 
--   1. Cuantificar el "Acantilado del 4.° Día" (SLA Cliff) sobre las reseñas.
--   2. Descomponer la causa raíz de los retrasos en corredores críticos:
--      First-Mile (Seller Lead Time) vs. Last-Mile (Carrier Transit Time).
-- =============================================================================

-- A. AUDITORÍA DEL ACANTILADO DE SATISFACCIÓN (SLA CLIFF: VENTANA DE 72 HORAS)
WITH tramos_sla AS (
  SELECT 
    o.order_id,
    r.review_score,
    CASE 
      WHEN o.dias_retraso_sla <= 0 THEN '1. A tiempo o antes (<= SLA)'
      WHEN o.dias_retraso_sla > 0 AND o.dias_retraso_sla <= 3 THEN '2. Retraso leve (1 a 3 días)'
      WHEN o.dias_retraso_sla > 3 AND o.dias_retraso_sla <= 7 THEN '3. Retraso moderado (4 a 7 días)'
      ELSE '4. Retraso crítico (> 7 días)'
    END AS tramo_entrega
  FROM `olist_ecommerce.vw_orders_clean` o
  INNER JOIN `olist_ecommerce.order_reviews` r ON o.order_id = r.order_id
)
SELECT 
  tramo_entrega,
  COUNT(1) AS total_evaluaciones,
  ROUND(COUNT(1) * 100.0 / SUM(COUNT(1)) OVER(), 2) AS pct_volumen,
  ROUND(AVG(review_score), 2) AS puntaje_promedio_estrellas,
  ROUND(COUNTIF(review_score <= 2) * 100.0 / COUNT(1), 2) AS pct_detractores,
  ROUND(COUNTIF(review_score = 5) * 100.0 / COUNT(1), 2) AS pct_promotores
FROM tramos_sla
GROUP BY tramo_entrega
ORDER BY tramo_entrega;

-- B. AUDITORÍA DE CAUSA RAÍZ: FIRST-MILE (SELLER) VS. LAST-MILE (CARRIER)
WITH desglose_tiempos AS (
  SELECT 
    o.order_id,
    CONCAT(s.seller_state, ' -> ', c.customer_state) AS corredor,
    ROUND(DATETIME_DIFF(o.order_delivered_carrier_date, o.order_approved_at, HOUR) / 24.0, 2) AS dias_despacho_seller,
    ROUND(DATETIME_DIFF(o.order_delivered_customer_date, o.order_delivered_carrier_date, HOUR) / 24.0, 2) AS dias_transito_carrier,
    ROUND(DATETIME_DIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date, HOUR) / 24.0, 2) AS dias_retraso_sla,
    CASE WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 1 ELSE 0 END AS cumple_sla
  FROM `olist_ecommerce.orders` o
  INNER JOIN `olist_ecommerce.order_items` oi ON o.order_id = oi.order_id
  INNER JOIN `olist_ecommerce.sellers` s ON oi.seller_id = s.seller_id
  INNER JOIN `olist_ecommerce.customers` c ON o.customer_id = c.customer_id
  WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
    AND o.order_delivered_carrier_date IS NOT NULL
    AND o.order_approved_at IS NOT NULL
)
SELECT 
  corredor,
  COUNT(1) AS total_items,
  ROUND(AVG(dias_despacho_seller), 1) AS media_dias_seller,
  ROUND(AVG(dias_transito_carrier), 1) AS media_dias_carrier,
  ROUND(AVG(CASE WHEN cumple_sla = 0 THEN dias_despacho_seller END), 1) AS seller_dias_en_atrasos,
  ROUND(AVG(CASE WHEN cumple_sla = 0 THEN dias_transito_carrier END), 1) AS carrier_dias_en_atrasos,
  ROUND((1 - AVG(cumple_sla)) * 100, 2) AS pct_retraso
FROM desglose_tiempos
GROUP BY corredor
HAVING total_items >= 500
ORDER BY pct_retraso DESC
LIMIT 10;
