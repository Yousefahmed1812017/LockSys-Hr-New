-- Mobile auth API, step 2: phone normalizer + the new view APP_USERS_LOGIN_V2.
-- Run in the ERP schema (GSPLUS) with UTF-8, after 01_APP_AUTH_TABLES.sql.
--
-- APP_USERS_LOGIN_V2 is a COPY of APP_USERS_LOGIN under a new name; the old view
-- and everything that uses it are untouched. Differences:
--   removed : PASSWORD (a view that anyone can SELECT must not carry it)
--   added   : USER_CODE, USER_LANGUAGE, USER_IMAGE_PATH, the missing OTP flags
--             (IS_OTP_WHATSAPP / IS_OTP_MAIL / IS_OTP_LOGIN), PHONE_NORMALIZED,
--             EMAIL_NORMALIZED, and PHONE_IS_SHARED / EMAIL_IS_SHARED (the same
--             phone/e-mail on 2+ users cannot identify one person).
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

-- 11 digits 01xxxxxxxxx, 10 digits 1xxxxxxxxx and 20 1xxxxxxxxx all become
-- 201xxxxxxxxx; text and numbers of impossible length become NULL.
CREATE OR REPLACE FUNCTION APP_NORMALIZE_PHONE (
    p_phone   IN VARCHAR2,
    p_country IN VARCHAR2 DEFAULT '20'
) RETURN VARCHAR2 DETERMINISTIC IS
    l_d VARCHAR2(100);
BEGIN
    IF p_phone IS NULL OR REGEXP_LIKE(p_phone, '[A-Za-z]') THEN
        RETURN NULL;
    END IF;
    l_d := REGEXP_REPLACE(p_phone, '[^0-9]', '');
    IF l_d IS NULL THEN
        RETURN NULL;
    END IF;
    IF SUBSTR(l_d, 1, 2) = '00' THEN
        l_d := SUBSTR(l_d, 3);
    END IF;
    IF SUBSTR(l_d, 1, LENGTH(p_country)) = p_country AND LENGTH(l_d) = LENGTH(p_country) + 10 THEN
        RETURN l_d;
    END IF;
    IF SUBSTR(l_d, 1, 1) = '0' AND LENGTH(l_d) = 11 THEN
        RETURN p_country || SUBSTR(l_d, 2);
    END IF;
    IF SUBSTR(l_d, 1, 1) = '1' AND LENGTH(l_d) = 10 THEN
        RETURN p_country || l_d;
    END IF;
    IF LENGTH(l_d) BETWEEN 8 AND 15 THEN
        RETURN l_d;
    END IF;
    RETURN NULL;
END;
/

CREATE OR REPLACE VIEW APP_USERS_LOGIN_V2 AS
SELECT
    -- user (SEC_USERS) ----------------------------------------------------------
    U.ID                        AS USER_ID,
    U.CODE                      AS USER_CODE,
    U.USERNAME,
    U.NAME                      AS USER_NAME_EN,
    U.NAME_AR                   AS USER_NAME_AR,
    U.EMAIL,
    LOWER(TRIM(U.EMAIL))        AS EMAIL_NORMALIZED,
    CASE WHEN LOWER(TRIM(U.EMAIL)) IS NOT NULL
          AND COUNT(*) OVER (PARTITION BY LOWER(TRIM(U.EMAIL))) > 1
         THEN 1 ELSE 0 END      AS EMAIL_IS_SHARED,
    U.PHONE,
    APP_NORMALIZE_PHONE(U.PHONE) AS PHONE_NORMALIZED,
    CASE WHEN APP_NORMALIZE_PHONE(U.PHONE) IS NOT NULL
          AND COUNT(*) OVER (PARTITION BY APP_NORMALIZE_PHONE(U.PHONE)) > 1
         THEN 1 ELSE 0 END      AS PHONE_IS_SHARED,
    U.IS_LOCKED,
    U.STATUS                    AS USER_STATUS,
    U.NOTES                     AS USER_NOTES,
    U.USER_TYPE,
    U.IS_OTP_SMS,
    U.IS_OTP_WHATSAPP,
    U.IS_OTP_MAIL,
    U.IS_OTP_LOGIN,
    U.IS_MOBILE_APP,
    U.DEFAULT_COMPANY_ID,
    U.DEFAULT_BRANCH_ID,
    U.DEVICE_UUID               AS DEVICE_UUID,
    U.IS_CHANGE_PASSWORD        AS IS_CHANGE_PASSWORD,
    U.IS_PASSWORD_CHANGED       AS IS_PASSWORD_CHANGED,
    U.PASSWORD_CHANGE_DATE      AS PASSWORD_CHANGE_DATE,
    U.ALLOW_ATTENDANCE,
    U.ALLOW_DAILIES,
    U.DEFAULT_LANGUAGE          AS USER_LANGUAGE,
    U.IMAGE_PATH                AS USER_IMAGE_PATH,
    -- employee (HR_EMPLOYEES) -----------------------------------------------------
    E.EMPLOYEE_ID,
    E.CODE                      AS EMPLOYEE_CODE,
    E.ID_NUMBER,
    E.DATE_OF_BIRTH,
    E.FULL_NAME_AR              AS EMPLOYEE_NAME_AR,
    E.FULL_NAME_EN              AS EMPLOYEE_NAME_EN,
    E.HIRE_DATE,
    E.EMPLOYMENT_STATUS,
    E.WORK_LOCATION,
    E.SITE_ID,
    E.CHECK_LOCATION,
    -- category / status -------------------------------------------------------------
    E.EMPLOYEE_CATEGORY_ID,
    CAT.NAME                    AS EMPLOYEE_CATEGORY_NAME_EN,
    CAT.ARABIC_NAME             AS EMPLOYEE_CATEGORY_NAME_AR,
    E.EMPLOYMENT_STATUS         AS EMPLOYEE_STATUS_ID,
    EMP_STS.NAME                AS EMPLOYEE_STATUS_NAME_EN,
    EMP_STS.ARABIC_NAME         AS EMPLOYEE_STATUS_NAME_AR,
    -- department / job ----------------------------------------------------------------
    E.DEPARTMENT_ID,
    DEPT.NAME                   AS DEPARTMENT_NAME_EN,
    DEPT.ARABIC_NAME            AS DEPARTMENT_NAME_AR,
    DEPT.CODE                   AS DEPARTMENT_CODE,
    E.JOB_ID,
    JOB.NAME                    AS JOB_TITLE_NAME_EN,
    JOB.ARABIC_NAME             AS JOB_TITLE_NAME_AR,
    JOB.CODE                    AS JOB_TITLE_CODE,
    -- site and its location (for the attendance geofence) ------------------------------
    SITE.NAME                   AS SITE_NAME_EN,
    SITE.ARABIC_NAME            AS SITE_NAME_AR,
    SITE.CODE                   AS SITE_CODE,
    E.LOCATION_ID,
    LOC.NAME                    AS LOCATION_NAME_EN,
    LOC.ARABIC_NAME             AS LOCATION_NAME_AR,
    LOC.LATITUDE                AS LOCATION_LATITUDE,
    LOC.LONGITUDE               AS LOCATION_LONGITUDE,
    LOC.ZONE_TYPE               AS LOCATION_ZONE_TYPE,
    LOC.ZONE_RADIUS             AS LOCATION_ZONE_RADIUS,
    -- direct manager ----------------------------------------------------------------------
    E.REPORTS_TO                AS MANAGER_EMPLOYEE_ID,
    MGR.FULL_NAME_EN            AS MANAGER_NAME_EN,
    MGR.FULL_NAME_AR            AS MANAGER_NAME_AR,
    -- company / branch --------------------------------------------------------------------
    COMP.NAME_AR                AS COMPANY_NAME,
    BRNCH.NAME_AR               AS BRANCH_NAME
FROM SEC_USERS U
LEFT JOIN HR_EMPLOYEES E
    ON U.USER_TYPE = 'EMPLOYEE'
   AND E.EMPLOYEE_ID = U.REFERENCE_USER_ID
LEFT JOIN HR_EMPLOYEE_CATEGORIES CAT
    ON CAT.ID = E.EMPLOYEE_CATEGORY_ID
LEFT JOIN HR_EMPLOYEE_STATUS EMP_STS
    ON EMP_STS.ID = E.EMPLOYMENT_STATUS
LEFT JOIN HR_DEPARTMENT DEPT
    ON DEPT.ID = E.DEPARTMENT_ID
LEFT JOIN HR_JOB_TITLE JOB
    ON JOB.ID = E.JOB_ID
LEFT JOIN HR_SITES SITE
    ON SITE.ID = E.SITE_ID
LEFT JOIN HR_SITE_LOCATIONS LOC
    ON LOC.ID = E.LOCATION_ID
LEFT JOIN HR_EMPLOYEES MGR
    ON MGR.EMPLOYEE_ID = E.REPORTS_TO
LEFT JOIN DBS_COMP COMP
    ON COMP.ID = U.DEFAULT_COMPANY_ID
LEFT JOIN DBS_BRANCHES BRNCH
    ON BRNCH.ID = U.DEFAULT_BRANCH_ID;

COMMENT ON TABLE APP_USERS_LOGIN_V2 IS 'Users for the mobile auth API. Copy of APP_USERS_LOGIN without PASSWORD, plus normalized phone/e-mail, shared-contact flags and the other OTP flags.';
