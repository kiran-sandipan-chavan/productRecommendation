-- Arrays for realistic data generation (re-declared for standalone execution)
DECLARE SALES_CHANNELS ARRAY<STRING> DEFAULT ['Online', 'MobileApp', 'In-Store', 'Partner'];
DECLARE UA_DEVICES ARRAY<STRING> DEFAULT ['Desktop', 'Mobile', 'Tablet'];

-- Insert Sample Data into InvoiceFact Table (approx. 600 records)
INSERT INTO `directed-asset-449105-t9.ML_DS.InvoiceFact` (
    InvoiceId, InvoiceNumber, Type, Status, DateCreated, DateApproved, Description,
    TotalAmount, DiscountAmount, TaxAmount, TaxPixCredits, TaxRate, TaxJurisdiction,
    TotalRevenue, TotalPixCredits, AccountID, OrderHistoryID, CreditCardTransactionID,
    PayPalTransactionID, BalanceID, PaymentComm, WLOrderHistory, WePayTransactionID,
    SQSPOrderHistoryID, SQSPTransactionID, UA_Device, UA_IsMobileDevice, NewCustomerFlag,
    MembershipID, Occupation, Email, FullName, EffectiveLoadTime, LoadID,
    InsertedDateTime, ProUserFlag, SalesChannel, CreatedBy, AcceptedBy, RejectedBy,
    CreditType, AdminEmail, CreditsCreatedBy, ActiveFlag, InActiveDate
)
SELECT
    FORMAT('inv_%05d', id) AS InvoiceId,
    FORMAT('INV-2023-%05d', id) AS InvoiceNumber,
    'Sale' AS Type,
    'Paid' AS Status,
    TIMESTAMP_ADD(TIMESTAMP('2023-01-01 00:00:00 UTC'), INTERVAL id * 86400 SECOND) AS DateCreated, -- Daily invoices
    TIMESTAMP_ADD(TIMESTAMP_ADD(TIMESTAMP('2023-01-01 00:00:00 UTC'), INTERVAL id * 86400 SECOND), INTERVAL 5 MINUTE) AS DateApproved,
    'General online purchase' AS Description,
    CAST(ROUND(RAND() * 1000 + 10, 2) AS NUMERIC) AS TotalAmount,
    CAST(ROUND(RAND() * 50, 2) AS NUMERIC) AS DiscountAmount,
    CAST(ROUND(RAND() * 70, 2) AS NUMERIC) AS TaxAmount,
    CAST(0.00 AS NUMERIC) AS TaxPixCredits,
    0.07 AS TaxRate,
    CASE WHEN MOD(id, 3) = 0 THEN 'NY' WHEN MOD(id, 3) = 1 THEN 'CA' ELSE 'TX' END AS TaxJurisdiction,
    CAST(ROUND(RAND() * 900 + 10, 2) AS NUMERIC) AS TotalRevenue,
    CAST(0.00 AS NUMERIC) AS TotalPixCredits,
    (SELECT AccountID FROM `directed-asset-449105-t9.ML_DS.Account` WHERE LoadID = CAST(MOD(id - 1, 500) + 1 AS INT64)) AS AccountID, -- Link to existing accounts
    FORMAT('OH-%05d', id) AS OrderHistoryID,
    CASE WHEN MOD(id, 2) = 0 THEN FORMAT('CC_%05d', id) ELSE NULL END AS CreditCardTransactionID,
    CASE WHEN MOD(id, 2) = 1 THEN FORMAT('PP_%05d', id) ELSE NULL END AS PayPalTransactionID,
    FORMAT('BAL-%05d', id) AS BalanceID,
    1 AS PaymentComm,
    FORMAT('WL-OH-%05d', id) AS WLOrderHistory,
    NULL AS WePayTransactionID, NULL AS SQSPOrderHistoryID, NULL AS SQSPTransactionID,
    UA_DEVICES[OFFSET(MOD(id, ARRAY_LENGTH(UA_DEVICES)))] AS UA_Device,
    CASE WHEN MOD(id, 3) != 0 THEN '1' ELSE '0' END AS UA_IsMobileDevice,
    CASE WHEN id < 50 THEN 1 ELSE 0 END AS NewCustomerFlag,
    (SELECT MembershipID FROM `directed-asset-449105-t9.ML_DS.Account` WHERE LoadID = CAST(MOD(id - 1, 500) + 1 AS INT64)) AS MembershipID,
    (SELECT Occupation FROM `directed-asset-449105-t9.ML_DS.Account` WHERE LoadID = CAST(MOD(id - 1, 500) + 1 AS INT64)) AS Occupation,
    CAST(FORMAT('user%d@example.com', CAST(MOD(id - 1, 500) + 1 AS INT64)) AS STRING) AS Email,
    CAST(FORMAT('User Name %d', CAST(MOD(id - 1, 500) + 1 AS INT64)) AS STRING) AS FullName,
    CURRENT_TIMESTAMP() AS EffectiveLoadTime,
    id AS LoadID,
    DATETIME(CURRENT_TIMESTAMP()) AS InsertedDateTime,
    CASE WHEN MOD(id, 4) = 0 THEN 1 ELSE 0 END AS ProUserFlag,
    SALES_CHANNELS[OFFSET(MOD(id, ARRAY_LENGTH(SALES_CHANNELS)))] AS SalesChannel,
    'system_gen' AS CreatedBy,
    'system_app' AS AcceptedBy,
    NULL AS RejectedBy,
    'Standard' AS CreditType,
    CAST(FORMAT('admin%d@example.com', CAST(MOD(id - 1, 500) + 1 AS INT64)) AS STRING) AS AdminEmail,
    'admin_script' AS CreditsCreatedBy,
    1 AS ActiveFlag,
    NULL AS InActiveDate
FROM
    UNNEST(GENERATE_ARRAY(1, 600)) AS id;
