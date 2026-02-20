
  
    

  create  table "postgres"."public_integration"."intg_activity_types__dbt_tmp"
  
  
    as
  
  (
    

SELECT *
FROM "postgres"."public"."activity_types"
  );
  