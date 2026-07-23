# Olist Customer Segmentation — A Retention Analysis

Customer segmentation on a Brazilian e-commerce marketplace (~100k orders, 2016–2018), built in PostgreSQL and visualized in Tableau.

**[View the interactive dashboard →](https://public.tableau.com/app/profile/emanuel.ortega5911/viz/OlistCustomerSegmentationRetentionAnalysis/Dashboard1)**

---

## Headline findings

- **97% of customers never make a second purchase.** Of 93,358 customers with delivered orders, 90,557 bought exactly once. Only 2,801 ever returned.
- **Repeat customers are worth 1.9x more.** Average lifetime value is R$309 for repeat buyers vs R$161 for one-time buyers — yet repeat buyers are 3% of the base.
- **Revenue is concentrated.** The two high-spending segments hold 30% of customers but 56% of revenue.
- **Standard RFM does not work on this dataset.** The frequency dimension has almost no variance, which invalidates the textbook approach. Diagnosing and correcting this is the core of the analysis (see below).

The business implication: Olist's constraint is not identifying loyal customers to nurture. It is that loyal customers barely exist. This is an acquisition business with a retention problem.

---

## The analytical story: why v1 was wrong

**v1 — standard RFM.** I began with the textbook approach: score each customer 1–5 on Recency, Frequency, and Monetary using `NTILE(5)`, then combine the scores into named segments (Champions, Loyal, At Risk, and so on). The query ran and produced six clean segments.

**The diagnosis.** The output looked plausible but the segment profiles did not hold up:

| Segment (v1) | Avg. frequency | Avg. recency |
|---|---|---|
| Champions | 1.09 | 90 days |
| New / Promising | 1.00 | 91 days |
| At Risk | 1.05 | 395 days |
| Hibernating / Lost | 1.00 | 396 days |

"Champions" and "New / Promising" were statistically the same customers under two different labels — as were "At Risk" and "Hibernating / Lost". Average monetary value was also nearly flat across every segment (R$155–R$177).

Measuring the frequency distribution explained why:

| Purchases | Customers | % of customers |
|---|---|---|
| 1 | 90,557 | 97.00% |
| 2 | 2,573 | 2.76% |
| 3 | 181 | 0.19% |
| 4+ | 47 | 0.05% |

With 97% of customers tied at a single value, `NTILE(5)` splits identical rows into arbitrary buckets. The v1 segments were recency rankings wearing RFM labels, and the "loyalty" they described did not exist.

**v2 — rebuilt on dimensions that vary.** The corrected approach:

1. Treats the 97% single-purchase rate as the headline finding rather than an obstacle.
2. Segments on **Recency × Monetary**, the two dimensions with real spread.
3. Splits repeat buyers into their own cohort rather than diluting them across segments dominated by one-time buyers.

Both versions are kept in this repo. `rfm_analysis.sql` is the v1 attempt; `rfm_analysis_v2.sql` is the corrected model.

---

## Results

| Segment | Customers | Avg. recency | Avg. value | Revenue | % of revenue |
|---|---|---|---|---|---|
| Recent High Spender | 14,393 | 92 days | R$302 | R$4.35M | 28.2% |
| Lapsed High Spender | 13,762 | 395 days | R$308 | R$4.23M | 27.5% |
| Mid Recency | 18,065 | 220 days | R$152 | R$2.75M | 17.8% |
| Lapsed Low Spender | 22,589 | 396 days | R$73 | R$1.64M | 10.6% |
| Recent Low Spender | 21,748 | 90 days | R$73 | R$1.59M | 10.3% |
| Repeat – High Value | 2,238 | 216 days | R$362 | R$0.81M | 5.2% |
| Repeat – Standard | 563 | 241 days | R$98 | R$0.06M | 0.4% |

*Totals: 93,358 customers, R$15.42M revenue (delivered orders only).*

### Recommended actions

- **Recent High Spender** — the single best retention target. High value, recently active, but only one purchase. Post-purchase sequences, cross-sell based on category, and a second-purchase incentive should concentrate here.
- **Lapsed High Spender** — R$4.2M of proven spend that has gone quiet for over a year. Best win-back economics in the base, since willingness to spend is already demonstrated.
- **Repeat – High Value** — small but the most valuable cohort per customer. Worth studying qualitatively: what did these 2,238 people buy, and why did they come back? Those answers inform every other segment.
- **Recent Low Spender** — high volume, low value. Test basket-size levers (bundles, free-shipping thresholds) before spending on retention.
- **Lapsed Low Spender** — largest segment, lowest return. Lowest-cost channels only; do not over-invest.
- **Mid Recency** — monitor for drift toward the lapsed segments.

---

## Method

- **Grouping key:** `customer_unique_id`, not `customer_id`. Olist generates a new `customer_id` for every order, so grouping by it makes nearly every customer appear to be a one-time buyer. This is the most common error made with this dataset.
- **Order scope:** `order_status = 'delivered'` only, so cancelled and undelivered orders do not count toward revenue.
- **Order value:** payments are summed per order first, since a single order can have multiple payment rows (e.g. card plus voucher).
- **Snapshot date:** the day after the final purchase in the dataset, used as the reference point for recency.
- **Scoring:** `NTILE(5)` quintiles. Recency is reverse-scored (`ORDER BY recency_days DESC`) so that the most recent customers receive the highest score.
- **Validation:** SQL logic was tested against a synthetic dataset with known expected outputs before being run against the full data, and row counts were verified against source files after loading.

---

## Limitations

- **Frequency has no usable variance.** The 97% single-purchase rate is the finding, but it also means this dataset cannot support a true RFM model. A repeat-heavy dataset would make F meaningful.
- **Marketplace, not retailer.** Olist is a platform connecting sellers to marketplaces, so "customer loyalty" is partly a function of seller behaviour and channel mix, not just customer preference.
- **No marketing cost data.** Segment recommendations are prioritized by revenue potential; without acquisition or campaign costs, true ROI cannot be calculated.
- **Historical data** (2016–2018) from a single market. Findings should not be generalized to other geographies or periods.
- **Currency:** all figures are Brazilian reais (R$), not USD.

---

## Repo contents

| File | Purpose |
|---|---|
| `schema.sql` | PostgreSQL table definitions for the Olist dataset |
| `load_data.sql` | `\copy` commands to load the source CSVs |
| `rfm_analysis.sql` | v1 — standard RFM (retained to show the diagnosis) |
| `rfm_analysis_v2.sql` | v2 — corrected Recency × Monetary segmentation |
| `data/customer_segments.csv` | Exported segmentation output |
| `data/purchase_frequency_dist.csv` | Exported frequency distribution |

## Stack

PostgreSQL 18 · pgAdmin 4 · Tableau Public · SQL (CTEs, window functions, `NTILE`)

**Pipeline:** raw CSVs → PostgreSQL (schema, load, transformation) → SQL views → CSV export → Tableau Public dashboard. The published dashboard runs on a Tableau extract, not a live database connection.

## Data source

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle) — ~100k orders placed between 2016 and 2018.
