# Pipedrive CRM Sales Funnel Analysis

## Project Summary

This dbt project transforms Pipedrive CRM data into a monthly sales funnel report using a **four-layer architecture** designed for maximum reusability. While the immediate deliverable is `rep_sales_funnel_monthly`, the data layers are structured to serve unlimited future analytical needs.

### Deliverable
**Model:** `rep_sales_funnel_monthly`  
**Location:** `models/marts/rep_sales_funnel_monthly.sql`  
**Output Schema:** `public_marts`  
**Grain:** One row per (month × funnel_step)  
**Columns:** `month`, `kpi_name`, `funnel_step`, `deals_count`

---

## Key Architectural Decisions

### Four-Layer Design
1. **Staging** - Clean, standardized source data (1:1 with sources)
2. **Intermediate** - Business logic transformations at deal-level grain
3. **Curated** - Reusable business entities (THE FOUNDATION)
4. **Marts** - Pre-aggregated, use-case specific reports

**Why This Matters:**  
The curated `deals` model serves as a reusable foundation for unlimited future analyses (funnel at any time grain, win/loss analysis, sales cycle metrics, forecasting, etc.). New reports can be built quickly without rebuilding base transformations.

---

## Data Modeling Approach

This project uses **entity-based modeling** with a layered architecture, following modern analytics engineering best practices:

- **Entity-based design:** Core business entities (`deals`) maintained at granular (deal-level) grain for flexibility
- **Wide table pattern:** Denormalized entities with pre-joined dimensions (stage names, lost_reason labels) for query simplicity
- **Layered transformation:** Staging → Intermediate → Curated → Marts (inspired by Medallion architecture)
- **Reusability focus:** Curated layer serves as foundation for multiple use cases

**Why Not Traditional Star Schema:**  
Rather than creating separate fact and dimension tables, this approach uses enriched wide tables at the curated layer. This trade-off prioritizes:
- Query simplicity (no complex joins required)
- Rapid development (single source of truth per entity)
- Flexibility (easy to aggregate at any grain)

This approach balances query performance with architectural flexibility, enabling rapid development of new reports without rebuilding base transformations.

---

## Data Quality Testing Strategy

### Testing Levels
- **Staging:** Source data integrity (primary keys, relationships, not-null constraints)
- **Intermediate:** Grain validation (deal_id uniqueness, required timestamps)
- **Curated:** Business logic correctness (outcome flags, derived metrics)
- **Marts:** Report completeness (month × step combinations, accepted values)

### Key Validations
- **Primary key uniqueness** tested at every layer
- **Referential integrity** between activity types, users, and deals
- **Not-null constraints** on critical fields (deal_id, created_at, creation_month)
- **Accepted values** for funnel_step (1-9, 2.1, 3.1)
- **Expression tests** for deals_count (>= 0)

### Initial Data Quality Investigations - Key Findings & Decisions

**See:** `analyses/exploratory_analysis.md` for comprehensive validation queries and findings.

#### 1. Activity Data Exclusion
**Finding:** Only 6 of 2,288 activity records (0.26%) matched pipeline deals  
**Validation:**
- 50% had activities 3-6 months BEFORE deal creation (questionable timelines)
- 100% had different user ownership (deal owner ≠ activity assignee)
- Activity types violated business logic ("after_close_call" before deal exists)

**Root Cause:** Activities likely tracked in separate lead management system with independent ID sequence (ID collisions, not legitimate cross-references)

**Decision:** Excluded activity data from intermediate and curated layers. Steps 2.1 (Sales Call 1) and 3.1 (Sales Call 2) included in final report but return zero counts. The reporting model can be enriched when accurate data is available.

#### 2. Lost Reason Filtering
**Finding:** All 324 won deals had lost_reason values set 1-39 days AFTER reaching stage 9  
**Root Cause:** CRM workflow issue requiring lost_reason for all closed deals  
**Decision:** Filter lost_reasons set after stage 9 in `int_deal_milestones` to prevent won deals being incorrectly flagged as lost

**See:** `analyses/exploratory_analysis.md` Section 1.4 for timing analysis

---

## Project Structure
```
├── analyses/
│   └── exploratory_analysis.md    # Comprehensive EDA with validation queries
├── models/
│   ├── staging/                   # 6 source-aligned models
│   ├── intermediate/              # int_deal_milestones (transformations)
│   ├── curated/                   # deals (reusable business entity)
│   │   └── README.md             # Curated layer documentation
│   ├── marts/                     # rep_sales_funnel_monthly (deliverable)
│   └── documentation.md           # dbt doc blocks
├── dbt_project.yml
└── README.md                      # This file
```

---

## Funnel Report Details

### Structure
- **11 funnel steps** (9 stage-based + 2 activity-based placeholders)
- **Date spine implementation** ensures all month × step combinations exist (no gaps in time-series)
- **Zero counts preserved** for steps with no deals (prevents visualization issues)

### Steps Included
1. Lead Generation (Stage 1)
2. Qualified Lead (Stage 2)
2.1. Sales Call 1 (Activity - returns 0)
3. Needs Assessment (Stage 3)
3.1. Sales Call 2 (Activity - returns 0)
4. Proposal/Quote Preparation (Stage 4)
5. Negotiation (Stage 5)
6. Closing (Stage 6)
7. Implementation/Onboarding (Stage 7)
8. Follow-up/Customer Success (Stage 8)
9. Renewal/Expansion (Stage 9)

---

## Known Limitations

1. **Activity-based sub-steps (2.1, 3.1)** return zero counts due to validated data quality issues
2. **Activity data** available in `stg_activity` but cannot be reliably joined to pipeline deals
3. **Lost reasons** for won deals filtered out (spurious CRM workflow artifacts)

---

## Recommendations for Future Enhancement

### 1. Implement Lead-to-Deal ID Preservation (High Priority)
Configure Pipedrive to preserve lead IDs during conversion to ensure activity history follows deals through the pipeline.

### 2. Create Mapping Table (Medium Priority)
Build `lead_deal_mapping` table linking lead IDs to deal IDs to enable historical activity enrichment.

### 3. Add Business Identifiers (Medium Priority)
Include company name, email domain, or customer ID in both systems to enable matching when IDs don't align.

### 4. System Consolidation (Long-Term)
Evaluate migrating all customer tracking to single platform to reduce data fragmentation.

---

## How to Run

### Prerequisites
- Docker Desktop installed and running
- Python 3.8+ with dbt-core and dbt-postgres
- PostgreSQL client (DataGrip, DBeaver, pgAdmin, etc.)

### Setup Steps

1. **Start the database:**
```bash
   docker compose up
```

2. **Database credentials:**
```
   Host: localhost
   User: admin
   Password: admin
   Port: 5432
```

3. **Install dbt dependencies:**
```bash
   dbt deps
```

4. **Run the project:**
```bash
   # Build all models
   dbt run

   # Run tests
   dbt test

   # Generate documentation
   dbt docs generate
   dbt docs serve
```

5. **Query the deliverable:**
```sql
   SELECT * FROM public_marts.rep_sales_funnel_monthly
   ORDER BY month, funnel_step;
```
---

## Original Assignment Instructions

## Setup

1. Download Docker Desktop (if you don’t have installed) using the official website, install and launch.
2. Fork this Github project to you Github account. Clone the forked repo to your device.
3. Open your Command Prompt or Terminal, navigate to that folder, and run the command `docker compose up`.
4. Now you have launched a local Postgres database with the following credentials:
 ```
    Host: localhost
    User: admin
    Password: admin
    Port: 5432 
```
5. Connect to the db via a preferred tool (e.g. DataGrip, Dbeaver etc)
6. Install dbt-core and dbt-postgres using pip (if you don’t have) on your preferred environment.
7. Now you can run `dbt run` with the test model and check public_pipedrive_analytics schema to see the dbt result (with one test model)

## Project
1. Remove the test model once you make sure it works
2. Dive deep into the Pipedrive CRM source data to gain a thorough understanding of all its details. (You may also research the Pipedrive CRM tool terms).
3. Define DBT sources and build the necessary layers organizing the data flow for optimal relevance and maintainability.
4. Build a reporting model (rep_sales_funnel_monthly) with monthly intervals, incorporating the following funnel steps (KPIs):  
  &nbsp;&nbsp;&nbsp;Step 1: Lead Generation  
  &nbsp;&nbsp;&nbsp;Step 2: Qualified Lead  
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Step 2.1: Sales Call 1  
  &nbsp;&nbsp;&nbsp;Step 3: Needs Assessment  
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Step 3.1: Sales Call 2  
  &nbsp;&nbsp;&nbsp;Step 4: Proposal/Quote Preparation  
  &nbsp;&nbsp;&nbsp;Step 5: Negotiation  
  &nbsp;&nbsp;&nbsp;Step 6: Closing  
  &nbsp;&nbsp;&nbsp;Step 7: Implementation/Onboarding  
  &nbsp;&nbsp;&nbsp;Step 8: Follow-up/Customer Success  
  &nbsp;&nbsp;&nbsp;Step 9: Renewal/Expansion
5. Column names of the reporting model: `month`, `kpi_name`, `funnel_step`, `deals_count`
6. “Git commit” all the changes and create a PR to your forked repo (not the original one). Send your repo link to us.
