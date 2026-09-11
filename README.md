# Purchase-to-Pay-Process-Mining-Exception-Intelligence

Portfolio focus: Data Analyst + Business Analyst
Dataset: BPI Challenge 2019 P2P event log converted to CSV

Project Summary

This project analyzes a large Purchase-to-Pay (P2P) event log to understand how transactions are actually executed, where operational rework and exceptions occur, which process paths experience long cycle times, and which cases or process segments should be prioritized for investigation.

The project combines Business Analysis (business problem, scope, stakeholders, requirements, process analysis, acceptance criteria) with Data Analysis (SQL, Python, Excel, Power BI, KPI analysis, process variants, cycle time, and root-cause exploration).

Validated Dataset Baseline

Metric

Value

Event rows

1,595,923

Columns

21

Unique P2P cases

251,734

Purchasing documents

76,349

Vendors

1,975

Activities

42

Companies

4

The raw CSV is intentionally not committed to GitHub because of size and reproducibility concerns. The data/README.md documents how the source data is handled.

Business Problem

A multinational organization processes a high volume of P2P transactions across vendors, purchasing processes, spend categories, and operational resources. Although many transactions follow common purchasing and invoice-processing paths, others contain purchase-order modifications, approval changes, goods-receipt reversals, invoice reversals, payment-block handling, repeated activities, and unusual process sequences.

Management lacks a consolidated analytical view of how transactions actually move through the P2P process, where operational rework and processing delays occur, and which cases or process segments contribute disproportionately to process complexity.

The project therefore develops a data-driven P2P process-intelligence solution to reconstruct actual transaction flows, measure process performance, identify exception and rework patterns, and prioritize cases/process areas requiring investigation and improvement.

Key Business Questions

What process variants occur and which ones dominate the case population?

Which variants and segments have the longest median and P90 cycle times?

How frequently are purchase orders modified and where is modification concentrated?

How frequently are invoice receipts reversed?

How frequently are goods receipts reversed?

Which cases contain payment-block handling and how do they progress?

Which vendors have disproportionately high exception rates after controlling for volume?

Are repeated activities and resource handoffs associated with longer processing time?

How do 2-way and 3-way matching process groups differ?

Which cases combine multiple investigation signals and should be reviewed first?

Project Scope

In Scope

Event-log validation and profiling

Event-level and case-level analytical models

Process variant and cycle-time analysis

PO modifications / rework

Invoice and goods-receipt reversals

Payment-block handling

Repeated activities and resource handoffs

Vendor and purchasing-dimension benchmarking

Case investigation prioritization

SQL, Python, Excel, Power BI and BA deliverables

Out of Scope

Fraud prediction

Supplier credit/quality scoring

Employee performance evaluation

Unsupported financial-loss, savings or ROI claims

Contract-price validation without supporting data

Automated ERP write-back

Phase 1 Deliverables

ba/P2P_Business_Case_BRD.pdf - consolidated business case and Phase 1 BRD

ba/stakeholder_register.xlsx - concise power/interest and RACI stakeholder register

ba/requirements_traceability.xlsx - business questions mapped to dataset evidence, metrics and stakeholders

Repository Structure

p2p-process-intelligence/
├── README.md
├── .gitignore
├── data/
│   └── README.md
├── ba/
│   ├── P2P_Business_Case_BRD.pdf
│   ├── stakeholder_register.xlsx
│   └── requirements_traceability.xlsx
├── sql/
├── notebooks/
├── excel/
├── powerbi/
│   └── screenshots/
└── docs/

Analytical Boundaries

An exception is an investigation signal, not proof of fraud or financial loss.

Repeated activities are not automatically classified as rework.

Rare process variants are not automatically non-compliant.

Payment-block events require careful set/remove interpretation.

Monetary exposure will not be aggregated at raw event grain until its case-level meaning is validated.

Associations in event data will not be presented as proven causation without supporting evidence.

Tools Planned

SQL | Python (Pandas / NumPy / Matplotlib) | Excel | Power BI | Business Analysis / Process Analysis
