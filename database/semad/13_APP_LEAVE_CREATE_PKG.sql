-- Mobile leave API, step 4: create a leave request from the app. Run in the ERP schema
-- (GSPLUS) with UTF-8, after 06_APP_LEAVE_PKG.sql. New package APP_LEAVE_NEW_PKG:
--   PREVIEW - counts the days and checks every rule, writes nothing (for the form)
--   CREATE_REQUEST - same checks, then inserts HR_EMPLOYEE_LEAVE_REQUESTS and builds the
--                    approval stages with HR_CREATE_LEAVE_STAGES_V2 (that procedure commits)
-- Body (JSON): {"typeId":3,"startDate":"2026-11-01","endDate":"2026-11-03",
--               "halfDayType":null|1|2,"reason":"...","emergencyPhone":"..."}
-- The employee always comes from the Bearer token. Only types with IS_MOBILE_APP = 1.
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

CREATE OR REPLACE PACKAGE APP_LEAVE_NEW_PKG AS
    PROCEDURE PREVIEW        (p_auth IN VARCHAR2, p_body IN CLOB, p_status OUT NUMBER, p_json OUT CLOB);
    PROCEDURE CREATE_REQUEST (p_auth IN VARCHAR2, p_body IN CLOB, p_status OUT NUMBER, p_json OUT CLOB);
END APP_LEAVE_NEW_PKG;
/

CREATE OR REPLACE PACKAGE BODY APP_LEAVE_NEW_PKG AS

    PROCEDURE RUN (p_auth IN VARCHAR2, p_body IN CLOB, p_create IN BOOLEAN, p_status OUT NUMBER, p_json OUT CLOB) IS
        l_user     NUMBER;
        l_emp      NUMBER;
        l_username VARCHAR2(200);
        l_company  NUMBER;
        l_branch   NUMBER;
        l_type     NUMBER;
        l_start    DATE;
        l_end      DATE;
        l_half     NUMBER;
        l_reason   VARCHAR2(1000);
        l_phone    VARCHAR2(50);
        t          APP_LEAVE_TYPES_V2%ROWTYPE;
        l_total    NUMBER;
        l_working  NUMBER;
        l_holidays NUMBER := 0;
        l_weekend  NUMBER;
        l_deduct   NUMBER;
        l_rest     NUMBER := 0;
        l_comp     NUMBER := 0;
        l_emp_type NUMBER;
        l_group    NUMBER;
        l_shift    NUMBER;
        l_religion NUMBER;
        l_ex_wk    NUMBER;
        l_ex_hol   NUMBER;
        l_cur      DATE;
        l_used     NUMBER;
        l_remain   NUMBER;
        l_carried  NUMBER;
        l_entitle  NUMBER;
        l_safety   NUMBER := 0;
        l_before   NUMBER;
        l_after    NUMBER;
        l_year_sum NUMBER;
        l_count    NUMBER;
        l_id       NUMBER;
        l_return   DATE;
        l_data     CLOB;
        e_stop     EXCEPTION;

        PROCEDURE ERR (p_http IN NUMBER, p_code IN VARCHAR2, p_ar IN VARCHAR2, p_en IN VARCHAR2) IS
        BEGIN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, p_http, p_code, p_ar, p_en);
            RAISE e_stop;
        END;

        FUNCTION DATE_OF (p_path IN VARCHAR2) RETURN DATE IS
        BEGIN
            RETURN TO_DATE(JSON_VALUE(p_body, p_path), 'YYYY-MM-DD');
        EXCEPTION
            WHEN OTHERS THEN RETURN DATE '0001-01-01';   -- present but not a date
        END;

        -- the employee's rest day (fixed rotation or weekly shift) and official holiday,
        -- the same rules as the ERP leave page
        FUNCTION IS_REST (p_d IN DATE) RETURN NUMBER IS
            l_n NUMBER := 0;
        BEGIN
            IF l_emp_type = 1 THEN
                IF GET_SHIFT_TYPE_ID(p_d, l_group) = 64 THEN l_n := 1; END IF;
            ELSIF l_emp_type = 2 AND l_shift IS NOT NULL THEN
                SELECT COUNT(*) INTO l_n
                  FROM HR_WORK_SHIF_DAYS SD JOIN HR_WEEK_DAYS WD ON WD.DAY_ID = SD.DAY_ID
                 WHERE SD.SHIFT_ID = l_shift AND WD.DAY_NAME_EN = TRIM(TO_CHAR(p_d, 'DAY')) AND SD.IS_OFF = 1;
            END IF;
            RETURN l_n;
        END;

        FUNCTION IS_HOLIDAY (p_d IN DATE) RETURN NUMBER IS
            l_n NUMBER;
        BEGIN
            SELECT COUNT(*) INTO l_n FROM HR_OFFICIAL_HOLIDAYS PH
             WHERE PH.HOLIDAY_DATE = TRUNC(p_d) AND NVL(PH.STATUS, 1) = 1
               AND (PH.RELIGION_ID IS NULL OR PH.RELIGION_ID = l_religion)
               AND (PH.SHIFT_ID IS NULL OR PH.SHIFT_ID = l_shift);
            RETURN l_n;
        END;

        FUNCTION NUM_OF (p_path IN VARCHAR2) RETURN NUMBER IS
        BEGIN
            RETURN TO_NUMBER(JSON_VALUE(p_body, p_path));
        EXCEPTION
            WHEN OTHERS THEN RETURN -1;
        END;
    BEGIN
        APP_AUTH_PKG.AUTHENTICATE(p_auth, l_user, p_status, p_json);
        IF p_json IS NOT NULL THEN RETURN; END IF;
        SELECT MAX(EMPLOYEE_ID), MAX(USERNAME) INTO l_emp, l_username FROM APP_USERS_LOGIN_V2 WHERE USER_ID = l_user;
        IF l_emp IS NULL THEN
            ERR(403, 'NO_EMPLOYEE', 'هذا الحساب غير مرتبط بموظف', 'This account is not linked to an employee');
        END IF;
        SELECT COMPANY_ID, BRANCH_ID INTO l_company, l_branch FROM HR_EMPLOYEES WHERE EMPLOYEE_ID = l_emp;

        -- ----- the body
        IF p_body IS NULL OR DBMS_LOB.GETLENGTH(p_body) = 0 OR p_body IS NOT JSON THEN
            ERR(400, 'VALIDATION_ERROR', 'بيانات الطلب غير صحيحة', 'The request body is not valid JSON');
        END IF;
        l_type   := NUM_OF('$.typeId');
        l_start  := DATE_OF('$.startDate');
        l_end    := NVL(DATE_OF('$.endDate'), l_start);
        l_half   := NUM_OF('$.halfDayType');
        l_reason := TRIM(JSON_VALUE(p_body, '$.reason' RETURNING VARCHAR2(1000)));
        l_phone  := TRIM(JSON_VALUE(p_body, '$.emergencyPhone' RETURNING VARCHAR2(50)));
        IF l_type IS NULL OR l_type < 0 THEN
            ERR(400, 'VALIDATION_ERROR', 'نوع الإجازة مطلوب', 'typeId is required');
        END IF;
        IF l_start IS NULL OR l_start = DATE '0001-01-01' OR l_end = DATE '0001-01-01' THEN
            ERR(400, 'VALIDATION_ERROR', 'التاريخ غير صحيح (YYYY-MM-DD)', 'Invalid date (YYYY-MM-DD)');
        END IF;
        IF l_half IS NOT NULL AND l_half NOT IN (1, 2) THEN
            ERR(400, 'VALIDATION_ERROR', 'نوع نصف اليوم غير صحيح', 'Invalid halfDayType');
        END IF;

        -- ----- the type: active and allowed from the app
        BEGIN
            SELECT * INTO t FROM APP_LEAVE_TYPES_V2 WHERE LEAVE_TYPE_ID = l_type AND IS_MOBILE_APP = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                ERR(422, 'TYPE_NOT_ALLOWED', 'هذا النوع من الإجازات غير متاح من التطبيق', 'This leave type is not available in the app');
        END;

        IF l_end < l_start THEN
            ERR(422, 'DATE_ORDER', 'تاريخ النهاية قبل تاريخ البداية', 'The end date is before the start date');
        END IF;
        IF l_start < TRUNC(SYSDATE) THEN
            ERR(422, 'PAST_DATE', 'لا يمكن طلب إجازة بتاريخ سابق', 'A leave cannot start in the past');
        END IF;
        IF l_half IS NOT NULL THEN
            IF NVL(t.ALLOW_HALF_DAY, '0') <> '1' THEN
                ERR(422, 'HALF_DAY_NOT_ALLOWED', 'هذا النوع لا يسمح بنصف يوم', 'This type does not allow a half day');
            END IF;
            IF l_start <> l_end THEN
                ERR(422, 'HALF_DAY_ONE_DATE', 'نصف اليوم يكون ليوم واحد فقط', 'A half day is for one date only');
            END IF;
        END IF;
        IF NVL(t.ADVANCE_NOTICE_DAYS, 0) > 0 AND l_start - TRUNC(SYSDATE) < t.ADVANCE_NOTICE_DAYS THEN
            ERR(422, 'ADVANCE_NOTICE', 'يجب تقديم الطلب قبل ' || t.ADVANCE_NOTICE_DAYS || ' أيام على الأقل',
                'The request must be made at least ' || t.ADVANCE_NOTICE_DAYS || ' days ahead');
        END IF;
        IF (NVL(t.REQUIRES_REASON, '0') = '1' OR NVL(t.REQUIRES_DOCUMENT, '0') = '1') AND l_reason IS NULL THEN
            ERR(422, 'REASON_REQUIRED', 'سبب الإجازة مطلوب', 'A reason is required');
        END IF;

        -- ----- the days, exactly as the ERP leave page counts them
        SELECT WORK_SHIFT_TYPE_ID, SHIFT_GROUP_ID, WORK_SHIFT_ID, RELIGION
          INTO l_emp_type, l_group, l_shift, l_religion FROM HR_EMPLOYEES WHERE EMPLOYEE_ID = l_emp;
        l_ex_wk  := NVL(TO_NUMBER(t.EXCLUDE_WEEKENDS), 0);
        l_ex_hol := NVL(TO_NUMBER(t.EXCLUDE_HOLIDAYS), 0);
        l_total  := l_end - l_start + 1;
        l_cur    := l_start;
        WHILE l_cur <= l_end LOOP
            IF IS_HOLIDAY(l_cur) > 0 THEN
                l_holidays := l_holidays + 1;
            ELSIF IS_REST(l_cur) > 0 THEN
                l_rest := l_rest + 1;
            END IF;
            l_cur := l_cur + 1;
        END LOOP;
        SELECT COUNT(*) INTO l_comp FROM VW_SHIFT_COMPENSATORY_DAYS CD
         WHERE CD.WORK_SHIFT_ID = l_shift AND CD.COMP_DATE BETWEEN l_start AND l_end;
        l_working := l_total - (l_rest + l_holidays + l_comp);
        l_deduct  := CASE WHEN NVL(TO_NUMBER(t.DEDUCT_FROM_BALANCE), 1) = 0 THEN 0
                          ELSE l_total - CASE WHEN l_ex_wk = 1 THEN l_rest ELSE 0 END
                                       - CASE WHEN l_ex_hol = 1 THEN l_holidays ELSE 0 END - l_comp END;
        IF l_half IS NOT NULL AND l_total = 1 THEN
            l_total    := .5;
            l_working  := CASE WHEN l_working > 0 THEN .5 ELSE 0 END;
            l_rest     := CASE WHEN l_rest > 0 THEN .5 ELSE 0 END;
            l_holidays := CASE WHEN l_holidays > 0 THEN .5 ELSE 0 END;
            l_comp     := CASE WHEN l_comp > 0 THEN .5 ELSE 0 END;
            l_deduct   := CASE WHEN l_deduct > 0 THEN .5 ELSE 0 END;
        END IF;
        l_weekend := l_rest;
        IF l_working <= 0 THEN
            ERR(422, 'NO_WORKING_DAYS', 'الفترة المختارة كلها راحة أو إجازة رسمية', 'The chosen period is all rest days or holidays');
        END IF;

        -- the return date: the first day after the leave that is neither rest nor holiday
        l_return := l_end + 1;
        WHILE (IS_REST(l_return) > 0 OR IS_HOLIDAY(l_return) > 0) AND l_safety < 30 LOOP
            l_return := l_return + 1;
            l_safety := l_safety + 1;
        END LOOP;
        IF l_half IS NOT NULL THEN l_return := l_start; END IF;

        IF t.MIN_DAYS_PER_REQUEST IS NOT NULL AND l_working < t.MIN_DAYS_PER_REQUEST THEN
            ERR(422, 'MIN_DAYS', 'أقل مدة للطلب ' || t.MIN_DAYS_PER_REQUEST || ' يوم', 'The minimum is ' || t.MIN_DAYS_PER_REQUEST || ' day(s) per request');
        END IF;
        IF t.MAX_DAYS_PER_REQUEST IS NOT NULL AND l_working > t.MAX_DAYS_PER_REQUEST THEN
            ERR(422, 'MAX_DAYS', 'أقصى مدة للطلب ' || t.MAX_DAYS_PER_REQUEST || ' يوم', 'The maximum is ' || t.MAX_DAYS_PER_REQUEST || ' day(s) per request');
        END IF;
        IF t.MAX_DAYS_PER_YEAR IS NOT NULL THEN
            SELECT NVL(SUM(WORKING_DAYS), 0) INTO l_year_sum
              FROM HR_EMPLOYEE_LEAVE_REQUESTS
             WHERE EMPLOYEE_ID = l_emp AND LEAVE_TYPE_ID = l_type AND STATUS_ID IN (1, 2, 3, 4)
               AND EXTRACT(YEAR FROM START_DATE) = EXTRACT(YEAR FROM l_start);
            IF l_year_sum + l_working > t.MAX_DAYS_PER_YEAR THEN
                ERR(422, 'MAX_DAYS_YEAR', 'تجاوزت الحد السنوي لهذا النوع (' || t.MAX_DAYS_PER_YEAR || ' يوم)',
                    'You passed the yearly limit for this type (' || t.MAX_DAYS_PER_YEAR || ' days)');
            END IF;
        END IF;

        -- ----- no overlap with a live request of the same employee
        SELECT COUNT(*) INTO l_count FROM HR_EMPLOYEE_LEAVE_REQUESTS
         WHERE EMPLOYEE_ID = l_emp AND STATUS_ID IN (1, 2, 3, 4)
           AND START_DATE <= l_end AND END_DATE >= l_start;
        IF l_count > 0 THEN
            ERR(422, 'OVERLAP', 'لديك إجازة أخرى تتداخل مع هذه الفترة', 'You already have a leave that overlaps this period');
        END IF;

        -- ----- the balance (annual 3 and casual 24 are counted)
        IF l_type IN (3, 24) THEN
            l_before := HR_GET_LEAVE_REMAINING(l_emp, l_type, EXTRACT(YEAR FROM l_start));
            l_after  := l_before - l_deduct;
            IF l_deduct > 0 AND l_after < 0 AND NVL(t.CAN_EXCEED_BALANCE, '0') <> '1' THEN
                ERR(422, 'INSUFFICIENT_BALANCE', 'رصيدك لا يكفي (المتبقي ' || l_before || ' والمطلوب ' || l_deduct || ')',
                    'Not enough balance (' || l_before || ' left, ' || l_deduct || ' needed)');
            END IF;
        END IF;

        IF NOT p_create THEN
            SELECT JSON_OBJECT(
                       'typeId'     VALUE l_type,
                       'startDate'  VALUE TO_CHAR(l_start, 'YYYY-MM-DD'),
                       'endDate'    VALUE TO_CHAR(l_end, 'YYYY-MM-DD'),
                       'returnDate' VALUE TO_CHAR(l_return, 'YYYY-MM-DD'),
                       'isHalfDay'  VALUE CASE WHEN l_half IS NULL THEN 'false' ELSE 'true' END FORMAT JSON,
                       'days'       VALUE JSON_OBJECT('total' VALUE l_total, 'weekend' VALUE l_weekend, 'holidays' VALUE l_holidays,
                                                      'working' VALUE l_working, 'comp' VALUE l_comp, 'deducted' VALUE l_deduct),
                       'balance'    VALUE (CASE WHEN l_before IS NULL THEN NULL
                                           ELSE JSON_OBJECT('before' VALUE l_before, 'after' VALUE l_after) END) FORMAT JSON
                       RETURNING CLOB)
              INTO l_data FROM DUAL;
            p_status := 200;
            p_json   := APP_AUTH_PKG.OK_RESPONSE(l_data);
            RETURN;
        END IF;

        -- ----- create: the row, then its approval chain
        -- the balance figures of the ERP page, saved with the request (not shown by the app)
        BEGIN
            l_used    := HR_GET_LEAVE_BALANCE_USED(l_emp, l_type);
            l_remain  := HR_GET_LEAVE_REMAINING(l_emp, l_type);
            l_carried := HR_GET_CARRIED_FORWARD(l_emp);
            l_entitle := HR_GET_LEAVE_ENTITLEMENT(l_emp, l_type);
        EXCEPTION
            WHEN OTHERS THEN NULL;   -- a type without a counted balance
        END;

        SAVEPOINT before_leave;
        INSERT INTO HR_EMPLOYEE_LEAVE_REQUESTS
            (COMPANY_ID, BRANCH_ID, LEAVE_TYPE_ID, EMPLOYEE_ID, REQUEST_DATE, START_DATE, END_DATE, RETURN_DATE,
             TOTAL_LEAVE_DAYS, WEEKEND_DAYS, OFFICIAL_HOLIDAYS, WORKING_DAYS, EMPLOYEE_BALANCE, BALANCE_BEFORE, BALANCE_AFTER,
             DISCOUNTED_BALANCE, BALANCE_USED, ENTITLEMENT, START_BALANCE, LEAVE_REASON, EMERGENCY_PHONE, STATUS_ID, HALF_DAY_TYPE, IS_MOBILE_USER,
             CREATED_BY, CREATED_BY_USER_ID)
        VALUES
            (l_company, l_branch, l_type, l_emp, TRUNC(SYSDATE), l_start, l_end, l_return,
             l_total, l_weekend, l_holidays, l_working, NVL(l_remain, l_before), NVL(l_remain, l_before), NVL(l_before, l_remain) - l_deduct,
             l_deduct, l_used, l_entitle, l_carried, l_reason, l_phone, 1, l_half, 1,
             l_username, l_user)
        RETURNING ID INTO l_id;

        BEGIN
            HR_CREATE_LEAVE_STAGES_V2(l_id, l_user, l_username);
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK TO before_leave;
                IF SQLCODE BETWEEN -20999 AND -20000 THEN
                    ERR(422, 'LEAVE_REJECTED', REGEXP_REPLACE(SQLERRM, '^ORA-\d+: ?', ''), REGEXP_REPLACE(SQLERRM, '^ORA-\d+: ?', ''));
                END IF;
                RAISE;
        END;

        SELECT JSON_OBJECT('request' VALUE APP_LEAVE_PKG.REQUEST_JSON(l_id) FORMAT JSON RETURNING CLOB) INTO l_data FROM DUAL;
        p_status := 201;
        p_json   := APP_AUTH_PKG.OK_RESPONSE(l_data);
    EXCEPTION
        WHEN e_stop THEN NULL;   -- p_status / p_json already hold the answer
        WHEN OTHERS THEN
            IF SQLCODE BETWEEN -20999 AND -20000 THEN
                APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 422, 'LEAVE_REJECTED',
                    REGEXP_REPLACE(SQLERRM, '^ORA-\d+: ?', ''), REGEXP_REPLACE(SQLERRM, '^ORA-\d+: ?', ''));
            ELSE
                APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 500, 'SERVER_ERROR', 'تعذر تنفيذ الطلب', 'The request could not be completed');
            END IF;
    END;

    PROCEDURE PREVIEW (p_auth IN VARCHAR2, p_body IN CLOB, p_status OUT NUMBER, p_json OUT CLOB) IS
    BEGIN
        RUN(p_auth, p_body, FALSE, p_status, p_json);
    END;

    PROCEDURE CREATE_REQUEST (p_auth IN VARCHAR2, p_body IN CLOB, p_status OUT NUMBER, p_json OUT CLOB) IS
    BEGIN
        RUN(p_auth, p_body, TRUE, p_status, p_json);
    END;

END APP_LEAVE_NEW_PKG;
/

SHOW ERRORS
