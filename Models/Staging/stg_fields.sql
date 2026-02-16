/*
    Model: stg_fields
    
    Purpose: 
        Field metadata with JSON-encoded value options for lookups.
        Enables enrichment of deal outcomes (e.g., lost_reason labels).
    
    Grain: One row per field definition
*/

with source as (

    select
        id,
        field_key,
        name,
        field_value_options

    from {{ source('pipedrive', 'fields') }}

),

final as (

    select
        id::int as field_id,
        field_key::text as field_key,
        name::text as field_name,
        field_value_options::json as field_value_options

    from source

)

select * from final
