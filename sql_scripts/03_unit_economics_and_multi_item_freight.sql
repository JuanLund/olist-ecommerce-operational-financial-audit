-- =============================================================================
-- PROYECTO 2: AUDITORÍA OPERATIVA Y FINANCIERA E-COMMERCE (OLIST)
-- Archivo: 03_unit_economics_and_multi_item_freight.sql
-- Autor: Juan E. Lund — Business & Operations Data Analyst
-- Propósito: 
--   1. Evaluar la densidad económica y erosión por flete (>20%) por categoría.
--   2. Auditar la falla algorítmica en carritos multi-unidad del mismo seller.
-- =============================================================================

-- A. RANKING DE UNIT ECONOMICS Y FRICCIÓN DE FLETE POR CATEGORÍA
WITH metricas_categoria AS (
  SELECT 
    COALESCE(p.product_category_name, 'sin_categoria') AS categoria,
    COUNT(DISTINCT oi.order_id) AS total_ordenes,
    COUNT(oi.order_item_id) AS total_items_vendidos,
    ROUND(COUNT(oi.order_item_id) * 1.0 / COUNT(DISTINCT oi.order_id), 2) AS items_por_orden,
    ROUND(SUM(oi.price), 2) AS facturacion_productos,
    ROUND(SUM(oi.freight_value), 2) AS costo_total_flete,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS gmv_total,
    ROUND(AVG(oi.price), 2) AS ticket_promedio_item,
    ROUND(AVG(oi.freight_value), 2) AS flete_promedio_item,
    ROUND((SUM(oi.freight_value) / NULLIF(SUM(oi.price), 0)) * 100, 2) AS pct_peso_flete_sobre_precio
  FROM `olist_ecommerce.vw_orders_clean` o
  INNER JOIN `olist_ecommerce.order_items` oi ON o.order_id = oi.order_id
  LEFT JOIN `olist_ecommerce.products` p ON oi.product_id = p.product_id
  GROUP BY categoria
)
SELECT 
  categoria,
  total_ordenes,
  items_por_orden,
  facturacion_productos,
  costo_total_flete,
  pct_peso_flete_sobre_precio,
  ticket_promedio_item,
  RANK() OVER (ORDER BY facturacion_productos DESC) AS ranking_ingresos,
  RANK() OVER (ORDER BY pct_peso_flete_sobre_precio DESC) AS ranking_flete_erosivo
FROM metricas_categoria
WHERE total_ordenes >= 200
ORDER BY facturacion_productos DESC
LIMIT 10;

-- B. AUDITORÍA DE CARRITOS MULTI-ÍTEM DEL MISMO VENDEDOR (COBRO LINEAL DE FLETE)
WITH ordenes_mismo_producto AS (
  SELECT 
    order_id,
    product_id,
    seller_id,
    COUNT(order_item_id) AS unidades_compradas,
    MIN(freight_value) AS flete_min_unidad,
    MAX(freight_value) AS flete_max_unidad,
    SUM(price) AS subtotal_producto,
    SUM(freight_value) AS subtotal_flete
  FROM `olist_ecommerce.order_items`
  GROUP BY order_id, product_id, seller_id
  HAVING COUNT(order_item_id) >= 2
)
SELECT 
  COUNT(1) AS total_ordenes_multi_sku_identico,
  COUNTIF(ABS(flete_max_unidad - flete_min_unidad) < 0.01) AS ordenes_sin_descuento_consolidacion,
  ROUND(SUM(subtotal_flete) * 100.0 / SUM(subtotal_producto), 2) AS pct_flete_sobre_precio_multi_item
FROM ordenes_mismo_producto;
