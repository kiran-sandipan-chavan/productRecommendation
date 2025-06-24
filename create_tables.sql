-- Create the dataset if it doesn't exist
CREATE SCHEMA IF NOT EXISTS `directed-asset-449105-t9.ML_DS`;

--------------------------------------------------------------------------------
-- DDL for Account Table
--------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `directed-asset-449105-t9.ML_DS.Account` (
    AccountID STRING,
    CreatedDate TIMESTAMP,
    MembershipID STRING,
    Occupation STRING,
    MembershipStartDate TIMESTAMP,
    MembershipDowngradeDate TIMESTAMP,
    ExpiredDate TIMESTAMP,
    TrialProLevelUsed BOOLEAN,
    AccountType STRING,
    LoadID INTEGER,
    InsertedDateTime DATETIME,
    SubscriptionType INTEGER,
    EffectiveLoadTime TIMESTAMP,
    ActiveFlag INTEGER,
    ActiveDate DATE,
    LoyaltyTierID STRING
);

--------------------------------------------------------------------------------
-- DDL for InvoiceFact Table
--------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `directed-asset-449105-t9.ML_DS.InvoiceFact` (
    InvoiceId STRING,
    InvoiceNumber STRING,
    Type STRING,
    Status STRING,
    DateCreated TIMESTAMP,
    DateApproved TIMESTAMP,
    Description STRING,
    TotalAmount NUMERIC,
    DiscountAmount NUMERIC,
    TaxAmount NUMERIC,
    TaxPixCredits NUMERIC,
    TaxRate FLOAT64, -- Changed from FLOAT to FLOAT64 to resolve error
    TaxJurisdiction STRING,
    TotalRevenue NUMERIC,
    TotalPixCredits NUMERIC,
    AccountID STRING,
    OrderHistoryID STRING,
    CreditCardTransactionID STRING,
    PayPalTransactionID STRING,
    BalanceID STRING,
    PaymentComm INTEGER,
    WLOrderHistory STRING,
    WePayTransactionID STRING,
    SQSPOrderHistoryID INTEGER,
    SQSPTransactionID STRING,
    UA_Device STRING,
    UA_IsMobileDevice STRING,
    NewCustomerFlag INTEGER,
    MembershipID STRING,
    Occupation STRING,
    Email STRING,
    FullName STRING,
    EffectiveLoadTime TIMESTAMP,
    LoadID INTEGER,
    InsertedDateTime DATETIME,
    ProUserFlag INTEGER,
    SalesChannel STRING,
    CreatedBy STRING,
    AcceptedBy STRING,
    RejectedBy STRING,
    CreditType STRING,
    AdminEmail STRING,
    CreditsCreatedBy STRING,
    ActiveFlag INTEGER,
    InActiveDate DATE
);

--------------------------------------------------------------------------------
-- DDL for InvoiceItem Table
--------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `directed-asset-449105-t9.ML_DS.InvoiceItem` (
    ItemId STRING,
    InvoiceId STRING,
    Category STRING,
    Type STRING,
    Finish STRING,
    PrintSize STRING,
    ProductName STRING,
    LineNumber STRING,
    Description STRING,
    Amount NUMERIC,
    Quantity INTEGER,
    PaidQuantity INTEGER,
    Unit NUMERIC,
    CostAmount NUMERIC,
    TotalAmount NUMERIC,
    TaxCredits NUMERIC,
    Revenue NUMERIC,
    TaxCredits_Item NUMERIC,
    Discount NUMERIC,
    InDiscount NUMERIC,
    InsertedDateTime DATETIME,
    EffectiveLoadTime TIMESTAMP,
    EntryType STRING,
    Flag INTEGER,
    EntryDate DATE,
    IsItem BOOLEAN,
    ShippingRevenue NUMERIC,
    OtherRevenue NUMERIC,
    Shipping NUMERIC,
    ShippingDiscount NUMERIC,
    TotalDiscount NUMERIC
);
