
  
    

  create  table "postgres"."public_integration"."intg_deal_changes__dbt_tmp"
  
  
    as
  
  (
    

SELECT *
FROM "postgres"."public"."deal_changes"
  );
  