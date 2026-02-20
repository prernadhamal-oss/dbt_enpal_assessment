
  
    

  create  table "postgres"."public_integration"."intg_stages__dbt_tmp"
  
  
    as
  
  (
    

SELECT *
FROM "postgres"."public"."stages"
  );
  