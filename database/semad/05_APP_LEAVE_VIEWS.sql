-- Mobile leave API, step 1: three NEW views over the leave tables. Nothing existing is
-- touched (VW_EMPLOYEE_LEAVES and the old Leave / MyEmployees modules stay as they are).
-- Run in the ERP schema (GSPLUS) with UTF-8.
--
-- Tables behind them:
--   HR_EMPLOYEE_LEAVE_REQUESTS     one row per request (dates, day counts, balance before/after, status)
--   HR_LEAVE_TYPES                 the leave types and their rules
--   HR_LEAVE_STATUS                1 New, 2 Pending, 3 In progress, 4 Approved, 5 Rejected, 6 Cancelled
--   HR_LEAVE_BALANCES              one row per employee and year (annual, casual, sick, ...)
--   HR_LEAVE_REQUEST_STAGES        the approval chain of a request (stage order, PENDING/APPROVED/REJECTED)
--   HR_LEAVE_APPROVAL_STAGES       names of the stages (employee, substitute, direct manager, HR ...)
--   HR_EMPLOYEE_LEAVE_REQUEST_STATUS_LOG   status history of a request
--   HR_LEAVE_STATUS_REASONS        why a request was cancelled / changed
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

CREATE OR REPLACE VIEW APP_LEAVE_REQUESTS_V2 AS
SELECT
    LR.ID                              AS REQUEST_ID,
    LR.LEAVE_REQUEST_NO                AS REQUEST_NO,
    LR.EMPLOYEE_ID,
    LR.COMPANY_ID,
    LR.LEAVE_TYPE_ID,
    LT.CODE                            AS TYPE_CODE,
    LT.NAME                            AS TYPE_NAME_EN,
    LT.ARABIC_NAME                     AS TYPE_NAME_AR,
    LT.IS_PAID                         AS TYPE_IS_PAID,
    LT.DEDUCT_FROM_BALANCE             AS TYPE_DEDUCTS_BALANCE,
    LR.REQUEST_DATE,
    LR.START_DATE,
    LR.END_DATE,
    EXTRACT(YEAR FROM LR.START_DATE)   AS START_YEAR,
    LR.RETURN_DATE,
    LR.ACTUAL_RETURN_DATE,
    LR.TOTAL_LEAVE_DAYS                AS TOTAL_DAYS,
    LR.WEEKEND_DAYS,
    LR.OFFICIAL_HOLIDAYS               AS HOLIDAY_DAYS,
    LR.WORKING_DAYS,
    LR.HALF_DAY_TYPE,
    LR.BALANCE_BEFORE,
    LR.BALANCE_AFTER,
    LR.DISCOUNTED_BALANCE,
    LR.UNPAID_DAYS,
    LR.LEAVE_REASON                    AS REASON,
    LR.EMERGENCY_PHONE,
    LR.SUBSTITUTE_EMP_ID               AS SUBSTITUTE_EMPLOYEE_ID,
    SUB.FULL_NAME_AR                   AS SUBSTITUTE_NAME_AR,
    SUB.FULL_NAME_EN                   AS SUBSTITUTE_NAME_EN,
    LR.STATUS_ID,
    ST.NAME                            AS STATUS_NAME_EN,
    ST.ARABIC_NAME                     AS STATUS_NAME_AR,
    ST.COLOR_ID                        AS STATUS_COLOR_ID,
    ST.CAN_EDIT                        AS STATUS_CAN_EDIT,
    ST.CAN_CANCEL                      AS STATUS_CAN_CANCEL,
    ST.IS_FINAL                        AS STATUS_IS_FINAL,
    LR.STATUS_DATE,
    LR.STATUS_REASON_ID,
    SR.NAME                            AS STATUS_REASON_NAME_EN,
    SR.ARABIC_NAME                     AS STATUS_REASON_NAME_AR,
    LR.STATUS_REASON_TEXT,
    LR.DECISION_NUMBER,
    LR.DECISION_YEAR,
    NVL(LR.IS_CUT, 0)                  AS IS_CUT,
    LR.CUT_DATE,
    LR.CUT_REASON,
    NVL(LR.IS_MOBILE_USER, 0)          AS CREATED_FROM_MOBILE,
    PS.STAGE_ID                        AS CURRENT_STAGE_ID,
    AST.CODE                           AS CURRENT_STAGE_CODE,
    AST.NAME                           AS CURRENT_STAGE_NAME_EN,
    AST.ARABIC_NAME                    AS CURRENT_STAGE_NAME_AR,
    NVL(LR.CREATED_DATE, LR.CREATED)   AS CREATED_AT
FROM HR_EMPLOYEE_LEAVE_REQUESTS LR
JOIN HR_LEAVE_TYPES LT
    ON LT.ID = LR.LEAVE_TYPE_ID
LEFT JOIN HR_LEAVE_STATUS ST
    ON ST.ID = LR.STATUS_ID
LEFT JOIN HR_LEAVE_STATUS_REASONS SR
    ON SR.ID = LR.STATUS_REASON_ID
LEFT JOIN HR_EMPLOYEES SUB
    ON SUB.EMPLOYEE_ID = LR.SUBSTITUTE_EMP_ID
-- the stage the request is waiting at: the first one still PENDING
LEFT JOIN (
    SELECT LEAVE_REQUEST_ID, STAGE_ID,
           ROW_NUMBER() OVER (PARTITION BY LEAVE_REQUEST_ID ORDER BY STAGE_ORDER) AS RN
      FROM HR_LEAVE_REQUEST_STAGES
     WHERE STATUS = 'PENDING'
) PS
    ON PS.LEAVE_REQUEST_ID = LR.ID AND PS.RN = 1
LEFT JOIN HR_LEAVE_APPROVAL_STAGES AST
    ON AST.ID = PS.STAGE_ID;

COMMENT ON TABLE APP_LEAVE_REQUESTS_V2 IS 'Leave requests with type, status, current approval stage and substitute names, for the mobile leave API.';

-- Same figures as VW_EMPLOYEE_BALANCE (the ERP's own balance view): the stored entitlement
-- and carried-forward days, and what was USED / what REMAINS counted from the approved
-- requests (HR_GET_LEAVE_BALANCE_USED / HR_GET_LEAVE_REMAINING). The USED / REMAINING
-- columns stored in HR_LEAVE_BALANCES are not maintained and are not used here.
-- Unlike VW_EMPLOYEE_BALANCE, the year of the row is passed to the functions.
CREATE OR REPLACE VIEW APP_LEAVE_BALANCES_V2 AS
SELECT
    B.EMPLOYEE_ID,
    B.BALANCE_YEAR,
    NVL(B.CARRIED_FORWARD, 0)                                   AS ANNUAL_CARRIED_FORWARD,
    NVL(B.ANNUAL_ENTITLEMENT, 0)                                AS ANNUAL_ENTITLEMENT,
    NVL(B.CARRIED_FORWARD, 0) + NVL(B.ANNUAL_ENTITLEMENT, 0)    AS ANNUAL_TOTAL_AVAILABLE,
    HR_GET_LEAVE_BALANCE_USED(B.EMPLOYEE_ID, 3, B.BALANCE_YEAR) AS ANNUAL_USED,
    HR_GET_LEAVE_REMAINING(B.EMPLOYEE_ID, 3, B.BALANCE_YEAR)    AS ANNUAL_REMAINING,
    NVL(B.CASUAL_ENTITLEMENT, 0)                                AS CASUAL_ENTITLEMENT,
    HR_GET_LEAVE_BALANCE_USED(B.EMPLOYEE_ID, 24, B.BALANCE_YEAR) AS CASUAL_USED,
    HR_GET_LEAVE_REMAINING(B.EMPLOYEE_ID, 24, B.BALANCE_YEAR)   AS CASUAL_REMAINING
FROM HR_LEAVE_BALANCES B
WHERE NVL(B.STATUS, '1') = '1';

COMMENT ON TABLE APP_LEAVE_BALANCES_V2 IS 'Annual and casual leave balances of an employee per year (same figures as VW_EMPLOYEE_BALANCE), for the mobile leave API.';

CREATE OR REPLACE VIEW APP_LEAVE_TYPES_V2 AS
SELECT
    LT.ID                      AS LEAVE_TYPE_ID,
    LT.COMPANY_ID,
    LT.CODE,
    LT.NAME                    AS NAME_EN,
    LT.ARABIC_NAME             AS NAME_AR,
    LT.DISPLAY_ORDER,
    NVL(LT.IS_MOBILE_APP, 0)   AS IS_MOBILE_APP,
    LT.IS_PAID,
    LT.DEDUCT_FROM_BALANCE,
    LT.ALLOW_HALF_DAY,
    LT.MIN_DAYS_PER_REQUEST,
    LT.MAX_DAYS_PER_REQUEST,
    LT.MAX_DAYS_PER_YEAR,
    LT.MAX_DAYS_PER_MONTH,
    LT.EXCLUDE_WEEKENDS,
    LT.EXCLUDE_HOLIDAYS,
    LT.REQUIRES_REASON,
    LT.REQUIRES_APPROVAL,
    LT.REQUIRES_DOCUMENT,
    LT.ATTACHMENT_MANDATORY,
    LT.ADVANCE_NOTICE_DAYS,
    LT.GENDER_SPECIFIC,
    LT.CAN_EXCEED_BALANCE
FROM HR_LEAVE_TYPES LT
WHERE LT.STATUS = '1';

COMMENT ON TABLE APP_LEAVE_TYPES_V2 IS 'Active leave types and their rules, for the mobile leave API (IS_MOBILE_APP = 1 can be requested from the app).';
