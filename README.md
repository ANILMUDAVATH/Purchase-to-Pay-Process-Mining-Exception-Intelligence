
# Purchase-to-Pay Process Mining & Exception Intelligence

## Project Overview

This project analyzes a large Purchase-to-Pay (P2P) event log to understand how procurement and invoice-processing transactions actually move through the business process.

The goal is to identify:

* process variants,
* long-running transactions,
* purchase-order rework,
* invoice and goods-receipt reversals,
* payment-block handling,
* repeated activities,
* resource handoffs,
* exception concentrations,
* and transactions that should be prioritized for operational investigation.

The project combines **Data Analyst and Business Analyst responsibilities** using:

**SQL | Python | Excel | Power BI | Business Analysis | Process Mining**

---

## Business Problem

A multinational organization processes a high volume of Purchase-to-Pay transactions across vendors, purchasing processes, spend categories, and operational resources.

Although many transactions follow common purchasing and invoice-processing paths, others contain purchase-order modifications, approval changes, goods-receipt reversals, invoice reversals, payment-block handling, repeated activities, and unusual process sequences.

Management lacks a consolidated analytical view of:

* how transactions actually move through the P2P process,
* where operational rework occurs,
* where processing delays are concentrated,
* which process variants are unusually complex,
* which vendors or purchasing segments show high exception rates,
* and which individual transactions should be investigated first.

The project therefore develops a **P2P Process Intelligence and Exception Monitoring solution** that reconstructs actual transaction flows, measures process performance, detects exception patterns, and supports evidence-based process-improvement decisions.

---

## Project Objective

The primary objective is to develop a data-driven P2P analytical solution that enables Procurement, Accounts Payable, Finance, and process owners to:

* understand actual P2P execution,
* identify common and unusual process variants,
* quantify rework and reversals,
* measure processing cycle times,
* detect long-running cases,
* investigate payment-block handling,
* compare exception rates across business dimensions,
* identify high-complexity transactions,
* and prioritize cases and process areas requiring further investigation.

---

## Dataset

The project uses the **BPI Challenge 2019 Purchase-to-Pay event log** converted from XES format into CSV.

### Dataset Baseline

| Metric               |     Value |
| -------------------- | --------: |
| Event Rows           | 1,595,923 |
| Columns              |        21 |
| Unique P2P Cases     |   251,734 |
| Purchasing Documents |    76,349 |
| Vendors              |     1,975 |
| Activities           |        42 |
| Companies            |         4 |

The dataset is an **event log**, meaning multiple rows can belong to the same P2P case.

Therefore:

> Event count ≠ transaction count.

---

## Important Dataset Fields

| Field                        | Purpose                                          |
| ---------------------------- | ------------------------------------------------ |
| `case:concept:name`          | Unique process case identifier                   |
| `concept:name`               | Activity/event name                              |
| `time:timestamp`             | Event sequencing and duration analysis           |
| `org:resource`               | Resource and handoff analysis                    |
| `case:Vendor`                | Vendor-level comparison                          |
| `case:Company`               | Company-level segmentation                       |
| `case:Spend area text`       | Spend segmentation                               |
| `case:Sub spend area text`   | Detailed spend analysis                          |
| `case:Item Category`         | P2P process / matching category                  |
| `case:Document Type`         | Document-type analysis                           |
| `case:GR-Based Inv. Verif.`  | GR-based invoice verification                    |
| `case:Goods Receipt`         | Goods-receipt characteristic                     |
| `Cumulative net worth (EUR)` | Transaction-value analysis subject to validation |

---

## P2P Activities Available

The event log contains activities from multiple parts of the P2P lifecycle.

### Procurement

* Create Purchase Requisition Item
* Release Purchase Requisition
* Create Purchase Order Item
* Release Purchase Order
* Receive Order Confirmation
* Update Order Confirmation

### Purchase Order Changes

* Change Quantity
* Change Price
* Change Approval for Purchase Order
* Change Delivery Indicator
* Change Storage Location
* Change Currency
* Change payment term
* Delete Purchase Order Item
* Block Purchase Order Item
* Reactivate Purchase Order Item

### Goods / Service Receipt

* Record Goods Receipt
* Cancel Goods Receipt
* Record Service Entry Sheet

### Invoice Processing

* Vendor creates invoice
* Record Invoice Receipt
* Cancel Invoice Receipt
* Vendor creates debit memo
* Record Subsequent Invoice
* Cancel Subsequent Invoice

### Payment Handling

* Set Payment Block
* Remove Payment Block
* Clear Invoice

The dataset also contains several SRM/system-related activities.

---

## Key Business Questions

The project is driven by business questions rather than dashboard visuals.

1. What process variants occur in the P2P lifecycle?
2. What percentage of cases follows the most common process variants?
3. Which process variants have the longest processing times?
4. How frequently are purchase orders modified?
5. Which types of PO modifications occur most frequently?
6. Are PO-change cases associated with longer cycle times?
7. How frequently are invoice receipts reversed?
8. How frequently are goods receipts reversed?
9. Are reversal cases associated with longer processing times?
10. How do different P2P matching processes compare?
11. Which vendors have disproportionately high exception rates?
12. Which spend areas show higher levels of operational rework?
13. How frequently do activities repeat within a case?
14. How many resources typically participate in a transaction?
15. Are higher resource handoffs associated with longer processing times?
16. Which cases have unusually long cycle times?
17. Which rare process variants require investigation?
18. Which high-value transactions also show high process complexity?
19. Where are exception patterns concentrated?
20. Which transactions should operations investigate first?

---

## Analytical Approach

The project follows the workflow:

```text
Business Problem
        ↓
Business Requirements
        ↓
Raw Event Data
        ↓
Data Understanding
        ↓
Data Validation
        ↓
Event-Level Model
        ↓
Case-Level Analytical Model
        ↓
Process Variant Analysis
        ↓
Exception Analysis
        ↓
Cycle-Time Analysis
        ↓
Root-Cause Exploration
        ↓
Power BI Decision Support
        ↓
Business Recommendations
```

---

## Event-Level vs Case-Level Analysis

This project maintains two separate analytical grains.

### Event Level

Used for:

* process sequencing,
* activity analysis,
* repeated events,
* resource transitions,
* process mining,
* event-based exception detection.

Example:

```text
Case001 → Create Purchase Order Item
Case001 → Record Goods Receipt
Case001 → Vendor creates invoice
Case001 → Record Invoice Receipt
Case001 → Clear Invoice
```

### Case Level

A case-level table will be created with one row per P2P case.

Expected derived fields include:

```text
case_id
vendor
item_category
case_start
case_end
cycle_time_days
event_count
unique_activity_count
unique_resource_count
resource_handoff_count
process_variant
po_change_flag
po_change_count
invoice_reversal_flag
gr_reversal_flag
payment_block_handling_flag
repeated_activity_count
long_cycle_flag
rare_variant_flag
investigation_priority
```

The case-level table will become the main analytical model for SQL, Python, Excel, and Power BI.

---

## Preliminary Exception Framework

### Purchase Order Rework

Examples:

* Change Quantity
* Change Price
* Change Approval for Purchase Order
* Change Delivery Indicator
* Change Storage Location
* Change Currency
* Change payment term

### Invoice Reversal

Primary event:

```text
Cancel Invoice Receipt
```

### Goods Receipt Reversal

Primary event:

```text
Cancel Goods Receipt
```

### Payment Block Handling

The dataset contains both:

```text
Set Payment Block
Remove Payment Block
```

These will be analyzed separately because their frequencies are highly asymmetric.

A payment-block event will **not automatically be interpreted as financial loss or process failure**.

### Repeated Activities

Repeated events within the same case will be measured as process-complexity indicators.

Repeated activity does not automatically mean rework.

---

## Preliminary KPI Framework

Planned KPIs include:

* Total Cases
* Total Events
* Median Cycle Time
* P90 Cycle Time
* Long-Cycle Case Rate
* Number of Process Variants
* Top Variant Coverage
* Rare Variant Rate
* PO Change Rate
* Invoice Reversal Rate
* Goods Receipt Reversal Rate
* Payment-Block Handling Case Rate
* Repeated-Activity Case Rate
* Median Resource Handoffs
* Invoice Clearing Rate
* High-Priority Investigation Cases

Final KPI definitions will be created only after data validation and case-level modeling.

---

## Business Analyst Deliverables

The BA component includes:

* Business problem definition
* Problem statement
* Project scope
* Stakeholder analysis
* Business requirements
* Requirement traceability
* AS-IS process analysis
* Pain-point identification
* Business-rule definition
* KPI requirements
* TO-BE process recommendations
* Acceptance criteria
* Risks and limitations

Main artifacts:

```text
ba/
├── P2P_Business_Case_BRD.pdf
├── stakeholder_register.xlsx
└── requirements_traceability.xlsx
```

---

## Data Analyst Deliverables

The DA component includes:

### SQL

* data validation,
* case-level model creation,
* exception analysis,
* business KPI analysis,
* vendor/process comparison,
* cycle-time investigation.

### Python

* data profiling,
* event-log validation,
* process-variant analysis,
* cycle-time distributions,
* rework analysis,
* outlier investigation,
* root-cause exploration,
* case prioritization.

### Excel

Used for:

* operational exception review,
* reconciliation,
* Pivot Tables,
* conditional investigation,
* management review.

### Power BI

Planned dashboard pages:

1. Executive Overview
2. Process Variants
3. Exception & Root-Cause Analysis
4. Case Investigation

---

## Important Analytical Boundaries

This project will **not automatically claim**:

* fraud,
* supplier credit risk,
* supplier quality failure,
* employee underperformance,
* financial loss,
* working-capital savings,
* ROI,
* causation from correlation.

An exception is treated as:

> **a signal requiring investigation**

rather than proof of failure.

Similarly:

```text
Rare process variant
≠
Non-compliant process
```

and:

```text
Repeated activity
≠
Confirmed rework
```

unless supported by documented business rules.

---

## Data Quality Considerations

Initial profiling identified areas requiring investigation before cleaning.

### Duplicate-Looking Rows

The source contains a large number of identical-looking rows.

These cannot simply be removed because events such as goods receipt and service entry may legitimately repeat.

Therefore:

```python
df.drop_duplicates()
```

will not be used without investigation.

### Timestamp Anomalies

Some events contain unusually old timestamps compared with the dominant dataset period.

These will be investigated and flagged rather than silently deleted.

### Resource Fields

Initial validation found that:

```text
User
and
org:resource
```

appear to contain the same information.

This will be formally validated before one field is removed from the analytical model.

### Monetary Value

`Cumulative net worth (EUR)` may vary within some cases.

The field will therefore not be summed at raw event level until its business meaning and case-level behavior are validated.

---

## Repository Structure

```text
p2p-process-intelligence/
│
├── README.md
├── requirements.txt
├── .gitignore
│
├── data/
│   ├── README.md
│   └── sample_bpi2019.csv
│
├── ba/
│   ├── P2P_Business_Case_BRD.pdf
│   ├── stakeholder_register.xlsx
│   └── requirements_traceability.xlsx
│
├── sql/
│   ├── 01_data_validation.sql
│   ├── 02_case_level_model.sql
│   ├── 03_exception_analysis.sql
│   └── 04_business_analysis.sql
│
├── notebooks/
│   ├── 01_data_understanding.ipynb
│   ├── 02_process_analysis.ipynb
│   └── 03_root_cause_analysis.ipynb
│
├── excel/
│   └── P2P_Exception_Analysis.xlsx
│
├── powerbi/
│   ├── P2P_Process_Intelligence.pbix
│   └── screenshots/
│
└── docs/
    ├── data_model.png
    └── project_architecture.png
```

---

## Project Roadmap

### Phase 1 — Business Understanding

* [x] Define business problem
* [x] Define project objective
* [x] Define scope
* [x] Identify stakeholders
* [x] Define core business questions
* [x] Create business-case documentation

### Phase 2 — Data Understanding

* [ ] Profile all 21 columns
* [ ] Validate event and case grain
* [ ] Analyze missing values
* [ ] Review 42 activities
* [ ] Investigate duplicate-looking events
* [ ] Investigate timestamp anomalies
* [ ] Validate case-level attribute consistency

### Phase 3 — Data Preparation

* [ ] Build validated event table
* [ ] Create case-level analytical table
* [ ] Generate process variants
* [ ] Create resource handoff metrics
* [ ] Create exception flags

### Phase 4 — Business Rules

* [ ] Finalize exception taxonomy
* [ ] Define long-cycle thresholds
* [ ] Define rare-variant logic
* [ ] Finalize KPI dictionary

### Phase 5 — SQL

* [ ] Data validation queries
* [ ] Case-level model
* [ ] Exception analysis
* [ ] Business analysis

### Phase 6 — Python

* [ ] Data-understanding notebook
* [ ] Process-analysis notebook
* [ ] Root-cause notebook

### Phase 7 — Excel

* [ ] Operational exception workbook

### Phase 8 — Power BI

* [ ] Executive Overview
* [ ] Process Variant Analysis
* [ ] Exception / Root-Cause Analysis
* [ ] Case Investigation

### Phase 9 — Business Recommendations

* [ ] Convert analytical findings into recommendations
* [ ] Prioritize improvement opportunities
* [ ] Define KPIs to monitor outcomes

### Phase 10 — Portfolio & Interview Preparation

* [ ] Finalize README
* [ ] Add quantified findings
* [ ] Add dashboard screenshots
* [ ] Prepare resume bullets
* [ ] Prepare DA/BA interview explanation
---

## Tools

* **Python:** Pandas, NumPy, Matplotlib
* **SQL:** PostgreSQL / MySQL / SQL Server compatible analytical concepts
* **Excel:** Pivot Tables, XLOOKUP, SUMIFS, COUNTIFS, conditional formatting
* **Power BI:** Data modeling, DAX, drill-through, KPI reporting
* **Business Analysis:** BRD, stakeholder analysis, requirements traceability, AS-IS/TO-BE, business rules, acceptance criteria

---

## Project Positioning

This project is designed as a combined:

**Data Analyst + Business Analyst + Process Analytics portfolio project**

with emphasis on:

> **business decision-making, process understanding, analytical integrity, and evidence-based recommendations rather than dashboard decoration.**
