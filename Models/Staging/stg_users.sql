/*
    Model: stg_users
    
    Purpose: CRM user reference data.
    
    Grain: One row per user
*/

with source as (

    select
        id,
        name,
        email,
        modified

    from {{ source('pipedrive', 'users') }}

),

final as (

    select
        id::int as user_id,
        name::text as user_name,
        email::text as user_email,
        modified::timestamp as modified_at

    from source

)

select * from final
