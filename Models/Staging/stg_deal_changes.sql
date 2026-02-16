/*
    Model: stg_deal_changes
    
    Purpose: Event-level history of all changes applied to deals.
    
    Grain: One row per deal change event
*/

with source as (

    select
        deal_id,
        change_time,
        changed_field_key,
        new_value

    from {{ source('pipedrive', 'deal_changes') }}

),

final as (

    select
        deal_id::int as deal_id,
        change_time::timestamp as change_time,
        changed_field_key::text as changed_field_key,
        new_value::text as new_value

    from source

)

select * from final
