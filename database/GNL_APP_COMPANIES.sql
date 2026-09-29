-- =============================================================================
-- GNL_APP_COMPANIES
-- Registry of the companies that use the LockSys HR mobile app.
--
-- The app asks the user for a company CODE once (first launch). It sends the
-- code to the central endpoint, which reads this table and returns the
-- company's name, its own ORDS base URL (API_BASE_URL), the languages it
-- supports and the modules (FEATURES) it has enabled.
--
-- Conventions: GNL_ prefix (general / shared), ARABIC_NAME + NAME, STATUS '1'/'0',
-- mandatory audit columns, {TABLE}_SEQ, TRG_{TABLE}_AUD, IDX_/CHK_ naming.
-- NOTE: no COMPANY_ID / BRANCH_ID columns on purpose: this table IS the list of
-- companies, so it is not company-scoped.
--
-- Run as the API schema owner (e.g. LOCKSYS_API), with UTF-8 enabled so the
-- Arabic text is stored correctly (SQLcl: set encoding UTF-8 / -Dfile.encoding=UTF-8).
-- =============================================================================

-- 1) Sequence -----------------------------------------------------------------
CREATE SEQUENCE GNL_APP_COMPANIES_SEQ START WITH 1 INCREMENT BY 1 NOCACHE;

-- 2) Table --------------------------------------------------------------------
CREATE TABLE GNL_APP_COMPANIES (
    ID                  NUMBER          NOT NULL,
    CODE                VARCHAR2(50)    NOT NULL,                  -- typed by the user in the app, stored UPPER
    ARABIC_NAME         VARCHAR2(500)   NOT NULL,
    NAME                VARCHAR2(500)   NOT NULL,                  -- English name
    API_BASE_URL        VARCHAR2(500)   NOT NULL,                  -- this company's ORDS base URL (https, ends with /)
    MULTI_LANGUAGE      VARCHAR2(1)     DEFAULT '1' NOT NULL,      -- 1 = Arabic + English, 0 = DEFAULT_LANGUAGE only
    DEFAULT_LANGUAGE    VARCHAR2(5)     DEFAULT 'ar' NOT NULL,     -- ar | en
    FEATURES            VARCHAR2(1000)  DEFAULT '["attendance","leave","payslip"]' NOT NULL, -- enabled modules (JSON array)
    LOGO_URL            VARCHAR2(500),
    COUNTRY_CODE        VARCHAR2(2)     DEFAULT 'SA' NOT NULL,     -- ISO 3166-1 alpha-2
    TIMEZONE            VARCHAR2(50)    DEFAULT 'Asia/Riyadh' NOT NULL,
    CURRENCY_CODE       VARCHAR2(3)     DEFAULT 'SAR' NOT NULL,    -- ISO 4217 (payslip)
    SUPPORT_EMAIL       VARCHAR2(200),
    SUPPORT_PHONE       VARCHAR2(30),
    MIN_APP_VERSION     VARCHAR2(20),                              -- older app builds are asked to update
    MAINTENANCE_MODE    VARCHAR2(1)     DEFAULT '0' NOT NULL,      -- 1 = company server under maintenance
    STATUS              VARCHAR2(10)    DEFAULT '1' NOT NULL,      -- 1 active, 0 inactive (code rejected by the app)
    NOTES               VARCHAR2(4000),
    CREATED_BY_USER_ID  NUMBER,
    CREATED_BY          VARCHAR2(1000),
    CREATED_DATE        DATE,
    UPDATED_BY_USER_ID  NUMBER,
    UPDATED_BY          VARCHAR2(1000),
    UPDATED_DATE        DATE,
    CONSTRAINT GNL_APP_COMPANIES_PK PRIMARY KEY (ID),
    CONSTRAINT GNL_APP_COMPANIES_UQ UNIQUE (CODE),
    CONSTRAINT CHK_GNL_APP_COMPANIES_CODE   CHECK (REGEXP_LIKE(CODE, '^[A-Z0-9_-]{2,50}$')),
    CONSTRAINT CHK_GNL_APP_COMPANIES_URL    CHECK (REGEXP_LIKE(API_BASE_URL, '^https://[^ ]+/$')),
    CONSTRAINT CHK_GNL_APP_COMPANIES_MULTI  CHECK (MULTI_LANGUAGE IN ('0','1')),
    CONSTRAINT CHK_GNL_APP_COMPANIES_LANG   CHECK (DEFAULT_LANGUAGE IN ('ar','en')),
    CONSTRAINT CHK_GNL_APP_COMPANIES_FEAT   CHECK (FEATURES IS JSON),
    CONSTRAINT CHK_GNL_APP_COMPANIES_COUNTRY CHECK (REGEXP_LIKE(COUNTRY_CODE, '^[A-Z]{2}$')),
    CONSTRAINT CHK_GNL_APP_COMPANIES_CURR   CHECK (REGEXP_LIKE(CURRENCY_CODE, '^[A-Z]{3}$')),
    CONSTRAINT CHK_GNL_APP_COMPANIES_MAINT  CHECK (MAINTENANCE_MODE IN ('0','1')),
    CONSTRAINT CHK_GNL_APP_COMPANIES_STATUS CHECK (STATUS IN ('0','1'))
);

-- 3) Indexes (the UNIQUE constraint already indexes CODE, the lookup key) -------
CREATE INDEX IDX_APP_COMPANIES_STATUS ON GNL_APP_COMPANIES (STATUS);

-- 4) Comments -----------------------------------------------------------------
COMMENT ON TABLE  GNL_APP_COMPANIES                  IS 'Companies registered to use the LockSys HR mobile app (one row per company, resolved by CODE).';
COMMENT ON COLUMN GNL_APP_COMPANIES.ID               IS 'Primary key (from GNL_APP_COMPANIES_SEQ).';
COMMENT ON COLUMN GNL_APP_COMPANIES.CODE             IS 'Company code the user types in the app. Unique, UPPER case, cannot be changed after creation.';
COMMENT ON COLUMN GNL_APP_COMPANIES.ARABIC_NAME      IS 'Company name in Arabic.';
COMMENT ON COLUMN GNL_APP_COMPANIES.NAME             IS 'Company name in English.';
COMMENT ON COLUMN GNL_APP_COMPANIES.API_BASE_URL     IS 'Root ORDS URL of this company''s server. https only, always ends with /. All app requests after sign-in use it.';
COMMENT ON COLUMN GNL_APP_COMPANIES.MULTI_LANGUAGE   IS '1 = the company supports Arabic and English (user can switch), 0 = only DEFAULT_LANGUAGE.';
COMMENT ON COLUMN GNL_APP_COMPANIES.DEFAULT_LANGUAGE IS 'Main language of the company: ar or en. Used as the app language when MULTI_LANGUAGE = 0.';
COMMENT ON COLUMN GNL_APP_COMPANIES.FEATURES         IS 'JSON array of enabled modules, e.g. ["attendance","leave","payslip"]. The app shows only these.';
COMMENT ON COLUMN GNL_APP_COMPANIES.LOGO_URL         IS 'Optional company logo (absolute https URL).';
COMMENT ON COLUMN GNL_APP_COMPANIES.COUNTRY_CODE     IS 'ISO 3166-1 alpha-2 country code (SA, AE, ...).';
COMMENT ON COLUMN GNL_APP_COMPANIES.TIMEZONE         IS 'IANA time zone used for attendance times (e.g. Asia/Riyadh).';
COMMENT ON COLUMN GNL_APP_COMPANIES.CURRENCY_CODE    IS 'ISO 4217 currency shown on payslips (SAR, AED, ...).';
COMMENT ON COLUMN GNL_APP_COMPANIES.SUPPORT_EMAIL    IS 'HR / support e-mail shown in the app help screen.';
COMMENT ON COLUMN GNL_APP_COMPANIES.SUPPORT_PHONE    IS 'HR / support phone shown in the app help screen.';
COMMENT ON COLUMN GNL_APP_COMPANIES.MIN_APP_VERSION  IS 'Minimum mobile app version allowed for this company (force-update). NULL = any.';
COMMENT ON COLUMN GNL_APP_COMPANIES.MAINTENANCE_MODE IS '1 = the company server is under maintenance; the app shows a maintenance message.';
COMMENT ON COLUMN GNL_APP_COMPANIES.STATUS           IS '1 = active, 0 = inactive (the app rejects the code).';

-- 5) Trigger (audit pattern) ----------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_GNL_APP_COMPANIES_AUD
    BEFORE INSERT OR UPDATE
    ON GNL_APP_COMPANIES
    FOR EACH ROW
BEGIN
    IF INSERTING THEN
        -- 1) ID from Sequence
        IF :NEW.ID IS NULL THEN
            SELECT GNL_APP_COMPANIES_SEQ.NEXTVAL INTO :NEW.ID FROM DUAL;
        END IF;

        -- 2) Audit - Insert
        :NEW.CREATED_DATE       := SYSDATE;
        :NEW.CREATED_BY         := NVL(V('APP_USER'), USER);
        :NEW.CREATED_BY_USER_ID := V('P0_USER_ID');

        -- 3) Status default
        IF :NEW.STATUS IS NULL THEN
            :NEW.STATUS := '1';
        END IF;

        -- 4/5) No COMPANY_ID / BRANCH_ID: this table is the list of companies.
        -- 6) CODE is typed by the user (not auto generated).
    END IF;

    IF UPDATING THEN
        IF :NEW.CODE <> :OLD.CODE THEN
            RAISE_APPLICATION_ERROR(-20001, 'GNL_APP_COMPANIES.CODE cannot be changed. Create a new company instead.');
        END IF;

        -- Audit - Update
        :NEW.UPDATED_DATE       := SYSDATE;
        :NEW.UPDATED_BY         := NVL(V('APP_USER'), USER);
        :NEW.UPDATED_BY_USER_ID := V('P0_USER_ID');
    END IF;

    -- 7) Custom logic: normalize values (INSERT and UPDATE)
    :NEW.CODE := UPPER(TRIM(:NEW.CODE));
    IF :NEW.API_BASE_URL IS NOT NULL THEN
        :NEW.API_BASE_URL := TRIM(:NEW.API_BASE_URL);
        IF SUBSTR(:NEW.API_BASE_URL, -1) <> '/' THEN
            :NEW.API_BASE_URL := :NEW.API_BASE_URL || '/';
        END IF;
    END IF;
    :NEW.DEFAULT_LANGUAGE := LOWER(TRIM(:NEW.DEFAULT_LANGUAGE));
    :NEW.COUNTRY_CODE     := UPPER(TRIM(:NEW.COUNTRY_CODE));
    :NEW.CURRENCY_CODE    := UPPER(TRIM(:NEW.CURRENCY_CODE));
END;
/
ALTER TRIGGER TRG_GNL_APP_COMPANIES_AUD ENABLE;

-- 6) Test data: 5 companies ------------------------------------------------------
-- URLs and contact details are placeholders: replace with the real ORDS URLs.
-- LOCKSYS  : all modules, Arabic + English, Arabic default
INSERT INTO GNL_APP_COMPANIES
    (CODE, ARABIC_NAME, NAME, API_BASE_URL, MULTI_LANGUAGE, DEFAULT_LANGUAGE, FEATURES,
     COUNTRY_CODE, TIMEZONE, CURRENCY_CODE, SUPPORT_EMAIL, SUPPORT_PHONE, MIN_APP_VERSION, NOTES)
VALUES
    ('LOCKSYS', 'لوك سيس للحلول', 'LockSys Solutions', 'https://api.locksys.co/ords/hr/', '1', 'ar',
     '["attendance","leave","payslip"]', 'SA', 'Asia/Riyadh', 'SAR',
     'hr@locksys.co', '+966500000001', '1.0.0', 'Main company and reference tenant.');

-- DEMO     : attendance + leave only, English default (for demos)
INSERT INTO GNL_APP_COMPANIES
    (CODE, ARABIC_NAME, NAME, API_BASE_URL, MULTI_LANGUAGE, DEFAULT_LANGUAGE, FEATURES,
     COUNTRY_CODE, TIMEZONE, CURRENCY_CODE, SUPPORT_EMAIL, SUPPORT_PHONE, NOTES)
VALUES
    ('DEMO', 'الشركة التجريبية', 'Demo Company', 'https://demo.locksys.co/ords/hr/', '1', 'en',
     '["attendance","leave"]', 'SA', 'Asia/Riyadh', 'SAR',
     'demo@locksys.co', '+966500000002', 'Used for demos and app store review.');

-- ALNOOR   : Arabic only (MULTI_LANGUAGE = 0), all modules
INSERT INTO GNL_APP_COMPANIES
    (CODE, ARABIC_NAME, NAME, API_BASE_URL, MULTI_LANGUAGE, DEFAULT_LANGUAGE, FEATURES,
     COUNTRY_CODE, TIMEZONE, CURRENCY_CODE, SUPPORT_EMAIL, SUPPORT_PHONE, NOTES)
VALUES
    ('ALNOOR', 'شركة النور للتجارة', 'Al Noor Trading Co.', 'https://hr.alnoor.example.com/ords/hr/', '0', 'ar',
     '["attendance","leave","payslip"]', 'SA', 'Asia/Riyadh', 'SAR',
     'hr@alnoor.example.com', '+966500000003', 'Arabic-only company (no language switch in the app).');

-- GULFTECH : inactive (code rejected), English default, UAE
INSERT INTO GNL_APP_COMPANIES
    (CODE, ARABIC_NAME, NAME, API_BASE_URL, MULTI_LANGUAGE, DEFAULT_LANGUAGE, FEATURES,
     COUNTRY_CODE, TIMEZONE, CURRENCY_CODE, SUPPORT_EMAIL, SUPPORT_PHONE, STATUS, NOTES)
VALUES
    ('GULFTECH', 'شركة الخليج للتقنية', 'Gulf Technology Co.', 'https://hr.gulftech.example.com/ords/hr/', '1', 'en',
     '["attendance","payslip"]', 'AE', 'Asia/Dubai', 'AED',
     'hr@gulftech.example.com', '+971500000004', '0', 'Suspended subscription: used to test the inactive-company path.');

-- ALAMAL   : medical group, all modules, Arabic default
INSERT INTO GNL_APP_COMPANIES
    (CODE, ARABIC_NAME, NAME, API_BASE_URL, MULTI_LANGUAGE, DEFAULT_LANGUAGE, FEATURES,
     COUNTRY_CODE, TIMEZONE, CURRENCY_CODE, SUPPORT_EMAIL, SUPPORT_PHONE, MIN_APP_VERSION, NOTES)
VALUES
    ('ALAMAL', 'مجموعة الأمل الطبية', 'Al Amal Medical Group', 'https://hr.alamal.example.com/ords/hr/', '1', 'ar',
     '["attendance","leave","payslip"]', 'SA', 'Asia/Riyadh', 'SAR',
     'hr@alamal.example.com', '+966500000005', '1.0.0', 'Healthcare group with several branches.');

COMMIT;

-- 7) Quick check ------------------------------------------------------------------
-- SELECT ID, CODE, ARABIC_NAME, NAME, API_BASE_URL, MULTI_LANGUAGE, DEFAULT_LANGUAGE, FEATURES, STATUS
-- FROM   GNL_APP_COMPANIES ORDER BY ID;
