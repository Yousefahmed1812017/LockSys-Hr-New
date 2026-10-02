-- Mobile leave API, step 2: package APP_LEAVE_PKG (read side: my requests, one request,
-- my balances, the leave types). Run in the ERP schema (GSPLUS) with UTF-8, after
-- 03_APP_AUTH_PKG.sql and 05_APP_LEAVE_VIEWS.sql. Only new objects; nothing is written
-- to any leave table.
--
-- Same envelope as the sign-in API: {success:true,data} / {success:false,error:{...}}.
-- The employee always comes from the Bearer token (user -> employee), never from the
-- request, so nobody can read someone else's leaves.
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

CREATE OR REPLACE PACKAGE APP_LEAVE_PKG AS
    -- p_state: all | open (new, pending, in progress) | approved | rejected | cancelled
    PROCEDURE LIST_REQUESTS (p_auth IN VARCHAR2, p_state IN VARCHAR2, p_year IN VARCHAR2, p_type_id IN VARCHAR2,
                             p_limit IN VARCHAR2, p_offset IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB);
    PROCEDURE GET_REQUEST   (p_auth IN VARCHAR2, p_id IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB);
    PROCEDURE BALANCES      (p_auth IN VARCHAR2, p_year IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB);
    PROCEDURE TYPES         (p_auth IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB);

    -- public only because SQL statements call it
    FUNCTION REQUEST_JSON (p_request_id IN NUMBER) RETURN CLOB;
END APP_LEAVE_PKG;
/

CREATE OR REPLACE PACKAGE BODY APP_LEAVE_PKG AS

    c_max_limit CONSTANT NUMBER := 100;

    FUNCTION TO_INT (p IN VARCHAR2) RETURN NUMBER IS
    BEGIN
        RETURN CASE WHEN p IS NULL THEN NULL ELSE TO_NUMBER(TRIM(p)) END;
    EXCEPTION
        WHEN VALUE_ERROR THEN RETURN -1;
    END;

    -- Signed in AND an employee. p_employee_id is set when it returns FALSE-free.
    FUNCTION WHO (p_auth IN VARCHAR2, p_employee_id OUT NUMBER, p_status OUT NUMBER, p_json OUT CLOB) RETURN BOOLEAN IS
        l_user NUMBER;
    BEGIN
        APP_AUTH_PKG.AUTHENTICATE(p_auth, l_user, p_status, p_json);
        IF p_json IS NOT NULL THEN
            RETURN FALSE;
        END IF;
        SELECT MAX(EMPLOYEE_ID) INTO p_employee_id FROM APP_USERS_LOGIN_V2 WHERE USER_ID = l_user;
        IF p_employee_id IS NULL THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 403, 'NO_EMPLOYEE',
                'هذا الحساب غير مرتبط بموظف', 'This account is not linked to an employee');
            RETURN FALSE;
        END IF;
        RETURN TRUE;
    END;

    -- ===================================================================== one request
    FUNCTION REQUEST_JSON (p_request_id IN NUMBER) RETURN CLOB IS
        l CLOB;
    BEGIN
        SELECT JSON_OBJECT(
            'id'                VALUE R.REQUEST_ID,
            'requestNo'         VALUE R.REQUEST_NO,
            'type'              VALUE JSON_OBJECT('id' VALUE R.LEAVE_TYPE_ID, 'code' VALUE R.TYPE_CODE,
                                                  'nameAr' VALUE R.TYPE_NAME_AR, 'nameEn' VALUE R.TYPE_NAME_EN,
                                                  'isPaid' VALUE CASE WHEN R.TYPE_IS_PAID = '1' THEN 'true' ELSE 'false' END FORMAT JSON,
                                                  'deductsBalance' VALUE CASE WHEN R.TYPE_DEDUCTS_BALANCE = '1' THEN 'true' ELSE 'false' END FORMAT JSON),
            'requestDate'       VALUE TO_CHAR(R.REQUEST_DATE, 'YYYY-MM-DD'),
            'startDate'         VALUE TO_CHAR(R.START_DATE, 'YYYY-MM-DD'),
            'endDate'           VALUE TO_CHAR(R.END_DATE, 'YYYY-MM-DD'),
            'returnDate'        VALUE TO_CHAR(R.RETURN_DATE, 'YYYY-MM-DD'),
            'actualReturnDate'  VALUE TO_CHAR(R.ACTUAL_RETURN_DATE, 'YYYY-MM-DD'),
            'days'              VALUE JSON_OBJECT('total' VALUE R.TOTAL_DAYS, 'weekend' VALUE R.WEEKEND_DAYS,
                                                  'holidays' VALUE R.HOLIDAY_DAYS, 'working' VALUE R.WORKING_DAYS,
                                                  'unpaid' VALUE R.UNPAID_DAYS),
            'isHalfDay'         VALUE CASE WHEN R.HALF_DAY_TYPE IS NOT NULL THEN 'true' ELSE 'false' END FORMAT JSON,
            'halfDayType'       VALUE R.HALF_DAY_TYPE,
            'balance'           VALUE JSON_OBJECT('before' VALUE R.BALANCE_BEFORE, 'after' VALUE R.BALANCE_AFTER,
                                                  'deducted' VALUE R.DISCOUNTED_BALANCE),
            'reason'            VALUE R.REASON,
            'emergencyPhone'    VALUE R.EMERGENCY_PHONE,
            'substitute'        VALUE (CASE WHEN R.SUBSTITUTE_EMPLOYEE_ID IS NULL THEN NULL
                                       ELSE JSON_OBJECT('employeeId' VALUE R.SUBSTITUTE_EMPLOYEE_ID,
                                                        'nameAr' VALUE R.SUBSTITUTE_NAME_AR, 'nameEn' VALUE R.SUBSTITUTE_NAME_EN) END) FORMAT JSON,
            'status'            VALUE JSON_OBJECT('id' VALUE R.STATUS_ID, 'nameAr' VALUE R.STATUS_NAME_AR, 'nameEn' VALUE R.STATUS_NAME_EN,
                                                  'colorId' VALUE R.STATUS_COLOR_ID,
                                                  'isFinal' VALUE CASE WHEN R.STATUS_IS_FINAL = '1' THEN 'true' ELSE 'false' END FORMAT JSON,
                                                  'canCancel' VALUE CASE WHEN R.STATUS_CAN_CANCEL = '1' THEN 'true' ELSE 'false' END FORMAT JSON,
                                                  'canEdit' VALUE CASE WHEN R.STATUS_CAN_EDIT = '1' THEN 'true' ELSE 'false' END FORMAT JSON),
            'statusDate'        VALUE TO_CHAR(R.STATUS_DATE, 'YYYY-MM-DD'),
            'statusReason'      VALUE (CASE WHEN R.STATUS_REASON_ID IS NULL AND R.STATUS_REASON_TEXT IS NULL THEN NULL
                                       ELSE JSON_OBJECT('id' VALUE R.STATUS_REASON_ID, 'nameAr' VALUE R.STATUS_REASON_NAME_AR,
                                                        'nameEn' VALUE R.STATUS_REASON_NAME_EN, 'text' VALUE R.STATUS_REASON_TEXT) END) FORMAT JSON,
            'currentStage'      VALUE (CASE WHEN R.CURRENT_STAGE_ID IS NULL THEN NULL
                                       ELSE JSON_OBJECT('id' VALUE R.CURRENT_STAGE_ID, 'code' VALUE R.CURRENT_STAGE_CODE,
                                                        'nameAr' VALUE R.CURRENT_STAGE_NAME_AR, 'nameEn' VALUE R.CURRENT_STAGE_NAME_EN) END) FORMAT JSON,
            'decision'          VALUE (CASE WHEN R.DECISION_NUMBER IS NULL THEN NULL
                                       ELSE JSON_OBJECT('number' VALUE R.DECISION_NUMBER, 'year' VALUE R.DECISION_YEAR) END) FORMAT JSON,
            'cut'               VALUE (CASE WHEN R.IS_CUT = 1
                                       THEN JSON_OBJECT('date' VALUE TO_CHAR(R.CUT_DATE, 'YYYY-MM-DD'), 'reason' VALUE R.CUT_REASON) END) FORMAT JSON,
            'createdFromMobile' VALUE CASE WHEN R.CREATED_FROM_MOBILE = 1 THEN 'true' ELSE 'false' END FORMAT JSON,
            'createdAt'         VALUE TO_CHAR(R.CREATED_AT, 'YYYY-MM-DD"T"HH24:MI:SS')
            RETURNING CLOB)
          INTO l FROM APP_LEAVE_REQUESTS_V2 R WHERE R.REQUEST_ID = p_request_id;
        RETURN l;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN NULL;
    END;

    -- ========================================================================== list
    PROCEDURE LIST_REQUESTS (p_auth IN VARCHAR2, p_state IN VARCHAR2, p_year IN VARCHAR2, p_type_id IN VARCHAR2,
                             p_limit IN VARCHAR2, p_offset IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB) IS
        l_emp    NUMBER;
        l_state  VARCHAR2(20) := LOWER(NVL(TRIM(p_state), 'all'));
        l_year   NUMBER := TO_INT(p_year);
        l_type   NUMBER := TO_INT(p_type_id);
        l_limit  NUMBER := NVL(TO_INT(p_limit), 20);
        l_offset NUMBER := NVL(TO_INT(p_offset), 0);
        l_total  NUMBER;
        l_items  CLOB;
        l_data   CLOB;
    BEGIN
        IF NOT WHO(p_auth, l_emp, p_status, p_json) THEN RETURN; END IF;
        IF l_state NOT IN ('all', 'open', 'approved', 'rejected', 'cancelled')
           OR l_year < 0 OR l_type < 0 OR l_limit < 1 OR l_offset < 0 THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 400, 'VALIDATION_ERROR',
                'قيمة غير صحيحة في المعاملات (state, year, typeId, limit, offset)',
                'Invalid query parameter (state, year, typeId, limit, offset)');
            RETURN;
        END IF;
        l_limit := LEAST(l_limit, c_max_limit);

        -- the filter on state is applied to the list only; the summary counts all states
        SELECT COUNT(*) INTO l_total
          FROM APP_LEAVE_REQUESTS_V2 R
         WHERE R.EMPLOYEE_ID = l_emp
           AND (l_year IS NULL OR R.START_YEAR = l_year)
           AND (l_type IS NULL OR R.LEAVE_TYPE_ID = l_type)
           AND (l_state = 'all'
                OR (l_state = 'open' AND R.STATUS_ID IN (1, 2, 3))
                OR (l_state = 'approved' AND R.STATUS_ID = 4)
                OR (l_state = 'rejected' AND R.STATUS_ID = 5)
                OR (l_state = 'cancelled' AND R.STATUS_ID = 6));

        SELECT NVL(JSON_ARRAYAGG(APP_LEAVE_PKG.REQUEST_JSON(X.REQUEST_ID) FORMAT JSON
                                 ORDER BY X.START_DATE DESC, X.REQUEST_ID DESC RETURNING CLOB), '[]')
          INTO l_items
          FROM (SELECT R.REQUEST_ID, R.START_DATE
                  FROM APP_LEAVE_REQUESTS_V2 R
                 WHERE R.EMPLOYEE_ID = l_emp
                   AND (l_year IS NULL OR R.START_YEAR = l_year)
                   AND (l_type IS NULL OR R.LEAVE_TYPE_ID = l_type)
                   AND (l_state = 'all'
                        OR (l_state = 'open' AND R.STATUS_ID IN (1, 2, 3))
                        OR (l_state = 'approved' AND R.STATUS_ID = 4)
                        OR (l_state = 'rejected' AND R.STATUS_ID = 5)
                        OR (l_state = 'cancelled' AND R.STATUS_ID = 6))
                 ORDER BY R.START_DATE DESC, R.REQUEST_ID DESC
                OFFSET l_offset ROWS FETCH NEXT l_limit ROWS ONLY) X;

        SELECT JSON_OBJECT(
                   'items'   VALUE l_items FORMAT JSON,
                   'paging'  VALUE JSON_OBJECT('total' VALUE l_total, 'limit' VALUE l_limit, 'offset' VALUE l_offset,
                                               'hasMore' VALUE CASE WHEN l_offset + l_limit < l_total THEN 'true' ELSE 'false' END FORMAT JSON),
                   'summary' VALUE (SELECT JSON_OBJECT(
                                        'total'     VALUE COUNT(*),
                                        'open'      VALUE NVL(SUM(CASE WHEN R.STATUS_ID IN (1, 2, 3) THEN 1 END), 0),
                                        'approved'  VALUE NVL(SUM(CASE WHEN R.STATUS_ID = 4 THEN 1 END), 0),
                                        'rejected'  VALUE NVL(SUM(CASE WHEN R.STATUS_ID = 5 THEN 1 END), 0),
                                        'cancelled' VALUE NVL(SUM(CASE WHEN R.STATUS_ID = 6 THEN 1 END), 0))
                                      FROM APP_LEAVE_REQUESTS_V2 R
                                     WHERE R.EMPLOYEE_ID = l_emp
                                       AND (l_year IS NULL OR R.START_YEAR = l_year)
                                       AND (l_type IS NULL OR R.LEAVE_TYPE_ID = l_type)) FORMAT JSON
                   RETURNING CLOB)
          INTO l_data FROM DUAL;
        p_status := 200;
        p_json   := APP_AUTH_PKG.OK_RESPONSE(l_data);
    END;

    -- ======================================================================== detail
    PROCEDURE GET_REQUEST (p_auth IN VARCHAR2, p_id IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB) IS
        l_emp      NUMBER;
        l_id       NUMBER := TO_INT(p_id);
        l_owner    NUMBER;
        l_request  CLOB;
        l_stages   CLOB;
        l_history  CLOB;
        l_data     CLOB;
    BEGIN
        IF NOT WHO(p_auth, l_emp, p_status, p_json) THEN RETURN; END IF;
        -- someone else's request answers exactly like a missing one
        SELECT MAX(EMPLOYEE_ID) INTO l_owner FROM APP_LEAVE_REQUESTS_V2 WHERE REQUEST_ID = l_id;
        IF l_id IS NULL OR l_id < 0 OR l_owner IS NULL OR l_owner <> l_emp THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 404, 'REQUEST_NOT_FOUND', 'الطلب غير موجود', 'Leave request not found');
            RETURN;
        END IF;
        l_request := REQUEST_JSON(l_id);

        -- the approval chain, in order
        SELECT NVL(JSON_ARRAYAGG(JSON_OBJECT(
                       'order'    VALUE S.STAGE_ORDER,
                       'code'     VALUE A.CODE,
                       'nameAr'   VALUE A.ARABIC_NAME,
                       'nameEn'   VALUE A.NAME,
                       'status'   VALUE S.STATUS,
                       'date'     VALUE TO_CHAR(S.STATUS_DATE, 'YYYY-MM-DD'),
                       'approver' VALUE (CASE WHEN E.EMPLOYEE_ID IS NULL THEN NULL
                                         ELSE JSON_OBJECT('nameAr' VALUE E.FULL_NAME_AR, 'nameEn' VALUE E.FULL_NAME_EN) END) FORMAT JSON)
                   ORDER BY S.STAGE_ORDER RETURNING CLOB), '[]')
          INTO l_stages
          FROM HR_LEAVE_REQUEST_STAGES S
          LEFT JOIN HR_LEAVE_APPROVAL_STAGES A ON A.ID = S.STAGE_ID
          LEFT JOIN HR_EMPLOYEES E ON E.EMPLOYEE_ID = S.EMPLOYEE_ID
         WHERE S.LEAVE_REQUEST_ID = l_id;

        -- what happened to the request, oldest first
        SELECT NVL(JSON_ARRAYAGG(JSON_OBJECT(
                       'statusId'   VALUE L.STATUS_ID,
                       'nameAr'     VALUE ST.ARABIC_NAME,
                       'nameEn'     VALUE ST.NAME,
                       'date'       VALUE TO_CHAR(L.STATUS_DATE, 'YYYY-MM-DD'),
                       'reasonAr'   VALUE SR.ARABIC_NAME,
                       'reasonEn'   VALUE SR.NAME,
                       'reasonText' VALUE L.STATUS_REASON_TEXT)
                   ORDER BY L.STATUS_DATE, L.ID RETURNING CLOB), '[]')
          INTO l_history
          FROM HR_EMPLOYEE_LEAVE_REQUEST_STATUS_LOG L
          LEFT JOIN HR_LEAVE_STATUS ST ON ST.ID = L.STATUS_ID
          LEFT JOIN HR_LEAVE_STATUS_REASONS SR ON SR.ID = L.STATUS_REASON_ID
         WHERE L.LEAVE_REQUEST_ID = l_id;

        SELECT JSON_OBJECT('request' VALUE l_request FORMAT JSON,
                           'approvalStages' VALUE l_stages FORMAT JSON,
                           'history' VALUE l_history FORMAT JSON RETURNING CLOB)
          INTO l_data FROM DUAL;
        p_status := 200;
        p_json   := APP_AUTH_PKG.OK_RESPONSE(l_data);
    END;

    -- ===================================================================== balances
    PROCEDURE BALANCES (p_auth IN VARCHAR2, p_year IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB) IS
        l_emp   NUMBER;
        l_year  NUMBER := NVL(TO_INT(p_year), EXTRACT(YEAR FROM SYSDATE));
        l_bal   CLOB;
        l_years CLOB;
        l_data  CLOB;
    BEGIN
        IF NOT WHO(p_auth, l_emp, p_status, p_json) THEN RETURN; END IF;
        IF l_year < 1990 OR l_year > 2100 THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 400, 'VALIDATION_ERROR', 'السنة غير صحيحة', 'Invalid year');
            RETURN;
        END IF;
        BEGIN
            SELECT JSON_OBJECT(
                       'annual' VALUE JSON_OBJECT('carriedForward' VALUE B.ANNUAL_CARRIED_FORWARD,
                                                  'entitlement' VALUE B.ANNUAL_ENTITLEMENT,
                                                  'totalAvailable' VALUE B.ANNUAL_TOTAL_AVAILABLE,
                                                  'used' VALUE B.ANNUAL_USED, 'remaining' VALUE B.ANNUAL_REMAINING),
                       'casual' VALUE JSON_OBJECT('entitlement' VALUE B.CASUAL_ENTITLEMENT,
                                                  'used' VALUE B.CASUAL_USED, 'remaining' VALUE B.CASUAL_REMAINING)
                       RETURNING CLOB)
              INTO l_bal
              FROM APP_LEAVE_BALANCES_V2 B WHERE B.EMPLOYEE_ID = l_emp AND B.BALANCE_YEAR = l_year;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN l_bal := NULL;
        END;
        SELECT NVL(JSON_ARRAYAGG(BALANCE_YEAR ORDER BY BALANCE_YEAR DESC RETURNING CLOB), '[]')
          INTO l_years FROM APP_LEAVE_BALANCES_V2 WHERE EMPLOYEE_ID = l_emp;
        SELECT JSON_OBJECT('year' VALUE l_year, 'balance' VALUE l_bal FORMAT JSON,
                           'years' VALUE l_years FORMAT JSON RETURNING CLOB)
          INTO l_data FROM DUAL;
        p_status := 200;
        p_json   := APP_AUTH_PKG.OK_RESPONSE(l_data);
    END;

    -- ======================================================================== types
    -- The types the employee can request from the app, with the rules and, for the
    -- types that have a counted balance (annual 3, casual 24), what is left this year.
    PROCEDURE TYPES (p_auth IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB) IS
        l_emp   NUMBER;
        l_items CLOB;
        l_data  CLOB;
    BEGIN
        IF NOT WHO(p_auth, l_emp, p_status, p_json) THEN RETURN; END IF;
        SELECT NVL(JSON_ARRAYAGG(JSON_OBJECT(
                       'id'                 VALUE T.LEAVE_TYPE_ID,
                       'code'               VALUE T.CODE,
                       'nameAr'             VALUE T.NAME_AR,
                       'nameEn'             VALUE T.NAME_EN,
                       'isPaid'             VALUE CASE WHEN T.IS_PAID = '1' THEN 'true' ELSE 'false' END FORMAT JSON,
                       'deductsBalance'     VALUE CASE WHEN T.DEDUCT_FROM_BALANCE = '1' THEN 'true' ELSE 'false' END FORMAT JSON,
                       'allowHalfDay'       VALUE CASE WHEN T.ALLOW_HALF_DAY = '1' THEN 'true' ELSE 'false' END FORMAT JSON,
                       'minDaysPerRequest'  VALUE T.MIN_DAYS_PER_REQUEST,
                       'maxDaysPerRequest'  VALUE T.MAX_DAYS_PER_REQUEST,
                       'maxDaysPerYear'     VALUE T.MAX_DAYS_PER_YEAR,
                       'maxDaysPerMonth'    VALUE T.MAX_DAYS_PER_MONTH,
                       'advanceNoticeDays'  VALUE T.ADVANCE_NOTICE_DAYS,
                       'requiresReason'     VALUE CASE WHEN T.REQUIRES_REASON = '1' THEN 'true' ELSE 'false' END FORMAT JSON,
                       'requiresDocument'   VALUE CASE WHEN T.REQUIRES_DOCUMENT = '1' THEN 'true' ELSE 'false' END FORMAT JSON,
                       'excludesWeekends'   VALUE CASE WHEN T.EXCLUDE_WEEKENDS = '1' THEN 'true' ELSE 'false' END FORMAT JSON,
                       'excludesHolidays'   VALUE CASE WHEN T.EXCLUDE_HOLIDAYS = '1' THEN 'true' ELSE 'false' END FORMAT JSON,
                       'remaining'          VALUE CASE T.LEAVE_TYPE_ID WHEN 3 THEN B.ANNUAL_REMAINING WHEN 24 THEN B.CASUAL_REMAINING END)
                   ORDER BY T.DISPLAY_ORDER, T.LEAVE_TYPE_ID RETURNING CLOB), '[]')
          INTO l_items
          FROM APP_LEAVE_TYPES_V2 T
          LEFT JOIN APP_LEAVE_BALANCES_V2 B
            ON B.EMPLOYEE_ID = l_emp AND B.BALANCE_YEAR = EXTRACT(YEAR FROM SYSDATE)
         WHERE T.IS_MOBILE_APP = 1;
        SELECT JSON_OBJECT('items' VALUE l_items FORMAT JSON RETURNING CLOB) INTO l_data FROM DUAL;
        p_status := 200;
        p_json   := APP_AUTH_PKG.OK_RESPONSE(l_data);
    END;

END APP_LEAVE_PKG;
/
