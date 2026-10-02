-- Mobile auth API, step 3: APP_AUTH_PKG. Run in the ERP schema (GSPLUS) with UTF-8,
-- after steps 1 and 2. New package only; no existing object is touched, except that
-- (like the old LoginUser) a successful sign in binds SEC_USERS.DEVICE_UUID and a
-- password change/reset writes SEC_USERS.PASSWORD and its flags.
--
-- Every endpoint is a procedure returning the HTTP status and the JSON body, so it
-- can be tested from SQL; WRITE_RESPONSE prints it from the ORDS handler.
-- Envelope (same as the company directory API):
--   ok    {"success":true,"data":{...}}
--   error {"success":false,"error":{"code","message_ar","message_en","retryAfterSeconds"?,"attemptsLeft"?}}
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

CREATE OR REPLACE PACKAGE APP_AUTH_PKG AS
    PROCEDURE LOGIN_PASSWORD   (p_body IN CLOB, p_ip IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB);
    -- p_purpose: LOGIN (sign in with a code) or RESET (forgot password)
    PROCEDURE OTP_REQUEST      (p_purpose IN VARCHAR2, p_body IN CLOB, p_ip IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB);
    PROCEDURE OTP_VERIFY_LOGIN (p_body IN CLOB, p_ip IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB);
    PROCEDURE OTP_VERIFY_RESET (p_body IN CLOB, p_ip IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB);
    PROCEDURE PASSWORD_RESET   (p_body IN CLOB, p_ip IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB);
    PROCEDURE PASSWORD_CHANGE  (p_auth IN VARCHAR2, p_body IN CLOB, p_status OUT NUMBER, p_json OUT CLOB);
    PROCEDURE ME               (p_auth IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB);
    PROCEDURE LOGOUT           (p_auth IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB);

    PROCEDURE WRITE_RESPONSE   (p_json IN CLOB);
    FUNCTION  CLIENT_IP RETURN VARCHAR2;
    FUNCTION  CFG (p_code IN VARCHAR2, p_default IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;
    -- null = the user may sign in; otherwise the reason code
    FUNCTION  LOGIN_BLOCK_REASON (p_user_id IN NUMBER) RETURN VARCHAR2;
    PROCEDURE PURGE_OLD;
    -- public only because SQL statements inside the body call them
    FUNCTION  SHA (p_text IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION  USER_JSON (p_user_id IN NUMBER) RETURN CLOB;

    -- For the other mobile APIs (leave, ...): checks "Authorization: Bearer <token>".
    -- p_json stays NULL when the caller is signed in (p_user_id is then set);
    -- otherwise p_status / p_json hold the error answer.
    PROCEDURE AUTHENTICATE (p_auth IN VARCHAR2, p_user_id OUT NUMBER, p_status OUT NUMBER, p_json OUT CLOB);
    FUNCTION  OK_RESPONSE (p_data IN CLOB) RETURN CLOB;
    PROCEDURE FAIL_RESPONSE (p_status OUT NUMBER, p_json OUT CLOB, p_http IN NUMBER, p_code IN VARCHAR2,
                             p_ar IN VARCHAR2, p_en IN VARCHAR2);
END APP_AUTH_PKG;
/

CREATE OR REPLACE PACKAGE BODY APP_AUTH_PKG AS

    TYPE t_in IS RECORD (
        username     VARCHAR2(200),
        password     VARCHAR2(200),
        device       VARCHAR2(100),
        id_type      VARCHAR2(20),
        identifier   VARCHAR2(200),
        channel      VARCHAR2(20),
        otp_id       VARCHAR2(64),
        code         VARCHAR2(20),
        reset_token  VARCHAR2(100),
        new_password VARCHAR2(200),
        old_password VARCHAR2(200)
    );

    -- ======================================================================= basics
    FUNCTION CFG (p_code IN VARCHAR2, p_default IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 IS
        l_v APP_AUTH_CONFIG.CFG_VALUE%TYPE;
    BEGIN
        SELECT CFG_VALUE INTO l_v FROM APP_AUTH_CONFIG WHERE CODE = p_code AND STATUS = '1';
        RETURN NVL(l_v, p_default);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN p_default;
    END;

    FUNCTION CFG_NUM (p_code IN VARCHAR2, p_default IN NUMBER) RETURN NUMBER IS
    BEGIN
        RETURN TO_NUMBER(CFG(p_code, TO_CHAR(p_default)));
    EXCEPTION
        WHEN VALUE_ERROR THEN RETURN p_default;
    END;

    FUNCTION SHA (p_text IN VARCHAR2) RETURN VARCHAR2 IS
        l_h VARCHAR2(64);
    BEGIN
        SELECT LOWER(RAWTOHEX(STANDARD_HASH(p_text, 'SHA256'))) INTO l_h FROM DUAL;
        RETURN l_h;
    END;

    -- 64 hex characters nobody can predict without the pepper (DBMS_CRYPTO is not
    -- granted to this schema; ask a DBA for it to get a true CSPRNG).
    FUNCTION RND_HEX (p_salt IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 IS
    BEGIN
        RETURN SHA(CFG('TOKEN_PEPPER') || ':' || RAWTOHEX(SYS_GUID()) || ':'
                   || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISSFF9') || ':'
                   || TO_CHAR(DBMS_RANDOM.VALUE) || ':' || p_salt);
    END;

    FUNCTION CLIENT_IP RETURN VARCHAR2 IS
        l_ip VARCHAR2(500);
    BEGIN
        BEGIN l_ip := OWA_UTIL.GET_CGI_ENV('HTTP_CF_CONNECTING_IP'); EXCEPTION WHEN OTHERS THEN l_ip := NULL; END;
        IF l_ip IS NULL THEN
            BEGIN l_ip := OWA_UTIL.GET_CGI_ENV('X-FORWARDED-FOR'); EXCEPTION WHEN OTHERS THEN l_ip := NULL; END;
        END IF;
        IF l_ip IS NULL THEN
            BEGIN l_ip := OWA_UTIL.GET_CGI_ENV('REMOTE_ADDR'); EXCEPTION WHEN OTHERS THEN l_ip := NULL; END;
        END IF;
        RETURN SUBSTR(TRIM(REGEXP_SUBSTR(l_ip, '[^,]+', 1, 1)), 1, 100);
    END;

    FUNCTION MASK_PHONE (p IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE WHEN p IS NULL THEN NULL ELSE UNISTR('\2022\2022\2022\2022') || ' ' || SUBSTR(p, -4) END;
    END;

    FUNCTION MASK_EMAIL (p IN VARCHAR2) RETURN VARCHAR2 IS
        l_at PLS_INTEGER := INSTR(p, '@');
    BEGIN
        IF p IS NULL OR l_at < 2 THEN RETURN NULL; END IF;
        RETURN SUBSTR(p, 1, 1) || UNISTR('\2022\2022\2022\2022\2022') || SUBSTR(p, l_at);
    END;

    -- ===================================================================== responses
    FUNCTION ERR (p_code IN VARCHAR2, p_ar IN VARCHAR2, p_en IN VARCHAR2,
                  p_retry IN NUMBER DEFAULT NULL, p_left IN NUMBER DEFAULT NULL) RETURN CLOB IS
        l CLOB;
    BEGIN
        SELECT JSON_OBJECT(
                   'success' VALUE 'false' FORMAT JSON,
                   'error'   VALUE JSON_OBJECT(
                       'code'              VALUE p_code,
                       'message_ar'        VALUE p_ar,
                       'message_en'        VALUE p_en,
                       'retryAfterSeconds' VALUE p_retry,
                       'attemptsLeft'      VALUE p_left
                       ABSENT ON NULL)
                   RETURNING CLOB)
          INTO l FROM DUAL;
        RETURN l;
    END;

    FUNCTION OKJ (p_data IN CLOB) RETURN CLOB IS
        l CLOB;
    BEGIN
        SELECT JSON_OBJECT('success' VALUE 'true' FORMAT JSON, 'data' VALUE p_data FORMAT JSON RETURNING CLOB)
          INTO l FROM DUAL;
        RETURN l;
    END;

    PROCEDURE WRITE_RESPONSE (p_json IN CLOB) IS
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

    PROCEDURE FAIL (p_status OUT NUMBER, p_json OUT CLOB, p_http IN NUMBER, p_code IN VARCHAR2,
                    p_ar IN VARCHAR2, p_en IN VARCHAR2, p_retry IN NUMBER DEFAULT NULL, p_left IN NUMBER DEFAULT NULL) IS
    BEGIN
        p_status := p_http;
        p_json   := ERR(p_code, p_ar, p_en, p_retry, p_left);
    END;

    PROCEDURE INVALID_REQUEST (p_status OUT NUMBER, p_json OUT CLOB) IS
    BEGIN
        FAIL(p_status, p_json, 400, 'VALIDATION_ERROR', 'تعذّر قراءة البيانات المرسلة', 'The request body is missing or is not valid JSON');
    END;

    PROCEDURE BLOCKED (p_reason IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB) IS
    BEGIN
        IF p_reason = 'ACCOUNT_LOCKED' THEN
            FAIL(p_status, p_json, 403, p_reason, 'الحساب موقوف، تواصل مع الإدارة', 'Account is locked');
        ELSIF p_reason = 'ACCOUNT_INACTIVE' THEN
            FAIL(p_status, p_json, 403, p_reason, 'الحساب غير نشط، تواصل مع الإدارة', 'Account is inactive');
        ELSIF p_reason = 'MOBILE_NOT_ENABLED' THEN
            FAIL(p_status, p_json, 403, p_reason, 'هذا الحساب غير مفعّل على تطبيق الموبايل', 'Mobile access is not enabled for this account');
        ELSIF p_reason = 'EMPLOYEE_NOT_ACTIVE' THEN
            FAIL(p_status, p_json, 403, p_reason, 'حالة الموظف لا تسمح باستخدام التطبيق، تواصل مع الموارد البشرية', 'The employee status does not allow using the app');
        ELSIF p_reason = 'USER_TYPE_NOT_ALLOWED' THEN
            FAIL(p_status, p_json, 403, p_reason, 'هذا النوع من الحسابات غير مسموح له باستخدام التطبيق', 'This account type cannot use the app');
        ELSE
            FAIL(p_status, p_json, 403, 'ACCOUNT_NOT_FOUND', 'الحساب غير موجود', 'Account not found');
        END IF;
    END;

    -- ======================================================================== input
    FUNCTION BODY_OK (p_body IN CLOB) RETURN BOOLEAN IS
        l NUMBER;
    BEGIN
        IF p_body IS NULL OR DBMS_LOB.GETLENGTH(p_body) = 0 THEN RETURN FALSE; END IF;
        SELECT CASE WHEN p_body IS JSON THEN 1 ELSE 0 END INTO l FROM DUAL;
        RETURN l = 1;
    END;

    FUNCTION PARSE (p_body IN CLOB) RETURN t_in IS
        r t_in;
    BEGIN
        SELECT TRIM(j.username), j.password, TRIM(j.device_uuid), TRIM(j.identifier_type), TRIM(j.identifier),
               TRIM(j.channel), TRIM(j.otp_id), TRIM(j.code), TRIM(j.reset_token), j.new_password, j.old_password
          INTO r.username, r.password, r.device, r.id_type, r.identifier,
               r.channel, r.otp_id, r.code, r.reset_token, r.new_password, r.old_password
          FROM JSON_TABLE(p_body, '$' COLUMNS (
                   username        VARCHAR2(200) PATH '$.username',
                   password        VARCHAR2(200) PATH '$.password',
                   device_uuid     VARCHAR2(100) PATH '$.deviceUuid',
                   identifier_type VARCHAR2(20)  PATH '$.identifierType',
                   identifier      VARCHAR2(200) PATH '$.identifier',
                   channel         VARCHAR2(20)  PATH '$.channel',
                   otp_id          VARCHAR2(64)  PATH '$.otpId',
                   code            VARCHAR2(20)  PATH '$.code',
                   reset_token     VARCHAR2(100) PATH '$.resetToken',
                   new_password    VARCHAR2(200) PATH '$.newPassword',
                   old_password    VARCHAR2(200) PATH '$.oldPassword')) j;
        RETURN r;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN r;
    END;

    -- Null = acceptable password.
    FUNCTION PASSWORD_PROBLEM (p_password IN VARCHAR2) RETURN VARCHAR2 IS
        l_min NUMBER := CFG_NUM('MIN_PASSWORD_LENGTH', 6);
    BEGIN
        IF p_password IS NULL OR LENGTH(p_password) < l_min THEN RETURN 'WEAK_PASSWORD'; END IF;
        IF LENGTH(p_password) > 20 THEN RETURN 'PASSWORD_TOO_LONG'; END IF;
        RETURN NULL;
    END;

    PROCEDURE PASSWORD_PROBLEM_RESPONSE (p_problem IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB) IS
    BEGIN
        IF p_problem = 'PASSWORD_TOO_LONG' THEN
            FAIL(p_status, p_json, 400, p_problem, 'كلمة المرور يجب ألا تزيد عن 20 حرفًا', 'The password must not be longer than 20 characters');
        ELSE
            FAIL(p_status, p_json, 400, 'WEAK_PASSWORD',
                 'كلمة المرور قصيرة، الحد الأدنى ' || CFG_NUM('MIN_PASSWORD_LENGTH', 6) || ' أحرف',
                 'The password is too short (minimum ' || CFG_NUM('MIN_PASSWORD_LENGTH', 6) || ' characters)');
        END IF;
    END;

    -- ============================================================ attempts / lockout
    -- Seconds left on a lock for p_key, 0 when not locked: p_max failures since the
    -- last success, inside the window, lock the key until the window of the last one ends.
    FUNCTION LOCK_SECONDS (p_key IN VARCHAR2, p_max IN NUMBER) RETURN NUMBER IS
        l_minutes NUMBER := CFG_NUM('LOGIN_LOCK_MINUTES', 15);
        l_since   DATE;
        l_fails   NUMBER;
        l_last    DATE;
    BEGIN
        SELECT NVL(MAX(ATTEMPT_AT), DATE '1970-01-01') INTO l_since
          FROM APP_AUTH_ATTEMPTS WHERE ATTEMPT_KEY = p_key AND IS_SUCCESS = '1';
        SELECT COUNT(*), MAX(ATTEMPT_AT) INTO l_fails, l_last
          FROM APP_AUTH_ATTEMPTS
         WHERE ATTEMPT_KEY = p_key AND IS_SUCCESS = '0'
           AND ATTEMPT_AT >= l_since AND ATTEMPT_AT > SYSDATE - l_minutes / 1440;
        IF l_fails >= p_max THEN
            RETURN CEIL(GREATEST(1, (l_last + l_minutes / 1440 - SYSDATE) * 86400));
        END IF;
        RETURN 0;
    END;

    -- Autonomous: the attempt must be kept even when the request is rolled back.
    PROCEDURE REG (p_key IN VARCHAR2, p_kind IN VARCHAR2, p_ok IN BOOLEAN, p_ip IN VARCHAR2) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_ok CHAR(1) := CASE WHEN p_ok THEN '1' ELSE '0' END;
    BEGIN
        INSERT INTO APP_AUTH_ATTEMPTS (ATTEMPT_KEY, KIND, IS_SUCCESS, IP_ADDRESS)
        VALUES (SUBSTR(p_key, 1, 200), p_kind, l_ok, p_ip);
        COMMIT;
    END;

    -- ===================================================================== eligibility
    FUNCTION LOGIN_BLOCK_REASON (p_user_id IN NUMBER) RETURN VARCHAR2 IS
        r APP_USERS_LOGIN_V2%ROWTYPE;
    BEGIN
        SELECT * INTO r FROM APP_USERS_LOGIN_V2 WHERE USER_ID = p_user_id AND ROWNUM = 1;
        IF NVL(r.IS_LOCKED, 0) = 1 THEN RETURN 'ACCOUNT_LOCKED'; END IF;
        IF NVL(r.USER_STATUS, '0') <> '1' THEN RETURN 'ACCOUNT_INACTIVE'; END IF;
        IF NVL(r.IS_MOBILE_APP, 0) <> 1 THEN RETURN 'MOBILE_NOT_ENABLED'; END IF;
        IF INSTR(',' || CFG('ALLOWED_USER_TYPES', 'EMPLOYEE') || ',', ',' || NVL(r.USER_TYPE, '-') || ',') = 0 THEN
            RETURN 'USER_TYPE_NOT_ALLOWED';
        END IF;
        IF r.USER_TYPE = 'EMPLOYEE'
           AND INSTR(',' || CFG('ALLOWED_EMPLOYMENT_STATUS', '1,4') || ',', ',' || NVL(TO_CHAR(r.EMPLOYMENT_STATUS), '-') || ',') = 0 THEN
            RETURN 'EMPLOYEE_NOT_ACTIVE';
        END IF;
        RETURN NULL;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN 'ACCOUNT_NOT_FOUND';
    END;

    -- The account is bound to its first device (same rule as the old LoginUser).
    FUNCTION BIND_DEVICE (p_user_id IN NUMBER, p_device IN VARCHAR2) RETURN BOOLEAN IS
        l_stored SEC_USERS.DEVICE_UUID%TYPE;
    BEGIN
        SELECT DEVICE_UUID INTO l_stored FROM SEC_USERS WHERE ID = p_user_id;
        IF l_stored IS NULL THEN
            IF p_device IS NOT NULL THEN
                UPDATE SEC_USERS SET DEVICE_UUID = p_device WHERE ID = p_user_id;
            END IF;
            RETURN TRUE;
        END IF;
        RETURN p_device IS NOT NULL AND p_device = l_stored;
    END;

    -- ========================================================================== data
    FUNCTION USER_JSON (p_user_id IN NUMBER) RETURN CLOB IS
        l CLOB;
    BEGIN
        SELECT JSON_OBJECT(
            'userId'          VALUE USER_ID,
            'username'        VALUE USERNAME,
            'code'            VALUE USER_CODE,
            'nameAr'          VALUE NVL(USER_NAME_AR, EMPLOYEE_NAME_AR),
            'nameEn'          VALUE NVL(USER_NAME_EN, EMPLOYEE_NAME_EN),
            'email'           VALUE EMAIL,
            'phone'           VALUE PHONE,
            'userType'        VALUE USER_TYPE,
            'language'        VALUE USER_LANGUAGE,
            'imagePath'       VALUE USER_IMAGE_PATH,
            'allowAttendance' VALUE CASE WHEN ALLOW_ATTENDANCE IN ('1', 'Y') THEN 'true' ELSE 'false' END FORMAT JSON,
            'allowDailies'    VALUE CASE WHEN ALLOW_DAILIES IN ('1', 'Y') THEN 'true' ELSE 'false' END FORMAT JSON,
            'employee'        VALUE (CASE WHEN EMPLOYEE_ID IS NULL THEN NULL ELSE JSON_OBJECT(
                'employeeId'    VALUE EMPLOYEE_ID,
                'code'          VALUE EMPLOYEE_CODE,
                'nameAr'        VALUE EMPLOYEE_NAME_AR,
                'nameEn'        VALUE EMPLOYEE_NAME_EN,
                'hireDate'      VALUE TO_CHAR(HIRE_DATE, 'YYYY-MM-DD'),
                'checkLocation' VALUE CASE WHEN CHECK_LOCATION IN ('1', 'Y') THEN 'true' ELSE 'false' END FORMAT JSON,
                'status'        VALUE JSON_OBJECT('id' VALUE EMPLOYEE_STATUS_ID, 'nameAr' VALUE EMPLOYEE_STATUS_NAME_AR, 'nameEn' VALUE EMPLOYEE_STATUS_NAME_EN),
                'category'      VALUE (CASE WHEN EMPLOYEE_CATEGORY_ID IS NULL THEN NULL ELSE JSON_OBJECT('id' VALUE EMPLOYEE_CATEGORY_ID, 'nameAr' VALUE EMPLOYEE_CATEGORY_NAME_AR, 'nameEn' VALUE EMPLOYEE_CATEGORY_NAME_EN) END) FORMAT JSON,
                'department'    VALUE (CASE WHEN DEPARTMENT_ID IS NULL THEN NULL ELSE JSON_OBJECT('id' VALUE DEPARTMENT_ID, 'code' VALUE DEPARTMENT_CODE, 'nameAr' VALUE DEPARTMENT_NAME_AR, 'nameEn' VALUE DEPARTMENT_NAME_EN) END) FORMAT JSON,
                'job'           VALUE (CASE WHEN JOB_ID IS NULL THEN NULL ELSE JSON_OBJECT('id' VALUE JOB_ID, 'code' VALUE JOB_TITLE_CODE, 'nameAr' VALUE JOB_TITLE_NAME_AR, 'nameEn' VALUE JOB_TITLE_NAME_EN) END) FORMAT JSON,
                'site'          VALUE (CASE WHEN SITE_ID IS NULL THEN NULL ELSE JSON_OBJECT('id' VALUE SITE_ID, 'code' VALUE SITE_CODE, 'nameAr' VALUE SITE_NAME_AR, 'nameEn' VALUE SITE_NAME_EN) END) FORMAT JSON,
                'location'      VALUE (CASE WHEN LOCATION_ID IS NULL THEN NULL ELSE JSON_OBJECT('id' VALUE LOCATION_ID, 'nameAr' VALUE LOCATION_NAME_AR, 'nameEn' VALUE LOCATION_NAME_EN, 'latitude' VALUE LOCATION_LATITUDE, 'longitude' VALUE LOCATION_LONGITUDE, 'zoneType' VALUE LOCATION_ZONE_TYPE, 'radiusMeters' VALUE LOCATION_ZONE_RADIUS) END) FORMAT JSON,
                'manager'       VALUE (CASE WHEN MANAGER_EMPLOYEE_ID IS NULL THEN NULL ELSE JSON_OBJECT('employeeId' VALUE MANAGER_EMPLOYEE_ID, 'nameAr' VALUE MANAGER_NAME_AR, 'nameEn' VALUE MANAGER_NAME_EN) END) FORMAT JSON
            ) END) FORMAT JSON,
            'company'         VALUE JSON_OBJECT('id' VALUE DEFAULT_COMPANY_ID, 'name' VALUE COMPANY_NAME),
            'branch'          VALUE JSON_OBJECT('id' VALUE DEFAULT_BRANCH_ID, 'name' VALUE BRANCH_NAME)
            RETURNING CLOB)
          INTO l FROM APP_USERS_LOGIN_V2 WHERE USER_ID = p_user_id AND ROWNUM = 1;
        RETURN l;
    END;

    -- Creates the token; only its hash is stored.
    PROCEDURE NEW_SESSION (p_user_id IN NUMBER, p_device IN VARCHAR2, p_method IN VARCHAR2, p_ip IN VARCHAR2,
                           p_token OUT VARCHAR2, p_expires OUT DATE) IS
    BEGIN
        p_token   := RND_HEX('session:' || p_user_id);
        p_expires := SYSDATE + CFG_NUM('SESSION_DAYS', 30);
        INSERT INTO APP_AUTH_SESSIONS (USER_ID, TOKEN_HASH, DEVICE_UUID, LOGIN_METHOD, EXPIRES_AT, LAST_USED_AT, IP_ADDRESS)
        VALUES (p_user_id, SHA(p_token || ':' || CFG('TOKEN_PEPPER')), p_device, p_method, p_expires, SYSDATE, p_ip);
    END;

    FUNCTION SESSION_JSON (p_user_id IN NUMBER, p_token IN VARCHAR2, p_expires IN DATE) RETURN CLOB IS
        l      CLOB;
        l_must NUMBER;
    BEGIN
        SELECT NVL(IS_CHANGE_PASSWORD, 0) INTO l_must FROM SEC_USERS WHERE ID = p_user_id;
        SELECT JSON_OBJECT(
                   'token'              VALUE p_token,
                   'tokenType'          VALUE 'Bearer',
                   'expiresAt'          VALUE TO_CHAR(FROM_TZ(CAST(p_expires AS TIMESTAMP), SESSIONTIMEZONE), 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM'),
                   'mustChangePassword' VALUE CASE WHEN l_must = 1 THEN 'true' ELSE 'false' END FORMAT JSON,
                   'user'               VALUE USER_JSON(p_user_id) FORMAT JSON
                   RETURNING CLOB)
          INTO l FROM DUAL;
        RETURN l;
    END;

    -- Finds the live session of "Authorization: Bearer <token>". p_error null = ok.
    PROCEDURE AUTH_SESSION (p_auth IN VARCHAR2, p_user_id OUT NUMBER, p_session_id OUT NUMBER, p_error OUT VARCHAR2) IS
        l_token  VARCHAR2(200);
        l_reason VARCHAR2(40);
    BEGIN
        p_error := NULL;
        IF p_auth IS NULL OR UPPER(SUBSTR(p_auth, 1, 7)) <> 'BEARER ' THEN
            p_error := 'TOKEN_REQUIRED';
            RETURN;
        END IF;
        l_token := TRIM(SUBSTR(p_auth, 8));
        BEGIN
            SELECT ID, USER_ID INTO p_session_id, p_user_id
              FROM APP_AUTH_SESSIONS
             WHERE TOKEN_HASH = SHA(l_token || ':' || CFG('TOKEN_PEPPER'))
               AND IS_REVOKED = '0' AND EXPIRES_AT > SYSDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                p_error := 'TOKEN_INVALID';
                RETURN;
        END;
        l_reason := LOGIN_BLOCK_REASON(p_user_id);
        IF l_reason IS NOT NULL THEN
            p_error := l_reason;
            RETURN;
        END IF;
        UPDATE APP_AUTH_SESSIONS SET LAST_USED_AT = SYSDATE WHERE ID = p_session_id;
    END;

    PROCEDURE AUTH_FAIL (p_error IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB) IS
    BEGIN
        IF p_error = 'TOKEN_REQUIRED' THEN
            FAIL(p_status, p_json, 401, p_error, 'يرجى تسجيل الدخول أولاً', 'Authentication required');
        ELSIF p_error = 'TOKEN_INVALID' THEN
            FAIL(p_status, p_json, 401, p_error, 'انتهت الجلسة، سجّل الدخول مرة أخرى', 'The session is not valid or has expired');
        ELSE
            BLOCKED(p_error, p_status, p_json);
        END IF;
    END;

    -- ========================================================================= sign in
    PROCEDURE LOGIN_PASSWORD (p_body IN CLOB, p_ip IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB) IS
        r        t_in;
        l_user   NUMBER;
        l_stored SEC_USERS.PASSWORD%TYPE;
        l_ukey   VARCHAR2(250);
        l_ikey   VARCHAR2(250);
        l_wait   NUMBER;
        l_reason VARCHAR2(40);
        l_token  VARCHAR2(64);
        l_exp    DATE;
    BEGIN
        IF NOT BODY_OK(p_body) THEN INVALID_REQUEST(p_status, p_json); RETURN; END IF;
        r := PARSE(p_body);
        r.username := UPPER(r.username);
        IF r.username IS NULL OR r.password IS NULL THEN
            FAIL(p_status, p_json, 400, 'VALIDATION_ERROR', 'اسم المستخدم وكلمة المرور مطلوبان', 'Username and password are required');
            RETURN;
        END IF;
        IF CFG('REQUIRE_DEVICE_UUID', '1') = '1' AND r.device IS NULL THEN
            FAIL(p_status, p_json, 400, 'DEVICE_REQUIRED', 'معرّف الجهاز مطلوب', 'deviceUuid is required');
            RETURN;
        END IF;

        l_ukey := 'U:' || r.username;
        l_ikey := 'I:' || NVL(p_ip, '?');
        l_wait := GREATEST(LOCK_SECONDS(l_ukey, CFG_NUM('LOGIN_MAX_FAILURES', 5)),
                           LOCK_SECONDS(l_ikey, CFG_NUM('LOGIN_IP_MAX_FAILURES', 30)));
        IF l_wait > 0 THEN
            FAIL(p_status, p_json, 429, 'TOO_MANY_ATTEMPTS', 'محاولات كثيرة، حاول مرة أخرى بعد قليل', 'Too many attempts, try again later', l_wait);
            RETURN;
        END IF;

        BEGIN
            SELECT ID, PASSWORD INTO l_user, l_stored FROM SEC_USERS WHERE UPPER(USERNAME) = r.username AND ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN l_user := NULL;
        END;
        -- Unknown user and wrong password look the same, and the password is checked
        -- before anything about the account is revealed.
        IF l_user IS NULL OR l_stored IS NULL OR l_stored <> r.password THEN
            REG(l_ukey, 'PASSWORD', FALSE, p_ip);
            REG(l_ikey, 'IP', FALSE, p_ip);
            FAIL(p_status, p_json, 401, 'INVALID_CREDENTIALS', 'اسم المستخدم أو كلمة المرور غير صحيحة', 'Invalid username or password');
            RETURN;
        END IF;

        l_reason := LOGIN_BLOCK_REASON(l_user);
        IF l_reason IS NOT NULL THEN BLOCKED(l_reason, p_status, p_json); RETURN; END IF;
        IF NOT BIND_DEVICE(l_user, r.device) THEN
            FAIL(p_status, p_json, 403, 'DEVICE_MISMATCH', 'هذا الحساب مرتبط بهاتف آخر. لا يمكنك تسجيل الدخول إلا من جهازك المعتمد.', 'This account is bound to another device');
            RETURN;
        END IF;

        REG(l_ukey, 'PASSWORD', TRUE, p_ip);
        REG(l_ikey, 'IP', TRUE, p_ip);
        NEW_SESSION(l_user, r.device, 'PASSWORD', p_ip, l_token, l_exp);
        p_status := 200;
        p_json   := OKJ(SESSION_JSON(l_user, l_token, l_exp));
    END;

    -- ============================================================================ OTP
    FUNCTION CHANNEL_AVAILABLE (p_channel IN VARCHAR2) RETURN BOOLEAN IS
        l NUMBER;
    BEGIN
        IF p_channel = 'SMS' THEN
            SELECT COUNT(*) INTO l FROM GNL_SMS_SETTINGS WHERE STATUS = '1';
        ELSIF p_channel = 'EMAIL' THEN
            SELECT COUNT(*) INTO l FROM SYS_EMAIL_SETTINGS WHERE SETTING_CODE = CFG('EMAIL_ACCOUNT_CODE', 'GMAIL_MAIN') AND IS_ACTIVE = 'Y';
        ELSIF p_channel = 'WHATSAPP' THEN
            -- Not wired yet: needs a provider in DBS_WHATSAPP_PROVIDER and a call below.
            RETURN CFG('WHATSAPP_ENABLED', '0') = '1';
        ELSE
            RETURN FALSE;
        END IF;
        RETURN l > 0;
    END;

    -- Sends (or only logs) the code. p_status: SENT / LOGGED / FAILED.
    PROCEDURE DELIVER (p_channel IN VARCHAR2, p_user_id IN NUMBER, p_dest IN VARCHAR2, p_company_id IN NUMBER,
                       p_code IN VARCHAR2, p_status OUT VARCHAR2, p_error OUT VARCHAR2) IS
        l_min NUMBER := ROUND(CFG_NUM('OTP_TTL_SECONDS', 300) / 60);
        l_to  VARCHAR2(50);
        l_ok  BOOLEAN;
    BEGIN
        p_error := NULL;
        IF CFG('OTP_DELIVERY', 'LOG_ONLY') <> 'LIVE' THEN
            p_status := 'LOGGED';
            RETURN;
        END IF;
        IF p_channel = 'SMS' THEN
            l_to := CASE WHEN CFG('SMS_DESTINATION_FORMAT', 'INTL') = 'LOCAL'
                         THEN '0' || SUBSTR(p_dest, LENGTH(CFG('DEFAULT_COUNTRY_CODE', '20')) + 1)
                         ELSE p_dest END;
            l_ok := GNL_SMS_PKG.SEND_SMS_FUNC(
                        P_TO               => l_to,
                        P_MESSAGE          => 'LockSys HR: رمز التحقق ' || p_code || ' صالح ' || l_min || ' دقائق. لا تشاركه مع أحد',
                        P_COMPANY_ID       => NVL(p_company_id, CFG_NUM('SMS_COMPANY_ID', 2)),
                        P_SOURCE_MODULE    => 'MOBILE_AUTH',
                        P_SOURCE_RECORD_ID => p_user_id);
            IF l_ok THEN p_status := 'SENT'; ELSE p_status := 'FAILED'; p_error := 'The SMS gateway reported a failure'; END IF;
        ELSIF p_channel = 'EMAIL' THEN
            PKG_SEND_MAIL.SEND(
                CFG('EMAIL_ACCOUNT_CODE', 'GMAIL_MAIN'), p_dest,
                'LockSys HR - رمز التحقق / Verification code',
                'رمز التحقق الخاص بك هو: ' || p_code || CHR(10) || 'صالح لمدة ' || l_min || ' دقائق. لا تشاركه مع أحد.' || CHR(10) || CHR(10)
                || 'Your LockSys HR verification code is ' || p_code || ' (valid for ' || l_min || ' minutes). Do not share it.',
                FALSE);
            p_status := 'SENT';
        ELSE
            p_status := 'FAILED';
            p_error  := 'Channel not supported';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'FAILED';
            p_error  := SUBSTR(SQLERRM, 1, 900);
    END;

    PROCEDURE PURGE_OLD IS
    BEGIN
        DELETE FROM APP_AUTH_OTP      WHERE CREATED_DATE < SYSDATE - 30 AND ROWNUM <= 500;
        DELETE FROM APP_AUTH_ATTEMPTS WHERE ATTEMPT_AT   < SYSDATE - 30 AND ROWNUM <= 500;
        DELETE FROM APP_AUTH_SESSIONS WHERE EXPIRES_AT   < SYSDATE - 30 AND ROWNUM <= 500;
    END;

    PROCEDURE OTP_REQUEST (p_purpose IN VARCHAR2, p_body IN CLOB, p_ip IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB) IS
        r          t_in;
        l_norm     VARCHAR2(200);
        l_key      VARCHAR2(64);
        l_n        NUMBER;
        l_last     DATE;
        l_oldest   DATE;
        l_row      APP_USERS_LOGIN_V2%ROWTYPE;
        l_found    BOOLEAN := FALSE;
        l_dest     VARCHAR2(200);
        l_masked   VARCHAR2(100);
        l_user     NUMBER;
        l_company  NUMBER;
        l_block    VARCHAR2(40);
        l_code     VARCHAR2(10);
        l_public   VARCHAR2(32);
        l_len      NUMBER := LEAST(GREATEST(CFG_NUM('OTP_LENGTH', 6), 4), 8);
        l_ttl      NUMBER := CFG_NUM('OTP_TTL_SECONDS', 300);
        l_max      NUMBER := CFG_NUM('OTP_MAX_ATTEMPTS', 5);
        l_resend   NUMBER := CFG_NUM('OTP_RESEND_SECONDS', 60);
        l_delivery VARCHAR2(30);
        l_error    VARCHAR2(1000);
        l_dev      VARCHAR2(10);
        l_data     CLOB;
        c_bullets  CONSTANT VARCHAR2(20) := UNISTR('\2022\2022\2022\2022');
    BEGIN
        IF NOT BODY_OK(p_body) THEN INVALID_REQUEST(p_status, p_json); RETURN; END IF;
        r := PARSE(p_body);
        r.id_type := UPPER(r.id_type);
        r.channel := UPPER(r.channel);
        IF r.id_type NOT IN ('PHONE', 'EMAIL') OR r.channel NOT IN ('SMS', 'WHATSAPP', 'EMAIL') OR r.identifier IS NULL THEN
            FAIL(p_status, p_json, 400, 'VALIDATION_ERROR',
                 'identifierType (phone|email) وidentifier وchannel (sms|whatsapp|email) مطلوبة',
                 'identifierType (phone|email), identifier and channel (sms|whatsapp|email) are required');
            RETURN;
        END IF;
        IF r.id_type = 'PHONE' THEN
            l_norm := APP_NORMALIZE_PHONE(r.identifier, CFG('DEFAULT_COUNTRY_CODE', '20'));
        ELSE
            l_norm := LOWER(r.identifier);
            IF NOT REGEXP_LIKE(l_norm, '^[^@ ]+@[^@ ]+\.[^@ ]+$') THEN l_norm := NULL; END IF;
        END IF;
        IF l_norm IS NULL THEN
            FAIL(p_status, p_json, 400, 'VALIDATION_ERROR',
                 CASE WHEN r.id_type = 'PHONE' THEN 'رقم الموبايل غير صحيح' ELSE 'البريد الإلكتروني غير صحيح' END,
                 CASE WHEN r.id_type = 'PHONE' THEN 'The mobile number is not valid' ELSE 'The email address is not valid' END);
            RETURN;
        END IF;
        IF NOT CHANNEL_AVAILABLE(r.channel) THEN
            FAIL(p_status, p_json, 400, 'CHANNEL_NOT_AVAILABLE', 'قناة الإرسال غير متاحة حاليًا', 'This delivery channel is not available');
            RETURN;
        END IF;

        -- Limits: per IP, per phone/e-mail (wait between codes, codes per hour).
        IF p_ip IS NOT NULL THEN
            SELECT COUNT(*) INTO l_n FROM APP_AUTH_OTP WHERE IP_ADDRESS = p_ip AND CREATED_DATE > SYSDATE - 1 / 24;
            IF l_n >= CFG_NUM('OTP_MAX_PER_IP_HOUR', 30) THEN
                FAIL(p_status, p_json, 429, 'TOO_MANY_REQUESTS', 'طلبات كثيرة، حاول لاحقًا', 'Too many requests, try later', 3600);
                RETURN;
            END IF;
        END IF;
        l_key := SHA(p_purpose || ':' || r.id_type || ':' || l_norm);
        SELECT MAX(CREATED_DATE), MIN(CASE WHEN CREATED_DATE > SYSDATE - 1 / 24 THEN CREATED_DATE END),
               SUM(CASE WHEN CREATED_DATE > SYSDATE - 1 / 24 THEN 1 ELSE 0 END)
          INTO l_last, l_oldest, l_n
          FROM APP_AUTH_OTP WHERE IDENTIFIER_KEY = l_key;
        IF l_last IS NOT NULL AND l_last > SYSDATE - l_resend / 86400 THEN
            FAIL(p_status, p_json, 429, 'OTP_RESEND_TOO_SOON', 'انتظر قليلًا قبل طلب رمز جديد', 'Wait a moment before asking for a new code',
                 CEIL((l_last + l_resend / 86400 - SYSDATE) * 86400));
            RETURN;
        END IF;
        IF NVL(l_n, 0) >= CFG_NUM('OTP_MAX_PER_HOUR', 5) THEN
            FAIL(p_status, p_json, 429, 'TOO_MANY_REQUESTS', 'طلبات كثيرة، حاول لاحقًا', 'Too many requests, try later',
                 CEIL(GREATEST(1, (l_oldest + 1 / 24 - SYSDATE) * 86400)));
            RETURN;
        END IF;

        -- Who is it? Exactly one user must own the phone/e-mail; otherwise (unknown, shared,
        -- not allowed, nothing to send to) a DECOY is stored and the answer is identical, so
        -- the API never tells a stranger whether an account exists.
        IF r.id_type = 'PHONE' THEN
            SELECT COUNT(*) INTO l_n FROM APP_USERS_LOGIN_V2 WHERE PHONE_NORMALIZED = l_norm AND PHONE_IS_SHARED = 0;
            IF l_n = 1 THEN
                SELECT * INTO l_row FROM APP_USERS_LOGIN_V2 WHERE PHONE_NORMALIZED = l_norm AND PHONE_IS_SHARED = 0;
                l_found := TRUE;
            END IF;
        ELSE
            SELECT COUNT(*) INTO l_n FROM APP_USERS_LOGIN_V2 WHERE EMAIL_NORMALIZED = l_norm AND EMAIL_IS_SHARED = 0;
            IF l_n = 1 THEN
                SELECT * INTO l_row FROM APP_USERS_LOGIN_V2 WHERE EMAIL_NORMALIZED = l_norm AND EMAIL_IS_SHARED = 0;
                l_found := TRUE;
            END IF;
        END IF;

        l_delivery := 'SKIPPED_NO_ACCOUNT';
        IF l_found THEN
            l_block := LOGIN_BLOCK_REASON(l_row.USER_ID);
            IF l_block IS NOT NULL THEN
                l_delivery := 'SKIPPED_' || l_block;
            ELSE
                IF r.channel = 'EMAIL' THEN
                    l_dest := CASE WHEN REGEXP_LIKE(LOWER(TRIM(l_row.EMAIL)), '^[^@ ]+@[^@ ]+\.[^@ ]+$') THEN TRIM(l_row.EMAIL) END;
                    l_masked := MASK_EMAIL(l_dest);
                ELSE
                    l_dest := l_row.PHONE_NORMALIZED;
                    l_masked := MASK_PHONE(l_dest);
                END IF;
                IF l_dest IS NULL THEN
                    l_delivery := 'SKIPPED_NO_DESTINATION';
                ELSE
                    l_user    := l_row.USER_ID;
                    l_company := l_row.DEFAULT_COMPANY_ID;
                    l_delivery := 'PENDING_DELIVERY';
                END IF;
            END IF;
        END IF;
        IF l_masked IS NULL THEN
            l_masked := CASE WHEN r.channel = 'EMAIL'
                             THEN CASE WHEN r.id_type = 'EMAIL' THEN MASK_EMAIL(l_norm) ELSE c_bullets || '@' || c_bullets END
                             ELSE CASE WHEN r.id_type = 'PHONE' THEN MASK_PHONE(l_norm) ELSE c_bullets || ' ' || c_bullets END END;
        END IF;

        l_code   := LPAD(TO_CHAR(MOD(TO_NUMBER(SUBSTR(RND_HEX('otp'), 1, 12), 'XXXXXXXXXXXX'), POWER(10, l_len))), l_len, '0');
        l_public := SUBSTR(RND_HEX('otp-id'), 1, 32);
        INSERT INTO APP_AUTH_OTP (PUBLIC_ID, PURPOSE, CHANNEL, IDENTIFIER_TYPE, IDENTIFIER_KEY, USER_ID, DESTINATION_MASKED,
                                  CODE_HASH, MAX_ATTEMPTS, EXPIRES_AT, DELIVERY_STATUS, IP_ADDRESS, DEVICE_UUID)
        VALUES (l_public, p_purpose, r.channel, r.id_type, l_key, l_user, l_masked,
                SHA(l_code || ':' || l_public || ':' || CFG('TOKEN_PEPPER')),
                l_max, SYSDATE + l_ttl / 86400, l_delivery, p_ip, r.device);

        IF l_user IS NOT NULL THEN
            DELIVER(r.channel, l_user, l_dest, l_company, l_code, l_delivery, l_error);
            IF l_delivery = 'LOGGED' THEN l_dev := l_code; END IF;
            UPDATE APP_AUTH_OTP SET DELIVERY_STATUS = l_delivery, DELIVERY_ERROR = l_error, DEV_CODE = l_dev
             WHERE PUBLIC_ID = l_public;
        END IF;
        PURGE_OLD;

        SELECT JSON_OBJECT(
                   'otpId'              VALUE l_public,
                   'channel'            VALUE LOWER(r.channel),
                   'destinationMasked'  VALUE l_masked,
                   'expiresInSeconds'   VALUE l_ttl,
                   'resendAfterSeconds' VALUE l_resend,
                   'devCode'            VALUE CASE WHEN l_dev IS NOT NULL AND CFG('EXPOSE_DEV_OTP', '0') = '1' THEN l_dev END
                   ABSENT ON NULL RETURNING CLOB)
          INTO l_data FROM DUAL;
        p_status := 200;
        p_json   := OKJ(l_data);
    END;

    -- Checks the code of an OTP row. TRUE = accepted (row locked and returned in o);
    -- FALSE = the answer is already in p_status / p_json.
    FUNCTION VERIFY_CODE (p_purpose IN VARCHAR2, r IN t_in, p_ip IN VARCHAR2, o OUT APP_AUTH_OTP%ROWTYPE,
                          p_status OUT NUMBER, p_json OUT CLOB) RETURN BOOLEAN IS
        l_code VARCHAR2(20) := r.code;
        l_ikey VARCHAR2(250) := 'I:' || NVL(p_ip, '?');
        l_wait NUMBER;
        l_left NUMBER;
    BEGIN
        IF r.otp_id IS NULL OR l_code IS NULL THEN
            FAIL(p_status, p_json, 400, 'VALIDATION_ERROR', 'otpId وcode مطلوبان', 'otpId and code are required');
            RETURN FALSE;
        END IF;
        IF REGEXP_LIKE(l_code, '^[0-9]+$') AND LENGTH(l_code) < CFG_NUM('OTP_LENGTH', 6) THEN
            l_code := LPAD(l_code, CFG_NUM('OTP_LENGTH', 6), '0');   -- a JSON number lost its leading zeros
        END IF;
        l_wait := LOCK_SECONDS(l_ikey, CFG_NUM('LOGIN_IP_MAX_FAILURES', 30));
        IF l_wait > 0 THEN
            FAIL(p_status, p_json, 429, 'TOO_MANY_ATTEMPTS', 'محاولات كثيرة، حاول مرة أخرى بعد قليل', 'Too many attempts, try again later', l_wait);
            RETURN FALSE;
        END IF;
        BEGIN
            SELECT * INTO o FROM APP_AUTH_OTP WHERE PUBLIC_ID = r.otp_id AND PURPOSE = p_purpose FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                REG(l_ikey, 'IP', FALSE, p_ip);
                FAIL(p_status, p_json, 400, 'INVALID_OTP', 'الرمز غير صحيح أو منتهي', 'The code is not valid or has expired');
                RETURN FALSE;
        END;
        IF o.OTP_STATUS <> 'PENDING' THEN
            FAIL(p_status, p_json, 400, 'INVALID_OTP', 'الرمز غير صحيح أو منتهي', 'The code is not valid or has expired');
            RETURN FALSE;
        END IF;
        IF o.EXPIRES_AT < SYSDATE THEN
            UPDATE APP_AUTH_OTP SET OTP_STATUS = 'EXPIRED' WHERE ID = o.ID;
            FAIL(p_status, p_json, 400, 'OTP_EXPIRED', 'انتهت صلاحية الرمز، اطلب رمزًا جديدًا', 'The code has expired, ask for a new one');
            RETURN FALSE;
        END IF;
        IF SHA(l_code || ':' || o.PUBLIC_ID || ':' || CFG('TOKEN_PEPPER')) <> o.CODE_HASH THEN
            l_left := o.MAX_ATTEMPTS - o.ATTEMPTS - 1;
            UPDATE APP_AUTH_OTP
               SET ATTEMPTS = ATTEMPTS + 1,
                   OTP_STATUS = CASE WHEN l_left <= 0 THEN 'CANCELLED' ELSE OTP_STATUS END
             WHERE ID = o.ID;
            REG(l_ikey, 'IP', FALSE, p_ip);
            IF l_left <= 0 THEN
                FAIL(p_status, p_json, 400, 'OTP_ATTEMPTS_EXCEEDED', 'تجاوزت عدد المحاولات، اطلب رمزًا جديدًا', 'Too many wrong codes, ask for a new one', NULL, 0);
            ELSE
                FAIL(p_status, p_json, 400, 'INVALID_OTP', 'الرمز غير صحيح', 'The code is not correct', NULL, l_left);
            END IF;
            RETURN FALSE;
        END IF;
        RETURN TRUE;
    END;

    PROCEDURE OTP_VERIFY_LOGIN (p_body IN CLOB, p_ip IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB) IS
        r        t_in;
        o        APP_AUTH_OTP%ROWTYPE;
        l_reason VARCHAR2(40);
        l_device VARCHAR2(100);
        l_token  VARCHAR2(64);
        l_exp    DATE;
    BEGIN
        IF NOT BODY_OK(p_body) THEN INVALID_REQUEST(p_status, p_json); RETURN; END IF;
        r := PARSE(p_body);
        IF CFG('REQUIRE_DEVICE_UUID', '1') = '1' AND r.device IS NULL THEN
            FAIL(p_status, p_json, 400, 'DEVICE_REQUIRED', 'معرّف الجهاز مطلوب', 'deviceUuid is required');
            RETURN;
        END IF;
        IF NOT VERIFY_CODE('LOGIN', r, p_ip, o, p_status, p_json) THEN RETURN; END IF;

        UPDATE APP_AUTH_OTP SET OTP_STATUS = 'USED', VERIFIED_AT = SYSDATE WHERE ID = o.ID;
        IF o.USER_ID IS NULL THEN   -- a decoy can never match; kept for safety
            FAIL(p_status, p_json, 400, 'INVALID_OTP', 'الرمز غير صحيح أو منتهي', 'The code is not valid or has expired');
            RETURN;
        END IF;
        l_reason := LOGIN_BLOCK_REASON(o.USER_ID);
        IF l_reason IS NOT NULL THEN BLOCKED(l_reason, p_status, p_json); RETURN; END IF;
        IF NOT BIND_DEVICE(o.USER_ID, r.device) THEN
            FAIL(p_status, p_json, 403, 'DEVICE_MISMATCH', 'هذا الحساب مرتبط بهاتف آخر. لا يمكنك تسجيل الدخول إلا من جهازك المعتمد.', 'This account is bound to another device');
            RETURN;
        END IF;
        REG('I:' || NVL(p_ip, '?'), 'IP', TRUE, p_ip);
        NEW_SESSION(o.USER_ID, r.device, 'OTP_' || o.CHANNEL, p_ip, l_token, l_exp);
        p_status := 200;
        p_json   := OKJ(SESSION_JSON(o.USER_ID, l_token, l_exp));
    END;

    -- ================================================================= forgot password
    PROCEDURE OTP_VERIFY_RESET (p_body IN CLOB, p_ip IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB) IS
        r        t_in;
        o        APP_AUTH_OTP%ROWTYPE;
        l_reason VARCHAR2(40);
        l_token  VARCHAR2(64);
        l_mins   NUMBER := CFG_NUM('RESET_TOKEN_MINUTES', 10);
        l_data   CLOB;
    BEGIN
        IF NOT BODY_OK(p_body) THEN INVALID_REQUEST(p_status, p_json); RETURN; END IF;
        r := PARSE(p_body);
        IF NOT VERIFY_CODE('RESET', r, p_ip, o, p_status, p_json) THEN RETURN; END IF;
        IF o.USER_ID IS NULL THEN
            UPDATE APP_AUTH_OTP SET OTP_STATUS = 'CANCELLED' WHERE ID = o.ID;
            FAIL(p_status, p_json, 400, 'INVALID_OTP', 'الرمز غير صحيح أو منتهي', 'The code is not valid or has expired');
            RETURN;
        END IF;
        l_reason := LOGIN_BLOCK_REASON(o.USER_ID);
        IF l_reason IS NOT NULL THEN
            UPDATE APP_AUTH_OTP SET OTP_STATUS = 'CANCELLED' WHERE ID = o.ID;
            BLOCKED(l_reason, p_status, p_json);
            RETURN;
        END IF;
        l_token := RND_HEX('reset:' || o.USER_ID);
        UPDATE APP_AUTH_OTP
           SET OTP_STATUS = 'VERIFIED', VERIFIED_AT = SYSDATE,
               RESET_TOKEN_HASH = SHA(l_token || ':' || CFG('TOKEN_PEPPER')),
               RESET_EXPIRES_AT = SYSDATE + l_mins / 1440
         WHERE ID = o.ID;
        SELECT JSON_OBJECT('resetToken' VALUE l_token, 'expiresInSeconds' VALUE l_mins * 60 RETURNING CLOB) INTO l_data FROM DUAL;
        p_status := 200;
        p_json   := OKJ(l_data);
    END;

    PROCEDURE PASSWORD_RESET (p_body IN CLOB, p_ip IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB) IS
        r         t_in;
        o         APP_AUTH_OTP%ROWTYPE;
        l_problem VARCHAR2(30);
        l_reason  VARCHAR2(40);
        l_uname   VARCHAR2(200);
        l_data    CLOB;
    BEGIN
        IF NOT BODY_OK(p_body) THEN INVALID_REQUEST(p_status, p_json); RETURN; END IF;
        r := PARSE(p_body);
        IF r.reset_token IS NULL OR r.new_password IS NULL THEN
            FAIL(p_status, p_json, 400, 'VALIDATION_ERROR', 'resetToken وnewPassword مطلوبان', 'resetToken and newPassword are required');
            RETURN;
        END IF;
        BEGIN
            SELECT * INTO o FROM APP_AUTH_OTP
             WHERE RESET_TOKEN_HASH = SHA(r.reset_token || ':' || CFG('TOKEN_PEPPER'))
               AND OTP_STATUS = 'VERIFIED' AND RESET_EXPIRES_AT > SYSDATE AND PURPOSE = 'RESET' FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                REG('I:' || NVL(p_ip, '?'), 'IP', FALSE, p_ip);
                FAIL(p_status, p_json, 400, 'INVALID_RESET_TOKEN', 'انتهت مهلة تغيير كلمة المرور، ابدأ من جديد', 'The reset session is not valid or has expired');
                RETURN;
        END;
        l_problem := PASSWORD_PROBLEM(r.new_password);
        IF l_problem IS NOT NULL THEN PASSWORD_PROBLEM_RESPONSE(l_problem, p_status, p_json); RETURN; END IF;
        l_reason := LOGIN_BLOCK_REASON(o.USER_ID);
        IF l_reason IS NOT NULL THEN BLOCKED(l_reason, p_status, p_json); RETURN; END IF;

        UPDATE SEC_USERS
           SET PASSWORD = r.new_password, IS_CHANGE_PASSWORD = 0, IS_PASSWORD_CHANGED = 1, PASSWORD_CHANGE_DATE = SYSDATE
         WHERE ID = o.USER_ID;
        UPDATE APP_AUTH_OTP SET OTP_STATUS = 'USED', RESET_TOKEN_HASH = NULL WHERE ID = o.ID;
        UPDATE APP_AUTH_SESSIONS SET IS_REVOKED = '1', REVOKED_AT = SYSDATE WHERE USER_ID = o.USER_ID AND IS_REVOKED = '0';
        SELECT UPPER(USERNAME) INTO l_uname FROM SEC_USERS WHERE ID = o.USER_ID;
        REG('U:' || l_uname, 'PASSWORD', TRUE, p_ip);
        SELECT JSON_OBJECT('passwordChanged' VALUE 'true' FORMAT JSON RETURNING CLOB) INTO l_data FROM DUAL;
        p_status := 200;
        p_json   := OKJ(l_data);
    END;

    -- =============================================================== signed-in endpoints
    PROCEDURE PASSWORD_CHANGE (p_auth IN VARCHAR2, p_body IN CLOB, p_status OUT NUMBER, p_json OUT CLOB) IS
        r         t_in;
        l_user    NUMBER;
        l_sid     NUMBER;
        l_error   VARCHAR2(40);
        l_stored  SEC_USERS.PASSWORD%TYPE;
        l_problem VARCHAR2(30);
        l_data    CLOB;
    BEGIN
        AUTH_SESSION(p_auth, l_user, l_sid, l_error);
        IF l_error IS NOT NULL THEN AUTH_FAIL(l_error, p_status, p_json); RETURN; END IF;
        IF NOT BODY_OK(p_body) THEN INVALID_REQUEST(p_status, p_json); RETURN; END IF;
        r := PARSE(p_body);
        IF r.old_password IS NULL OR r.new_password IS NULL THEN
            FAIL(p_status, p_json, 400, 'VALIDATION_ERROR', 'كلمة المرور القديمة والجديدة مطلوبتان', 'oldPassword and newPassword are required');
            RETURN;
        END IF;
        SELECT PASSWORD INTO l_stored FROM SEC_USERS WHERE ID = l_user;
        IF l_stored IS NULL OR l_stored <> r.old_password THEN
            FAIL(p_status, p_json, 400, 'INVALID_OLD_PASSWORD', 'كلمة المرور القديمة غير صحيحة', 'The old password is not correct');
            RETURN;
        END IF;
        l_problem := PASSWORD_PROBLEM(r.new_password);
        IF l_problem IS NOT NULL THEN PASSWORD_PROBLEM_RESPONSE(l_problem, p_status, p_json); RETURN; END IF;
        UPDATE SEC_USERS
           SET PASSWORD = r.new_password, IS_CHANGE_PASSWORD = 0, IS_PASSWORD_CHANGED = 1, PASSWORD_CHANGE_DATE = SYSDATE
         WHERE ID = l_user;
        -- every other device must sign in again with the new password
        UPDATE APP_AUTH_SESSIONS SET IS_REVOKED = '1', REVOKED_AT = SYSDATE WHERE USER_ID = l_user AND IS_REVOKED = '0' AND ID <> l_sid;
        SELECT JSON_OBJECT('passwordChanged' VALUE 'true' FORMAT JSON RETURNING CLOB) INTO l_data FROM DUAL;
        p_status := 200;
        p_json   := OKJ(l_data);
    END;

    PROCEDURE AUTHENTICATE (p_auth IN VARCHAR2, p_user_id OUT NUMBER, p_status OUT NUMBER, p_json OUT CLOB) IS
        l_sid   NUMBER;
        l_error VARCHAR2(40);
    BEGIN
        p_json := NULL;
        AUTH_SESSION(p_auth, p_user_id, l_sid, l_error);
        IF l_error IS NOT NULL THEN
            p_user_id := NULL;
            AUTH_FAIL(l_error, p_status, p_json);
        END IF;
    END;

    FUNCTION OK_RESPONSE (p_data IN CLOB) RETURN CLOB IS
    BEGIN
        RETURN OKJ(p_data);
    END;

    PROCEDURE FAIL_RESPONSE (p_status OUT NUMBER, p_json OUT CLOB, p_http IN NUMBER, p_code IN VARCHAR2,
                             p_ar IN VARCHAR2, p_en IN VARCHAR2) IS
    BEGIN
        FAIL(p_status, p_json, p_http, p_code, p_ar, p_en);
    END;

    PROCEDURE ME (p_auth IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB) IS
        l_user  NUMBER;
        l_sid   NUMBER;
        l_error VARCHAR2(40);
        l_data  CLOB;
    BEGIN
        AUTH_SESSION(p_auth, l_user, l_sid, l_error);
        IF l_error IS NOT NULL THEN AUTH_FAIL(l_error, p_status, p_json); RETURN; END IF;
        SELECT JSON_OBJECT('user' VALUE USER_JSON(l_user) FORMAT JSON RETURNING CLOB) INTO l_data FROM DUAL;
        p_status := 200;
        p_json   := OKJ(l_data);
    END;

    PROCEDURE LOGOUT (p_auth IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB) IS
        l_user  NUMBER;
        l_sid   NUMBER;
        l_error VARCHAR2(40);
        l_data  CLOB;
    BEGIN
        AUTH_SESSION(p_auth, l_user, l_sid, l_error);
        IF l_error IS NOT NULL THEN AUTH_FAIL(l_error, p_status, p_json); RETURN; END IF;
        UPDATE APP_AUTH_SESSIONS SET IS_REVOKED = '1', REVOKED_AT = SYSDATE WHERE ID = l_sid;
        SELECT JSON_OBJECT('loggedOut' VALUE 'true' FORMAT JSON RETURNING CLOB) INTO l_data FROM DUAL;
        p_status := 200;
        p_json   := OKJ(l_data);
    END;

END APP_AUTH_PKG;
/
