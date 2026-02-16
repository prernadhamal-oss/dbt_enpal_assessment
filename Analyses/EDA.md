Pipedrive CRM Data Investigation Report
This report examines the schema, interconnections, and operational rules across the six core Pipedrive CRM datasets. Through targeted SQL explorations, I've confirmed key hypotheses, pinpointed record-level granularity, and outlined dbt transformation guidelines.
​

Initial Table Checks
Stages Table Review
text
SELECT COUNT(*) AS total_records, COUNT(DISTINCT stageid) AS unique_stages 
FROM public.stages;
Primary key stageid shows 9 distinct entries, perfectly aligning with the 9-step sales funnel (plus activity sub-steps).
​

text
SELECT stageid, stagename FROM public.stages ORDER BY stageid;
Observations confirm clean, sequential stages ready for funnel progression tracking.

Activity Types Assessment
text
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT id) AS unique_types FROM public.activitytypes;
Solid unique keys; types like "meeting" and "sc2" tie directly to funnel milestones (e.g., Sales Call 1/2).
​

Activities Table Grain
text
SELECT dealid, activityid FROM public.activity GROUP BY 1,2 HAVING COUNT(*) > 1;
No duplicates per deal-activity pair, though activityid repeats across deals—suggests reassignments, not errors.
​

text
SELECT done, COUNT(*) FROM public.activity GROUP BY done;
Filter to done = true for funnel steps 2.1/3.1 to capture only finished actions.

Deal Changes Overview
text
SELECT COUNT(*) AS total_events, COUNT(DISTINCT dealid) AS unique_deals FROM public.dealchanges;
Event-driven structure with multiple logs per deal; focuses on addtime (creation) and stageid shifts.
​

text
SELECT newvalue AS stageid, COUNT(DISTINCT dealid) AS deals_per_stage 
FROM public.dealchanges WHERE changedfieldkey = 'stageid' 
GROUP BY newvalue ORDER BY stageid;
Progressive drop-off validates funnel dynamics.

Critical Finding: Lost Reason Anomaly

text
WITH won_deals AS (
  SELECT dealid,
    MIN(CASE WHEN changedfieldkey = 'stageid' AND newvalue = '9' THEN changetime END) AS win_time,
    MIN(CASE WHEN changedfieldkey = 'lostreason' THEN changetime END) AS lost_time
  FROM public.dealchanges GROUP BY dealid 
  HAVING MIN(CASE WHEN changedfieldkey = 'stageid' AND newvalue = '9' THEN changetime END) IS NOT NULL
)
SELECT COUNT(*) AS won_with_lost, AVG(lost_time - win_time) AS avg_delay_days 
FROM won_deals WHERE lost_time > win_time;
All 324 wins have post-win lostreason entries (avg 15 days later)—filter these for true loss analysis.
​

Cross-Table Links
User & Type Integrity
All activity assignees exist in users; every type references activitytypes—no orphans.
​

Activity-Deal Mismatch
text
SELECT COUNT(*) AS orphaned_activities 
FROM public.activity a LEFT JOIN public.dealchanges dc ON a.dealid = dc.dealid 
WHERE a.done = true AND dc.dealid IS NULL;
~4,000 unmatched (99.7% for sales calls). Matches (just 6) show impossibilities: activities pre-dating deals, owner mismatches, logic violations (e.g., post-close before creation).
​

Root: Separate lead vs. pipeline systems with colliding IDs. Exclude activities from core funnel for reliability.

Quality Highlights
Full referential integrity on stages/users.

Reliable addtime for cohorts.

Expected stagnation in early stages.
​

Activity gap: Ends Sep 2024 vs. deals to Mar 2025.

Funnel Modeling Notes
Use MIN(changetime) per stage/deal from dealchanges. Activity sub-steps (2.1/3.1) zeroed out due to links issue; 9 stages suffice.
​

dbt Layer Strategy
Staging (stg_): Clean sources (e.g., stg_dealchanges parses timestamps).
​

Intermediate (int_): int_deal_milestones pivots stages, filters bad lostreasons.

Curated: deals—deal-grain lifecycle w/ timestamps, outcomes, cycle duration.

Marts: rep_sales_funnel_monthly—month/step counts.

This setup scales for win/loss, velocity, cohorts—prioritizing trust over completeness.