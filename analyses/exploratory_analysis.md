# Exploratory Data Analysis (EDA)

This analysis investigates the structure, relationships, and business logic of the six Pipedrive CRM source tables. SQL queries were executed to validate assumptions, identify table grain, and derive rules for dbt modeling.

---

# 1. Table-Level Validation

## 1.1 stages

### Uniqueness check

```sql
select 
    count(*) as total_rows,
    count(distinct stage_id) AS distinct_stage_ids

from public.stages;
```

### Field inspection
```sql
select 
    stage_id, 
    stage_name

from public.stages
order by stage_id;
```

**Insights:**  
- Clean primary key: `stage_id` has 9 unique values.  
- Direct mapping to funnel stages (1–9) defined in assignment.

---

## 1.2 activity_types

### Uniqueness check 

```sql
select 
    count(*) AS total_rows,
    count(distinct id) as distinct_type_ids

from public.activity_types;
```

### Field inspection 

```sql
select 
    type, 
    name

from public.activity_types;
```

**Insights:**  
- Unique primary key.  
- The dataset includes multiple distinct activity types. A review of the corresponding name field indicates these represent meaningful CRM actions.
- These activity types (e.g., "meeting", "sc_2") can be mapped to specific funnel sub-steps such as Sales Call 1 and Sales Call 2, which contribute to Steps 2.1 and 3.1 of the funnel.

---

## 1.3 activity

### Uniqueness check

```sql
select
    count(*) as total_rows,
    count(distinct activity_id) AS distinct_ids,
    count(distinct deal_id) AS distinct_deals

from public.activity;

---
select 
    deal_id,
    activity_id 
    
from public.activity
group by 1,2
having count(*) > 1;
```

**Insight:**   
- `activity_id` is not globally unique and can appear across multiple deals.  
- Each `(activity_id, deal_id)` combination appears only once, indicating that activities may be reassigned between deals rather than duplicated within the same deal.

### Check "done" distribution

```sql
select 
    done, 
    count(*) 

from public.activity
group by done;
```

**Insight:**  
- Funnel steps 2.1 and 3.1 should use only done = true. Since the two funnel sub-steps - Sales Call 1 and Sales Call 2, depend on `activity` data, using only completed activities (`done = true`) provides an accurate reflection of actual funnel progress.

---

## 1.4 deal_changes

### Uniqueness check

```sql
select 
    count(*) as total_rows,
    count(distinct deal_id) as distinct_deals

from public.deal_changes;
```

**Insight:**  
- Multiple change events per deal → event-grain table.

### Change fields observed

```sql
select 
    distinct changed_field_key

from public.deal_changes;
```

**Insight:**  
- Key fields of interest:  
  - `add_time` (creation time)  
  - `stage_id` (funnel transitions)  

### Validate stage_id references

```sql
select 
    distinct new_value

from public.deal_changes
where changed_field_key = 'stage_id';
```

**Insight:**  
- All values appear in stages table — consistent dataset.

### Creation timestamp extraction feasibility

```sql
select deal_id,
    min(change_time) filter (where changed_field_key = 'add_time') as created_at

from public.deal_changes
group by deal_id;
```

**Insight:**  
- `add_time` exists for all deals → reliable cohorting field.

### deal stage distribution

```sql
select 
    new_value as stage_id,
    count(distinct deal_id) as deals_reached_stage

from public.deal_changes
where changed_field_key = 'stage_id'
group by new_value
order by stage_id;
```

**Insight:**  
- The number of deals decreases as stage_id increases, reflecting natural funnel drop-off.
- Deals that never appear for a given stage_id simply did not reach that step and therefore will not have a timestamp for it.

### Lost reason timing pattern
```sql
with won_deals_timeline as (
    select 
        d.deal_id,
        min(case when d.changed_field_key = 'stage_id' and d.new_value = '9' 
            then d.change_time end) as stage_9_reached_at,
        min(case when d.changed_field_key = 'lost_reason' 
            then d.change_time end) as lost_reason_set_at
    from public.deal_changes d
    group by d.deal_id
    having min(case when d.changed_field_key = 'stage_id' and d.new_value = '9' 
               then d.change_time end) is not null
       and min(case when d.changed_field_key = 'lost_reason' 
               then d.change_time end) is not null
)
select 
    count(*) as total_won_deals_with_lost_reason,
    count(case when lost_reason_set_at > stage_9_reached_at then 1 end) as lost_reason_after_win,
    min(lost_reason_set_at - stage_9_reached_at) as earliest_gap,
    max(lost_reason_set_at - stage_9_reached_at) as latest_gap,
    avg(lost_reason_set_at - stage_9_reached_at) as avg_gap
from won_deals_timeline;
```

**Insight:**
- All 324 won deals have lost_reason values set 1-39 days AFTER reaching stage 9 (average: ~15 days)
- Suggests lost_reason may be a required field in CRM workflow for all closed deals, regardless of outcome
- Deal 102496 example: Won on Jun 22, lost_reason "Product Mismatch" set Jul 1 (9 days later)
- For accurate win/loss analysis, lost_reasons set after stage 9 should be filtered out

---

## 1.5 fields

### validate structure

```sql
select * from public.fields;
```

**Insight:**  
- Fields table contains metadata only.  
- No direct obvious role in funnel modeling except enrichment of source data like deal_changes.


### Expand and inspect JSON values
```sql
select 
    f.field_key,
    value->>'id' as option_id,
    value->>'label' as option_label

from public.fields f,
     json_array_elements(f.field_value_options::json) as value
where f.field_key in ('stage_id', 'lost_reason')
order by f.field_key, option_id;
```

**Insight:**
- JSON arrays expand cleanly and contain well-structured `id`/`label` pairs.
- The stage metadata includes exactly 9 stages, matching the stages table and the required funnel steps.
- Although not required for funnel KPIs, these lookups can enrich intermediate models (e.g., mapping lost_reason to its label)

---

## 1.6 users

### Uniqueness validation

```sql
select 
    count(*) as total_rows,
    count(distinct id) as distinct_ids

from public.users;
```

**Insight:**  
- User table contains unique IDs with no duplication.

### Check for missing emails or names

```sql
select 
    sum(case when coalesce(email,'') = '' then 1 else 0 end) as missing_emails,
    sum(case when coalesce(name,'') = '' then 1 else 0  end) as missing_names

from public.users;
```

**Insight:**  
- CRM users have no missing names or emails; dataset complete.

---

# 2. Relationship Validation

## 2.1 Check activity types present in data

```sql
select 
    distinct a.type

from public.activity a
left join public.activity_types t on a.type = t.type
where t.type is null;
```

**Insight:**  
- The query returns 0 rows, confirming that every activity `type` used in the `activity` table is defined in `activity_types`, indicating a consistent and complete mapping of activity categories

---

## 2.2 Validate assigned_to_user exists

```sql
select
    count(*) as missing_users

from public.activity a
left join public.users u on a.assigned_to_user = u.id
where u.id is null;
```

**Insight:**  
- Missing users would indicate incomplete CRM extraction.  
- Dataset is complete as no missing users.

## 2.3 Activity-to-deal linkage validation

### Initial discovery
```sql
select 
    count(*) as missing_deal_links
from public.activity a
left join public.deal_changes dc on a.deal_id = dc.deal_id
where dc.deal_id is null;
```

**Finding:**  
The query returns **4,000+ rows**, indicating that a significant number of activity records reference deal_ids that do not exist in the deal_changes table.

---

### Focus on sales call activities
```sql
select 
    count(distinct a.deal_id) as activity_deals,
    count(distinct dc.deal_id) as deals_also_in_changes,
    count(distinct case when dc.deal_id is null then a.deal_id end) as unmatched_deals
from public.activity a
left join public.deal_changes dc on a.deal_id = dc.deal_id
where a.done = true
  and a.type in ('meeting', 'sc_2');
```

**Insight:**
- Of 1,128 deals with completed sales call activities, only 2 (0.2%) exist in deal_changes
- 1,126 deals (99.8%) are unmatched
- This represents a near-complete disconnect between activity logging and deal tracking systems

---

### Matching deal validation

**Query: Count deals with activities vs total deals**
```sql
select 
    (select count(distinct deal_id) from public.activity where done = true) as deals_with_activities,
    (select count(distinct deal_id) from public.deal_changes) as deals_in_pipeline,
    count(distinct d.deal_id) as matching_deals,
    round(100.0 * count(distinct d.deal_id) / 
          (select count(distinct deal_id) from public.activity where done = true), 2) as match_rate_pct
from public.deal_changes d
inner join public.activity a 
    on d.deal_id = a.deal_id 
    and a.done = true;
```

**Result:**
- 2,288 deals with completed activities
- 1,995 deals in pipeline
- Only 6 matching deals (0.26% match rate)

---

### Timeline and business logic validation

**Query: Check if activities occurred before deal creation**
```sql
select 
    a.deal_id,
    min(case when dc.changed_field_key = 'add_time' then dc.change_time end) as deal_created,
    a.due_to as activity_date,
    a.type,
    a.assigned_to_user as activity_owner
from public.activity a
inner join public.deal_changes dc on a.deal_id = dc.deal_id
where a.deal_id in (206594, 264879, 278788, 640838, 672206, 984965)
  and a.done = true
group by a.deal_id, a.due_to, a.type, a.assigned_to_user
order by a.deal_id;
```

**Key Findings:**
- 3 of 6 deals (50%) have activities 3-6 months BEFORE deal creation
- Includes "after_close_call" and "sc_2" activity types before deals exist
- Violates business logic (cannot have "after close call" before deal created)

---

**Query: Compare deal owners vs activity owners**
```sql
select 
    a.deal_id,
    max(case when dc.changed_field_key = 'user_id' then dc.new_value end) as deal_owner,
    a.assigned_to_user as activity_owner
from public.activity a
inner join public.deal_changes dc on a.deal_id = dc.deal_id
where a.deal_id in (206594, 264879, 278788, 640838, 672206, 984965)
  and a.done = true
group by a.deal_id, a.assigned_to_user
order by a.deal_id;
```

**Key Findings:**
- All 6 matches (100%) have different users owning deal vs activity
- Indicates separate systems with independent user assignments

---

### Date range comparison

```sql
select 
    'deal_changes' as source,
    min(change_time) as earliest_date,
    max(change_time) as latest_date
from public.deal_changes

union all

select 
    'activity' as source,
    min(due_to) as earliest_date,
    max(due_to) as latest_date
from public.activity
where done = true
  and type in ('meeting', 'sc_2');
```

**Insight:**
- deal_changes: Jan 2024 - Mar 2025 (15 months)
- activity data: Jan 2024 - Sept 2024 (9 months)
- Both datasets cover the same deal creation period (Jan-Sept 2024)
- Activity-deal disconnect is not due to temporal mismatch

---

**Conclusion:**

The 6 matching deal_ids are coincidental ID collisions between two separate systems, not legitimate cross-references:

1. **Timeline evidence:** 50% have activities occurring 3-6 months before deal creation, including "after_close_call" activities before deals exist—physically impossible scenarios

2. **User ownership evidence:** 100% have different users owning the deal versus the activity, indicating separate systems with independent user assignments

3. **Business logic evidence:** Activity types like "after_close_call" appearing before deal creation and "Sales Call 2" occurring before deals reach "Sales Call 1" violate fundamental business process logic

4. **Statistical evidence:** Only 0.26% of activities (6 of 2,288) match pipeline deals—statistically implausible if systems were integrated

**Root Cause:**
Activities are likely logged in a lead management system while deals represent pipeline opportunities. The two systems use independent ID sequences with no cross-reference mechanism, resulting in 99.7% of activities being orphaned from pipeline deals.

---

# 3. Data Quality Observations Summary

### Activity-Deal Disconnect
- **99.7% of activity records** do not match pipeline deals (only 6 of 2,288 deals with completed activities match)
- Validation revealed ID collisions rather than legitimate cross-references:
  - 50% have activities logged 3-6 months before deal creation
  - 100% have mismatched user ownership (deal owner ≠ activity assignee)
  - Activity types violate business logic ("after_close_call" before deal exists)
- **Root cause:** Activities tracked in separate lead management system with independent ID sequence
- **See Section 2.3** for comprehensive validation analysis

### Lost Reason Timing Issue
- **All 324 won deals** (100%) have lost_reason values set 1-39 days AFTER reaching stage 9
- Average gap: ~15 days after winning
- **Root cause:** CRM workflow issue where lost_reason appears to be required field for all closed deals
- **See Section 1.4** for timing analysis

### General Data Quality
- **No missing stage references** - all stage_id values exist in stages table
- **No undefined activity types** - all activity types defined in activity_types table
- **Complete user data** - no missing names or emails in users table
- **Reliable creation timestamps** - add_time exists for all deals
- **Activity completion status** - activities include both completed (`done = true`) and uncompleted events; only completed activities considered for analysis
- **Data coverage limitation** - activity data stops September 2024 while deal_changes continues through March 2025 (both cover same deal creation period Jan-Sept 2024)
- **Funnel drop-off** - some deals stagnate in early stages (expected CRM behavior reflecting natural funnel attrition)

---

# 4. Key Insights Relevant to Funnel Modeling

- **Stages map exactly to 9 funnel steps** → direct alignment with assignment specification
- **Stage transitions from deal_changes** determine entry timestamp for each funnel step
- **Funnel modeling requires first occurrence per step** per deal (use MIN aggregation for timestamps)
- **Deals may not reach all steps** → those steps will have NULL timestamps (expected funnel drop-off)
- **Monthly aggregation** → group deals by creation month, then count deals that reached each step
- **Activity-based sub-steps included with zero counts** → Due to validated data quality issues (see Section 3), sub-steps 2.1 and 3.1 are included in the funnel report but return zero for all months. Activity data (Sales Call 1, Sales Call 2) cannot be reliably linked to pipeline deals. The 9 stage-based steps provide complete, trustworthy funnel progression data.

---

# 5. Four-Layer Architecture Design

This project implements a **four-layer dbt architecture** prioritizing reusable business entities over report-specific transformations. While the immediate deliverable is a monthly sales funnel report, the data layers are designed to serve unlimited future analytical needs.

## 5.1 Staging Layer
Source-aligned models providing clean, standardized foundation (1:1 with sources).

- **stg_deal_changes** - Event-level deal change history with clean timestamps
- **stg_activity** - Standardized activity records with type normalization
- **stg_fields** - Field metadata with JSON value options for lookups
- **stg_stages** - Stage reference data with ordering
- **stg_activity_types** - Activity type reference with business names
- **stg_users** - User attributes for deal ownership

**Purpose:** Minimal transformation, data type standardization, naming conventions

---

## 5.2 Intermediate Layer
Business logic transformations preparing data for entity models.

- **int_deal_milestones**
  - Combines stage progression, deal creation timestamps, and outcome metadata
  - Pivots stage transitions to wide format (9 columns: `stage_1_reached_at` through `stage_9_reached_at`)
  - Extracts deal creation timestamp from `add_time` events
  - Captures latest `lost_reason` set BEFORE stage 9 (filters out spurious post-win lost reasons)
  - One row per deal with all temporal milestones
  - **Data quality filtering:** Excludes lost_reasons set after deals reached stage 9 (documented CRM workflow issue where all 324 won deals had lost_reasons set 1-39 days after winning)

**Purpose:** Apply transformations while maintaining deal-level grain for downstream flexibility

**Note on Activity Data:**
The staging layer includes `stg_activity` with completed activity records. However, comprehensive validation (see Section 2.3) revealed that only 6 of 2,288 activity records (0.26%) matched pipeline deals, with evidence of ID collisions rather than legitimate cross-references. Based on these findings, activity data will be excluded from the intermediate and curated layers to preserve data integrity.

---

## 5.3 Curated Layer (Reusable Business Entities)
**This is the foundation layer designed for maximum reusability.**

- **deals**
  - **Grain:** One row per deal
  - **Content:** 
    - Complete deal lifecycle with all 9 stage milestones
    - Creation timestamps at multiple grains (day, week, month, quarter) for flexible aggregation
    - Outcome metadata (lost_reason_id decoded to human-readable labels via `stg_fields`)
    - Outcome flags (`is_won`, `is_lost`) with proper business logic
    - Derived metrics (sales_cycle_duration)
  - **Enables:** 
    - Funnel analysis at any time grain (daily, weekly, monthly, quarterly)
    - Win/loss analysis by reason, stage, or cohort
    - Sales cycle velocity and duration metrics
    - Conversion rate analysis across stages
    - Pipeline forecasting and capacity planning
    - Cohort retention and progression analysis

**Why This Layer Matters:**
- Supports different aggregation levels (daily, weekly, monthly, quarterly)
- Enables different dimensional cuts (rep, product, region, segment)
- Powers different analysis types (funnel, win/loss, velocity, forecasting)
- Serves different consumers (dashboards, ad-hoc queries, ML models)

**Architectural Decision:**
The curated layer contains only the `deals` model. Activity data will be excluded based on validation findings showing unreliable activity-deal linkages (see Section 2.3). This design prioritizes data integrity over feature completeness, ensuring all curated entities are trustworthy and suitable for enterprise reporting.

---

## 5.4 Marts Layer (Reporting Aggregations)
Pre-aggregated models optimized for specific business questions.

- **rep_sales_funnel_monthly**
  - **Grain:** month × funnel_step
  - **Columns:** month, kpi_name, funnel_step, deals_count
  - **Content:** Monthly funnel progression across 9 stage-based steps
    - **Funnel Steps:**
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
  - **Source:** Aggregates from `deals` curated model
  - **Purpose:** Required deliverable demonstrating one use case of the curated layer

**Note on Assignment Specification:**
The original specification included activity-based sub-steps (2.1 Sales Call 1, 3.1 Sales Call 2). Based on comprehensive data quality validation findings, these sub-steps are included in the final report but return zero counts for all months due to unreliable activity-deal linkages. The 9 stage-based steps provide complete, trustworthy funnel progression data. See Section 2.3 for detailed validation findings and Section 3 for data quality summary.

**Future Marts (Examples of What's Possible):**
- `rep_sales_funnel_weekly` - Same funnel logic, weekly grain
- `rep_win_loss_by_reason` - Lost reason analysis by cohort
- `rep_sales_cycle_velocity` - Time-in-stage and conversion metrics

**Design Philosophy:** The curated layer is the investment; marts are specific applications built from that foundation.

---

# 6. Architecture Benefits

The four-layer structure separates concerns:

1. **Staging** - Source truth and data quality
2. **Intermediate** - Reusable transformations
3. **Curated** - Business entities
4. **Marts** - Use-case specific aggregations

This enables:
- New reports built quickly from curated layer (no need to rewrite transformations)
- Consistent business logic across all analyses
- Flexibility to aggregate at different grains without rebuilding base logic
- Clear separation between "how we transform data" and "what the business needs"
