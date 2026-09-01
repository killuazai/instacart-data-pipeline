-- saved-query name: 01_setup
-- paste the approved Databricks SQL for this task below

-- ============================================================
-- 01 SETUP
-- Purpose:
-- Create the schemas required for the Instacart pipeline.
--
-- Pipeline:
-- BRONZE -> SILVER -> GOLD -> ANALYTICS
-- ============================================================


-- Create Bronze schema
-- Stores raw source tables with minimal transformation
CREATE SCHEMA IF NOT EXISTS workspace.instacart_bronze;


-- Create Silver schema
-- Stores cleaned, standardized, and integrated tables
CREATE SCHEMA IF NOT EXISTS workspace.instacart_silver;


-- Create Gold schema
-- Stores dimensional-model tables such as facts and dimensions
CREATE SCHEMA IF NOT EXISTS workspace.instacart_gold;


-- Create Analytics schema
-- Stores business-question output tables or views
CREATE SCHEMA IF NOT EXISTS workspace.instacart_analytics;