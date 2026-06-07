"""Generate the sample CSV dataset for the DuckDB exploration.

Produces a small, realistic e-commerce dataset split the way real exports
often arrive: orders in one file per month, plus a customers file and a
products file you have to join back in.

Design choices that matter:
  - Revenue lives on the ORDER row (quantity x unit_price). The unit_price is
    captured at sale time, so a single monthly orders file is enough to answer
    "top products by revenue this month" without joining anything. That keeps
    the first query a true single-file query.
  - products.csv intentionally has NO price column. Price belongs to the order
    (what the customer actually paid), not the catalog. Region and category
    only become available once you join customers and products back in.

Deterministic: seeded so the committed CSVs are reproducible. Re-running
regenerates byte-identical files.

Uses only the Python standard library, so there is no `pip install` step.

Usage:
    python3 scripts/generate_data.py
"""

import csv
import random
from pathlib import Path

SEED = 42
MONTHS = range(1, 7)            # 2026-01 .. 2026-06
# ~150k orders per month, ~900k total. Big enough that the same questions get
# slow and clunky in Excel and pandas, while DuckDB still answers instantly.
ORDERS_PER_MONTH = 150_000
N_CUSTOMERS = 50
DATA_DIR = Path(__file__).resolve().parent.parent / "data"

REGIONS = ["West", "East", "South", "Midwest"]

# 20 products: (name, category, base_price). Price is the catalog reference;
# the actual order line price varies slightly around it (promotions, etc.).
PRODUCTS = [
    ("Wireless Earbuds", "Electronics", 89.99),
    ("Bluetooth Speaker", "Electronics", 54.50),
    ("USB-C Charger", "Electronics", 24.99),
    ("Mechanical Keyboard", "Electronics", 119.00),
    ("4K Webcam", "Electronics", 79.99),
    ("Ceramic Mug Set", "Home", 32.00),
    ("Linen Throw Blanket", "Home", 48.75),
    ("Cast Iron Skillet", "Home", 39.99),
    ("Scented Candle Trio", "Home", 27.50),
    ("Bamboo Cutting Board", "Home", 22.00),
    ("Cotton T-Shirt", "Apparel", 18.99),
    ("Merino Wool Socks", "Apparel", 14.50),
    ("Denim Jacket", "Apparel", 78.00),
    ("Running Shorts", "Apparel", 29.99),
    ("Knit Beanie", "Apparel", 16.00),
    ("Insulated Water Bottle", "Outdoors", 34.99),
    ("Trekking Poles", "Outdoors", 64.00),
    ("Headlamp", "Outdoors", 28.50),
    ("Packable Rain Jacket", "Outdoors", 92.00),
    ("Camping Hammock", "Outdoors", 45.99),
]

MONTH_DAYS = {1: 31, 2: 28, 3: 31, 4: 30, 5: 31, 6: 30}


def write_csv(path, header, rows):
    # newline="" + lineterminator="\n" forces LF endings so regenerated files
    # byte-match what git stores (which normalizes to LF), keeping the generator
    # genuinely deterministic across platforms.
    with open(path, "w", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(header)
        w.writerows(rows)


def main():
    rng = random.Random(SEED)
    DATA_DIR.mkdir(exist_ok=True)

    # customers.csv — who and where (region only joins in here)
    customers = [
        [cid, f"Customer {cid:03d}", rng.choice(REGIONS)]
        for cid in range(1, N_CUSTOMERS + 1)
    ]
    write_csv(DATA_DIR / "customers.csv",
              ["customer_id", "customer_name", "region"], customers)

    # products.csv — name and category, no price (price lives on the order)
    products = [
        [pid, name, category]
        for pid, (name, category, _base) in enumerate(PRODUCTS, start=1)
    ]
    write_csv(DATA_DIR / "products.csv",
              ["product_id", "product_name", "category"], products)

    # orders_2026_MM.csv — one file per month
    base_price = {pid: base for pid, (_n, _c, base) in enumerate(PRODUCTS, start=1)}
    for m in MONTHS:
        rows = []
        for seq in range(1, ORDERS_PER_MONTH + 1):
            pid = rng.randint(1, len(PRODUCTS))
            # order-line price drifts +/-10% around catalog price
            unit_price = round(base_price[pid] * rng.uniform(0.90, 1.10), 2)
            rows.append([
                f"ORD-{m:02d}-{seq:06d}",                 # order_id (text, keeps its shape)
                f"2026-{m:02d}-{rng.randint(1, MONTH_DAYS[m]):02d}",  # order_date
                rng.randint(1, N_CUSTOMERS),              # customer_id
                pid,                                      # product_id
                rng.randint(1, 5),                        # quantity
                unit_price,                               # unit_price (at sale)
            ])
        write_csv(
            DATA_DIR / f"orders_2026_{m:02d}.csv",
            ["order_id", "order_date", "customer_id", "product_id", "quantity", "unit_price"],
            rows,
        )

    total = ORDERS_PER_MONTH * len(list(MONTHS))
    print(f"Wrote {N_CUSTOMERS} customers, {len(PRODUCTS)} products, "
          f"{total} orders across {len(list(MONTHS))} monthly files -> {DATA_DIR}")


if __name__ == "__main__":
    main()
