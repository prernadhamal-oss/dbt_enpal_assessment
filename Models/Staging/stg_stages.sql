/*
    Model: stg_stages
    
    Purpose: Sales funnel stage reference data.
    
    Grain: One row per stage
*/

with source as (

    select
        stage_id,
        stage_name

    from {{ source('pipedrive', 'stages') }}

),

final as (

    select
        stage_id::int as stage_id,
        stage_name::text as stage_name

    from source

)

select * from final
