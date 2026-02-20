
  
    

  create  table "postgres"."public_marts"."rep_sales_funnel_monthly__dbt_tmp"
  
  
    as
  
  (
    /*
    Model: rep_sales_funnel_monthly
    
    Purpose:
        Monthly sales funnel report showing deal progression through 9 stage-based
        steps. Aggregates deals by creation month cohort and counts how many reached
        each funnel milestone.
    
    Grain: month × funnel_step (one row per month per step)
    
    Columns:
        - month: First day of month when deals were created
        - kpi_name: Human-readable funnel step name
        - funnel_step: Numeric step identifier (1-9)
        - deals_count: Number of deals from this cohort that reached this step
    
    Design:
        Uses a date spine to ensure all month × step combinations exist, even when
        counts are zero. This prevents gaps in time-series visualizations and ensures
        report completeness.
    
    Note:
        Activity-based sub-steps (2.1 Sales Call 1, 3.1 Sales Call 2) are included
        but return zero counts due to documented data quality issues. See project EDA
        for validation details.
*/


with deals_base as (

    select
        creation_month,
        stage_1_reached_at,
        stage_2_reached_at,
        stage_3_reached_at,
        stage_4_reached_at,
        stage_5_reached_at,
        stage_6_reached_at,
        stage_7_reached_at,
        stage_8_reached_at,
        stage_9_reached_at
    
    from "postgres"."public_curated"."deals"

),

-- Get all unique months from deals
months_spine as (

    select 
        distinct creation_month as month
    
    from deals_base

),

-- Define all funnel steps including activity-based sub-steps
steps_spine as (

    select * from (
        values
            ('1', 'Lead Generation'),
            ('2', 'Qualified Lead'),
            ('2.1', 'Sales Call 1'),
            ('3', 'Needs Assessment'),
            ('3.1', 'Sales Call 2'),
            ('4', 'Proposal/Quote Preparation'),
            ('5', 'Negotiation'),
            ('6', 'Closing'),
            ('7', 'Implementation/Onboarding'),
            ('8', 'Follow-up/Customer Success'),
            ('9', 'Renewal/Expansion')
    ) as t(funnel_step, kpi_name)

),

-- Create complete spine: every month × every step
complete_spine as (

    select
        months.month,
        steps.funnel_step,
        steps.kpi_name

    from months_spine as months
    
    cross join steps_spine as steps

),

-- Calculate actual counts per step
step_counts as (

    select
        creation_month as month,
        '1' as funnel_step,
        count(case when stage_1_reached_at is not null then 1 end) as deals_count
    
    from deals_base
    group by creation_month

    union all

    select
        creation_month as month,
        '2' as funnel_step,
        count(case when stage_2_reached_at is not null then 1 end) as deals_count
    
    from deals_base
    group by creation_month

    union all

    select
        creation_month as month,
        '3' as funnel_step,
        count(case when stage_3_reached_at is not null then 1 end) as deals_count
    
    from deals_base
    group by creation_month

    union all

    select
        creation_month as month,
        '4' as funnel_step,
        count(case when stage_4_reached_at is not null then 1 end) as deals_count
    
    from deals_base
    group by creation_month

    union all

    select
        creation_month as month,
        '5' as funnel_step,
        count(case when stage_5_reached_at is not null then 1 end) as deals_count
    
    from deals_base
    group by creation_month

    union all

    select
        creation_month as month,
        '6' as funnel_step,
        count(case when stage_6_reached_at is not null then 1 end) as deals_count
    
    from deals_base
    group by creation_month

    union all

    select
        creation_month as month,
        '7' as funnel_step,
        count(case when stage_7_reached_at is not null then 1 end) as deals_count
    
    from deals_base
    group by creation_month

    union all

    select
        creation_month as month,
        '8' as funnel_step,
        count(case when stage_8_reached_at is not null then 1 end) as deals_count
    
    from deals_base
    group by creation_month

    union all

    select
        creation_month as month,
        '9' as funnel_step,
        count(case when stage_9_reached_at is not null then 1 end) as deals_count
    
    from deals_base
    group by creation_month

),

final as (

    select
        spine.month,
        spine.kpi_name,
        spine.funnel_step,
        coalesce(counts.deals_count, 0) as deals_count
    
    from complete_spine as spine

    left join step_counts as counts
        on spine.month = counts.month
        and spine.funnel_step = counts.funnel_step

    order by spine.month, spine.funnel_step

)

select * from final
  );
  