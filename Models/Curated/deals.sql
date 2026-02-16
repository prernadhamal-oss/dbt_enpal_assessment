/*
    Model: deals
    
    Purpose:
        Complete deal entity combining stage progression, creation metadata,
        and outcome information. Serves as the foundational business entity
        for all deal-related analysis across the organization.
    
    Grain: One row per deal
    
    Reusability:
        This model enables multiple analytical use cases:
        - Funnel analysis at any time grain (daily, weekly, monthly, quarterly)
        - Win/loss analysis by reason, stage, or cohort
        - Sales cycle velocity and duration metrics
        - Conversion rate analysis across stages
        - Pipeline forecasting and capacity planning
        - Cohort retention and progression analysis
    
    Design Philosophy:
        Built as a reusable entity rather than report-specific aggregation.
        Maintains deal-level grain with enriched attributes to support
        flexible downstream analysis without rebuilding base logic.
*/

with deal_milestones as (

    select * from {{ ref('int_deal_milestones') }}

),

lost_reason_lookup as (

    select
        value->>'id' as lost_reason_id,
        value->>'label' as lost_reason_label

    from {{ ref('stg_fields') }},
         json_array_elements(field_value_options) as value
    
    where field_key = 'lost_reason'

),

final as (

    select
        milestones.deal_id,
        
        -- Creation timestamps at multiple grains for flexible aggregation
        milestones.created_at,
        date_trunc('day', milestones.created_at)::date as creation_date,
        date_trunc('week', milestones.created_at)::date as creation_week,
        date_trunc('month', milestones.created_at)::date as creation_month,
        date_trunc('quarter', milestones.created_at)::date as creation_quarter,
        
        -- Stage milestones (9 funnel steps)
        milestones.stage_1_reached_at,
        milestones.stage_2_reached_at,
        milestones.stage_3_reached_at,
        milestones.stage_4_reached_at,
        milestones.stage_5_reached_at,
        milestones.stage_6_reached_at,
        milestones.stage_7_reached_at,
        milestones.stage_8_reached_at,
        milestones.stage_9_reached_at,
        
        -- Deal outcome metadata
        milestones.lost_reason_id,
        lost_reasons.lost_reason_label as lost_reason,
        
        -- Derived metrics for analysis
        milestones.stage_9_reached_at is not null as is_won,
        
        -- Only lost if has reason AND didn't win
        (milestones.lost_reason_id is not null 
         and milestones.stage_9_reached_at is null) as is_lost,

        milestones.stage_9_reached_at - milestones.created_at as sales_cycle_duration

    from deal_milestones as milestones
    
    left join lost_reason_lookup as lost_reasons
        on milestones.lost_reason_id = lost_reasons.lost_reason_id
)

select * from final
