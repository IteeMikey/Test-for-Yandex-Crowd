-- Отчет по продажам в разрезе магазина и месяца (SQLite).
-- report_month = первое число месяца.

WITH
-- 1) Подготовка данных продаж:
--    - исключаем технические строки (is_buffer_row = 1),
--    - рассчитываем фактическую цену с учетом промокода PROMO10,
--    - приводим дату и месяц отчета к формату SQLite date().
sales_base AS (
  SELECT
    s.shop_id,
    date(s.date) AS sale_date,
    date(s.date, 'start of month') AS report_month,
    s.product_id,
    s.quantity,
    s.cost_price,
    CASE
      WHEN s.promocode = 'PROMO10' THEN s.price * 0.9
      ELSE s.price
    END AS actual_unit_price
  FROM sales s
  WHERE COALESCE(s.is_buffer_row, 0) = 0
),

-- 2) Для каждой пары (shop_id, product_id) определяем первую
--    "реальную продажу" за всю историю (только quantity > 0).
first_positive_sale AS (
  SELECT
    shop_id,
    product_id,
    MIN(sale_date) AS first_sale_date,
    date(MIN(sale_date), 'start of month') AS first_sale_month
  FROM sales_base
  WHERE quantity > 0
  GROUP BY shop_id, product_id
),

-- 3) Уникальные товары, которые имели положительные продажи
--    в конкретном месяце и магазине.
positive_products_by_month AS (
  SELECT DISTINCT
    shop_id,
    report_month,
    product_id
  FROM sales_base
  WHERE quantity > 0
),

-- 4) new_products_cnt:
--    считаем товары, у которых месяц первой продажи
--    совпадает с рассматриваемым месяцем.
new_products_by_month AS (
  SELECT
    p.shop_id,
    p.report_month,
    COUNT(DISTINCT p.product_id) AS new_products_cnt
  FROM positive_products_by_month p
  JOIN first_positive_sale f
    ON f.shop_id = p.shop_id
   AND f.product_id = p.product_id
   AND f.first_sale_month = p.report_month
  GROUP BY p.shop_id, p.report_month
),

-- 5) Основная агрегация по магазину и месяцу:
--    total_sales_amount         = SUM(actual_unit_price * quantity)
--    total_quantity_sold        = SUM(quantity)
--    unique_products_sold_cnt   = число уникальных товаров с quantity > 0
--    sales_below_cost_cnt       = число операций с actual_unit_price < cost_price и quantity != 0
--    sales_below_cost_amount    = нетто-выручка таких операций
monthly_agg AS (
  SELECT
    shop_id,
    report_month,
    SUM(actual_unit_price * quantity) AS total_sales_amount,
    SUM(quantity) AS total_quantity_sold,
    COUNT(DISTINCT CASE WHEN quantity > 0 THEN product_id END) AS unique_products_sold_cnt,
    SUM(CASE WHEN actual_unit_price < cost_price AND quantity <> 0 THEN 1 ELSE 0 END) AS sales_below_cost_cnt,
    SUM(CASE WHEN actual_unit_price < cost_price AND quantity <> 0 THEN actual_unit_price * quantity ELSE 0 END)
      AS sales_below_cost_amount
  FROM sales_base
  GROUP BY shop_id, report_month
)

-- 6) Финальная выдача:
--    - соединяем основные метрики с количеством новых товаров;
--    - COALESCE для new_products_cnt, чтобы в отсутствии совпадений был 0.
SELECT
  m.shop_id,
  m.report_month,
  m.total_sales_amount,
  m.total_quantity_sold,
  m.unique_products_sold_cnt,
  COALESCE(n.new_products_cnt, 0) AS new_products_cnt,
  m.sales_below_cost_cnt,
  m.sales_below_cost_amount
FROM monthly_agg m
LEFT JOIN new_products_by_month n
  ON n.shop_id = m.shop_id
 AND n.report_month = m.report_month
ORDER BY m.shop_id, m.report_month;