{{
  config(
    materialized='table',
    schema='pipedrive_analytics'
  )
}}

SELECT *
FROM {{ source('postgres_public','activity')}}