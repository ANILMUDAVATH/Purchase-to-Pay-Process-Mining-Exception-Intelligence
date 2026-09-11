# Purchase-to-Pay Process Mining & Exception Intelligence

## Overview

This project analyzes a large-scale Purchase-to-Pay (P2P) event log to understand how procurement and invoice-processing transactions actually move through the business process.

The solution combines **Data Analytics + Business Analysis + Process Mining** to identify:

* process variants,
* long-running transactions,
* purchase-order rework,
* invoice and goods-receipt reversals,
* payment-block handling,
* repeated activities,
* resource handoffs,
* exception concentrations,
* and transactions requiring operational investigation.

### Technology Stack

**Python | SQL | Excel | Power BI | Business Analysis | Process Mining**

---

# Business Problem

A multinational organization processes a high volume of Purchase-to-Pay transactions across vendors, purchasing processes, spend categories, and operational resources.

Although many transactions follow common purchasing and invoice-processing paths, others contain:

* purchase-order modifications,
* approval changes,
* goods-receipt reversals,
* invoice reversals,
* payment-block handling,
* repeated processing activities,
* and non-standard process sequences.

Management lacks a consolidated analytical view of how transactions actually move through the P2P lifecycle, where operational rework and processing delays occur, and which cases or process segments contribute disproportionately to process complexity.

This limits the ability of Procurement, Accounts Payable, Finance, and P2P process owners to systematically identify recurring operational issues and prioritize improvement opportunities.

The project therefore develops a **P2P Process Intelligence & Exception Monitoring solution** to reconstruct actual transaction flows, measure process performance, identify exception patterns, and support evidence-based process-improvement decisions.

---

# Project Objective

The objective is to develop a data-driven P2P analytical solution that enables business stakeholders to:

* reconstruct actual P2P process execution,
* identify common and unusual process variants,
* quantify purchase-order rework,
* identify invoice and goods-receipt reversals,
* measure transaction cycle times,
* detect long-running transactions,
* analyze payment-block handling,
* evaluate resource handoffs and process complexity,
* compare exception patterns across vendors and purchasing segments,
* and prioritize cases requiring further investigation.

---

# Dataset

The project uses the **BPI Challenge 2019 Purchase-to-Pay event log**, converted from XES format into CSV for analysis.

## Dataset Profile

| Metric               |     Value |
| -------------------- | --------: |
| Event Records        | 1,595,923 |
| Columns              |        21 |
| Unique P2P Cases     |   251,734 |
| Purchasing Documents |    76,349 |
| Vendors              |     1,975 |
| Activities           |        42 |
| Companies            |         4 |

The dataset is structured as an **event log**.

A single P2P case may contain multiple activities.

Therefore:

```text id="qrm86g"
Event Count ≠ Transaction Count
```

The analysis maintains both:

```text id="7xm0xp"
Event-Level Grain
        +
Case-Level Grain
```

to avoid incorrect aggregation.

---

# Core Dataset Fields

| Field                            | Analytical Purpose                               |
| -------------------------------- | ------------------------------------------------ |
| `case:concept:name`              | Unique P2P case identifier                       |
| `concept:name`                   | Activity / event name                            |
| `time:timestamp`                 | Event sequence and cycle-time analysis           |
| `org:resource`                   | Resource participation and handoffs              |
| `case:Vendor`                    | Vendor-level analysis                            |
| `case:Company`                   | Company segmentation                             |
| `case:Spend area text`           | Spend-area analysis                              |
| `case:Sub spend area text`       | Detailed spend segmentation                      |
| `case:Spend classification text` | Procurement classification                       |
| `case:Purchasing Document`       | Purchasing-document reference                    |
| `case:Purch. Doc. Category name` | Purchasing-document category                     |
| `case:Document Type`             | Document-type segmentation                       |
| `case:Item Type`                 | Item-level segmentation                          |
| `case:Item Category`             | P2P process / matching category                  |
| `case:GR-Based Inv. Verif.`      | GR-based invoice-verification analysis           |
| `case:Goods Receipt`             | Goods-receipt characteristic                     |
| `Cumulative net worth (EUR)`     | Transaction-value analysis subject to validation |

---

# P2P Process Coverage

The event log contains activities across several stages of the P2P lifecycle.

## Procurement

```text id="coap5s"
Create Purchase Requisition Item
        ↓
Release Purchase Requisition
        ↓
Create Purchase Order Item
        ↓
Release Purchase Order
        ↓
Receive Order Confirmation
```

## Purchase-Order Changes

Examples include:

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

## Receipt / Service Processing

* Record Goods Receipt
* Cancel Goods Receipt
* Record Service Entry Sheet

## Invoice Processing

* Vendor creates invoice
* Record Invoice Receipt
* Cancel Invoice Receipt
* Vendor creates debit memo
* Record Subsequent Invoice
* Cancel Subsequent Invoice

## Payment / Completion

* Set Payment Block
* Remove Payment Block
* Clear Invoice

The dataset also contains several SRM/system-related activities that will be analyzed separately from standard business-process activities.

---

# Business Questions

The analysis is driven by business questions rather than dashboard visuals.

## Process Performance

1. What process variants exist in the P2P lifecycle?
2. What proportion of transactions follows the most common process variants?
3. Which process variants have the longest cycle times?
4. Which activities appear most frequently in long-running transactions?

## Purchase-Order Rework

5. How frequently are purchase orders modified?
6. Which types of purchase-order changes occur most frequently?
7. Are PO-change cases associated with longer cycle times?
8. Which vendors or spend areas have higher PO-change rates?

## Invoice & Receipt Exceptions

9. How frequently are invoice receipts reversed?
10. How frequently are goods receipts reversed?
11. Are reversal cases associated with longer processing times?
12. Which vendors or purchasing categories show higher reversal rates?

## Payment-Block Handling

13. Which cases contain payment-block-related activities?
14. How long does it take to clear invoices after payment-block removal?
15. How do block-handling cases differ from standard invoice cases?

## Process Complexity

16. How frequently do activities repeat within a case?
17. How many resources participate in an average case?
18. Are higher resource handoffs associated with longer cycle times?
19. Which rare process variants show high operational complexity?

## Investigation Prioritization

20. Which cases combine multiple exception signals and should be investigated first?

---

# Analytical Framework

The project follows a structured business-to-analysis workflow:

```text id="76423w"
Business Problem
        ↓
Stakeholder Requirements
        ↓
Business Questions
        ↓
Raw P2P Event Data
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
Decision-Support Dashboard
        ↓
Business Recommendations
```

---

# Analytical Data Model

The source dataset is event-level.

Example:

```text id="61qhpo"
Case001 → Create Purchase Order Item
Case001 → Record Goods Receipt
Case001 → Vendor creates invoice
Case001 → Record Invoice Receipt
Case001 → Clear Invoice
```

For management analysis, a separate **case-level analytical model** will be created.

Expected structure:

```text id="ouy0y7"
case_id
vendor
company
spend_area
item_category
case_start
case_end
cycle_time
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

This case-level dataset will become the primary analytical model for:

* SQL,
* Python,
* Excel,
* and Power BI.

---

# Exception Framework

The project uses clearly defined exception categories.

## Purchase-Order Modification

Examples:

```text id="tkvp89"
Change Quantity
Change Price
Change Approval for Purchase Order
Change Delivery Indicator
Change Storage Location
Change Currency
Change payment term
```

These events will be used to calculate:

* PO Change Count
* PO Change Rate
* cases with PO rework

---

## Invoice Reversal

Primary indicator:

```text id="287fdi"
Cancel Invoice Receipt
```

Used to identify invoice-processing correction/reversal cases.

---

## Goods Receipt Reversal

Primary indicator:

```text id="f7g1ru"
Cancel Goods Receipt
```

Used to identify receipt-processing correction cases.

---

## Payment-Block Handling

The dataset contains:

```text id="cpmza8"
Set Payment Block
Remove Payment Block
```

These activities will be measured separately.

The analysis will distinguish between:

* Set Payment Block cases
* Remove Payment Block cases
* Any Payment Block Handling cases

---

## Repeated Activities

Activities occurring multiple times within the same case will be measured as a **process-complexity indicator**.

Repeated activity is not automatically treated as explicit rework.

---

# Planned KPI Framework

## Process KPIs

* Total P2P Cases
* Total Events
* Median Cycle Time
* P90 Cycle Time
* Long-Cycle Case Rate
* Number of Process Variants
* Top Variant Coverage
* Rare Variant Rate

## Exception KPIs

* PO Change Rate
* Invoice Reversal Rate
* Goods Receipt Reversal Rate
* Payment-Block Handling Rate
* Repeated-Activity Case Rate

## Complexity KPIs

* Average Events per Case
* Median Resource Handoffs
* Unique Activities per Case
* High-Complexity Case Count

## Investigation KPIs

* High-Priority Cases
* Exception Cases by Vendor
* Exception Cases by Spend Area
* Exception Rate by P2P Process Type

---

# Business Analysis Deliverables

The Business Analyst component focuses on translating the business problem into measurable analytical requirements.

Current BA deliverables:

```text id="3mlyhh"
ba/
├── P2P_Business_Case_BRD.pdf
├── stakeholder_register.xlsx
└── requirements_traceability.xlsx
```

These cover:

* business problem,
* problem statement,
* project scope,
* stakeholders,
* business requirements,
* business questions,
* analytical requirements,
* assumptions,
* constraints,
* success criteria,
* and requirement traceability.

---

# Data Analytics Deliverables

## SQL

```text id="21iyjw"
sql/
├── 01_data_validation.sql
├── 02_case_level_model.sql
├── 03_exception_analysis.sql
└── 04_business_analysis.sql
```

SQL will be used for:

* source validation,
* case-level transformation,
* exception classification,
* KPI calculation,
* segmentation,
* ranking,
* cycle-time analysis,
* and business investigations.

---

## Python

```text id="y7or32"
notebooks/
├── 01_data_understanding.ipynb
├── 02_process_analysis.ipynb
└── 03_root_cause_analysis.ipynb
```

Python will support:

* data profiling,
* data-quality investigation,
* activity analysis,
* process variants,
* cycle-time distributions,
* rework analysis,
* outlier investigation,
* root-cause exploration,
* and investigation prioritization.

---

## Excel

```text id="vcrtk5"
excel/
└── P2P_Exception_Analysis.xlsx
```

Excel will provide an operational review layer for:

* exception reconciliation,
* filtering,
* Pivot Tables,
* conditional formatting,
* vendor/category review,
* and management investigation.

---

## Power BI

```text id="so5d42"
powerbi/
├── P2P_Process_Intelligence.pbix
└── screenshots/
```

Planned dashboard pages:

### 1. Executive Overview

Overall process health and exception performance.

### 2. Process Variants

Actual P2P execution paths, frequency, and duration.

### 3. Exception & Root-Cause Analysis

PO changes, reversals, cycle time, handoffs, vendor and spend analysis.

### 4. Case Investigation

Transaction-level drill-through into exact event sequences and exception indicators.

---

# Business Analysis + Data Analysis Integration

The project intentionally combines both disciplines.

```text id="h37uzc"
BUSINESS ANALYST
      │
      ├── Business Problem
      ├── Stakeholders
      ├── Requirements
      ├── Process Analysis
      ├── Business Rules
      └── Acceptance Criteria
              │
              ▼
         DATA ANALYST
              │
              ├── Data Validation
              ├── SQL
              ├── Python
              ├── KPI Analysis
              ├── Root-Cause Analysis
              └── Power BI
                      │
                      ▼
              BUSINESS DECISION
```

Neither role is added artificially.

The BA work defines **what needs to be solved and why**.

The DA work determines **what the data shows and what actions the evidence supports**.

---

# Analytical Integrity

The project maintains strict analytical boundaries.

It does not automatically classify:

```text id="udw34d"
Exception = Fraud
```

or:

```text id="jd4mho"
Rare Variant = Non-Compliance
```

or:

```text id="febrvv"
Repeated Activity = Confirmed Rework
```

or:

```text id="nzk3kh"
High Exception Vendor = Poor Supplier
```

Instead, exceptions and unusual patterns are treated as **signals requiring investigation**.

The project also avoids unsupported claims regarding:

* fraud,
* supplier credit risk,
* supplier quality,
* employee performance,
* financial loss,
* cost savings,
* ROI,
* and causation.

---

# Data Quality Strategy

The dataset contains several areas that require investigation before transformation.

## Duplicate-Looking Events

Repeated rows cannot automatically be removed because multiple identical-looking events may represent legitimate P2P business activities.

Duplicate handling will therefore distinguish:

```text id="6sqs2p"
True Duplicate Records
        VS
Legitimate Repeated Events
```

---

## Timestamp Validation

Unusually old timestamps exist relative to the dominant event period.

These records will be:

```text id="uv3ljw"
Detected
↓
Investigated
↓
Flagged
↓
Handled using documented rules
```

rather than silently deleted.

---

## Resource Validation

`User` and `org:resource` appear to contain equivalent resource information.

The fields will be formally validated before one is removed from the analytical model.

---

## Monetary Value Validation

`Cumulative net worth (EUR)` can vary within some cases.

Therefore the project will first determine its correct business grain before using it for financial exposure analysis.

---

# Repository Structure

```text id="he0fvg"
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

# Project Roadmap

| Phase | Workstream                          
| ----- | ----------------------------------- 
| 1     | Business Understanding              
| 2     | Data Understanding & Profiling      
| 3     | Data Preparation & Case Model       
| 4     | Exception Rules & KPI Framework     
| 5     | SQL Analysis                        
| 6     | Python Analysis                     
| 7     | Excel Operational Analysis          
| 8     | Power BI Development                
| 9     | Insight-to-Action & Recommendations 
| 10    | Portfolio & Interview Review        

---

---

# Project Goal

The final solution should enable business stakeholders to move from:

```text id="fx2v2k"
Raw P2P Event Data
```

to:

```text id="e293xv"
Process Visibility
       ↓
Exception Detection
       ↓
Root-Cause Investigation
       ↓
Case Prioritization
       ↓
Business Action
       ↓
Performance Monitoring
```

The emphasis of this project is **business decision-making, process understanding, analytical rigor, and evidence-based recommendations** rather than dashboard decoration.
