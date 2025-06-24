-- Assume the following tables are already created and populated:
-- `directed-asset-449105-t9.ML_DS.Account`
-- `directed-asset-449105-t9.ML_DS.InvoiceFact`
-- `directed-asset-449105-t9.ML_DS.InvoiceItem`

--------------------------------------------------------------------------------
-- 1. Create Core Interaction Data for Matrix Factorization
--------------------------------------------------------------------------------
-- This step joins InvoiceFact and InvoiceItem to prepare the data
-- for the Matrix Factorization model.
-- user_id: AccountID from InvoiceFact
-- product_id: ItemId from InvoiceItem
-- interaction_score: Quantity from InvoiceItem
-- IMPORTANT: Aggregating duplicate user-item pairs to ensure unique entries for MF model.

CREATE OR REPLACE TABLE
  `directed-asset-449105-t9.ML_DS.product_interactions_for_mf` AS
SELECT
  f.AccountID AS user_id,
  i.ItemId AS product_id,
  SUM(i.Quantity) AS interaction_score -- Aggregate quantity for duplicate user-item pairs
FROM
  `directed-asset-449105-t9.ML_DS.InvoiceItem` AS i
JOIN
  `directed-asset-449105-t9.ML_DS.InvoiceFact` AS f
ON
  i.InvoiceId = f.InvoiceId
WHERE
  i.Quantity IS NOT NULL AND i.Quantity > 0 -- Filter out non-positive interactions
GROUP BY
  f.AccountID,
  i.ItemId
;

-- You can inspect the combined interaction data:
-- SELECT * FROM `directed-asset-449105-t9.ML_DS.product_interactions_for_mf` LIMIT 10;


--------------------------------------------------------------------------------
-- 2. Create and Train the Recommendation Model (MATRIX_FACTORIZATION)
--------------------------------------------------------------------------------
-- This statement creates the Matrix Factorization model using the prepared interaction data.
-- ****************************************************************************
-- IMPORTANT: TRAINING THIS MODEL TYPE REQUIRES A BIGQUERY RESERVATION (Flex or regular slots).
-- IT WILL NOT WORK WITH ON-DEMAND PRICING AND THE MODEL CREATION WILL FAIL.
-- IF MODEL CREATION FAILS, THE ML.RECOMMEND STEP WILL THEN THROW AN ERROR.
-- ****************************************************************************

CREATE OR REPLACE MODEL
  `directed-asset-449105-t9.ML_DS.product_recommender_mf_model`
OPTIONS (
  model_type='MATRIX_FACTORIZATION',
  user_col='user_id',            -- Column identifying the user (AccountID)
  item_col='product_id',         -- Column identifying the item (ItemId)
  rating_col='interaction_score',-- Column representing the interaction strength (Quantity)
  feedback_type='IMPLICIT',      -- Use 'IMPLICIT' for interaction counts/scores (like Quantity)
                                 -- or 'EXPLICIT' if you have explicit ratings (e.g., 1-5 stars)
  l2_reg=0.02,                   -- L2 regularization to prevent overfitting.
  num_factors=20                 -- Number of latent factors (dimensionality of embeddings).
) AS
SELECT
  user_id,
  product_id,
  interaction_score
FROM
  `directed-asset-449105-t9.ML_DS.product_interactions_for_mf`
;

-- Training time will vary based on your data size.
-- You can monitor the training progress in the BigQuery UI under the 'Model' tab.


--------------------------------------------------------------------------------
-- 3. Evaluate the Trained Model
--------------------------------------------------------------------------------
-- Evaluate the model's performance. For Matrix Factorization, metrics like
-- mean_average_precision and average_rank are provided.

SELECT
  *
FROM
  ML.EVALUATE(MODEL `directed-asset-449105-t9.ML_DS.product_recommender_mf_model`)
;


--------------------------------------------------------------------------------
-- 4. Generate Product Recommendations
--------------------------------------------------------------------------------
-- This query generates top N product recommendations for each user,
-- excluding products they have already interacted with.

CREATE OR REPLACE TABLE
  `directed-asset-449105-t9.ML_DS.user_product_recommendations_mf` AS
WITH
  PredictedRecommendations AS (
    SELECT
      user_id,
      product_id,
      predicted_interaction_score_confidence
    FROM
      ML.RECOMMEND(MODEL `directed-asset-449105-t9.ML_DS.product_recommender_mf_model`)
  ),
  UserExistingInteractions AS (
    SELECT DISTINCT
      user_id,
      product_id
    FROM
      `directed-asset-449105-t9.ML_DS.product_interactions_for_mf`
  )
SELECT
  pr.user_id,
  ARRAY_AGG(
    STRUCT(
      pr.product_id,
      pr.predicted_interaction_score_confidence
    )
    ORDER BY
      pr.predicted_interaction_score_confidence DESC
    LIMIT 5
  ) AS top_recommendations
FROM
  PredictedRecommendations AS pr
LEFT JOIN
  UserExistingInteractions AS uei
  ON pr.user_id = uei.user_id AND pr.product_id = uei.product_id
WHERE
  uei.product_id IS NULL
GROUP BY
  pr.user_id
ORDER BY
  pr.user_id
;

-- View the generated recommendations (join with Account and InvoiceItem for richer details):
-- Assume the following tables are already created and populated:
-- `directed-asset-449105-t9.ML_DS.Account`
-- `directed-asset-449105-t9.ML_DS.InvoiceFact`
-- `directed-asset-449105-t9.ML_DS.InvoiceItem`

--------------------------------------------------------------------------------
-- 1. Create Core Interaction Data for Matrix Factorization
--------------------------------------------------------------------------------
-- This step joins InvoiceFact and InvoiceItem to prepare the data
-- for the Matrix Factorization model.
-- user_id: AccountID from InvoiceFact
-- product_id: ItemId from InvoiceItem
-- interaction_score: Quantity from InvoiceItem
-- IMPORTANT: Aggregating duplicate user-item pairs to ensure unique entries for MF model.

CREATE OR REPLACE TABLE
  `directed-asset-449105-t9.ML_DS.product_interactions_for_mf` AS
SELECT
  f.AccountID AS user_id,
  i.ItemId AS product_id,
  SUM(i.Quantity) AS interaction_score -- Aggregate quantity for duplicate user-item pairs
FROM
  `directed-asset-449105-t9.ML_DS.InvoiceItem` AS i
JOIN
  `directed-asset-449105-t9.ML_DS.InvoiceFact` AS f
ON
  i.InvoiceId = f.InvoiceId
WHERE
  i.Quantity IS NOT NULL AND i.Quantity > 0 -- Filter out non-positive interactions
GROUP BY
  f.AccountID,
  i.ItemId
;

-- You can inspect the combined interaction data:
-- SELECT * FROM `directed-asset-449105-t9.ML_DS.product_interactions_for_mf` LIMIT 10;


--------------------------------------------------------------------------------
-- 2. Create and Train the Recommendation Model (MATRIX_FACTORIZATION)
--------------------------------------------------------------------------------
-- This statement creates the Matrix Factorization model using the prepared interaction data.
-- ****************************************************************************
-- IMPORTANT: TRAINING THIS MODEL TYPE REQUIRES A BIGQUERY RESERVATION (Flex or regular slots).
-- IT WILL NOT WORK WITH ON-DEMAND PRICING AND THE MODEL CREATION WILL FAIL.
-- IF MODEL CREATION FAILS, THE ML.RECOMMEND STEP WILL THEN THROW AN ERROR.
-- ****************************************************************************

CREATE OR REPLACE MODEL
  `directed-asset-449105-t9.ML_DS.product_recommender_mf_model`
OPTIONS (
  model_type='MATRIX_FACTORIZATION',
  user_col='user_id',            -- Column identifying the user (AccountID)
  item_col='product_id',         -- Column identifying the item (ItemId)
  rating_col='interaction_score',-- Column representing the interaction strength (Quantity)
  feedback_type='IMPLICIT',      -- Use 'IMPLICIT' for interaction counts/scores (like Quantity)
                                 -- or 'EXPLICIT' if you have explicit ratings (e.g., 1-5 stars)
  l2_reg=0.02,                   -- L2 regularization to prevent overfitting.
  num_factors=20                 -- Number of latent factors (dimensionality of embeddings).
) AS
SELECT
  user_id,
  product_id,
  interaction_score
FROM
  `directed-asset-449105-t9.ML_DS.product_interactions_for_mf`
;

-- Training time will vary based on your data size.
-- You can monitor the training progress in the BigQuery UI under the 'Model' tab.


--------------------------------------------------------------------------------
-- 3. Evaluate the Trained Model
--------------------------------------------------------------------------------
-- Evaluate the model's performance. For Matrix Factorization, metrics like
-- mean_average_precision and average_rank are provided.

SELECT
  *
FROM
  ML.EVALUATE(MODEL `directed-asset-449105-t9.ML_DS.product_recommender_mf_model`)
;


--------------------------------------------------------------------------------
-- 4. Generate Product Recommendations
--------------------------------------------------------------------------------
-- This query generates top N product recommendations for each user,
-- excluding products they have already interacted with.

CREATE OR REPLACE TABLE
  `directed-asset-449105-t9.ML_DS.user_product_recommendations_mf` AS
WITH
  PredictedRecommendations AS (
    SELECT
      user_id,
      product_id,
      predicted_interaction_score_confidence -- Updated column name
    FROM
      ML.RECOMMEND(MODEL `directed-asset-449105-t9.ML_DS.product_recommender_mf_model`)
  ),
  UserExistingInteractions AS (
    SELECT DISTINCT
      user_id,
      product_id
    FROM
      `directed-asset-449105-t9.ML_DS.product_interactions_for_mf`
  )
SELECT
  pr.user_id,
  ARRAY_AGG(
    STRUCT(
      pr.product_id,
      pr.predicted_interaction_score_confidence -- Updated column name
    )
    ORDER BY
      pr.predicted_interaction_score_confidence DESC -- Updated column name
    LIMIT 5
  ) AS top_recommendations
FROM
  PredictedRecommendations AS pr
LEFT JOIN
  UserExistingInteractions AS uei
  ON pr.user_id = uei.user_id AND pr.product_id = uei.product_id
WHERE
  uei.product_id IS NULL
GROUP BY
  pr.user_id
ORDER BY
  pr.user_id
;

--------------------------------------------------------------------------------
-- 5. View the generated recommendations (join with Account and InvoiceItem for richer details)
--    The previous correlated subquery has been de-correlated by joining at a higher level.
--------------------------------------------------------------------------------
SELECT
  r_main.user_id, -- Updated alias
  a.LoyaltyTierID,
  a.Occupation,
  ARRAY_AGG(
    STRUCT(
      rec.product_id,
      rec.predicted_interaction_score_confidence,
      item.ProductName,
      item.Category,
      item.Type,
      item.Description
    )
    ORDER BY
      rec.predicted_interaction_score_confidence DESC
    LIMIT 5
  ) AS enriched_recommendations
FROM
  `directed-asset-449105-t9.ML_DS.user_product_recommendations_mf` AS r_main
LEFT JOIN
  `directed-asset-449105-t9.ML_DS.Account` AS a
ON
  r_main.user_id = a.AccountID
CROSS JOIN
  UNNEST(r_main.top_recommendations) AS rec
LEFT JOIN
  `directed-asset-449105-t9.ML_DS.InvoiceItem` AS item
ON
  rec.product_id = item.ItemId
GROUP BY
  r_main.user_id,
  a.LoyaltyTierID,
  a.Occupation
ORDER BY
  r_main.user_id
LIMIT 10;

