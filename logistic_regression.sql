-- Assume the following tables are already created and populated with data:
-- `directed-asset-449105-t9.ML_DS.Account`
-- `directed-asset-449105-t9.ML_DS.InvoiceFact`
-- `directed-asset-449105-t9.ML_DS.InvoiceItem`

-- Also, assume `directed-asset-449105-t9.ML_DS.product_interactions_for_mf`
-- and `directed-asset-449105-t9.ML_DS.user_product_recommendations_mf`
-- from the Matrix Factorization model are available.


--------------------------------------------------------------------------------
-- PART 1: Popularity-Based Recommendations (for New Users / Cold Start)
--------------------------------------------------------------------------------
-- This section identifies the most popular products based on total quantity sold.
-- These recommendations can be used for new users with no interaction history.

CREATE OR REPLACE TABLE
  `directed-asset-449105-t9.ML_DS.popular_products` AS
SELECT
  item.ItemId AS product_id,
  item.ProductName AS product_name,
  item.Category AS product_category,
  SUM(item.Quantity) AS total_quantity_sold
FROM
  `directed-asset-449105-t9.ML_DS.InvoiceItem` AS item
GROUP BY
  item.ItemId,
  item.ProductName,
  item.Category
ORDER BY
  total_quantity_sold DESC
LIMIT 50; -- Top 50 most popular products

-- Inspect popular products:
-- SELECT * FROM `directed-asset-449105-t9.ML_DS.popular_products`;


--------------------------------------------------------------------------------
-- PART 2: Feature-Based Recommendation Model (LOGISTIC_REGRESSION)
--------------------------------------------------------------------------------
-- This section builds a classification model to predict the likelihood of a
-- user interacting with a product, based on explicit user and product features.
-- This is useful for cold-start problems and as a component in a hybrid system.

-- 2.1 Prepare Data with Features and Labels for LOGISTIC_REGRESSION Model
-- We need positive samples (actual interactions) and negative samples (non-interactions).
-- User features are derived from `Account` and aggregated from `InvoiceFact`.
-- Product features are derived from `InvoiceItem`.

CREATE OR REPLACE TABLE
  `directed-asset-449105-t9.ML_DS.feature_based_training_data` AS
WITH
  -- Positive samples: Actual user-product interactions from your data
  PositiveInteractions AS (
    SELECT
      f.AccountID AS user_id,
      i.ItemId AS product_id,
      1 AS target_interaction -- Label 1 for positive interaction
    FROM
      `directed-asset-449105-t9.ML_DS.InvoiceItem` AS i
    JOIN
      `directed-asset-449105-t9.ML_DS.InvoiceFact` AS f
    ON
      i.InvoiceId = f.InvoiceId
    WHERE
      i.Quantity IS NOT NULL AND i.Quantity > 0
    GROUP BY -- Ensure unique user-item pairs for positive samples too
      f.AccountID,
      i.ItemId
  ),
  -- All unique users and products for generating negative samples
  AllUsers AS (SELECT DISTINCT AccountID FROM `directed-asset-449105-t9.ML_DS.Account`),
  AllProducts AS (SELECT DISTINCT ItemId FROM `directed-asset-449105-t9.ML_DS.InvoiceItem`),
  -- Generate potential negative samples (all user-product pairs that *could* exist)
  AllPossibleInteractions AS (
    SELECT
      u.AccountID AS user_id,
      p.ItemId AS product_id
    FROM
      AllUsers AS u
    CROSS JOIN
      AllProducts AS p
  ),
  -- Negative samples: Randomly sample non-interactions
  -- Adjust the WHERE clause (RAND()) and LIMIT based on your data size and desired balance
  NegativeInteractions AS (
    SELECT
      api.user_id,
      api.product_id,
      0 AS target_interaction -- Label 0 for negative interaction
    FROM
      AllPossibleInteractions AS api
    LEFT JOIN
      PositiveInteractions AS pi
      ON api.user_id = pi.user_id AND api.product_id = pi.product_id
    WHERE
      pi.user_id IS NULL -- Only select non-interacted pairs
      AND RAND() < 0.1 -- Randomly sample 10% of non-interactions to balance dataset
    LIMIT 2000 -- Limit negative samples to avoid overwhelming positive ones
  ),
  -- Combine positive and negative samples
  CombinedInteractions AS (
    SELECT * FROM PositiveInteractions
    UNION ALL
    SELECT * FROM NegativeInteractions
  ),
  -- Aggregate InvoiceFact features per user to avoid correlated subquery
  -- Using ANY_VALUE for simplicity, but could use more sophisticated aggregation
  -- like MOST_FREQUENT or MAX(DateCreated) to pick a representative value.
  UserInvoiceFeatures AS (
    SELECT
      AccountID,
      ANY_VALUE(SalesChannel) AS user_sales_channel,
      ANY_VALUE(UA_Device) AS user_ua_device
    FROM
      `directed-asset-449105-t9.ML_DS.InvoiceFact`
    GROUP BY AccountID
  )
-- Join with user and product features
SELECT
  ci.user_id,
  ci.product_id,
  ci.target_interaction,
  -- User Features from Account table
  a.Occupation AS user_occupation,
  a.LoyaltyTierID AS user_loyalty_tier,
  a.AccountType AS user_account_type,
  -- Aggregated User-Invoice Features (de-correlated)
  uif.user_sales_channel, -- New column name
  uif.user_ua_device,     -- New column name
  -- Product Features from InvoiceItem table
  item.Category AS product_category,
  item.Type AS product_type,
  item.Finish AS product_finish,
  item.PrintSize AS product_print_size
FROM
  CombinedInteractions AS ci
LEFT JOIN
  `directed-asset-449105-t9.ML_DS.Account` AS a
ON
  ci.user_id = a.AccountID
LEFT JOIN
  UserInvoiceFeatures AS uif -- Join pre-aggregated user-level invoice features
ON
  ci.user_id = uif.AccountID
LEFT JOIN
  `directed-asset-449105-t9.ML_DS.InvoiceItem` AS item
ON
  ci.product_id = item.ItemId
GROUP BY -- Re-grouping after joins to ensure unique user-product feature rows for training
  ci.user_id,
  ci.product_id,
  ci.target_interaction,
  a.Occupation,
  a.LoyaltyTierID,
  a.AccountType,
  uif.user_sales_channel,
  uif.user_ua_device,
  item.Category,
  item.Type,
  item.Finish,
  item.PrintSize
;

-- Inspect feature-based training data:
-- SELECT * FROM `directed-asset-449105-t9.ML_DS.feature_based_training_data` LIMIT 10;


-- 2.2 Create and Train the LOGISTIC_REGRESSION Model
-- IMPORTANT: Ensure the BigQuery ML API is enabled for your project.
-- Go to Google Cloud Console -> APIs & Services -> Enabled APIs & services, and search for "BigQuery ML API".
CREATE OR REPLACE MODEL
  `directed-asset-449105-t9.ML_DS.product_likelihood_logreg_model`
OPTIONS (
  model_type='LOGISTIC_REG', -- Corrected model type name
  input_label_cols=['target_interaction'], -- The binary column (0 or 1) we want to predict
  auto_class_weights=TRUE, -- Helps handle potential class imbalance (more 0s than 1s)
  data_split_method='AUTO_SPLIT' -- Automatically splits data into train/eval
) AS
SELECT
  user_id,
  product_id,
  target_interaction,
  user_occupation,
  user_loyalty_tier,
  user_account_type,
  user_sales_channel, -- Updated column name
  user_ua_device,     -- Updated column name
  product_category,
  product_type,
  product_finish,
  product_print_size
FROM
  `directed-asset-449105-t9.ML_DS.feature_based_training_data`
;

-- 2.3 Evaluate the LOGISTIC_REGRESSION Model
SELECT`
  *
FROM
  ML.EVALUATE(MODEL `directed-asset-449105-t9.ML_DS.product_likelihood_logreg_model`)
;

-- 2.4 Generate Predictions/Recommendations from LOGISTIC_REGRESSION Model
-- Predict likelihood for all unseen user-product pairs using their features.
CREATE OR REPLACE TABLE
  `directed-asset-449105-t9.ML_DS.user_product_predictions_logreg` AS
WITH
  -- Get all unique users and all unique products
  AllUsers AS (SELECT DISTINCT AccountID FROM `directed-asset-449105-t9.ML_DS.Account`),
  AllProducts AS (SELECT DISTINCT ItemId FROM `directed-asset-449105-t9.ML_DS.InvoiceItem`),
  -- Generate all possible user-product combinations
  AllPossibleUserProductPairs AS (
    SELECT
      u.AccountID AS user_id,
      p.ItemId AS product_id
    FROM
      AllUsers AS u
    CROSS JOIN
      AllProducts AS p
  ),
  -- Exclude products the user has already interacted with
  UnseenUserProductPairs AS (
    SELECT
      app.user_id,
      app.product_id
    FROM
      AllPossibleUserProductPairs AS app
    LEFT JOIN
      `directed-asset-449105-t9.ML_DS.product_interactions_for_mf` AS pi -- Assuming this holds unique (user, item) interactions
      ON app.user_id = pi.user_id AND app.product_id = pi.product_id
    WHERE
      pi.user_id IS NULL
  ),
  -- Aggregate InvoiceFact features per user for prediction input consistency
  UserInvoiceFeaturesPrediction AS (
    SELECT
      AccountID,
      ANY_VALUE(SalesChannel) AS user_sales_channel,
      ANY_VALUE(UA_Device) AS user_ua_device
    FROM
      `directed-asset-449105-t9.ML_DS.InvoiceFact`
    GROUP BY AccountID
  ),
  -- Prepare input for ML.PREDICT with features
  PredictionInput AS (
    SELECT
      uup.user_id,
      uup.product_id,
      a.Occupation AS user_occupation,
      a.LoyaltyTierID AS user_loyalty_tier,
      a.AccountType AS user_account_type,
      uifp.user_sales_channel, -- New column name
      uifp.user_ua_device,     -- New column name
      item.Category AS product_category,
      item.Type AS product_type,
      item.Finish AS product_finish,
      item.PrintSize AS product_print_size
    FROM
      UnseenUserProductPairs AS uup
    LEFT JOIN
      `directed-asset-449105-t9.ML_DS.Account` AS a
      ON uup.user_id = a.AccountID
    LEFT JOIN
      UserInvoiceFeaturesPrediction AS uifp -- Join pre-aggregated user-level invoice features
    ON
      uup.user_id = uifp.AccountID
    LEFT JOIN
      `directed-asset-449105-t9.ML_DS.InvoiceItem` AS item
      ON uup.product_id = item.ItemId
    -- No GROUP BY needed here if uifp and item give unique feature rows per user-product
    -- However, if there are multiple item features for the same ItemId (e.g., from different InvoiceItem rows),
    -- you might need to pre-aggregate InvoiceItem features per ItemId as well.
    -- For now, assuming ItemId has consistent features across all its InvoiceItem entries.
  )
SELECT
  user_id,
  product_id,
  predicted_target_interaction_probs[OFFSET(0)].prob AS predicted_likelihood -- Probability of interaction (class 1)
FROM
  ML.PREDICT(MODEL `directed-asset-449105-t9.ML_DS.product_likelihood_logreg_model`, TABLE PredictionInput) -- Added TABLE keyword
ORDER BY
  predicted_likelihood DESC;

-- Inspect predictions from Logistic Regression:
SELECT 
  user_id, 
  product_id, 
  MAX(predicted_likelihood) 
FROM `directed-asset-449105-t9.ML_DS.user_product_predictions_logreg` 
GROUP BY 1,2
ORDER BY 1,2;


--------------------------------------------------------------------------------
-- PART 3: Conceptual Combination of Recommendation Approaches
--------------------------------------------------------------------------------
-- In a real application, you would combine these recommendations based on your logic:
--
-- 1. For a **TRULY NEW USER** (AccountID not in `product_interactions_for_mf`):
--    - Recommend from `directed-asset-449105-t9.ML_DS.popular_products`
--    - OR use `directed-asset-449105-t9.ML_DS.user_product_predictions_logreg`
--      (if you ensure all new users are included in the prediction input)
--
-- 2. For an **EXISTING USER** with some history:
--    - Prioritize recommendations from `directed-asset-449105-t9.ML_DS.user_product_recommendations_mf`
--      (your Matrix Factorization output). This is generally best for personalization.
--    - As a fallback or supplemental recommendations, you can also use
--      `directed-asset-449105-t9.ML_DS.user_product_predictions_logreg`
--      (feature-based). This is useful if MF output is limited or for
--      items that don't have enough collaborative history but fit user features.
--
-- Example of combining (conceptual UNION for top N overall):
/*
SELECT
    user_id,
    'Matrix Factorization' AS recommendation_source,
    top_recommendations
FROM
    `directed-asset-449105-t9.ML_DS.user_product_recommendations_mf`
WHERE
    user_id = 'some_specific_user_id' -- Or fetch for all users and apply application logic
UNION ALL
SELECT
    user_id,
    'Feature-Based (Logistic Regression)' AS recommendation_source,
    ARRAY_AGG(
        STRUCT(product_id, predicted_likelihood)
        ORDER BY predicted_likelihood DESC
        LIMIT 5
    ) AS top_recommendations
FROM
    `directed-asset-449105-t9.ML_DS.user_product_predictions_logreg`
WHERE
    user_id = 'some_specific_user_id'
GROUP BY
    user_id
UNION ALL
SELECT
    'new_user_example' AS user_id, -- For users with no history
    'Popularity-Based' AS recommendation_source,
    ARRAY_AGG(
        STRUCT(product_id, CAST(total_quantity_sold AS FLOAT64)) -- Cast quantity to float for consistency
        ORDER BY total_quantity_sold DESC
        LIMIT 5
    ) AS top_recommendations
FROM
    `directed-asset-449105-t9.ML_DS.popular_products`
LIMIT 1; -- Example for one new user
*/

-- The actual logic for selecting which recommendations to show (MF, LR, Popularity)
-- typically happens in your application layer (e.g., Python, Java, Node.js)
-- after querying these BigQuery tables.
