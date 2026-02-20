
  
    

  create  table "postgres"."public_integration"."intg_activity__dbt_tmp"
  
  
    as
  
  (
    

SELECT *
FROM "postgres"."public"."activity"
  );
  