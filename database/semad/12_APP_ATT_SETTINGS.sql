-- Mobile attendance settings per company, and the fake-location policy. Run in the ERP
-- schema (GSPLUS) with UTF-8, before 09_APP_ATTENDANCE_PKG.sql is re-run. Safe to run twice.
--
-- MOCK_LOCATION_POLICY decides what the server does when the phone reports a fake /
-- mock location (a "fake GPS" app or a mock provider):
--   BLOCK   the check-in is refused (403 MOCK_LOCATION). The employee sees why. (default)
--   RECORD  the check-in is accepted and written with IS_FAKE = 1 and the reported
--           coordinates in FAKE_LATITUDE / FAKE_LONGITUDE, with no work-area check, so HR
--           can review it (see APP_ATTENDANCE_FAKE_V2). Same as the old CheckInAndOut API.
-- Change it with:  UPDATE APP_ATT_SETTINGS SET MOCK_LOCATION_POLICY = 'RECORD' WHERE COMPANY_ID = 2;
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
    PROCEDURE RUN (p_sql IN VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE p_sql;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE NOT IN (-955, -1430, -2260, -2261, -2275, -1408) THEN RAISE; END IF;
    END;
BEGIN
    RUN('CREATE TABLE APP_ATT_SETTINGS (
            ID                  NUMBER NOT NULL,
            COMPANY_ID          NUMBER NOT NULL,
            MOCK_LOCATION_POLICY VARCHAR2(10) DEFAULT ''BLOCK'' NOT NULL,
            NOTES               VARCHAR2(4000),
            STATUS              VARCHAR2(10) DEFAULT ''1'',
            CREATED_BY_USER_ID  NUMBER,
            CREATED_BY          VARCHAR2(1000),
            CREATED_DATE        DATE,
            UPDATED_BY_USER_ID  NUMBER,
            UPDATED_BY          VARCHAR2(1000),
            UPDATED_DATE        DATE,
            CONSTRAINT APP_ATT_SETTINGS_PK PRIMARY KEY (ID),
            CONSTRAINT APP_ATT_SETTINGS_UQ UNIQUE (COMPANY_ID),
            CONSTRAINT CHK_APP_ATT_SETTINGS_POLICY CHECK (MOCK_LOCATION_POLICY IN (''BLOCK'', ''RECORD''))
        )');
    RUN('CREATE SEQUENCE APP_ATT_SETTINGS_SEQ START WITH 1 INCREMENT BY 1 NOCACHE');
    RUN('CREATE OR REPLACE TRIGGER TRG_APP_ATT_SETTINGS_AUD
            BEFORE INSERT OR UPDATE ON APP_ATT_SETTINGS
            FOR EACH ROW
         BEGIN
            IF INSERTING THEN
                IF :NEW.ID IS NULL THEN
                    SELECT APP_ATT_SETTINGS_SEQ.NEXTVAL INTO :NEW.ID FROM DUAL;
                END IF;
                :NEW.CREATED_DATE       := SYSDATE;
                :NEW.CREATED_BY         := NVL(V(''APP_USER''), USER);
                :NEW.CREATED_BY_USER_ID := V(''P0_USER_ID'');
                IF :NEW.STATUS IS NULL THEN :NEW.STATUS := ''1''; END IF;
            END IF;
            IF UPDATING THEN
                :NEW.UPDATED_DATE       := SYSDATE;
                :NEW.UPDATED_BY         := NVL(V(''APP_USER''), USER);
                :NEW.UPDATED_BY_USER_ID := V(''P0_USER_ID'');
            END IF;
         END;');
    RUN('COMMENT ON TABLE APP_ATT_SETTINGS IS ''Mobile attendance settings per company (fake-location policy)''');
    RUN('COMMENT ON COLUMN APP_ATT_SETTINGS.MOCK_LOCATION_POLICY IS ''BLOCK = refuse a check-in from a fake location; RECORD = accept it and flag it for HR (IS_FAKE = 1)''');
END;
/

-- one row for every company that has users on the mobile app (BLOCK until HR decides)
INSERT INTO APP_ATT_SETTINGS (COMPANY_ID, MOCK_LOCATION_POLICY, NOTES)
SELECT DISTINCT U.DEFAULT_COMPANY_ID, 'BLOCK', 'Default: fake locations are refused'
  FROM SEC_USERS U
 WHERE U.DEFAULT_COMPANY_ID IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM APP_ATT_SETTINGS S WHERE S.COMPANY_ID = U.DEFAULT_COMPANY_ID);
COMMIT;

-- The policy of a company; BLOCK when it has no row.
CREATE OR REPLACE FUNCTION APP_ATT_MOCK_POLICY (p_company_id IN NUMBER) RETURN VARCHAR2 IS
    l VARCHAR2(10);
BEGIN
    SELECT MOCK_LOCATION_POLICY INTO l FROM APP_ATT_SETTINGS WHERE COMPANY_ID = p_company_id AND STATUS = '1';
    RETURN l;
EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN 'BLOCK';
END;
/

-- For HR: every check-in made from a fake location, newest first.
CREATE OR REPLACE VIEW APP_ATTENDANCE_FAKE_V2 AS
SELECT L.ID                AS LOG_ID,
       L.EMPLOYEE_ID,
       E.CODE              AS EMPLOYEE_CODE,
       E.FULL_NAME_AR      AS EMPLOYEE_NAME_AR,
       E.FULL_NAME_EN      AS EMPLOYEE_NAME_EN,
       L.ATTENDANCE_DATE,
       L.ACTUAL_TIME,
       L.CHECK_TYPE,
       L.SITES_ID,
       S.ARABIC_NAME       AS SITE_NAME_AR,
       L.FAKE_LATITUDE,
       L.FAKE_LONGITUDE,
       L.NOTES
  FROM HR_ATTENDANCE_LOG L
  JOIN HR_EMPLOYEES E ON E.EMPLOYEE_ID = L.EMPLOYEE_ID
  LEFT JOIN HR_SITES S ON S.ID = L.SITES_ID
 WHERE L.IS_FAKE = 1;

COMMENT ON TABLE APP_ATTENDANCE_FAKE_V2 IS 'Check-ins that came from a fake / mock location (IS_FAKE = 1), for HR review';

SELECT COMPANY_ID, MOCK_LOCATION_POLICY FROM APP_ATT_SETTINGS ORDER BY COMPANY_ID;
