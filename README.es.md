# 🛒 Auditoría Operativa y Financiera E-Commerce: Caso Olist
![BigQuery](https://img.shields.io/badge/Google_BigQuery-Cloud_SQL-4285F4?logo=google-cloud&logoColor=white)
![Tableau](https://img.shields.io/badge/Tableau-Public-E97627?logo=tableau&logoColor=white)
![Status](https://img.shields.io/badge/Status-Completed-success)

Auditoría Operativa y Financiera sobre 96,470 Ventas Reales: Diagnóstico de Cuellos de Botella Logísticos, Fricción de Flete y Retención

## 1. Resumen Ejecutivo (Answer-First)

Para proteger el margen de contribución y escalar el volumen de ventas sin depender exclusivamente del gasto continuo en publicidad (CAC), la operación de Olist debe ejecutar una reingeniería quirúrgica en tres frentes: **desacoplar la última milla en Río de Janeiro del servicio postal estatal, corregir la distorsión tarifaria de flete en compras multi-ítem de categorías pesadas (>23% de envío) y activar un motor de retención en el ciclo natural de reposición (65 a 85 días)**.

Este análisis demuestra que el crecimiento en ventas brutas ocultaba pérdidas críticas de satisfacción y margen, y propone un plan de acción respaldado por pruebas A/B con un **impacto anual proyectado de R$ 1,230,000 en valor de negocio** (~R$ 680k en GMV protegido de quejas severas y R$ 550k en ventas incrementales sin CAC).

## 2. El Problema (Ask)

El equipo directivo y de operaciones de Olist identificó que, a pesar del aumento en órdenes, el marketplace enfrentaba tres dolores estructurales:
* **Incumplimiento logístico:** Frecuentes reclamos y quejas de clientes en corredores interestatales clave.
* **Fricción tarifaria por flete:** Categorías voluminosas donde el costo de envío supera una cuarta parte del valor del producto, elevando el abandono en el checkout.
* **Nula retención orgánica:** Dependencia casi total de captar clientes nuevos de una sola compra.

El objetivo comercial de este proyecto fue auditar la base de datos relacional en Google BigQuery para encontrar las causas raíz de estas fugas y diseñar un plan de intervenciones medibles.

## 3. Datos y Limpieza (Prepare & Process)

Se auditó el ecosistema relacional de Olist compuesto por 7 tablas interconectadas (`orders`, `order_items`, `order_payments`, `order_reviews`, `customers`, `products` y `sellers`).

* **Herramientas:** Google BigQuery (SQL Avanzado: Joins relacionales, CTEs, Window Functions `ROW_NUMBER`, `LAG`, `RANK`, Vistas) para el modelado y auditoría; Tableau Public para la visualización ejecutiva.
* **Volumen:** Se procesaron 99,441 órdenes brutas. Para evitar promedios engañosos y errores de cálculo, se aplicó una depuración estricta eliminando 1,107 pedidos en tránsito, 625 cancelados, 8 entregas con fechas nulas y 609 órdenes sin stock (~R$ 97k de GMV perdido por inventario fantasma).
* **Población Certificada:** Se consolidó la vista maestra `vw_orders_clean` con **96,470 ventas entregadas completas** y **93,350 clientes únicos**.

## 4. Análisis y Hallazgos Clave (Analyze)

El análisis cuantitativo sobre la base certificada reveló tres realidades contraintuitivas que explican el deterioro de la experiencia y la rentabilidad:

* **El "Acantilado del 4.° Día" (SLA Cliff):** El cliente tolera entre 1 y 3 días de atraso respecto a la fecha prometida (manteniendo 3.76 ★ de calificación y solo 19.3% de quejas). Sin embargo, **al cruzar el 4.° día de demora, la satisfacción colapsa a 2.31 ★ y los clientes detractores se triplican al 61.6%**, alcanzando un 78.3% pasados los 7 días.
* **Causa Raíz en Río de Janeiro (Falla de Última Milla, no del Vendedor):** La ruta São Paulo → Río de Janeiro (`SP -> RJ`) concentra casi el 10% del volumen nacional (9,403 pedidos) y sufre un 14.85% de retraso con 12.6 días de demora promedio. Al descomponer los tiempos en SQL, se demostró que el vendedor despacha en solo 4.6 días, pero **el transportista demora 31.3 días en las entregas atrasadas (el 87.2% del tiempo se pierde en la última milla postal de Río)**.
* **Falla Algorítmica en Carritos Multi-Ítem (>23% Flete):** En categorías pesadas como Muebles (`moveis_decoracao`: 23.65% de flete) y Bazar (`utilidades_domesticas`: 23.19%), el sistema cobraba el 100% del flete por cada unidad adicional sin descuento por consolidación de paquete (detectado en 6,570 órdenes), encareciendo el flete al 27.4% en compras de 2+ unidades y castigando el ticket promedio.
* **Ciclo de Recompra Tardío (81.7 Días) y Castigo por Atraso:** El 97.0% de los clientes compra una sola vez. Al analizar a los 2,801 compradores que repitieron pedido mediante `LAG()`, se descubrió que el ciclo de maduración real toma entre **81.7 y 116.8 días** (no ocurre en los primeros 15 días). Además, sufrir un atraso en la primera entrega reduce la probabilidad de recompra en un -17.4% relativo.

## 5. Visualización (Share)

Los hallazgos se estructuraron en un tablero ejecutivo interactivo de tres vistas para monitoreo directivo: Ranking de Corredores Logísticos, Curva Dual del Acantilado de Satisfacción y Matriz de Unit Economics por Categoría.

* **Dashboard en Tableau Public:** [Ver Tablero Interactivo Olist E-Commerce en Tableau Public](https://public.tableau.com/views/Brazil_ecomercce/Dashboard1?:language=es-ES&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)

## 6. Recomendaciones Estratégicas (Act)

Para revertir estas fugas operativas y financieras, se diseñaron tres iniciativas respaldadas por una matriz de experimentación A/B de 8 semanas:

* **Operación Desbloqueo RJ + Gatillo Preventivo a las 72h:** En los códigos postales críticos de Río de Janeiro, desviar el envío desde el correo estándar hacia transportistas privados y ofrecer 15% de descuento en flete por retiro en Puntos Seguros / Lockers (PUDO). Además, activar una alerta automática por WhatsApp a las 24 horas de retraso con tracking prioritario y cupón de compensación antes de que el cliente cruce el umbral del 4.° día (meta: proteger ~R$ 680k en GMV).
* **Flete Incremental en Carrito (> R$ 150) y Geo-Priorización:** Modificar la regla de checkout en categorías del hogar para bonificar el 50% del flete a partir de la segunda unidad del mismo vendedor en compras superiores a R$ 150 (comprimiendo el costo de envío del 23.6% al ~14.8%). A la vez, priorizar en el buscador a vendedores del mismo estado para bultos >5 kg, aprovechando que el envío local cumple el 94% del SLA en solo 7.9 días (meta: +R$ 310k en GMV incremental).
* **Motor de Recompra "Día 65" en Belleza y Salud + QR In-Box:** Filtrar a clientes que recibieron su pedido a tiempo (4.29 ★) y disparar un flujo automatizado de reposición entre los días 65 y 75 post-entrega en Belleza y Salud (la categoría #1 en ventas con R$ 1.23M y reposición natural de 60 a 90 días). Complementarlo con un código QR físico en el paquete para capturar al cliente en la app de Olist sin pagar publicidad (meta: elevar la recompra del 3.0% al 7.5%, sumando +R$ 240k en GMV con CAC = R$ 0).

## 7. Entregables y Estructura del Repositorio

El repositorio se encuentra estructurado en carpetas modulares para facilitar su navegación y reproducibilidad:

```text
├── deliverables/
│   ├── Olist_Presentacion_Ejecutiva_Final.pptx    # Deck ejecutivo de 13 slides con notas del orador
│   ├── Olist_Log_Auditoria_Metodologica.docx      # Bitácora detallada de decisiones y reglas de negocio
│   └── Olist_Caso_Estudio_Completo.md             # Documentación exhaustiva con tablas maestras
├── sql/
│   ├── 01_vw_orders_clean.sql                     # Vista maestra certificada en BigQuery
│   ├── 02_sla_cliff_and_last_mile_audit.sql       # Desglose First-Mile vs. Last-Mile y SLA Cliff
│   ├── 03_unit_economics_and_multi_item_freight.sql# Análisis de flete multi-unidad por categoría
│   └── 04_cohort_retention_and_sla_impact.sql     # Análisis de cohortes con ROW_NUMBER y LAG
├── data/
│   ├── 01_corredores_logisticos_bigquery.csv      # Extracto de métricas por corredor logístico
│   ├── 02_unit_economics_categorias_bigquery.csv  # Extracto de ingresos y ratio de flete
│   └── 03_sla_cliff_satisfaccion_bigquery.csv     # Extracto de tramos de SLA y reseñas
├── assets/
│   ├── tableau_dashboard.png                      # Captura del tablero en Tableau Public
│   └── sla_cliff_chart.png                        # Curva del Acantilado de Satisfacción
└── README.md
```

* **Presentación Ejecutiva:** [Ver Presentación Ejecutiva en `/deliverables`](./deliverables/Olist_Presentacion_Ejecutiva_Final.pptx)
* **Scripts SQL:** [Consultas SQL en `/sql`](./sql/)
* **Datos Procesados:** [Extractos de BigQuery en `/data`](./data/)
