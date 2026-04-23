import sqlite3
from pathlib import Path

import pandas as pd


# Берем самый свежий Excel-файл в текущей папке (кроме временных ~$...).
excel_file = sorted(
    [p for p in Path(".").glob("*.xlsx") if not p.name.startswith("~$")],
    key=lambda p: p.stat().st_mtime,
    reverse=True,
)[0]

# Читаем листы из Excel.
sales_df = pd.read_excel(excel_file, sheet_name="sales")
products_df = pd.read_excel(excel_file, sheet_name="products")

# Приводим названия колонок к нижнему регистру.
sales_df.columns = [c.strip().lower() for c in sales_df.columns]
products_df.columns = [c.strip().lower() for c in products_df.columns]

# Оставляем только нужные поля.
sales_df = sales_df[
    [
        "shop_id",
        "date",
        "product_id",
        "quantity",
        "price",
        "cost_price",
        "return_flg",
        "promocode",
        "is_buffer_row",
    ]
].copy()
products_df = products_df[["product_id", "category", "name"]].copy()

# Минимальная нормализация значений.
sales_df["date"] = pd.to_datetime(sales_df["date"]).dt.strftime("%Y-%m-%d")
sales_df["return_flg"] = sales_df["return_flg"].fillna(0).astype(int)
sales_df["is_buffer_row"] = sales_df["is_buffer_row"].fillna(0).astype(int)
sales_df["promocode"] = sales_df["promocode"].fillna("")

# Пересоздаем таблицы и загружаем данные.
con = sqlite3.connect("sales.db")
cur = con.cursor()

cur.execute("PRAGMA foreign_keys = OFF")
cur.execute("DROP TABLE IF EXISTS sales")
cur.execute("DROP TABLE IF EXISTS products")
cur.execute('DROP TABLE IF EXISTS " products"')

cur.execute(
    """
    CREATE TABLE products (
        product_id INTEGER PRIMARY KEY,
        category TEXT,
        name TEXT
    )
    """
)

cur.execute(
    """
    CREATE TABLE sales (
        shop_id INTEGER,
        date TEXT,
        product_id INTEGER,
        quantity INTEGER,
        price REAL,
        cost_price REAL,
        return_flg INTEGER,
        promocode TEXT,
        is_buffer_row INTEGER,
        FOREIGN KEY (product_id) REFERENCES products(product_id)
    )
    """
)

products_df.to_sql("products", con, if_exists="append", index=False)
sales_df.to_sql("sales", con, if_exists="append", index=False)
con.commit()
con.close()

print("Migration completed successfully.")
