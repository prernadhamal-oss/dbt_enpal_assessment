/*
    Model: trf_deal_milestones
    
    Purpose:
        Captures deal lifecycle milestones including stage progression,
        creation timestamp, and outcome metadata. Combines all key
        temporal and outcome data points for each deal.
    
    Grain: One row per deal
    
    Business Logic:
        - Pivots stage transitions to wide format (9 stage columns)
        - Extracts deal creation timestamp from add_time events
        - Captures latest lost_reason if deal was lost BEFORE winning
        - Filters out spurious lost_reasons set after deals reached stage 9
        - One row per deal with all temporal milestones
*/

{{
  config(
    materialized='table',
    schema='transformation'
  )
}}

with stage_changes as (

    select
        deal_id,
        new_value as stage_id,
        change_time as stage_reached_at

    from {{ ref('intg_deal_changes') }}
    
    where changed_field_key = 'stage_id'

),

creation_times as (

    select
        deal_id,
        min(change_time) as created_at

    from {{ ref('intg_deal_changes') }}
    
    where changed_field_key = 'add_time'
    
    group by deal_id

),

stage_9_times as (

    -- Get the timestamp when each deal reached stage 9 (won)
    -- Used to filter out lost_reasons that were set AFTER winning
    select
        deal_id,
        min(change_time) as stage_9_reached_at

    from {{ ref('intg_deal_changes') }}
    
    where changed_field_key = 'stage_id'
      and new_value = '9'
    
    group by deal_id

),

lost_reasons_raw as (

    -- Extract lost_reasons, but only those set BEFORE stage 9 (or if never reached stage 9)
    -- Data quality issue: All won deals have lost_reasons set 1-39 days AFTER winning, these are filtered out
    select
        lost_reasons.deal_id,
        lost_reasons.new_value as lost_reason_id,
        lost_reasons.change_time,
        s9.stage_9_reached_at,
       
        row_number() 
            over (partition by lost_reasons.deal_id order by lost_reasons.change_time desc) as row_number

    from {{ ref('intg_deal_changes') }} as lost_reasons
    
    left join stage_9_times as s9 
        on lost_reasons.deal_id = s9.deal_id
    
    where lost_reasons.changed_field_key = 'lost_reason'
      -- Only include lost_reasons set BEFORE stage 9 (or if never reached stage 9)
      and (s9.stage_9_reached_at is null 
           or lost_reasons.change_time <= s9.stage_9_reached_at)

),


lost_reasons as (
    
    -- Take the most recent valid lost_reason per deal
    select
        deal_id,
        lost_reason_id

    from lost_reasons_raw
    
    where row_number = 1

),


stage_pivot as (

    -- Pivot stage changes to wide format: one column per stage
    select
        deal_id,
        
        min(case when stage_id = '1' then stage_reached_at end) as stage_1_reached_at,
        min(case when stage_id = '2' then stage_reached_at end) as stage_2_reached_at,
        min(case when stage_id = '3' then stage_reached_at end) as stage_3_reached_at,
        min(case when stage_id = '4' then stage_reached_at end) as stage_4_reached_at,
        min(case when stage_id = '5' then stage_reached_at end) as stage_5_reached_at,
        min(case when stage_id = '6' then stage_reached_at end) as stage_6_reached_at,
        min(case when stage_id = '7' then stage_reached_at end) as stage_7_reached_at,
        min(case when stage_id = '8' then stage_reached_at end) as stage_8_reached_at,
        min(case when stage_id = '9' then stage_reached_at end) as stage_9_reached_at

    from stage_changes
    
    group by deal_id

),

final as (

    select
        pivot.deal_id,
        
        -- Creation timestamp
        creation_times.created_at,
        
        -- Stage milestones
        pivot.stage_1_reached_at,
        pivot.stage_2_reached_at,
        pivot.stage_3_reached_at,
        pivot.stage_4_reached_at,
        pivot.stage_5_reached_at,
        pivot.stage_6_reached_at,
        pivot.stage_7_reached_at,
        pivot.stage_8_reached_at,
        pivot.stage_9_reached_at,
        
        -- Outcome metadata
        lost_reasons.lost_reason_id

    from stage_pivot as pivot
    
    left join creation_times 
        on pivot.deal_id = creation_times.deal_id

    left join lost_reasons 
        on pivot.deal_id = lost_reasons.deal_id

)

select * from final
