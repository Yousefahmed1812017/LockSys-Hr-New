-- Mobile feature TREE + per-company grants. Run as LOCKSYS_API using UTF-8.
-- Prerequisite: GNL_APP_FEATURES.sql (flat catalog) and GNL_APP_COMPANIES.sql.
-- Features live in their own scripts, e.g. GNL_APP_FEATURES_AUTH.sql.
-- Re-runnable: structural changes are guarded. It seeds NO features or grants.
--
-- MODEL
--   GNL_APP_FEATURES           global catalog, a tree (PARENT_ID). Developer-owned.
--   GNL_APP_COMPANY_FEATURES   which features each company switched on (STATUS 1/0).
--   GNL_APP_COMPANY_FEATURES_V effective features per company (see rule below).
--   GNL_APP_FEATURES_PKG       IS_ENABLED / SET_ENABLED / ENABLED_JSON.
--
-- EFFECTIVE RULE: a feature is on for a company only when its own grant is on,
-- its catalog row is active, AND every ancestor is on. Switching a parent off
-- hides its children without deleting their saved choices; switching it back on
-- restores them. A child granted under a disabled parent is simply not effective.
--
-- CODE RULE (enforced by TRG_GNL_APP_FEATURES_TREE): a root code has no dot; a
-- child code is <parent code>.<one segment>. CODE and PARENT_ID are immutable.
--   auth                          main feature
--   auth.phone                      sub feature
--   auth.phone.via_sms                sub sub feature
--
-- ADD A FEATURE: (1) a script like GNL_APP_FEATURES_AUTH.sql (insert-only),
-- (2) add the same key to the Dart AppFeature enum, (3) grant it to companies with
--   BEGIN GNL_APP_FEATURES_PKG.SET_ENABLED('1000', 'auth.phone.via_sms', 1); COMMIT; END;
-- Retire a feature with STATUS = '0' rather than DELETE (grants reference it).
--
-- NOTE: a switch in this catalog states what the COMPANY allows. An OTP channel
-- only works once the backend actually has a gateway for it.
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

BEGIN
    IF USER <> 'LOCKSYS_API' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Run this migration as LOCKSYS_API.');
    END IF;
END;
/

-- 1) Catalog becomes a tree ---------------------------------------------------
DECLARE
    l_cnt NUMBER;
BEGIN
    SELECT COUNT(*) INTO l_cnt FROM USER_TAB_COLUMNS
     WHERE TABLE_NAME = 'GNL_APP_FEATURES' AND COLUMN_NAME = 'PARENT_ID';
    IF l_cnt = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE GNL_APP_FEATURES ADD (PARENT_ID NUMBER)';
    END IF;

    EXECUTE IMMEDIATE 'ALTER TABLE GNL_APP_FEATURES MODIFY (CODE VARCHAR2(100 CHAR))';

    SELECT COUNT(*) INTO l_cnt FROM USER_CONSTRAINTS
     WHERE CONSTRAINT_NAME = 'CHK_GNL_APP_FEATURES_CODE';
    IF l_cnt > 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE GNL_APP_FEATURES DROP CONSTRAINT CHK_GNL_APP_FEATURES_CODE';
    END IF;
    EXECUTE IMMEDIATE q'[ALTER TABLE GNL_APP_FEATURES ADD CONSTRAINT CHK_GNL_APP_FEATURES_CODE
        CHECK (REGEXP_LIKE(CODE, '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$', 'c'))]';

    SELECT COUNT(*) INTO l_cnt FROM USER_CONSTRAINTS
     WHERE CONSTRAINT_NAME = 'GNL_APP_FEATURES_FK_PARENT';
    IF l_cnt = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE GNL_APP_FEATURES ADD CONSTRAINT GNL_APP_FEATURES_FK_PARENT
            FOREIGN KEY (PARENT_ID) REFERENCES GNL_APP_FEATURES (ID)';
    END IF;

    SELECT COUNT(*) INTO l_cnt FROM USER_INDEXES WHERE INDEX_NAME = 'IDX_FEATURES_PARENT';
    IF l_cnt = 0 THEN
        EXECUTE IMMEDIATE 'CREATE INDEX IDX_FEATURES_PARENT ON GNL_APP_FEATURES (PARENT_ID)';
    END IF;
END;
/

COMMENT ON TABLE GNL_APP_FEATURES IS 'Global mobile app feature catalog, a tree: main features (PARENT_ID null) and their sub features. One row per implemented feature. Company grants live in GNL_APP_COMPANY_FEATURES.';
COMMENT ON COLUMN GNL_APP_FEATURES.CODE IS 'Immutable lowercase dotted path key used by API and mobile, e.g. auth.phone_otp.sms. A child code is its parent code plus one segment. Supplied explicitly by the developer.';
COMMENT ON COLUMN GNL_APP_FEATURES.PARENT_ID IS 'Parent feature; null for a main feature. Immutable. A sub feature is effective for a company only while every ancestor is also on.';

CREATE OR REPLACE TRIGGER TRG_GNL_APP_FEATURES_AUD
    BEFORE INSERT OR UPDATE ON GNL_APP_FEATURES
    FOR EACH ROW
BEGIN
    IF INSERTING THEN
        IF :NEW.ID IS NULL THEN
            SELECT GNL_APP_FEATURES_SEQ.NEXTVAL INTO :NEW.ID FROM DUAL;
        END IF;
        :NEW.CREATED_DATE := SYSDATE;
        :NEW.CREATED_BY := NVL(V('APP_USER'), USER);
        :NEW.CREATED_BY_USER_ID := V('P0_USER_ID');
        IF :NEW.STATUS IS NULL THEN
            :NEW.STATUS := '1';
        END IF;
        -- No company/branch: definitions are shared by all tenants.
        -- CODE is a developer-defined key, not an auto-generated number.
    END IF;
    IF UPDATING THEN
        :NEW.UPDATED_DATE := SYSDATE;
        :NEW.UPDATED_BY := NVL(V('APP_USER'), USER);
        :NEW.UPDATED_BY_USER_ID := V('P0_USER_ID');
    END IF;
    :NEW.CODE := LOWER(TRIM(:NEW.CODE));
    IF UPDATING AND (:NEW.CODE IS NULL OR :NEW.CODE <> :OLD.CODE) THEN
        RAISE_APPLICATION_ERROR(-20002, 'Feature CODE cannot be changed.');
    END IF;
    IF UPDATING AND NVL(:NEW.PARENT_ID, -1) <> NVL(:OLD.PARENT_ID, -1) THEN
        RAISE_APPLICATION_ERROR(-20003, 'Feature PARENT_ID cannot be changed.');
    END IF;
END;
/
ALTER TRIGGER TRG_GNL_APP_FEATURES_AUD ENABLE;

-- Code/parent consistency needs to read other rows of the same table, so it runs
-- after the statement (a row trigger would hit ORA-04091).
CREATE OR REPLACE TRIGGER TRG_GNL_APP_FEATURES_TREE
    FOR INSERT OR UPDATE OF CODE, PARENT_ID ON GNL_APP_FEATURES
COMPOUND TRIGGER
    TYPE t_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    g_ids t_ids;

    AFTER EACH ROW IS
    BEGIN
        g_ids(g_ids.COUNT + 1) := :NEW.ID;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        FOR i IN 1 .. g_ids.COUNT LOOP
            FOR r IN (
                SELECT c.CODE
                  FROM GNL_APP_FEATURES c
                  LEFT JOIN GNL_APP_FEATURES p ON p.ID = c.PARENT_ID
                 WHERE c.ID = g_ids(i)
                   AND ( (c.PARENT_ID IS NULL AND INSTR(c.CODE, '.') > 0)
                      OR (c.PARENT_ID IS NOT NULL
                          AND (p.ID IS NULL
                               OR SUBSTR(c.CODE, 1, LENGTH(p.CODE) + 1) <> p.CODE || '.'
                               OR INSTR(c.CODE, '.', LENGTH(p.CODE) + 2) > 0)) )
            ) LOOP
                RAISE_APPLICATION_ERROR(-20004,
                    'Feature code "' || r.CODE || '" must be a root without a dot, or its parent code + "." + one segment.');
            END LOOP;
        END LOOP;
    END AFTER STATEMENT;
END TRG_GNL_APP_FEATURES_TREE;
/
ALTER TRIGGER TRG_GNL_APP_FEATURES_TREE ENABLE;

-- 2) Company grants -----------------------------------------------------------
DECLARE
    l_cnt NUMBER;
BEGIN
    SELECT COUNT(*) INTO l_cnt FROM USER_TABLES WHERE TABLE_NAME = 'GNL_APP_COMPANY_FEATURES';
    IF l_cnt = 0 THEN
        EXECUTE IMMEDIATE q'[CREATE TABLE GNL_APP_COMPANY_FEATURES (
            ID                  NUMBER NOT NULL,
            COMPANY_ID          NUMBER NOT NULL,
            FEATURE_ID          NUMBER NOT NULL,
            STATUS              VARCHAR2(10) DEFAULT '1' NOT NULL,
            NOTES               VARCHAR2(4000),
            CREATED_BY_USER_ID  NUMBER,
            CREATED_BY          VARCHAR2(1000),
            CREATED_DATE        DATE,
            UPDATED_BY_USER_ID  NUMBER,
            UPDATED_BY          VARCHAR2(1000),
            UPDATED_DATE        DATE,
            CONSTRAINT GNL_APP_COMPANY_FEATURES_PK PRIMARY KEY (ID),
            CONSTRAINT GNL_APP_COMPANY_FEATURES_UQ UNIQUE (COMPANY_ID, FEATURE_ID),
            CONSTRAINT GNL_APP_COMPANY_FEATURES_FK_COMPANY
                FOREIGN KEY (COMPANY_ID) REFERENCES GNL_APP_COMPANIES (ID),
            CONSTRAINT GNL_APP_COMPANY_FEATURES_FK_FEATURE
                FOREIGN KEY (FEATURE_ID) REFERENCES GNL_APP_FEATURES (ID),
            CONSTRAINT CHK_GNL_APP_COMPANY_FEATURES_STATUS CHECK (STATUS IN ('0', '1'))
        )]';
        EXECUTE IMMEDIATE 'CREATE SEQUENCE GNL_APP_COMPANY_FEATURES_SEQ START WITH 1 INCREMENT BY 1 NOCACHE';
        EXECUTE IMMEDIATE 'CREATE INDEX IDX_COMPANY_FEATURES_FEATURE ON GNL_APP_COMPANY_FEATURES (FEATURE_ID)';
    END IF;
END;
/

COMMENT ON TABLE GNL_APP_COMPANY_FEATURES IS 'Features each mobile-app company has switched on. COMPANY_ID refers to the central directory GNL_APP_COMPANIES, not to a tenant company of the ERP.';
COMMENT ON COLUMN GNL_APP_COMPANY_FEATURES.STATUS IS '1 = the company allows this feature; 0 = switched off. A missing row means off. A sub feature is effective only when its ancestors are on too (see GNL_APP_COMPANY_FEATURES_V).';

CREATE OR REPLACE TRIGGER TRG_GNL_APP_COMPANY_FEATURES_AUD
    BEFORE INSERT OR UPDATE ON GNL_APP_COMPANY_FEATURES
    FOR EACH ROW
BEGIN
    IF INSERTING THEN
        IF :NEW.ID IS NULL THEN
            SELECT GNL_APP_COMPANY_FEATURES_SEQ.NEXTVAL INTO :NEW.ID FROM DUAL;
        END IF;
        :NEW.CREATED_DATE := SYSDATE;
        :NEW.CREATED_BY := NVL(V('APP_USER'), USER);
        :NEW.CREATED_BY_USER_ID := V('P0_USER_ID');
        IF :NEW.STATUS IS NULL THEN
            :NEW.STATUS := '1';
        END IF;
        -- COMPANY_ID is the directory company chosen by the caller; never defaulted
        -- from the ERP session.
    END IF;
    IF UPDATING THEN
        :NEW.UPDATED_DATE := SYSDATE;
        :NEW.UPDATED_BY := NVL(V('APP_USER'), USER);
        :NEW.UPDATED_BY_USER_ID := V('P0_USER_ID');
        IF :NEW.COMPANY_ID <> :OLD.COMPANY_ID OR :NEW.FEATURE_ID <> :OLD.FEATURE_ID THEN
            RAISE_APPLICATION_ERROR(-20005, 'COMPANY_ID and FEATURE_ID cannot be changed; disable the grant and add another.');
        END IF;
    END IF;
END;
/
ALTER TRIGGER TRG_GNL_APP_COMPANY_FEATURES_AUD ENABLE;

-- 3) Effective features per company -------------------------------------------
-- The hierarchy only descends through nodes that are on, so a row that survives
-- the WHERE has every ancestor on as well.
CREATE OR REPLACE VIEW GNL_APP_COMPANY_FEATURES_V AS
WITH cf AS (
    SELECT c.ID AS COMPANY_ID, c.CODE AS COMPANY_CODE,
           f.ID AS FEATURE_ID, f.CODE AS FEATURE_CODE, f.PARENT_ID,
           f.ARABIC_NAME, f.NAME, f.DISPLAY_ORDER,
           CASE WHEN f.STATUS = '1' AND g.STATUS = '1' THEN 1 ELSE 0 END AS IS_ON
      FROM GNL_APP_COMPANIES c
     CROSS JOIN GNL_APP_FEATURES f
      LEFT JOIN GNL_APP_COMPANY_FEATURES g
        ON g.COMPANY_ID = c.ID AND g.FEATURE_ID = f.ID
)
SELECT COMPANY_ID, COMPANY_CODE, FEATURE_ID, FEATURE_CODE, PARENT_ID,
       ARABIC_NAME, NAME, LEVEL AS TREE_LEVEL,
       LTRIM(SYS_CONNECT_BY_PATH(LPAD(DISPLAY_ORDER, 6, '0') || LPAD(FEATURE_ID, 10, '0'), '/'), '/') AS SORT_KEY
  FROM cf
 WHERE IS_ON = 1
 START WITH PARENT_ID IS NULL
CONNECT BY PRIOR FEATURE_ID = PARENT_ID
       AND PRIOR COMPANY_ID = COMPANY_ID
       AND PRIOR IS_ON = 1;

COMMENT ON TABLE GNL_APP_COMPANY_FEATURES_V IS 'Effective mobile features per directory company: own grant on, catalog row active and every ancestor on. Order by SORT_KEY for tree order.';

-- 4) Package ------------------------------------------------------------------
CREATE OR REPLACE PACKAGE GNL_APP_FEATURES_PKG AS
    -- 1 when the feature is effective for the company, else 0. SQL-callable.
    -- An unknown company yields 0; an unknown feature code raises -20011 so a
    -- typo in calling code is never silently treated as "off".
    FUNCTION IS_ENABLED (p_company_code IN VARCHAR2, p_feature_code IN VARCHAR2) RETURN NUMBER;

    -- Switches one company grant on (1) or off (0). Does not commit.
    PROCEDURE SET_ENABLED (p_company_code IN VARCHAR2, p_feature_code IN VARCHAR2, p_enabled IN NUMBER);

    -- JSON array of the company's effective feature codes, in tree order.
    FUNCTION ENABLED_JSON (p_company_id IN NUMBER) RETURN CLOB;
END GNL_APP_FEATURES_PKG;
/

CREATE OR REPLACE PACKAGE BODY GNL_APP_FEATURES_PKG AS

    FUNCTION FEATURE_ID_OF (p_feature_code IN VARCHAR2) RETURN NUMBER IS
        l_id GNL_APP_FEATURES.ID%TYPE;
    BEGIN
        SELECT ID INTO l_id FROM GNL_APP_FEATURES WHERE CODE = LOWER(TRIM(p_feature_code));
        RETURN l_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20011, 'Unknown feature code: ' || p_feature_code);
    END;

    FUNCTION IS_ENABLED (p_company_code IN VARCHAR2, p_feature_code IN VARCHAR2) RETURN NUMBER IS
        l_feature_id NUMBER := FEATURE_ID_OF(p_feature_code);
        l_cnt        NUMBER;
    BEGIN
        SELECT COUNT(*) INTO l_cnt
          FROM GNL_APP_COMPANY_FEATURES_V
         WHERE COMPANY_CODE = UPPER(TRIM(p_company_code))
           AND FEATURE_ID   = l_feature_id;
        RETURN CASE WHEN l_cnt > 0 THEN 1 ELSE 0 END;
    END;

    PROCEDURE SET_ENABLED (p_company_code IN VARCHAR2, p_feature_code IN VARCHAR2, p_enabled IN NUMBER) IS
        l_company_id NUMBER;
        l_feature_id NUMBER := FEATURE_ID_OF(p_feature_code);
        l_status     VARCHAR2(1);
    BEGIN
        IF p_enabled IS NULL OR p_enabled NOT IN (0, 1) THEN
            RAISE_APPLICATION_ERROR(-20012, 'p_enabled must be 0 or 1.');
        END IF;
        l_status := TO_CHAR(p_enabled);
        BEGIN
            SELECT ID INTO l_company_id FROM GNL_APP_COMPANIES
             WHERE CODE = UPPER(TRIM(p_company_code));
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20010, 'Unknown company code: ' || p_company_code);
        END;

        MERGE INTO GNL_APP_COMPANY_FEATURES g
        USING (SELECT l_company_id AS COMPANY_ID, l_feature_id AS FEATURE_ID FROM DUAL) s
           ON (g.COMPANY_ID = s.COMPANY_ID AND g.FEATURE_ID = s.FEATURE_ID)
         WHEN MATCHED THEN UPDATE SET g.STATUS = l_status
         WHEN NOT MATCHED THEN INSERT (COMPANY_ID, FEATURE_ID, STATUS)
              VALUES (s.COMPANY_ID, s.FEATURE_ID, l_status);
    END;

    FUNCTION ENABLED_JSON (p_company_id IN NUMBER) RETURN CLOB IS
        l_json CLOB;
    BEGIN
        SELECT JSON_ARRAYAGG(FEATURE_CODE ORDER BY SORT_KEY RETURNING CLOB)
          INTO l_json
          FROM GNL_APP_COMPANY_FEATURES_V
         WHERE COMPANY_ID = p_company_id;
        RETURN NVL(l_json, TO_CLOB('[]'));
    END;

END GNL_APP_FEATURES_PKG;
/

COMMENT ON COLUMN GNL_APP_COMPANIES.FEATURES IS 'DEPRECATED: superseded by GNL_APP_COMPANY_FEATURES. Nothing reads it any more; the API returns the effective features from the tree.';
