# Data

This folder documents the dataset used for the **Purchase-to-Pay Process Mining & Exception Intelligence** project.

## Dataset Source

The project uses the **BPI Challenge 2019 Purchase-to-Pay event log**.

* **Dataset:** BPI Challenge 2019
* **Publisher:** 4TU.Centre for Research Data / Eindhoven University of Technology
* **Format:** XES event log
* **Project Format:** Converted to CSV for analysis
* **DOI:** `10.4121/uuid:d06aff4b-79f0-45e6-8ec8-e19730c248f1`

## Full Dataset Profile

The converted dataset used in this project contains approximately:

| Metric               |     Value |
| -------------------- | --------: |
| Event Records        | 1,595,923 |
| Columns              |        21 |
| Unique P2P Cases     |   251,734 |
| Purchasing Documents |    76,349 |
| Vendors              |     1,975 |
| Activities           |        42 |
| Companies            |         4 |

The full source dataset is **not committed to this repository** because of its size.

Locally, the source file is stored as:

```text
data/raw/output.csv
```

The raw dataset is excluded from Git tracking through `.gitignore`.

---

## Sample Dataset

A small representative sample is included in this repository:

```text
sample_bpi2019.csv
```

The sample contains **complete P2P cases rather than randomly selected individual rows**.

This preserves the event sequence of each sampled transaction and makes the sample suitable for:

* reviewing the schema,
* understanding the event-log structure,
* testing code,
* and reproducing small examples.

The sample includes cases from the main P2P process categories:

* 2-way match
* 3-way match, invoice after GR
* 3-way match, invoice before GR
* Consignment

---

## Important Data Grain

The source is an **event log**.

One row represents one event, not one complete P2P transaction.

For example:

```text
case:concept:name   concept:name
Case001             Create Purchase Order Item
Case001             Record Goods Receipt
Case001             Vendor creates invoice
Case001             Record Invoice Receipt
Case001             Clear Invoice
```

All five rows above belong to the same P2P case.

Therefore:

> **Event count ≠ transaction count**

Case-level KPIs are calculated using unique `case:concept:name` values.

---

## Key Fields

| Field                            | Meaning / Use                                                |
| -------------------------------- | ------------------------------------------------------------ |
| `case:concept:name`              | Unique P2P case identifier                                   |
| `concept:name`                   | Activity / event name                                        |
| `time:timestamp`                 | Event sequencing and cycle-time analysis                     |
| `org:resource`                   | Resource / user involved in the event                        |
| `case:Vendor`                    | Vendor identifier                                            |
| `case:Company`                   | Company identifier                                           |
| `case:Spend area text`           | Spend-area classification                                    |
| `case:Sub spend area text`       | Detailed spend classification                                |
| `case:Spend classification text` | Procurement spend classification                             |
| `case:Purchasing Document`       | Purchasing-document reference                                |
| `case:Purch. Doc. Category name` | Purchasing-document category                                 |
| `case:Document Type`             | Document-type classification                                 |
| `case:Item Type`                 | Item-type classification                                     |
| `case:Item Category`             | P2P matching / process category                              |
| `case:GR-Based Inv. Verif.`      | GR-based invoice-verification indicator                      |
| `case:Goods Receipt`             | Goods-receipt characteristic                                 |
| `Cumulative net worth (EUR)`     | Monetary field requiring grain validation before aggregation |

---

## Data Quality Notes

The dataset contains several areas that require careful validation before cleaning.

### Duplicate-Looking Rows

Some rows appear identical across visible columns.

These rows are **not automatically removed**, because repeated goods-receipt, service-entry, or other process events may be legitimate business events.

### Timestamp Anomalies

Some timestamps fall outside the dominant event period.

These records are investigated and flagged before any correction or exclusion.

### Resource Fields

`User` and `org:resource` appear to contain equivalent values in the converted dataset.

This is validated before one field is removed from the analytical model.

### Monetary Value

`Cumulative net worth (EUR)` can vary within some cases.

For this reason, the field is not summed directly at raw event level until its correct business grain and interpretation are confirmed.

---

## Data Usage in This Project

The dataset is used to support:

* process variant analysis,
* cycle-time analysis,
* purchase-order rework analysis,
* invoice reversal analysis,
* goods-receipt reversal analysis,
* payment-block handling analysis,
* repeated-activity analysis,
* resource-handoff analysis,
* vendor and spend segmentation,
* case-level exception prioritization,
* and Power BI process-intelligence reporting.

---

## Repository Policy

Only a small representative sample is stored in GitHub.

The full dataset remains local and is excluded using:

```gitignore
data/raw/
output.csv
*.xes
```

This keeps the repository lightweight while preserving reproducibility and transparency.

---

## Data Ethics

The BPI Challenge 2019 dataset is anonymized.

This project does not attempt to reverse anonymization, identify the original organization, identify individual employees, or infer confidential supplier identities.

All business scenarios, stakeholder roles, and recommendations in this portfolio project are analytical assumptions built around the anonymized event data.
