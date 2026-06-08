# Claude Code + DuckDB: Analyze Any CSV on Your Laptop

Query a folder of CSV files in plain English, with no warehouse to set up and no
database to connect to. You ask the question, an AI agent writes the DuckDB SQL,
and you read every line so you actually trust the answer.

This repo is the companion to the video on the
[Kyle Chalmers Data Plus AI](https://www.youtube.com/@kylechalmersdataai) channel.
It ships a realistic e-commerce dataset (900,000 orders split across six monthly
files, plus customers and products) so you can follow along on your own machine.

![How it works: your laptop holds the data files, Claude Code writes the SQL, DuckDB runs it locally, and only the model call goes to the cloud](./images/diagram.png)

## Why this exists

You have a pile of CSV files. A few hundred thousand rows each, the kind of size
that turns Excel sluggish and makes pandas feel slow, and you just want to ask a
question. The usual reflex is to stand up a cloud warehouse, which means an
account, a login, and a bill you did not want.

DuckDB removes that step. It is an in-process analytical database (think SQLite,
but built for analytics) that queries CSV, Parquet, and JSON files directly on
your machine. There is no server to run and nothing to connect to. The file is
the table.

Pair it with Claude Code and you describe what you want in plain English. The
agent writes the SQL, runs it, and shows you both the query and the result. You
stay in control by reading the SQL, not by memorizing DuckDB's dialect first.

## Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| [Claude Code](https://claude.com/claude-code) | current | Writes and runs the SQL from plain-English prompts |
| [`duckdb-skills` plugin](https://github.com/duckdb/duckdb-skills) | current | Official Claude Code plugin for DuckDB. The recommended way in, and it can install the DuckDB CLI for you |
| [DuckDB CLI](https://duckdb.org) | 1.5.x | Runs the SQL locally against the CSV files. The plugin installs this if you do not have it |
| Python 3 | 3.9+ | Only needed if you want to regenerate the sample data |

The quickest setup is the official `duckdb-skills` plugin. Inside Claude Code:

```text
/plugin marketplace add duckdb/duckdb-skills
/plugin install duckdb-skills@duckdb-skills
```

If you do not have the DuckDB CLI yet, the plugin offers to install it for you
(`/duckdb-skills:install-duckdb`), so that is the whole setup.

Prefer to do it by hand? The plugin is a convenience wrapper over the DuckDB CLI,
so you can skip it entirely: install the CLI yourself (`brew install duckdb` on a
Mac, or see [duckdb.org/docs/installation](https://duckdb.org/docs/installation)
for Linux and Windows) and run the `duckdb` commands directly. Either way, you
read the same SQL. That is the whole point.

## Setup

```bash
git clone https://github.com/kyle-chalmers/claude-code-duckdb.git
cd claude-code-duckdb

# the data/ folder is already committed, so you can query immediately:
duckdb -c "SELECT * FROM 'data/orders_2026_01.csv' LIMIT 5;"
```

Quick health check on a fresh clone (you should see 900000, 50, 20):

```bash
duckdb -c "SELECT (SELECT COUNT(*) FROM 'data/orders_*.csv') AS orders,
                  (SELECT COUNT(*) FROM 'data/customers.csv') AS customers,
                  (SELECT COUNT(*) FROM 'data/products.csv') AS products;"
```

To regenerate the dataset from scratch (deterministic, seeded, standard library
only, no `pip install`):

```bash
python3 scripts/generate_data.py
```

## The data

Everything lives in `data/`. The files are split the way real exports often
arrive: one orders file per month, with customer and product details in separate
files you join back in.

| File | Columns | Notes |
|---|---|---|
| `orders_2026_01.csv` … `orders_2026_06.csv` | `order_id`, `order_date`, `customer_id`, `product_id`, `quantity`, `unit_price` | One file per month, January through June 2026 |
| `customers.csv` | `customer_id`, `customer_name`, `region` | Region is West, East, South, or Midwest |
| `products.csv` | `product_id`, `product_name`, `category` | Category is Electronics, Home, Apparel, or Outdoors |

Three things worth knowing:

- **Revenue is `quantity * unit_price`**, taken from the order row. This is the
  one easy trap: summing `unit_price` on its own ignores how many units sold and
  gives a number that looks plausible but is wrong. It is exactly the kind of
  mistake to catch by reading the SQL.
- A single monthly file is enough to rank products by revenue, no join required.
  `unit_price` is the price the customer paid, so it lives on the order;
  `products.csv` has no price column on purpose. Region and category only appear
  once you join `customers.csv` and `products.csv` back in.
- `order_id` is a text id (`ORD-01-000001`), not a number, so its shape is stable.
  It is unique but is never used as a join key.

## Try it yourself

The point is to ask in plain English and let the agent write the SQL. Open Claude
Code in this folder and try these, in order:

1. **"What were the top products by revenue in January?"**
   Reads `data/orders_2026_01.csv` directly. The file is the table, no import step.
   This first pass ranks by `product_id`, since names live in `products.csv`; the
   join that brings in product names shows up in the next two questions.

2. **"Now answer that across all six monthly files, not just January."**
   Uses a glob, `FROM 'data/orders_*.csv'`, so the whole folder becomes one table.

3. **"Give me revenue by region and by product category."**
   Joins the orders glob to `customers.csv` and `products.csv` on `customer_id`
   and `product_id`, then groups and aggregates.

Read the SQL it writes each time. A query can run clean and still be wrong (a
dropped filter, the wrong grain, or summing `unit_price` without multiplying by
`quantity`). Reading the SQL is how you catch that, and it is also how you pick up
DuckDB's dialect without studying it.

## The honest boundary

Your data files stay on your laptop. They are never uploaded. What does leave is
the question you typed, your schema (column names), the SQL the agent writes, and
a small sample of result rows so the agent can check its work. Those result rows
are real values from your data, so this is not fully private, and every question
is tokens, so it is cheap but not free. If you need fully offline, point the agent
at a local model and trade some quality to keep everything on your machine.

This earns a permanent spot for the everyday question you would otherwise spin up
a warehouse for. It is for your own local exploration, not a whole team writing
production dashboards against the same data at once. That stays warehouse
territory, and DuckDB is single-writer by design.

## Project structure

```
claude-code-duckdb/
├── data/                     # the sample CSVs (committed, query these directly)
│   ├── orders_2026_01.csv    # one orders file per month, Jan-Jun 2026
│   │   …
│   ├── orders_2026_06.csv
│   ├── customers.csv
│   └── products.csv
├── scripts/
│   └── generate_data.py      # seeded generator that rebuilds data/
├── sql/                      # saved analysis queries from the walkthrough
│   ├── june_revenue_by_product.sql
│   ├── half_year_revenue_by_product.sql
│   └── monthly_breakdowns.sql
├── images/
│   └── diagram.png           # how the pieces fit together
├── CLAUDE.md                 # context for the AI agent
└── README.md
```

## Resources

- DuckDB: https://duckdb.org
- DuckDB concurrency (the single-writer boundary): https://duckdb.org/docs/stable/connect/concurrency
- `duckdb-skills` (official Claude Code plugin): https://github.com/duckdb/duckdb-skills
- Claude Code: https://claude.com/claude-code

## About

Built for the [Kyle Chalmers Data Plus AI](https://www.youtube.com/@kylechalmersdataai)
channel, where I show how to use AI tools for real data work. The follow-up takes
this same setup to the cloud with MotherDuck for when the data outgrows your
laptop.
