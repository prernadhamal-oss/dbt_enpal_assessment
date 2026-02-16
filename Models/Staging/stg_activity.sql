/*
    Model: stg_activity
    
    Purpose: Clean and standardize activity records from Pipedrive CRM.
    
    Grain: One row per (activity_id, deal_id) combination
*/

with source as (

    select
        activity_id,
        type,
        assigned_to_user,
        deal_id,
        done,
        due_to

    from {{ source('pipedrive', 'activity') }}

),

final as (

    select
        activity_id::int as activity_id,
        type::text as activity_type_code,
        assigned_to_user::int as assigned_to_user_id,
        deal_id::int as deal_id,
        done::boolean as is_done,
        due_to::timestamp as due_at

    from source

)

select * from final
