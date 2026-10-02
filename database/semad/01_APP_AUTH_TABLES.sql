-- Mobile auth API, step 1: tables. Run in the ERP schema (GSPLUS) with UTF-8.
-- Creates only NEW objects (prefix APP_AUTH_); it never touches an existing
-- table, view, package or ORDS module. Re-runnable: nothing is dropped or
-- overwritten, settings you changed are kept.
--
--   APP_AUTH_CONFIG    every tunable of the API (see the seed at the bottom)
--   APP_AUTH_OTP       one-time codes (sign in and password recovery)
--   APP_AUTH_ATTEMPTS  failed / successful attempts, for lockout and rate limits
--   APP_AUTH_SESSIONS  issued tokens (stored hashed); revocable and expiring
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
    PROCEDURE make (p_table VARCHAR2, p_ddl VARCHAR2) IS
        l_cnt NUMBER;
    BEGIN
        SELECT COUNT(*) INTO l_cnt FROM USER_TABLES WHERE TABLE_NAME = p_table;
        IF l_cnt = 0 THEN
            EXECUTE IMMEDIATE p_ddl;
            EXECUTE IMMEDIATE 'CREATE SEQUENCE ' || p_table || '_SEQ START WITH 1 INCREMENT BY 1 NOCACHE';
        END IF;
    END;
BEGIN
    make('APP_AUTH_CONFIG', q'[CREATE TABLE APP_AUTH_CONFIG (
        ID                  NUMBER NOT NULL,
        CODE                VARCHAR2(50) NOT NULL,
        CFG_VALUE           VARCHAR2(500),
        NOTES               VARCHAR2(4000),
        STATUS              VARCHAR2(10) DEFAULT '1' NOT NULL,
        CREATED_BY_USER_ID  NUMBER,
        CREATED_BY          VARCHAR2(1000),
        CREATED_DATE        DATE,
        UPDATED_BY_USER_ID  NUMBER,
        UPDATED_BY          VARCHAR2(1000),
        UPDATED_DATE        DATE,
        CONSTRAINT APP_AUTH_CONFIG_PK PRIMARY KEY (ID),
        CONSTRAINT APP_AUTH_CONFIG_UQ UNIQUE (CODE),
        CONSTRAINT CHK_APP_AUTH_CONFIG_STATUS CHECK (STATUS IN ('0', '1'))
    )]');

    make('APP_AUTH_OTP', q'[CREATE TABLE APP_AUTH_OTP (
        ID                  NUMBER NOT NULL,
        PUBLIC_ID           VARCHAR2(32) NOT NULL,
        PURPOSE             VARCHAR2(10) NOT NULL,
        CHANNEL             VARCHAR2(10) NOT NULL,
        IDENTIFIER_TYPE     VARCHAR2(10) NOT NULL,
        IDENTIFIER_KEY      VARCHAR2(64) NOT NULL,
        USER_ID             NUMBER,
        DESTINATION_MASKED  VARCHAR2(100),
        CODE_HASH           VARCHAR2(64) NOT NULL,
        ATTEMPTS            NUMBER DEFAULT 0 NOT NULL,
        MAX_ATTEMPTS        NUMBER NOT NULL,
        OTP_STATUS          VARCHAR2(12) DEFAULT 'PENDING' NOT NULL,
        EXPIRES_AT          DATE NOT NULL,
        VERIFIED_AT         DATE,
        RESET_TOKEN_HASH    VARCHAR2(64),
        RESET_EXPIRES_AT    DATE,
        DELIVERY_STATUS     VARCHAR2(30),
        DELIVERY_ERROR      VARCHAR2(1000),
        DEV_CODE            VARCHAR2(10),
        IP_ADDRESS          VARCHAR2(100),
        DEVICE_UUID         VARCHAR2(100),
        CREATED_BY_USER_ID  NUMBER,
        CREATED_BY          VARCHAR2(1000),
        CREATED_DATE        DATE,
        UPDATED_BY_USER_ID  NUMBER,
        UPDATED_BY          VARCHAR2(1000),
        UPDATED_DATE        DATE,
        CONSTRAINT APP_AUTH_OTP_PK PRIMARY KEY (ID),
        CONSTRAINT APP_AUTH_OTP_UQ UNIQUE (PUBLIC_ID),
        CONSTRAINT CHK_APP_AUTH_OTP_PURPOSE CHECK (PURPOSE IN ('LOGIN', 'RESET')),
        CONSTRAINT CHK_APP_AUTH_OTP_CHANNEL CHECK (CHANNEL IN ('SMS', 'WHATSAPP', 'EMAIL')),
        CONSTRAINT CHK_APP_AUTH_OTP_TYPE CHECK (IDENTIFIER_TYPE IN ('PHONE', 'EMAIL')),
        CONSTRAINT CHK_APP_AUTH_OTP_STATUS CHECK (OTP_STATUS IN ('PENDING', 'VERIFIED', 'USED', 'EXPIRED', 'CANCELLED'))
    )]');

    make('APP_AUTH_ATTEMPTS', q'[CREATE TABLE APP_AUTH_ATTEMPTS (
        ID                  NUMBER NOT NULL,
        ATTEMPT_KEY         VARCHAR2(200) NOT NULL,
        KIND                VARCHAR2(12) NOT NULL,
        IS_SUCCESS          VARCHAR2(1) DEFAULT '0' NOT NULL,
        ATTEMPT_AT          DATE DEFAULT SYSDATE NOT NULL,
        IP_ADDRESS          VARCHAR2(100),
        CREATED_BY_USER_ID  NUMBER,
        CREATED_BY          VARCHAR2(1000),
        CREATED_DATE        DATE,
        UPDATED_BY_USER_ID  NUMBER,
        UPDATED_BY          VARCHAR2(1000),
        UPDATED_DATE        DATE,
        CONSTRAINT APP_AUTH_ATTEMPTS_PK PRIMARY KEY (ID),
        CONSTRAINT CHK_APP_AUTH_ATT_KIND CHECK (KIND IN ('PASSWORD', 'OTP', 'IP')),
        CONSTRAINT CHK_APP_AUTH_ATT_OK CHECK (IS_SUCCESS IN ('0', '1'))
    )]');

    make('APP_AUTH_SESSIONS', q'[CREATE TABLE APP_AUTH_SESSIONS (
        ID                  NUMBER NOT NULL,
        USER_ID             NUMBER NOT NULL,
        TOKEN_HASH          VARCHAR2(64) NOT NULL,
        DEVICE_UUID         VARCHAR2(100),
        LOGIN_METHOD        VARCHAR2(20),
        EXPIRES_AT          DATE NOT NULL,
        IS_REVOKED          VARCHAR2(1) DEFAULT '0' NOT NULL,
        REVOKED_AT          DATE,
        LAST_USED_AT        DATE,
        IP_ADDRESS          VARCHAR2(100),
        CREATED_BY_USER_ID  NUMBER,
        CREATED_BY          VARCHAR2(1000),
        CREATED_DATE        DATE,
        UPDATED_BY_USER_ID  NUMBER,
        UPDATED_BY          VARCHAR2(1000),
        UPDATED_DATE        DATE,
        CONSTRAINT APP_AUTH_SESSIONS_PK PRIMARY KEY (ID),
        CONSTRAINT APP_AUTH_SESSIONS_UQ UNIQUE (TOKEN_HASH),
        CONSTRAINT CHK_APP_AUTH_SES_REVOKED CHECK (IS_REVOKED IN ('0', '1'))
    )]');
END;
/

-- Indexes (guarded)
DECLARE
    PROCEDURE idx (p_name VARCHAR2, p_ddl VARCHAR2) IS
        l_cnt NUMBER;
    BEGIN
        SELECT COUNT(*) INTO l_cnt FROM USER_INDEXES WHERE INDEX_NAME = p_name;
        IF l_cnt = 0 THEN EXECUTE IMMEDIATE p_ddl; END IF;
    END;
BEGIN
    idx('IDX_AUTH_OTP_KEY',    'CREATE INDEX IDX_AUTH_OTP_KEY ON APP_AUTH_OTP (IDENTIFIER_KEY, CREATED_DATE)');
    idx('IDX_AUTH_OTP_IP',     'CREATE INDEX IDX_AUTH_OTP_IP ON APP_AUTH_OTP (IP_ADDRESS, CREATED_DATE)');
    idx('IDX_AUTH_OTP_RESET',  'CREATE INDEX IDX_AUTH_OTP_RESET ON APP_AUTH_OTP (RESET_TOKEN_HASH)');
    idx('IDX_AUTH_OTP_USER',   'CREATE INDEX IDX_AUTH_OTP_USER ON APP_AUTH_OTP (USER_ID)');
    idx('IDX_AUTH_ATT_KEY',    'CREATE INDEX IDX_AUTH_ATT_KEY ON APP_AUTH_ATTEMPTS (ATTEMPT_KEY, ATTEMPT_AT)');
    idx('IDX_AUTH_SES_USER',   'CREATE INDEX IDX_AUTH_SES_USER ON APP_AUTH_SESSIONS (USER_ID)');
END;
/

COMMENT ON TABLE APP_AUTH_CONFIG IS 'Settings of the mobile auth API (APP_AUTH_PKG). One row per setting; change CFG_VALUE to tune behaviour.';
COMMENT ON TABLE APP_AUTH_OTP IS 'One-time codes for mobile sign in and password recovery. Codes are stored hashed; DEV_CODE is filled only while OTP_DELIVERY = LOG_ONLY.';
COMMENT ON COLUMN APP_AUTH_OTP.PUBLIC_ID IS 'Opaque id the app sends back with the code. The row id is never exposed.';
COMMENT ON COLUMN APP_AUTH_OTP.USER_ID IS 'Null for a decoy: the identifier matched no single eligible user. Decoys look identical to the caller so the API does not reveal who has an account.';
COMMENT ON COLUMN APP_AUTH_OTP.IDENTIFIER_KEY IS 'SHA-256 of purpose + type + normalized phone/e-mail. Used for resend and hourly limits without keeping the number in clear.';
COMMENT ON TABLE APP_AUTH_ATTEMPTS IS 'Attempt log behind the lockout: N failures since the last success inside the window = locked.';
COMMENT ON TABLE APP_AUTH_SESSIONS IS 'Tokens issued by the mobile auth API. Only the SHA-256 of the token is stored.';

-- Audit trigger shared by the four tables (same pattern as the other tables).
DECLARE
    PROCEDURE trg (p_table VARCHAR2, p_has_status BOOLEAN) IS
    BEGIN
        EXECUTE IMMEDIATE
            'CREATE OR REPLACE TRIGGER TRG_' || p_table || '_AUD BEFORE INSERT OR UPDATE ON ' || p_table ||
            ' FOR EACH ROW BEGIN' ||
            '  IF INSERTING THEN' ||
            '    IF :NEW.ID IS NULL THEN SELECT ' || p_table || '_SEQ.NEXTVAL INTO :NEW.ID FROM DUAL; END IF;' ||
            '    :NEW.CREATED_DATE := SYSDATE;' ||
            '    :NEW.CREATED_BY := NVL(V(''APP_USER''), USER);' ||
            '    :NEW.CREATED_BY_USER_ID := V(''P0_USER_ID'');' ||
            CASE WHEN p_has_status THEN '    IF :NEW.STATUS IS NULL THEN :NEW.STATUS := ''1''; END IF;' ELSE '' END ||
            '  END IF;' ||
            '  IF UPDATING THEN' ||
            '    :NEW.UPDATED_DATE := SYSDATE;' ||
            '    :NEW.UPDATED_BY := NVL(V(''APP_USER''), USER);' ||
            '    :NEW.UPDATED_BY_USER_ID := V(''P0_USER_ID'');' ||
            '  END IF;' ||
            ' END;';
    END;
BEGIN
    trg('APP_AUTH_CONFIG', TRUE);
    trg('APP_AUTH_OTP', FALSE);
    trg('APP_AUTH_ATTEMPTS', FALSE);
    trg('APP_AUTH_SESSIONS', FALSE);
END;
/

-- Settings (insert-only: a value you changed is never overwritten).
-- OTP_DELIVERY starts as LOG_ONLY so nothing is sent to real employees until you
-- switch it:  UPDATE APP_AUTH_CONFIG SET CFG_VALUE = 'LIVE' WHERE CODE = 'OTP_DELIVERY'; COMMIT;
DECLARE
    l_pepper VARCHAR2(64);
    PROCEDURE cfg (p_code VARCHAR2, p_value VARCHAR2, p_notes VARCHAR2) IS
    BEGIN
        INSERT INTO APP_AUTH_CONFIG (CODE, CFG_VALUE, NOTES)
        SELECT p_code, p_value, p_notes FROM DUAL
         WHERE NOT EXISTS (SELECT 1 FROM APP_AUTH_CONFIG WHERE CODE = p_code);
    END;
BEGIN
    cfg('OTP_DELIVERY', 'LOG_ONLY', 'LIVE = send the code by SMS / e-mail. LOG_ONLY = send nothing, keep the code in APP_AUTH_OTP.DEV_CODE (testing).');
    cfg('EXPOSE_DEV_OTP', '0', '1 = also return the code in the API response. Only with OTP_DELIVERY = LOG_ONLY, for testing. Never in production.');
    cfg('OTP_LENGTH', '6', 'Digits in the code.');
    cfg('OTP_TTL_SECONDS', '300', 'How long a code is valid.');
    cfg('OTP_MAX_ATTEMPTS', '5', 'Wrong codes allowed per code before it is cancelled.');
    cfg('OTP_RESEND_SECONDS', '60', 'Minimum wait before another code for the same phone/e-mail.');
    cfg('OTP_MAX_PER_HOUR', '5', 'Codes per phone/e-mail per hour.');
    cfg('OTP_MAX_PER_IP_HOUR', '30', 'Codes requested from one IP per hour.');
    cfg('LOGIN_MAX_FAILURES', '5', 'Failed attempts (per username, and per phone/e-mail) before a temporary lock.');
    cfg('LOGIN_IP_MAX_FAILURES', '30', 'Failed attempts per IP before a temporary lock.');
    cfg('LOGIN_LOCK_MINUTES', '15', 'Length of the temporary lock and of the failure window.');
    cfg('SESSION_DAYS', '30', 'Token lifetime.');
    cfg('RESET_TOKEN_MINUTES', '10', 'Time to set the new password after the recovery code was accepted.');
    cfg('MIN_PASSWORD_LENGTH', '6', 'Shortest new password. The longest is 20 (the SEC_USERS.PASSWORD column).');
    cfg('ALLOWED_USER_TYPES', 'EMPLOYEE', 'Comma list of SEC_USERS.USER_TYPE allowed to use the app.');
    cfg('ALLOWED_EMPLOYMENT_STATUS', '1,4', 'Comma list of HR_EMPLOYEE_STATUS ids allowed to sign in (1 = Active, 4 = On leave).');
    cfg('REQUIRE_DEVICE_UUID', '1', '1 = sign in needs deviceUuid (the account is bound to the first device).');
    cfg('SMS_DESTINATION_FORMAT', 'INTL', 'INTL = 2010xxxxxxxx, LOCAL = 010xxxxxxxx (what the SMS gateway expects).');
    cfg('SMS_COMPANY_ID', '2', 'GNL_SMS_SETTINGS company used when the user has no default company (2 = Delta).');
    cfg('EMAIL_ACCOUNT_CODE', 'GMAIL_MAIN', 'SYS_EMAIL_SETTINGS.SETTING_CODE used to send the e-mail.');
    cfg('WHATSAPP_ENABLED', '0', '1 once a WhatsApp provider is configured and wired into APP_AUTH_PKG.');
    cfg('DEFAULT_COUNTRY_CODE', '20', 'Added to local numbers (01xxxxxxxxx -> 201xxxxxxxxx).');
    -- A secret mixed into every hash so a leaked table cannot be used to guess codes or tokens.
    SELECT LOWER(RAWTOHEX(STANDARD_HASH(RAWTOHEX(SYS_GUID()) || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISSFF9') || DBMS_RANDOM.STRING('x', 64), 'SHA256')))
      INTO l_pepper FROM DUAL;
    cfg('TOKEN_PEPPER', l_pepper,
        'Secret pepper. Do not change it while there are active codes or sessions (they would stop working); do not share it.');
END;
/
COMMIT;
