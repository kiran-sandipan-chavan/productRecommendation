-- Arrays for realistic data generation
DECLARE ACCOUNT_TYPES ARRAY<STRING> DEFAULT ['Individual', 'Business', 'Premium'];
DECLARE OCCUPATIONS ARRAY<STRING> DEFAULT ['Software Engineer', 'Graphic Designer', 'Student', 'Marketing Manager', 'Architect', 'Doctor', 'Teacher', 'Sales', 'Analyst', 'Artist'];
DECLARE LOYALTY_TIERS ARRAY<STRING> DEFAULT ['New', 'Bronze', 'Silver', 'Gold', 'Platinum'];

-- Insert Sample Data into Account Table (approx. 500 records)
INSERT INTO `directed-asset-449105-t9.ML_DS.Account` (
    AccountID, CreatedDate, MembershipID, Occupation, MembershipStartDate,
    MembershipDowngradeDate, ExpiredDate, TrialProLevelUsed, AccountType, LoadID,
    InsertedDateTime, SubscriptionType, EffectiveLoadTime, ActiveFlag, ActiveDate, LoyaltyTierID
)
SELECT
    FORMAT('cust_%04d', id) AS AccountID,
    TIMESTAMP_ADD(TIMESTAMP('2021-01-01 00:00:00 UTC'), INTERVAL id * 1000000 SECOND) AS CreatedDate,
    CASE WHEN MOD(id, 5) = 0 THEN 'M_PLATINUM'
         WHEN MOD(id, 5) = 1 THEN 'M_GOLD'
         WHEN MOD(id, 5) = 2 THEN 'M_SILVER'
         ELSE 'M_BRONZE' END AS MembershipID,
    OCCUPATIONS[OFFSET(MOD(id, ARRAY_LENGTH(OCCUPATIONS)))] AS Occupation,
    TIMESTAMP_ADD(TIMESTAMP('2021-01-01 00:00:00 UTC'), INTERVAL id * 1000000 SECOND) AS MembershipStartDate,
    NULL AS MembershipDowngradeDate,
    TIMESTAMP(DATE_ADD(DATE(TIMESTAMP_ADD(TIMESTAMP('2021-01-01 00:00:00 UTC'), INTERVAL id * 1000000 SECOND)), INTERVAL 2 YEAR)) AS ExpiredDate,
    MOD(id, 7) = 0 AS TrialProLevelUsed,
    ACCOUNT_TYPES[OFFSET(MOD(id, ARRAY_LENGTH(ACCOUNT_TYPES)))] AS AccountType,
    id AS LoadID,
    DATETIME(CURRENT_TIMESTAMP()) AS InsertedDateTime,
    MOD(id, 3) AS SubscriptionType,
    CURRENT_TIMESTAMP() AS EffectiveLoadTime,
    1 AS ActiveFlag,
    DATE(CURRENT_TIMESTAMP()) AS ActiveDate,
    LOYALTY_TIERS[OFFSET(MOD(id, ARRAY_LENGTH(LOYALTY_TIERS)))] AS LoyaltyTierID
FROM
    UNNEST(GENERATE_ARRAY(1, 500)) AS id;
