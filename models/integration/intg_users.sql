{{
  config(
    materialized='table',
    schema='integration'
  )
}}

SELECT *
FROM {{ source('postgres','users')}}