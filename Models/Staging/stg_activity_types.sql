/*
    Model: stg_activity_types
    
    Purpose: Activity type reference data with codes and business names.
    
    Grain: One row per activity type
*/

with source as (

    select
        id,
        type,
        name,
        active

    from {{ source('pipedrive', 'activity_types') }}

),

final as (

    select
        id::int as activity_type_id,
        type::text as activity_type_code,
        name::text as activity_type_name,
        active::text as is_active

    from source

)

select * from final
