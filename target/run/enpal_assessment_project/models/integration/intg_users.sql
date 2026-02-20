
  
    

  create  table "postgres"."public_integration"."intg_users__dbt_tmp"
  
  
    as
  
  (
    

SELECT *
FROM "postgres"."public"."users"
  );
  