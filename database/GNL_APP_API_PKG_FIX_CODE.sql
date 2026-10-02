WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SET DEFINE OFF
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

