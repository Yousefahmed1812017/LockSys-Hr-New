-- =============================================================================
-- LockSys HR mobile app: central API (ORDS)
--
--   GET  {ords}/app/v1/companies/{CODE}          resolve a company code
--
-- Security : HTTP Basic auth on every call. Users live in GNL_APP_API_USERS
--            (salted SHA-256 hash, never the clear password).
-- Response : always JSON  {"success": true|false, ...}  (see GNL_APP_API_PKG)
-- Run as   : LOCKSYS_API (needs ORDS installed on the database).
-- Run with : sqlplus, UTF-8 (Arabic text), e.g.  set NLS_LANG=.AL32UTF8
-- =============================================================================

-- 1) API users ----------------------------------------------------------------
CREATE SEQUENCE GNL_APP_API_USERS_SEQ START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE TABLE GNL_APP_API_USERS (
    ID                  NUMBER          NOT NULL,
    USERNAME            VARCHAR2(100)   NOT NULL,
    PASSWORD_SALT       VARCHAR2(64)    NOT NULL,
    PASSWORD_HASH       VARCHAR2(64)    NOT NULL,     -- SHA-256 hex of SALT || password
    STATUS              VARCHAR2(10)    DEFAULT '1' NOT NULL,
    NOTES               VARCHAR2(4000),
    CREATED_BY_USER_ID  NUMBER,
    CREATED_BY          VARCHAR2(1000),
    CREATED_DATE        DATE,
    UPDATED_BY_USER_ID  NUMBER,
    UPDATED_BY          VARCHAR2(1000),
    UPDATED_DATE        DATE,
    CONSTRAINT GNL_APP_API_USERS_PK PRIMARY KEY (ID),
    CONSTRAINT GNL_APP_API_USERS_UQ UNIQUE (USERNAME),
    CONSTRAINT CHK_GNL_APP_API_USERS_STATUS CHECK (STATUS IN ('0','1'))
);

COMMENT ON TABLE  GNL_APP_API_USERS               IS 'Accounts allowed to call the central LockSys HR app API (HTTP Basic).';
COMMENT ON COLUMN GNL_APP_API_USERS.USERNAME      IS 'Basic-auth user name (case-insensitive match).';
COMMENT ON COLUMN GNL_APP_API_USERS.PASSWORD_SALT IS 'Random salt, generated automatically when the password is set.';
COMMENT ON COLUMN GNL_APP_API_USERS.PASSWORD_HASH IS 'SHA-256 hex of PASSWORD_SALT || password. Set it with GNL_APP_API_PKG.SET_PASSWORD.';
COMMENT ON COLUMN GNL_APP_API_USERS.STATUS        IS '1 = active, 0 = disabled.';

CREATE OR REPLACE TRIGGER TRG_GNL_APP_API_USERS_AUD
    BEFORE INSERT OR UPDATE
    ON GNL_APP_API_USERS
    FOR EACH ROW
BEGIN
    IF INSERTING THEN
        IF :NEW.ID IS NULL THEN
            SELECT GNL_APP_API_USERS_SEQ.NEXTVAL INTO :NEW.ID FROM DUAL;
        END IF;
        :NEW.CREATED_DATE       := SYSDATE;
        :NEW.CREATED_BY         := NVL(V('APP_USER'), USER);
        :NEW.CREATED_BY_USER_ID := V('P0_USER_ID');
        IF :NEW.STATUS IS NULL THEN
            :NEW.STATUS := '1';
        END IF;
    END IF;

    IF UPDATING THEN
        :NEW.UPDATED_DATE       := SYSDATE;
        :NEW.UPDATED_BY         := NVL(V('APP_USER'), USER);
        :NEW.UPDATED_BY_USER_ID := V('P0_USER_ID');
    END IF;

    :NEW.USERNAME := TRIM(:NEW.USERNAME);
END;
/
ALTER TRIGGER TRG_GNL_APP_API_USERS_AUD ENABLE;

-- 2) Package ------------------------------------------------------------------
CREATE OR REPLACE PACKAGE GNL_APP_API_PKG AS
    -- Set (or create) an API user's password.
    PROCEDURE SET_PASSWORD (p_username IN VARCHAR2, p_password IN VARCHAR2);

    -- GET /companies/:code (p_auth = the Authorization header). Writes the JSON body and returns the HTTP status.
    FUNCTION RESOLVE_COMPANY (p_code IN VARCHAR2, p_auth IN VARCHAR2 DEFAULT NULL) RETURN NUMBER;
END GNL_APP_API_PKG;
/

CREATE OR REPLACE PACKAGE BODY GNL_APP_API_PKG AS

    FUNCTION HASH_PASSWORD (p_salt IN VARCHAR2, p_password IN VARCHAR2) RETURN VARCHAR2 IS
        l_hash VARCHAR2(64);
    BEGIN
        SELECT RAWTOHEX(STANDARD_HASH(p_salt || p_password, 'SHA256')) INTO l_hash FROM DUAL;
        RETURN l_hash;
    END;

    PROCEDURE SET_PASSWORD (p_username IN VARCHAR2, p_password IN VARCHAR2) IS
        l_salt VARCHAR2(64) := RAWTOHEX(SYS_GUID());
        l_hash VARCHAR2(64);
    BEGIN
        l_hash := HASH_PASSWORD(l_salt, p_password);
        MERGE INTO GNL_APP_API_USERS u
        USING (SELECT p_username AS USERNAME FROM DUAL) s
        ON (UPPER(u.USERNAME) = UPPER(s.USERNAME))
        WHEN MATCHED THEN UPDATE SET
            u.PASSWORD_SALT = l_salt,
            u.PASSWORD_HASH = l_hash
        WHEN NOT MATCHED THEN INSERT (USERNAME, PASSWORD_SALT, PASSWORD_HASH)
            VALUES (p_username, l_salt, l_hash);
    END;

    -- Writes a JSON body (UTF-8) to the HTTP response.
    PROCEDURE HTPP (p_json IN CLOB) IS
        l_pos PLS_INTEGER := 1;
        l_len PLS_INTEGER := DBMS_LOB.GETLENGTH(p_json);
    BEGIN
        OWA_UTIL.MIME_HEADER('application/json', FALSE, 'utf-8');
        OWA_UTIL.HTTP_HEADER_CLOSE;
        WHILE l_pos <= l_len LOOP
            HTP.PRN(DBMS_LOB.SUBSTR(p_json, 4000, l_pos));
            l_pos := l_pos + 4000;
        END LOOP;
    END;

    -- Writes the standard failure envelope.
    PROCEDURE FAIL (p_error_code IN VARCHAR2, p_ar IN VARCHAR2, p_en IN VARCHAR2) IS
        l_json CLOB;
    BEGIN
        SELECT JSON_OBJECT(
                   'success' VALUE 'false' FORMAT JSON,
                   'error'   VALUE JSON_OBJECT(
                       'code'       VALUE p_error_code,
                       'message_ar' VALUE p_ar,
                       'message_en' VALUE p_en)
                   RETURNING CLOB)
          INTO l_json FROM DUAL;
        HTPP(l_json);
    END;

    -- Basic auth check against GNL_APP_API_USERS.
    FUNCTION IS_AUTHORIZED (p_auth IN VARCHAR2) RETURN BOOLEAN IS
        l_header   VARCHAR2(4000) := NVL(p_auth, OWA_UTIL.GET_CGI_ENV('HTTP_AUTHORIZATION'));
        l_decoded  VARCHAR2(4000);
        l_user     VARCHAR2(100);
        l_pass     VARCHAR2(1000);
        l_pos      PLS_INTEGER;
        l_salt     GNL_APP_API_USERS.PASSWORD_SALT%TYPE;
        l_hash     GNL_APP_API_USERS.PASSWORD_HASH%TYPE;
    BEGIN
        IF l_header IS NULL OR UPPER(SUBSTR(l_header, 1, 6)) <> 'BASIC ' THEN
            RETURN FALSE;
        END IF;

        l_decoded := UTL_RAW.CAST_TO_VARCHAR2(
                         UTL_ENCODE.BASE64_DECODE(UTL_RAW.CAST_TO_RAW(TRIM(SUBSTR(l_header, 7)))));
        l_pos := INSTR(l_decoded, ':');
        IF l_pos < 2 THEN
            RETURN FALSE;
        END IF;
        l_user := SUBSTR(l_decoded, 1, l_pos - 1);
        l_pass := SUBSTR(l_decoded, l_pos + 1);

        SELECT PASSWORD_SALT, PASSWORD_HASH
          INTO l_salt, l_hash
          FROM GNL_APP_API_USERS
         WHERE UPPER(USERNAME) = UPPER(l_user)
           AND STATUS = '1';

        RETURN LOWER(l_hash) = LOWER(HASH_PASSWORD(l_salt, l_pass));
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN FALSE;
        WHEN OTHERS        THEN RETURN FALSE;
    END;

    FUNCTION RESOLVE_COMPANY (p_code IN VARCHAR2, p_auth IN VARCHAR2 DEFAULT NULL) RETURN NUMBER IS
        l_code GNL_APP_COMPANIES.CODE%TYPE;
        c      GNL_APP_COMPANIES%ROWTYPE;
        l_json CLOB;
    BEGIN
        IF NOT IS_AUTHORIZED(p_auth) THEN
            FAIL('UNAUTHORIZED', 'بيانات الدخول إلى الخدمة غير صحيحة', 'Invalid API credentials');
            RETURN 401;
        END IF;

        IF p_code IS NULL OR LENGTHB(TRIM(p_code)) > 50 THEN
            FAIL('COMPANY_NOT_FOUND', 'كود الشركة غير صحيح', 'Company code is not valid');
            RETURN 404;
        END IF;
        l_code := UPPER(TRIM(p_code));

        BEGIN
            SELECT * INTO c FROM GNL_APP_COMPANIES WHERE CODE = l_code;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                FAIL('COMPANY_NOT_FOUND', 'كود الشركة غير صحيح', 'Company code is not valid');
                RETURN 404;
        END;

        IF c.STATUS <> '1' THEN
            FAIL('COMPANY_INACTIVE', 'هذه الشركة غير مفعّلة', 'This company is not active');
            RETURN 403;
        END IF;

        SELECT JSON_OBJECT(
            'success' VALUE 'true' FORMAT JSON,
            'data'    VALUE JSON_OBJECT(
                'code'            VALUE c.CODE,
                'name'            VALUE c.NAME,
                'arabicName'      VALUE c.ARABIC_NAME,
                'baseUrl'         VALUE c.API_BASE_URL,
                'multiLanguage'   VALUE CASE c.MULTI_LANGUAGE WHEN '1' THEN 'true' ELSE 'false' END FORMAT JSON,
                'defaultLanguage' VALUE c.DEFAULT_LANGUAGE,
                'features'        VALUE GNL_APP_FEATURES_PKG.ENABLED_JSON(c.ID) FORMAT JSON,
                'logoUrl'         VALUE c.LOGO_URL,
                'countryCode'     VALUE c.COUNTRY_CODE,
                'timezone'        VALUE c.TIMEZONE,
                'currencyCode'    VALUE c.CURRENCY_CODE,
                'supportEmail'    VALUE c.SUPPORT_EMAIL,
                'supportPhone'    VALUE c.SUPPORT_PHONE,
                'minAppVersion'   VALUE c.MIN_APP_VERSION,
                'maintenance'     VALUE CASE c.MAINTENANCE_MODE WHEN '1' THEN 'true' ELSE 'false' END FORMAT JSON)
            RETURNING CLOB)
          INTO l_json FROM DUAL;
        HTPP(l_json);
        RETURN 200;
    END;

END GNL_APP_API_PKG;
/

-- 3) Users --------------------------------------------------------------------
BEGIN
    GNL_APP_API_PKG.SET_PASSWORD('Locksys', 'Mo123!@#');
    COMMIT;
END;
/

-- 4) ORDS module --------------------------------------------------------------
BEGIN
    ORDS.ENABLE_SCHEMA(
        p_enabled             => TRUE,
        p_schema              => 'LOCKSYS_API',
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => 'locksys',
        p_auto_rest_auth      => FALSE);

    ORDS.DEFINE_MODULE(
        p_module_name    => 'app_v1',
        p_base_path      => '/app/v1/',
        p_items_per_page => 0,
        p_status         => 'PUBLISHED');

    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'app_v1',
        p_pattern     => 'companies/:code');

    ORDS.DEFINE_HANDLER(
        p_module_name => 'app_v1',
        p_pattern     => 'companies/:code',
        p_method      => 'GET',
        p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source      => 'BEGIN :status_code := GNL_APP_API_PKG.RESOLVE_COMPANY(:code, :auth); END;');

    ORDS.DEFINE_PARAMETER(
        p_module_name        => 'app_v1',
        p_pattern            => 'companies/:code',
        p_method             => 'GET',
        p_name               => 'Authorization',
        p_bind_variable_name => 'auth',
        p_source_type        => 'HEADER',
        p_param_type         => 'STRING',
        p_access_method      => 'IN');

    COMMIT;
END;
/

-- Full URL:  https://<ords-host>/ords/locksys/app/v1/companies/LOCKSYS

exit
