-- Arrays for realistic data generation (re-declared for standalone execution)
DECLARE PRODUCT_CATEGORIES ARRAY<STRING> DEFAULT ['Electronics', 'Books', 'Home Decor', 'Photography', 'Software', 'Merchandise', 'Apparel', 'Accessories', 'Services'];
DECLARE PRODUCT_NAMES ARRAY<STRING> DEFAULT [
    'UltraBook Pro X', 'Galactic Wanderer Novel', 'Magic Realm Saga Ebook', 'Abstract Sunset Print', 'Mountain Landscape Canvas',
    'Creative Studio Pro', 'Personalized Photo Mug', 'Noise-Cancelling Headphones', 'Ergonomic Office Chair', 'Vintage Leather Journal',
    'Digital Camera Kit', 'Premium Coffee Beans', 'Smart Home Hub', 'Fitness Tracker Watch', 'Artisan Soap Set',
    'Gaming Keyboard', 'Virtual Reality Headset', 'Gardening Tool Set', 'Custom T-Shirt Design', 'Online Course Subscription'
];

-- Insert Sample Data into InvoiceItem Table (multiple items per invoice, approx. 1200-1800 records)
INSERT INTO `directed-asset-449105-t9.ML_DS.InvoiceItem` (
    ItemId, InvoiceId, Category, Type, Finish, PrintSize, ProductName, LineNumber,
    Description, Amount, Quantity, PaidQuantity, Unit, CostAmount, TotalAmount,
    TaxCredits, Revenue, TaxCredits_Item, Discount, InDiscount, InsertedDateTime,
    EffectiveLoadTime, EntryType, Flag, EntryDate, IsItem, ShippingRevenue,
    OtherRevenue, Shipping, ShippingDiscount, TotalDiscount
)
SELECT
    FORMAT('prod_%03d', MOD(item_id_idx, 50) + 1) AS ItemId,
    (SELECT InvoiceId FROM `directed-asset-449105-t9.ML_DS.InvoiceFact` WHERE LoadID = CAST(MOD(base_id - 1, 600) + 1 AS INT64)) AS InvoiceId,
    PRODUCT_CATEGORIES[OFFSET(MOD(CAST(MOD(item_id_idx, 50) + 1 AS INT64), ARRAY_LENGTH(PRODUCT_CATEGORIES)))] AS Category,
    'Standard' AS Type,
    'N/A' AS Finish,
    'N/A' AS PrintSize,
    PRODUCT_NAMES[OFFSET(MOD(item_id_idx, ARRAY_LENGTH(PRODUCT_NAMES)))] AS ProductName,
    FORMAT('%d', CAST(item_in_invoice_idx AS INT64)) AS LineNumber,
    'Sample product description.' AS Description,
    CAST(ROUND(RAND() * 500 + 5, 2) AS NUMERIC) AS Amount,
    CAST(CEIL(RAND() * 5) AS INT64) AS Quantity, -- Explicitly cast to INT64
    CAST(CEIL(RAND() * 5) AS INT64) AS PaidQuantity, -- Explicitly cast to INT64
    CAST(ROUND(RAND() * 500 + 5, 2) AS NUMERIC) AS Unit,
    CAST(ROUND(RAND() * 300 + 1, 2) AS NUMERIC) AS CostAmount,
    CAST(ROUND(RAND() * 500 + 5, 2) AS NUMERIC) AS TotalAmount,
    CAST(0.00 AS NUMERIC) AS TaxCredits,
    CAST(ROUND(RAND() * 500 + 5, 2) AS NUMERIC) AS Revenue,
    CAST(0.00 AS NUMERIC) AS TaxCredits_Item,
    CAST(0.00 AS NUMERIC) AS Discount, CAST(0.00 AS NUMERIC) AS InDiscount,
    DATETIME(CURRENT_TIMESTAMP()) AS InsertedDateTime,
    CURRENT_TIMESTAMP() AS EffectiveLoadTime,
    'Sale' AS EntryType,
    1 AS Flag,
    DATE(CURRENT_TIMESTAMP()) AS EntryDate,
    TRUE AS IsItem,
    CAST(0.00 AS NUMERIC) AS ShippingRevenue, CAST(0.00 AS NUMERIC) AS OtherRevenue,
    CAST(0.00 AS NUMERIC) AS Shipping, CAST(0.00 AS NUMERIC) AS ShippingDiscount, CAST(0.00 AS NUMERIC) AS TotalDiscount
FROM
    UNNEST(GENERATE_ARRAY(1, 600)) AS base_id,
    UNNEST(GENERATE_ARRAY(1, CEIL(RAND() * 3) + 1)) AS item_in_invoice_idx,
    UNNEST(GENERATE_ARRAY(1, 50)) AS item_id_idx
QUALIFY ROW_NUMBER() OVER (PARTITION BY CAST(base_id AS INT64), CAST(item_in_invoice_idx AS INT64) ORDER BY RAND()) = 1
ORDER BY base_id, item_in_invoice_idx;