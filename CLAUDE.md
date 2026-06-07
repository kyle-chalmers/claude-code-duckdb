# CLAUDE.md

Project context for AI coding agents (Claude Code) working in this repository.

> IMPORTANT: Everything in this repo is public-facing. Do not place any sensitive
> information here. Anything that must persist across sessions but should not be
> published (personal config, operational notes) goes in the `.internal/` folder,
> which is ignored by git via `.gitignore`. Do not proactively read `.internal/`
> files other than `OWNER_CONFIG.md`.

## Project overview

This project explores a folder of e-commerce CSV files with DuckDB, driven from
the terminal. The data is a small order history split into monthly files, plus a
customers file and a products file. The goal is to answer real analytical
questions (top products by revenue, trends across months, revenue by region and
category) by querying the raw files directly, with the SQL written by an AI agent
and verified by a human reading it.

There is no database server, no warehouse, and no import step. DuckDB queries the
CSV files in place. The only thing that needs to exist before you start is the
`data/` folder, which is committed to the repo (and regenerable via
`scripts/generate_data.py`).

Tech stack: DuckDB CLI (local, in-process), the `duckdb` command run through the
Bash tool, Python 3 standard library for the data generator.

## Data

All files live in `data/`. The file IS the table, so put the path straight in a
SQL `FROM` clause.

`data/orders_2026_01.csv` through `data/orders_2026_06.csv` (one per month, Jan-Jun 2026):

| column | type | notes |
|---|---|---|
| order_id | text | unique within the dataset |
| order_date | date (YYYY-MM-DD) | falls inside the file's month |
| customer_id | int | joins to customers.csv |
| product_id | int | joins to products.csv |
| quantity | int | 1 to 5 |
| unit_price | decimal | price at time of sale |

`data/customers.csv`: `customer_id`, `customer_name`, `region` (West / East / South / Midwest)

`data/products.csv`: `product_id`, `product_name`, `category` (Electronics / Home / Apparel / Outdoors)

Key facts:
- **Revenue = `quantity * unit_price`**, computed from the order row. A single
  monthly orders file is enough to rank products by revenue, no join needed.
- `unit_price` lives on the order (what the customer paid), not on the product.
  `products.csv` deliberately has no price column.
- `region` is only available by joining `customers.csv`; `category` only by
  joining `products.csv`.

## Available tools

Run DuckDB through the Bash tool. Two common shapes:

```bash
# one-off query, print the result
duckdb -c "SELECT * FROM 'data/orders_2026_01.csv' LIMIT 5;"

# query every monthly file at once with a glob
duckdb -c "SELECT COUNT(*) FROM 'data/orders_*.csv';"
```

DuckDB infers the schema from the CSV header automatically. No `CREATE TABLE`, no
load step.

If the official [`duckdb-skills`](https://github.com/duckdb/duckdb-skills) plugin is
installed, its `query`, `read-file`, and `attach-db` skills are the recommended way
to drive DuckDB from a plain-English question. It is a wrapper over the same DuckDB
CLI, so everything in this file still holds: query the files directly, prefer a glob
for multi-file questions, and always surface the SQL that runs so it can be read and
checked. The plugin writes its state under `.duckdb-skills/` (git-ignored).

## Conventions

- **The file is the table.** Reference CSV paths directly in `FROM`. Do not import
  into a persistent database unless a task specifically calls for it.
- **Use a glob for multi-file questions.** `FROM 'data/orders_*.csv'` reads all
  monthly files as one table. Prefer this over `UNION ALL` across files.
- **Print the SQL before running it.** Show the query as a formatted SQL block,
  then execute it. The query should be readable on its own.
- **Compute revenue as `quantity * unit_price`.** A sum of `unit_price` alone is
  wrong: it ignores how many units were sold.
- **Join on the natural keys:** `customer_id` for region, `product_id` for
  category. `USING(customer_id)` / `USING(product_id)` keeps joins terse.
- Round money to 2 decimals in final output (`ROUND(SUM(quantity*unit_price), 2)`).

## Working principles

- Explain non-obvious SQL briefly (what a glob does, why a join is needed, what a
  `GROUP BY` grain is), but do not narrate trivial syntax.
- Verify results before trusting them. Read the generated SQL line by line; a query
  can run clean and still answer the wrong question (wrong grain, missing filter,
  forgetting to multiply by quantity).
- When a query looks off, point at the specific line, correct it, and re-run rather
  than starting over.
- Keep the data files local. DuckDB reads them on the machine and nothing uploads
  the CSVs. The only thing that leaves is what the model call needs: the question,
  the schema, the SQL, and a small sample of result rows (which are real values).

## Regenerating the data

`python3 scripts/generate_data.py` rewrites the `data/` CSVs deterministically
(seeded). Re-running produces identical files.
