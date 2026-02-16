# Curated Layer - Reusable Business Entities

## Purpose

This layer contains **definitive business entities** that serve as the single source of truth for all analytical work. These models are:

- Fully enriched with business logic and reference data
- Maintained at granular grain (deal-level) for maximum flexibility
- **Designed to serve unlimited future analytical needs**

## Key Principle

**This is THE layer that enables reusability.** All future reports, dashboards, and analyses should build from these entities rather than going back to staging or intermediate layers.

The intermediate layer contains **transformations** (how we reshape data).  
The curated layer contains **entities** (what the business cares about).

Analysts and BI developers should work primarily with this curated layer.

---

## Models

### `deals`
Complete deal entity with lifecycle milestones, outcomes, and metadata.

**Grain:** One row per deal

**Enables:**
- Funnel analysis at any time grain (daily, weekly, monthly, quarterly)
- Win/loss analysis by reason, stage, or cohort
- Sales cycle velocity and duration metrics
- Conversion rate analysis across stages
- Pipeline forecasting and capacity planning
- Cohort retention and progression analysis

**Key Columns:**
- Creation timestamps at multiple grains (day, week, month, quarter)
- 9 stage milestone timestamps
- Lost reason (ID and label)
- Outcome flags (is_won, is_lost)
- Sales cycle duration

---

## Data Quality Notes

### Activity Data Exclusion

**Finding:**
Only 6 of 2,288 activity records (0.3%) matched deal IDs, suggesting activities 
are tracked in a separate lead management system while deals represent pipeline opportunities.

**Validation Tests Outcomes:**

1. **Timeline Consistency:** 3 of 6 matches (50%) had activities logged 3-6 months 
   BEFORE the deal was created. Activity types included "after_close_call" and 
   "Sales Call 2" occurring before deals existed—physically impossible scenarios.

2. **User Ownership:** All 6 matches (100%) had different users owning the deal 
   versus the activity, indicating separate systems with independent user assignments.

3. **Business Logic:** Activities like "after_close_call" appearing before deal 
   creation and "Sales Call 2" occurring before "Sales Call 1" violate fundamental 
   business process logic.

4. **Statistical Coverage:** Even if valid, only 1-2 deals would appear in 
   activity-based funnel sub-steps (0.05% coverage)—statistically meaningless for analysis.

**Conclusion:**
The 6 matching IDs are coincidental collisions between two separate systems with 
independent ID sequences, not legitimate cross-references to the same business entities.

**Decision:**
All activity data has been excluded from the curated layer and final reporting. 
The funnel analysis contains only the 9 stage-based steps, which are complete, 
trustworthy, and provide comprehensive deal progression analysis.

**For Activity Analysis:**
Activity data remains available in `stg_activity` for use cases that don't require 
deal attribution:
- Activity volume by type, user, or time period
- Activity completion rates
- User productivity metrics

However, activities CANNOT be reliably joined to deals for conversion analysis, 
funnel sub-steps, or attribution to deal outcomes.

---

### Lost Reason on Won Deals

Investigation revealed that lost_reason values were systematically being set 1-39 days 
AFTER deals reached stage 9 (won status). This affected all 324 won deals and represents 
a CRM workflow issue where lost_reason appears to be a required field for all closed deals.

**Resolution:**
The intermediate layer (`int_deal_milestones`) filters out lost_reasons set after 
stage 9 is reached, preserving only legitimate lost_reasons set during the deal lifecycle.

**Edge Case:**
One deal (554294) has a lost_reason because it was legitimately marked as lost (Oct 8) 
before recovering and winning (Oct 26). The `is_lost` flag correctly shows `false` 
despite having a `lost_reason_id`, as the deal ultimately won.

---

## Usage Examples

### Example 1: Weekly Funnel Analysis
```sql
select
    creation_week as week,
    count(case when stage_1_reached_at is not null then 1 end) as step_1_count,
    count(case when stage_2_reached_at is not null then 1 end) as step_2_count,
    count(case when stage_9_reached_at is not null then 1 end) as won_count
from public_curated.deals
group by creation_week
order by creation_week;
```

### Example 2: Sales Cycle Duration by Quarter
```sql
select
    creation_quarter,
    avg(sales_cycle_duration) as avg_cycle_duration,
    count(*) filter (where is_won) as won_deals,
    count(*) filter (where is_lost) as lost_deals
from public_curated.deals
group by creation_quarter;
```

### Example 3: Win/Loss Analysis by Lost Reason
```sql
select
    lost_reason,
    count(*) as deal_count,
    round(100.0 * count(*) / sum(count(*)) over (), 2) as pct_of_total
from public_curated.deals
where is_lost = true
group by lost_reason
order by deal_count desc;
```


**Note:** See project EDA documentation for detailed analysis and recommendations 
to address this limitation at the source system level.

## Future Use Cases Supported

- Different time aggregations (daily, weekly, monthly, quarterly)  
- Different dimensional cuts (rep, product, region, segment)  
- Different analyses (cohort, win/loss, velocity, forecasting)  
- Different consumers (dashboards, ad-hoc queries, ML models)
