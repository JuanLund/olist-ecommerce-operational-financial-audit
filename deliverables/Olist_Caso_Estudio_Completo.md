# PROYECTO 2: Auditoría Operativa y Financiera E-Commerce (Dataset Olist)
**Autor:** Juan E. Lund — Business & Operations Data Analyst  
**Stack Técnico:** Google BigQuery (Cloud SQL: CTEs, Window Functions `ROW_NUMBER`, `LAG`, `RANK`, Views) · Tableau Public · Diseño Experimental A/B  
**Volumen Procesado:** 99,441 órdenes brutas $\rightarrow$ 96,470 órdenes entregadas certificadas · 93,350 clientes únicos · 7 tablas relacionales  
**Dashboard Interactivo (Tableau Public):** [Olist E-Commerce: Auditoría Operativa y Financiera (`Brazil_ecomercce/Dashboard1`)](https://public.tableau.com/views/Brazil_ecomercce/Dashboard1?:language=es-ES&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)

---

## 1. Síntesis Ejecutiva (Answer-First) y Valor de Negocio ($\text{R\$ }1.23\text{M}$)
El crecimiento sostenible y el margen de contribución de Olist están siendo erosionados por tres fugas estructurales silenciosas: **un colapso de satisfacción del cliente al 4.° día de retraso logístico concentrado en la última milla de Río de Janeiro, una severa fricción tarifaria por flete ($>23\%$) agravada por el cobro del $100\%$ de envío en unidades adicionales del mismo vendedor, y una dependencia extrema de compradores de única vez ($97.0\%$ *one-shot*)**.

La implementación del **Plan de Reingeniería Operativa y Comercial a 90 Días** proyecta un impacto anual consolidado de **$\text{R\$ }1,230,000$ en GMV protegido e incremental** ($\sim\text{R\$ }680\text{k}$ en GMV blindado contra detractoría en RJ, $+\text{R\$ }310\text{k}$ por expansión de ticket en Hogar y $+\text{R\$ }240\text{k}$ por reactivación sin CAC en Belleza y Salud):

| Pilar Auditado | Métrica Base Certificada | Causa Raíz Demostrada en SQL (BigQuery) | Plan de Acción Quirúrgico (Fase Act) | Impacto Anual Proyectado |
| :--- | :---: | :--- | :--- | :---: |
| **1. Logística y SLAs** | **$91.89\%$** SLA general ($88,644$ a tiempo; $7,826$ tarde) | **Acantilado al 4.° día:** de $3.76\ \star$ ($1\text{–}3\text{d}$) cae a **$2.31\ \star$** ($61.62\%$ detractores). En **SP $\rightarrow$ RJ** ($14.85\%$ atraso), el *seller* despacha en **$4.6\text{d}$**, pero el *carrier* tarda **$31.3\text{d}$** ($87.2\%$ del fallo). | **Operación Desbloqueo RJ** (enrutamiento a *carriers* privados / Lockers PUDO con $15\%$ dto.) + **Gatillo Preventivo a las 72h** (WhatsApp T+24h de retraso). | **$\sim\text{R\$ }680,000$** en GMV protegido y $-40\%$ en tickets de reclamo. |
| **2. Unit Economics y Flete** | Top 10 Categorías ($\text{R\$ }8.25\text{M}$ ventas; umbral $20\%$ flete) | **Falla algorítmica multi-ítem:** en **$6,570$ órdenes** con $2+$ unidades idénticas, el sistema cobró $100\%$ de flete por cada ítem extra, hundiendo a `moveis_decoracao` (**$23.65\%$** flete) y `utilidades` (**$23.19\%$**). | **Regla de Flete Incremental (*Same-Seller Bundling* $>\text{R\$ }150$):** bonificar $50\%$ del flete desde la 2.ª unidad del mismo *seller* + **Geo-Priorización Local**. | **$+\text{R\$ }310,000$** en GMV incremental (ratio flete baja de $23.6\%$ a $\sim 14.8\%$). |
| **3. Retención y Cohortes** | **$93,350$** clientes únicos ($97.00\%$ *One-Shot*) | **Bifurcación e impacto logístico:** de los $2,801$ recurrentes ($3.00\%$), el $30.5\%$ son carritos divididos el mismo día ($<24\text{h}$) y el $69.5\%$ recompra entre los **$81.7\text{ y }116.8\text{ días}$**. Sufrir atraso reduce la recompra un **$-17.4\%$**. | **Motor de LTV en el Día 65 (`beleza_saude`):** campaña de reposición exclusiva para clientes entregados *On-Time* ($\le\text{SLA}$) + **Tarjeta QR física In-Box**. | **$+\text{R\$ }240,000$** en GMV recurrente con $\text{CAC} = \text{R\$ }0$ (meta $7.5\%$ recompra). |

---

## 2. Fase 1, 2 & 3: Ask, Prepare & Process (Arquitectura y Gobernanza en BigQuery)

### 2.1 Arquitectura Relacional (7 Tablas Conectadas)
* `orders`: Llave primaria `order_id` y foránea `customer_id`. Marcas temporales de compra, aprobación, despacho al transportista (`order_delivered_carrier_date`), entrega real (`order_delivered_customer_date`) y SLA estimado (`order_estimated_delivery_date`).
* `order_items`: Detalle transaccional por ítem (`order_item_id`, `product_id`, `seller_id`), precio unitario (`price`) y flete (`freight_value`).
* `order_payments`: Métodos de pago, cuotas y valor total transaccionado (`payment_value`).
* `order_reviews`: Calificaciones de 1 a 5 estrellas (`review_score`) y reseñas verificadas.
* `customers`: Llave de sesión `customer_id` e identificador único real del comprador `customer_unique_id` (esencial para el seguimiento longitudinal de cohortes).
* `products` & `sellers`: Categorías de catálogo (`product_category_name`), dimensiones volumétricas y localización estadual de los vendedores (`seller_state`).

### 2.2 Tabla de Conciliación de Estados Operativos y Reglas de Gobernanza
| Estado Operativo (`order_status`) | Volumen de Órdenes | % del Total Bruto | Entregas sin Fecha (`NULL`) | Rango Temporal Auditado | Regla de Gobernanza Analítica y Financiera Aplicada |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **`delivered` (Certificadas)** | **$96,470$** | **$97.01\%$** | $0$ ($8$ excluidas) | 2016-09-15 a 2018-08-29 | Población oficial en `vw_orders_clean` para auditoría de SLAs, rutas y reseñas. |
| **`delivered` (Anómalas)** | $8$ | $0.01\%$ | $8$ | 2017-05-19 a 2018-07-03 | Excluidas de cálculos de `DATETIME_DIFF` para evitar distorsión por nulos. |
| **`shipped` (En tránsito)** | $1,107$ | $1.11\%$ | $1,107$ | 2016-09-04 a 2018-09-03 | Órdenes despachadas al transportista sin cierre de última milla al corte. |
| **`canceled` (Canceladas)** | $625$ | $0.63\%$ | $619$ ($6$ entregadas) | 2016-09-05 a 2018-10-17 | Excluidas de GMV neto; $6$ órdenes con fecha indican devolución post-entrega. |
| **`unavailable` (Quiebre stock)** | $609$ | $0.61\%$ | $609$ | 2016-10-05 a 2018-08-21 | Fuga operativa directa por inventario fantasma del *seller* ($\sim\text{R\$ }97\text{k}$ perdidos). |
| **`invoiced` / `processing` / Otros** | $622$ | $0.63\%$ | $622$ | 2016-10-04 a 2018-08-14 | Incluye `invoiced` ($314$), `processing` ($301$), `created` ($5$) y `approved` ($2$). |
| **Total Auditado** | **$99,441$** | **$100.00\%$** | **$2,965$** | **Sep 2016 – Oct 2018** | **Fuga operativa (`canceled` + `unavailable`): $1,234$ órdenes ($1.24\%$ bruta / $\sim\text{R\$ }197\text{k}$ GMV).** |

---

## 3. Repositorio Completo de Scripts SQL en Google BigQuery

### 3.1 Creación de la Vista Maestra Limpia (`01_vw_orders_clean.sql`)
```sql
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
  
  -- Cálculo de tiempos logísticos en días exactos (resolución horaria)
  ROUND(DATETIME_DIFF(order_delivered_customer_date, order_purchase_timestamp, HOUR) / 24.0, 2) AS dias_entrega_real,
  ROUND(DATETIME_DIFF(order_estimated_delivery_date, order_purchase_timestamp, HOUR) / 24.0, 2) AS dias_entrega_estimada,
  ROUND(DATETIME_DIFF(order_delivered_customer_date, order_estimated_delivery_date, HOUR) / 24.0, 2) AS dias_retraso_sla,
  
  -- Bandera de cumplimiento de SLA
  CASE 
    WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 1 
    ELSE 0 
  END AS cumple_sla,
  
  -- Clasificación temporal
  DATE(order_purchase_timestamp) AS fecha_compra,
  FORMAT_DATE('%Y-%m', DATE(order_purchase_timestamp)) AS anio_mes_compra
FROM `olist_ecommerce.orders`
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;
```

### 3.2 Pilar 1: Auditoría de SLAs, Acantilado de Satisfacción y Descomposición First-Mile vs. Last-Mile (`02_sla_and_corridors_audit.sql`)
```sql
-- A. CONSULTA DEL ACANTILADO DE SATISFACCIÓN (SLA CLIFF)
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

-- B. AUDITORÍA DE CAUSA RAÍZ: SELLER LEAD TIME (FIRST-MILE) VS. CARRIER TRANSIT (LAST-MILE)
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
```

### 3.3 Pilar 2: Unit Economics y Fricción por Flete (`03_unit_economics_freight.sql`)
```sql
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
```

### 3.4 Pilar 3: Retención de Clientes y Ciclo de Recompra (`04_cohort_retention_lag.sql`)
```sql
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
```

---

## 4. Fase 4: Analizar (Analyze) — Tablas Certificadas de Hallazgos y Causa Raíz

### 4.1 Tabla del Acantilado de Satisfacción (*SLA Cliff*)
> **Nota Metodológica:** La clasificación utiliza la resolución exacta en horas (`DATETIME_DIFF(..., HOUR) / 24.0`), lo que permite aislar la ventana crítica de las primeras **72 horas (0.01 a 3.00 días)** frente al colapso reputacional que se inicia en el **4.° día (> 3.00 días)** sobre las $96,363$ reseñas vinculadas.

| Tramo de Entrega vs. SLA | Evaluaciones | % del Volumen | Calificación Promedio ($\star$) | % Detractores ($1\text{ y }2\ \star$) | % Promotores ($5\ \star$) | Diagnóstico de Experiencia de Cliente |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **1. A tiempo o antes ($\le\text{SLA}$)** | $88,653$ | $92.00\%$ | **$4.29\ \star$** | $9.23\%$ | $62.43\%$ | Estándar saludable de operación; impulsor de confianza. |
| **2. Retraso leve ($1\text{ a }3\text{ días}$)** | $2,665$ | $2.77\%$ | **$3.76\ \star$** | **$19.32\%$** | $43.08\%$ | **Ventana de gracia de 72 horas:** el cliente aún tolera la demora. |
| **3. Retraso moderado ($4\text{ a }7\text{ días}$)** | $1,790$ | $1.86\%$ | **$2.31\ \star$** | **$61.62\%$** | $17.82\%$ | **El Acantilado (*SLA Cliff*):** las quejas se triplican al cruzar el 4.° día. |
| **4. Retraso crítico ($>7\text{ días}$)** | $3,245$ | $3.37\%$ | **$1.73\ \star$** | **$78.34\%$** | $7.52\%$ | Destrucción total de marca y saturación de soporte. |

### 4.2 Auditoría de Causa Raíz en Corredores: First-Mile (Seller) vs. Last-Mile (Carrier)
¿Los retrasos en Río de Janeiro ocurren porque los vendedores de São Paulo tardan en despachar o porque el correo colapsa en la entrega final? La descomposición en SQL demuestra de forma contundente que **el $87.2\%$ del tiempo en los pedidos atrasados de `SP -> RJ` ($31.3\text{ días}$ de $35.9\text{ días}$ totales) ocurre en manos del transportista (*Last-Mile*)**:

| Corredor Logístico | Volumen Ítems / Órdenes | % Peso Nacional | Despacho Seller (General) | Tránsito Carrier (General) | Despacho Seller (En Atrasos) | Tránsito Carrier (En Atrasos) | % Tasa Retraso | Diagnóstico de Causa Raíz Operativa |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **`SP -> RJ` (Foco #1)** | $9,403$ | **$9.91\%$** | $3.1\text{ días}$ | $12.6\text{ días}$ | **$4.6\text{ días}$** | **$31.3\text{ días}$** | **$14.85\%$** | **Colapso Last-Mile ($87.2\%$ carrier):** bloqueo postal en RJ ($\sim\text{R\$ }197\text{k}$ GMV atrasado). |
| **`PR -> RJ`** | $1,115$ | $1.17\%$ | $3.1\text{ días}$ | $13.5\text{ días}$ | **$5.5\text{ días}$** | **$34.2\text{ días}$** | **$13.09\%$** | Confirma que el problema es el estado receptor (RJ) y no el origen. |
| **`SP -> BA`** | $2,626$ | $2.77\%$ | $2.9\text{ días}$ | $16.3\text{ días}$ | $3.5\text{ días}$ | $32.2\text{ días}$ | $14.78\%$ | Fricción de larga distancia hacia el Nordeste sin *hub* local. |
| **`SP -> CE`** | $1,091$ | $1.15\%$ | $2.9\text{ días}$ | $17.6\text{ días}$ | $3.8\text{ días}$ | $35.8\text{ días}$ | $15.40\%$ | Mayor demora de tránsito interestatal ($>20\text{ días}$ promedio). |
| **Envíos Mismo Estado** | $39,861$ | **$36.18\%$** | $2.8\text{ días}$ | $4.7\text{ días}$ | $6.1\text{ días}$ | $13.5\text{ días}$ | **$5.98\%$** | **Benchmark de eficiencia:** entrega total en $7.9\text{ días}$ ($94.02\%$ SLA). |

### 4.3 Tabla de Unit Economics y Hallazgo de Falla Algorítmica en Carritos Multi-Ítem
Al auditar a nivel de línea de ítem (`order_items`), se descubrió que en **$6,570$ órdenes con $2$ o más unidades idénticas del mismo vendedor**, el algoritmo de checkout cobró el **$100\%$ del costo de flete por cada unidad adicional ($0$ órdenes con descuento por consolidación)**. Como resultado, en Muebles y Bazar los carritos de $2+$ ítems sufren un ratio Flete/Precio aún más alto ($27.4\%\text{–}28.2\%$) que los de $1$ ítem ($21.8\%$):

| Categoría de Producto | Órdenes | Ítems / Orden | Facturación ($\text{R\$}$) | Costo Total Flete ($\text{R\$}$) | Ticket Promedio ($\text{R\$}$) | % Flete sobre Precio | Diagnóstico de Unit Economics (Umbral Crítico: $20\%$) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **`beleza_saude` (#1)** | $8,647$ | $1.09$ | $\text{R\$ }1,233,132$ | $\text{R\$ }178,958$ | $\text{R\$ }130.28$ | **$14.51\%$** | **Estrella de LTV:** Alta facturación, flete sano y producto consumible. |
| **`relogios_presentes` (#2)** | $5,493$ | $1.07$ | $\text{R\$ }1,165,899$ | $\text{R\$ }98,118$ | $\text{R\$ }199.06$ | **$8.42\%$** | **Líder en Densidad Económica:** Alto ticket y bajo peso volumétrico. |
| **`cama_mesa_banho` (#3)** | $9,272$ | $1.18$ | $\text{R\$ }1,023,435$ | $\text{R\$ }201,775$ | $\text{R\$ }93.44$ | $19.72\%$ | **Volumen en Alerta:** Mayor número de órdenes, en el límite del $20\%$. |
| **`moveis_decoracao` (#6)** | $6,307$ | $1.29$ | $\text{R\$ }711,928$ | $\text{R\$ }168,402$ | $\text{R\$ }87.25$ | **$23.65\%$** | **Erosión Severa ($>20\%$):** Cobro lineal de flete por unidad castiga el margen. |
| **`utilidades_domesticas` (#7)** | $5,743$ | $1.18$ | $\text{R\$ }615,629$ | $\text{R\$ }142,764$ | $\text{R\$ }90.60$ | **$23.19\%$** | **Erosión Severa ($>20\%$):** Requiere descuento de flete incremental en 2.ª unidad. |

### 4.4 Tabla de Cohortes de Retención, Bifurcación Temporal e Impacto del SLA en LTV
El cruce entre el cumplimiento logístico de la primera orden y la tasa de recompra demuestra que **sufrir un retraso en la primera compra reduce la probabilidad de recompra en un $-17.4\%$ relativo** (de $3.04\%$ en clientes entregados a tiempo a $2.51\%$ en clientes con atraso). Asimismo, al desglosar a los $2,801$ compradores recurrentes se identifican dos comportamientos distintos:

| Segmento de Fidelidad (`customer_unique_id`) | Clientes Únicos | % de la Base Total | Días Promedio hasta Recompra | Diagnóstico Estratégico de Crecimiento (Growth & CRM) |
| :--- | :---: | :---: | :---: | :--- |
| **1 Compra (One-Shot)** | **$90,549$** | **$97.00\%$** | N/A | **Fuga masiva de CAC:** El negocio financia adquisición paga sin retención orgánica. |
| **2 Compras (Promedio General)** | $2,573$ | $2.76\%$ | **$81.7\text{ días}$** | Incluye tanto carritos divididos en el checkout como recompras de ciclo de vida. |
| $\hookrightarrow$ *Sub-segmento: Split-Cart ($<24\text{h}$)* | *853* | *0.91%* | *$<1.0\text{ día}$* | *30.5% de los recurrentes son órdenes simultáneas divididas por el checkout en el mismo día.* |
| $\hookrightarrow$ *Sub-segmento: Ciclo Real ($\ge 24\text{h}$)* | *1,948* | *2.09%* | **$116.8\text{ días}$** | *69.5% son recompras genuinas con maduración trimestral ($65\text{ a }115\text{ días}$).* |
| **3+ Compras (Cliente Fiel)** | $228$ | $0.24\%$ | **$68.7\text{ días}$** | Aceleración del hábito una vez superada la barrera de la segunda compra. |

---

## 5. Fase 5 & 6: Share & Act — Plan Estratégico de Reingeniería y Matriz A/B (90 Días)

### 5.1 Profundización en las 3 Iniciativas Ejecutivas (¿Qué hacer, cómo ejecutarlo y cuánto rinde?)

#### 1. Iniciativa 1 (Logística y SLA): "Operación Desbloqueo RJ" + Gatillo Preventivo a las 72 Horas
* **Justificación Analítica:** El atraso en `SP -> RJ` ($14.85\%$) y `PR -> RJ` ($13.09\%$) es un fallo de última milla del correo estatal ($31.3\text{ días}$ de tránsito del *carrier* en pedidos atrasados vs. $4.6\text{ días}$ del *seller*). Además, existe una ventana de gracia de 72 horas ($3.76\ \star$) antes de que los detractores salten del $19.3\%$ al $61.6\%$ en el 4.° día.
* **Mecánica de Ejecución en 3 Niveles:**
  1. **Bypass Postal y Red PUDO en Río de Janeiro:** Integrar en el motor de checkout una regla de enrutamiento por código postal (CEP). Para los CEPs de RJ catalogados como *áreas de restricción domiciliaria*, deshabilitar Correios estándar y asignar automáticamente *carriers* privados con flota dedicada (Jadlog / Sequoia) o desplegar la opción **"Retiro Seguro en Locker / Punto PUDO con 15% de descuento en flete"**.
  2. **Gatillo Automatizado a las 72 Horas (`SLA Breach T+24h`):** Configurar un webhook en BigQuery/CRM que detecte toda orden sin confirmación de entrega a las 24 horas de vencido su `order_estimated_delivery_date`. Antes de que cruce el 4.° día, disparar un mensaje proactivo por WhatsApp/Email pidiendo disculpas, entregando un enlace de rastreo prioritario y otorgando un **cupón de contención de $\text{R\$ }15$** para amortiguar la frustración.
  3. **Scorecard Algorítmico de Sellers (Cut-off 48h):** Penalizar en visibilidad del *Buy Box* a los vendedores que excedan $48\text{ horas}$ en despachar (`dias_despacho_seller > 2.0`) o superen el $2\%$ de cancelaciones por quiebre de stock (`unavailable`), atacando los $\sim\text{R\$ }197,000$ de GMV perdido en $1,234$ órdenes fallidas.
* **Impacto Financiero Anual:** Protección directa de **$\sim\text{R\$ }680,000$ en GMV** expuesto a reseñas de $1\star\text{–}2\star$ en el corredor Sudeste y reducción del **$40\%$ en el costo de tickets de soporte (`WISMO` - *Where Is My Order*)**.

#### 2. Iniciativa 2 (Unit Economics): Regla de Flete Incremental (*Same-Seller Bundling* $>\text{R\$ }150$) + Geo-Priorización
* **Justificación Analítica:** En `moveis_decoracao` ($\text{R\$ }87.25$; $23.65\%$ flete) y `utilidades_domesticas` ($\text{R\$ }90.60$; $23.19\%$ flete), el comprador que agrega una segunda unidad del mismo vendedor recibe un cobro del $100\%$ del flete adicional ($6,570$ casos comprobados), elevando el peso del envío al $27.4\%$ y destruyendo la conversión.
* **Mecánica de Ejecución en 3 Niveles:**
  1. **Reingeniería del Motor de Tarifas (*Same-Seller Bundling*):** Reprogramar la regla de cálculo de envío en Muebles, Bazar y Cama/Mesa: cuando el comprador agrega una **2.ª unidad del mismo `seller_id` y supera los $\text{R\$ }150$ de carrito**, aplicar un **descuento del $50\%$ sobre el flete incremental** de las unidades adicionales (cofinanciado $25\%$ por ahorro de consolidación en una sola guía física y $25\%$ por el *seller*). Al pasar de $1$ ítem ($\text{R\$ }87$ producto / $\text{R\$ }20.6$ flete = $23.6\%$) a $2$ ítems consolidados ($\text{R\$ }174.5$ producto / $\text{R\$ }25.8$ flete), **el peso del flete cae del $23.65\%$ al $14.78\%$**, situándose bajo el umbral saludable del $15\%$.
  2. **Barra de Progreso Interactiva en Checkout:** Desplegar en el carrito lateral para órdenes de $1$ ítem: *"Agrega $\text{R\$ }60$ más de este vendedor y desbloquea 50% OFF en el envío adicional"*, mostrando carruseles de productos complementarios del mismo almacén.
  3. **Geo-Priorización en el Algoritmo de Búsqueda:** Para productos con peso volumétrico $>5\text{ kg}$, ponderar en el Top 3 del ranking de búsqueda a los vendedores ubicados en el **mismo estado (`seller_state = customer_state`)**, aprovechando que el envío local cuesta $38\%$ menos y cumple el $94.02\%$ del SLA en $7.9\text{ días}$.
* **Impacto Financiero Anual:** Generación de **$+\text{R\$ }310,000$ en GMV incremental neto** al elevar la densidad de $1.18\text{–}1.29$ a $\ge 1.45\text{ ítems/orden}$ sin erosionar el *take-rate* de Olist.

#### 3. Iniciativa 3 (Retención y LTV): Motor de Reposición "Día 65" en `beleza_saude` + Captura Física In-Box
* **Justificación Analítica:** Invertir presupuesto de remarketing en toda la base o a los 15 días de la compra fracasa porque: (a) los clientes que sufrieron retrasos tienen $-17.4\%$ menos propensión a recomprar, (b) categorías duraderas (Muebles/Informática) no tienen reposición corta, y (c) el ciclo natural de recompra ocurre entre los **$81.7\text{ y }116.8\text{ días}$**.
* **Mecánica de Ejecución en 3 Niveles:**
  1. **Filtro de Elegibilidad por Calidad Logística:** Restringir las campañas de retención exclusivamente a compradores cuya primera orden fue entregada **A Tiempo (`cumple_sla = 1`, calificación media $4.29\ \star$)**, garantizando que el incentivo impacte sobre promotores de marca.
  2. **Automatización de Reposición en el "Día 65":** Focalizar el flujo en la categoría #1 en facturación, **`beleza_saude` ($\text{R\$ }1.23\text{M}$; $8,647$ órdenes; flete sano del $14.51\%$)** junto con `perfumaria` y `bebes`. Disparar una secuencia personalizada por Email/WhatsApp en el **día 65 post-entrega** (anticipando en 15 días la ventana natural de agotamiento del producto del día 81.7) con un botón de *"Recompra en 1-Click con Envío Gratis sobre tu mismo producto"*.
  3. **Tarjeta Física con Código QR In-Box (*First-Party Data*):** Incluir dentro del empaque físico de los *sellers* Top de Belleza y Salud un inserto con código QR (*"Escanea y activa $\text{R\$ }15$ para tu próxima reposición en la App"*), convirtiendo el tráfico prestado de marketplaces 3P en base propia con **$\text{CAC} = \text{R\$ }0$**.
* **Impacto Financiero Anual:** Incremento de la tasa de recompra en la cohorte objetivo del **$3.00\%$ al $\ge 7.50\%$ ($2.5\times$)**, generando **$+\text{R\$ }240,000$ en GMV recurrente anual** libre de costo de adquisición.

---

### 5.2 Matriz de Gobernanza Experimental A/B (8 Semanas)
| Iniciativa Estratégica | Grupo Control vs. Tratamiento | Muestra Objetivo | KPI Primario de Éxito | Métrica Guarda-Riel (Guardrail) | Impacto Anual Proyectado |
| :--- | :--- | :---: | :--- | :--- | :---: |
| **1. Operación Desbloqueo RJ + Gatillo 72h** | **Control (50%):** Flujo Correios estándar sin alerta temprana.<br>**Tratamiento (50%):** Enrutamiento PUDO/Carrier privado en RJ + Alerta WhatsApp a las 24h de retraso. | $1,600$ órdenes en eje `SP/PR/SC -> RJ` | Reducir atraso en RJ del $14.85\%$ a $<8.0\%$ y bajar detractores ($>4\text{d}$) del $61.6\%$ a $<35.0\%$. | Variación del costo logístico unitario ($\le +3\%$) y conversión en checkout de RJ. | **$\sim\text{R\$ }680,000$** en GMV protegido y $-40\%$ en reclamos. |
| **2. Flete Incremental ($>\text{R\$ }150$) + Geo-Local** | **Control (50%):** Cobro lineal del $100\%$ de flete por unidad.<br>**Tratamiento (50%):** $50\%$ OFF en flete desde la 2.ª unidad del mismo *seller* ($>\text{R\$ }150$) + Barra en checkout. | $15,000$ sesiones en `moveis_decoracao` y `utilidades` | Comprimir ratio Flete/Precio del $23.6\%$ a $<16.5\%$ y elevar densidad a $\ge 1.45\text{ ítems/orden}$. | *Take-rate* neto de comisión de Olist y conversión en órdenes de 1 solo ítem. | **$+\text{R\$ }310,000$** en GMV incremental por mayor AOV. |
| **3. Motor LTV Día 65 (`beleza_saude`)** | **Control / Holdout (20%):** Sin contacto post-venta.<br>**Tratamiento (80%):** Disparo CRM en Día 65 a clientes entregados *On-Time* + QR In-Box. | $1,400$ clientes únicos de `beleza_saude` | Elevar tasa de recompra a 90 días del $3.00\%$ base al $\ge 7.50\%$ ($2.5\times$). | Margen neto post-subsidio ($\ge 12\%$) y tasa de baja de comunicaciones ($<0.5\%$). | **$+\text{R\$ }240,000$** en GMV recurrente con $\text{CAC} = \text{R\$ }0$. |
