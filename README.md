# Sales Report Test Task
Проект формирует месячный отчет по продажам на основе данных из Excel и SQLite.

## Предложения и вопросы
- Что означает is_buffer_row? Предположу, что это технические строки, которые не должны учитываться в отчёте. Поэтому добавлю фильтр is_buffer_row = FALSE.
- Очевидно, что return_flg - это флаг возврата. Исходя из таблицы sales, можно увидеть следующую закономерность: если return _flg = true, то quantity становится отрицательным. Это говорит о том, что система учитывает возврат как сторнирующую проводку, что позволяет использовать простую суммарную агрегацию для получения любых нетто-показателей.
- Как считать «новый товар для магазина»? Нужно для каждой пары (shop_id, product_id) найти минимальную дату продажи (без учёта возвратов и технических строк). Если эта минимальная дата попадает в отчётный месяц – товар считается новым в этом месяце. Это требует анализа всей истории продаж до текущего месяца.
- Как учитывать скидку PROMO10? Умножаем price на 0.9, если promocode = 'PROMO10'. Сравниваем полученную цену продажи с cost_price.
- Нужно ли учитывать промокоды в будущем? (PROMO15). В текущем состояниии только ‘PROMO10’. В идеале сделать поле с процентом скидки, либо добавить таблицу промо.

## Структура таблицы для отчета
1. shop_id (INTEGER) - Идентификатор магазина
2. report_month (TEXT) - Месяц отчета
3. total_sales_amount (REAL) - Нетто-выручка за месяц по магазину:
    SUM(actual_unit_price * quantity)
    где actual_unit_price = price * 0.9 при promocode = 'PROMO10', иначе price.
    Возвраты учитываются отрицательно через quantity < 0.
4. total_quantity_sold (INTEGER) - Нетто-количество: SUM(quantity) с учётом возвратов.
5. unique_products_sold_cnt (INTEGER) - Количество уникальных товаров, которые имели положительную продажу в месяце:
    COUNT(DISTINCT product_id) только для quantity > 0.
6. new_products_cnt (INTEGER) - Количество уникальных товаров, впервые проданных в этом магазине именно в этом месяце.
“Впервые” определяется по минимальной дате продажи (quantity > 0) для пары (shop_id, product_id) за всю историю.
7. sales_below_cost_cnt (INTEGER) - Количество операций, где actual_unit_price < cost_price и quantity != 0.
Дополнительно: строки с is_buffer_row = 1 исключаются из всех расчётов.


## Что в проекте
- `migrate_from_excel.py` — миграция данных из Excel в `sales.db`.
- `monthly_sales_report.sql` — финальный SQL-отчет (CTE, SQLite).
- `sales.db` — база SQLite.

## Быстрый запуск проверки

### 1) Установить зависимости

```bash
python -m pip install pandas openpyxl
```

### 2) Положить Excel-файл в корень проекта

Требования к Excel:
- лист `sales` с колонками:
  `shop_id, date, product_id, quantity, price, cost_price, return_flg, promocode, is_buffer_row`
- лист `products` с колонками:
  `product_id, category, name`

### 3) Выполнить миграцию в SQLite

```bash
python migrate_from_excel.py
```

Ожидаемый результат: сообщение `Migration completed successfully.`

### 4) Выполнить отчетный SQL

Откройте `sales.db` в SQLite-расширении VS Code или в любом SQLite-клиенте и запустите:
- `monthly_sales_report.sql`

## Критерии корректности

- Технические строки (`is_buffer_row = 1`) не попадают в расчет.
- Возвраты не удаляются, а учитываются знаком `quantity`.
- `PROMO10` снижает цену на 10%.
- `new_products_cnt` считается по первой положительной продаже товара в магазине.
- Метрики below-cost считаются только для строк `actual_unit_price < cost_price` и `quantity != 0`.
