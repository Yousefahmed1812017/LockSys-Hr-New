-- Central mobile feature catalog. Run as LOCKSYS_API using UTF-8.
-- Global definitions only: company grants and employee permissions are separate.
-- CODE matches the mobile AppFeature / API keys. Register future features here.
-- Existing GNL_APP_COMPANIES.FEATURES and ORDS behavior are unchanged.
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

BEGIN
    IF USER <> 'LOCKSYS_API' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Run this migration as LOCKSYS_API.');
    END IF;
END;
/

CREATE TABLE GNL_APP_FEATURES (
    ID                  NUMBER NOT NULL,
    CODE                VARCHAR2(50 CHAR) NOT NULL,
    ARABIC_NAME         VARCHAR2(500 CHAR) NOT NULL,
    NAME                VARCHAR2(500 CHAR) NOT NULL,
    STATUS              VARCHAR2(10) DEFAULT '1' NOT NULL,
    DISPLAY_ORDER       NUMBER DEFAULT 0 NOT NULL,
    NOTES               VARCHAR2(4000),
    CREATED_BY_USER_ID  NUMBER,
    CREATED_BY          VARCHAR2(1000),
    CREATED_DATE        DATE,
    UPDATED_BY_USER_ID  NUMBER,
    UPDATED_BY          VARCHAR2(1000),
    UPDATED_DATE        DATE,
    CONSTRAINT GNL_APP_FEATURES_PK PRIMARY KEY (ID),
    CONSTRAINT GNL_APP_FEATURES_UQ UNIQUE (CODE),
    CONSTRAINT CHK_GNL_APP_FEATURES_CODE
        CHECK (REGEXP_LIKE(CODE, '^[a-z][a-z0-9_]{0,49}$', 'c')),
    CONSTRAINT CHK_GNL_APP_FEATURES_STATUS CHECK (STATUS IN ('0', '1')),
    CONSTRAINT CHK_GNL_APP_FEATURES_ORDER
        CHECK (DISPLAY_ORDER >= 0 AND DISPLAY_ORDER = TRUNC(DISPLAY_ORDER))
);

CREATE SEQUENCE GNL_APP_FEATURES_SEQ START WITH 1 INCREMENT BY 1 NOCACHE;

COMMENT ON TABLE GNL_APP_FEATURES IS 'Global mobile app feature catalog; one row per implemented feature. Company grants and employee permissions are managed separately.';
COMMENT ON COLUMN GNL_APP_FEATURES.CODE IS 'Immutable lowercase API/mobile feature key, e.g. attendance. Supplied explicitly by the developer.';
COMMENT ON COLUMN GNL_APP_FEATURES.STATUS IS '1 = active catalog entry; 0 = inactive. Enforcement requires API/mobile integration.';
COMMENT ON COLUMN GNL_APP_FEATURES.DISPLAY_ORDER IS 'Nonnegative integer display order; smaller values first.';

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
END;
/
ALTER TRIGGER TRG_GNL_APP_FEATURES_AUD ENABLE;

INSERT INTO GNL_APP_FEATURES (CODE, ARABIC_NAME, NAME, DISPLAY_ORDER)
VALUES ('attendance', 'الحضور والانصراف', 'Attendance', 10);
INSERT INTO GNL_APP_FEATURES (CODE, ARABIC_NAME, NAME, DISPLAY_ORDER)
VALUES ('leave', 'الإجازات', 'Leave', 20);
INSERT INTO GNL_APP_FEATURES (CODE, ARABIC_NAME, NAME, DISPLAY_ORDER)
VALUES ('payslip', 'كشف الراتب', 'Payslip', 30);
COMMIT;
