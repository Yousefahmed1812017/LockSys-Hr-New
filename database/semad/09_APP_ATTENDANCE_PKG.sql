-- Mobile attendance API, step 1: package APP_ATTENDANCE_PKG. Run in the ERP schema
-- (GSPLUS) with UTF-8, after 03_APP_AUTH_PKG.sql and 08_HR_EMPLOYEES_APP_CHECKIN.sql.
-- New package only. TODAY reads; CHECK writes ONE row to HR_ATTENDANCE_LOG (like the
-- old Users/CheckInAndOut did, CHECK_METHOD = 'MOBILE'), with the server's own clock.
--
-- What the server decides (the phone only reports what it measured):
--   * who may check in, and how        HR_EMPLOYEES.APP_CHECKIN_BY_LOCATION / APP_CHECKIN_BY_FACE
--   * which sites the employee has      HR_EMPLOYEES.SITE_ID + HR_EMPLOYEE_SITES
--   * where inside a site               the employee's own LOCATION_ID when it belongs to the
--                                       site, otherwise every active location of the site
--   * IN or OUT, and the day's state    from today's rows of HR_ATTENDANCE_LOG:
--                                       none -> IN, one IN -> OUT, IN and OUT -> done ("you left")
--   * the time                          SYSDATE of the server, never the phone's
--   * coordinates are always required (also with the face check): they are stored with the row.
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

CREATE OR REPLACE PACKAGE APP_ATTENDANCE_PKG AS
    PROCEDURE TODAY (p_auth IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB);
    PROCEDURE CHECK_IN_OUT (p_auth IN VARCHAR2, p_body IN CLOB, p_ip IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB);
    -- One month of the employee, day by day (p_month = 'YYYY-MM', empty = this month).
    PROCEDURE MONTH_SUMMARY (p_auth IN VARCHAR2, p_month IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB);
    -- public only because SQL statements call it: text to number, NULL when it is not a number
    FUNCTION NUM (p IN VARCHAR2) RETURN NUMBER;
END APP_ATTENDANCE_PKG;
/

CREATE OR REPLACE PACKAGE BODY APP_ATTENDANCE_PKG AS

    c_active CONSTANT VARCHAR2(10) := '1';   -- HR_ATTENDANCE_LOG.STATUS of a live row (as the old API writes it)

    TYPE t_emp IS RECORD (
        employee_id NUMBER,
        user_id     NUMBER,
        username    VARCHAR2(200),
        site_id     NUMBER,
        location_id NUMBER,
        by_location NUMBER,
        by_face     NUMBER,
        company_id  NUMBER
    );

    -- Signed in AND an employee. FALSE = the answer is already in p_status / p_json.
    FUNCTION WHO (p_auth IN VARCHAR2, e OUT t_emp, p_status OUT NUMBER, p_json OUT CLOB) RETURN BOOLEAN IS
    BEGIN
        APP_AUTH_PKG.AUTHENTICATE(p_auth, e.user_id, p_status, p_json);
        IF p_json IS NOT NULL THEN RETURN FALSE; END IF;
        BEGIN
            SELECT U.EMPLOYEE_ID, U.USERNAME, H.SITE_ID, H.LOCATION_ID,
                   NVL(H.APP_CHECKIN_BY_LOCATION, 0), NVL(H.APP_CHECKIN_BY_FACE, 0), U.DEFAULT_COMPANY_ID
              INTO e.employee_id, e.username, e.site_id, e.location_id, e.by_location, e.by_face, e.company_id
              FROM APP_USERS_LOGIN_V2 U
              JOIN HR_EMPLOYEES H ON H.EMPLOYEE_ID = U.EMPLOYEE_ID
             WHERE U.USER_ID = e.user_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 403, 'NO_EMPLOYEE',
                    'هذا الحساب غير مرتبط بموظف', 'This account is not linked to an employee');
                RETURN FALSE;
        END;
        RETURN TRUE;
    END;

    FUNCTION NUM (p IN VARCHAR2) RETURN NUMBER IS
    BEGIN
        RETURN TO_NUMBER(p DEFAULT NULL ON CONVERSION ERROR, '999999.999999999999', 'NLS_NUMERIC_CHARACTERS=''.,''');
    END;

    -- Meters between two points (great circle).
    FUNCTION DISTANCE_M (lat1 IN NUMBER, lng1 IN NUMBER, lat2 IN NUMBER, lng2 IN NUMBER) RETURN NUMBER IS
        k CONSTANT NUMBER := 3.141592653589793 / 180;
    BEGIN
        RETURN 6371000 * ACOS(LEAST(1, GREATEST(-1,
                   SIN(lat1 * k) * SIN(lat2 * k) + COS(lat1 * k) * COS(lat2 * k) * COS((lng2 - lng1) * k))));
    END;

    -- Today's rows of the employee: has IN / has OUT, the times and the site of the IN.
    PROCEDURE DAY_STATE (p_employee_id IN NUMBER, p_has_in OUT BOOLEAN, p_has_out OUT BOOLEAN,
                         p_in_at OUT VARCHAR2, p_out_at OUT VARCHAR2, p_in_site OUT NUMBER) IS
        l_in  NUMBER;
        l_out NUMBER;
    BEGIN
        SELECT COUNT(CASE WHEN UPPER(CHECK_TYPE) = 'IN' THEN 1 END),
               COUNT(CASE WHEN UPPER(CHECK_TYPE) = 'OUT' THEN 1 END),
               MIN(CASE WHEN UPPER(CHECK_TYPE) = 'IN' THEN ACTUAL_TIME END),
               MAX(CASE WHEN UPPER(CHECK_TYPE) = 'OUT' THEN ACTUAL_TIME END),
               MIN(CASE WHEN UPPER(CHECK_TYPE) = 'IN' THEN SITES_ID END)
          INTO l_in, l_out, p_in_at, p_out_at, p_in_site
          FROM HR_ATTENDANCE_LOG
         WHERE EMPLOYEE_ID = p_employee_id
           AND ATTENDANCE_DATE >= TRUNC(SYSDATE) AND ATTENDANCE_DATE < TRUNC(SYSDATE) + 1
           AND STATUS IN (c_active, 'ACTIVE', 'CORRECTED');
        p_has_in  := l_in > 0;
        p_has_out := l_out > 0;
    END;

    FUNCTION HAS_SITE (p_employee_id IN NUMBER, p_home_site IN NUMBER, p_site_id IN NUMBER) RETURN BOOLEAN IS
        l NUMBER;
    BEGIN
        IF p_site_id IS NULL THEN RETURN FALSE; END IF;
        SELECT COUNT(*) INTO l
          FROM HR_SITES S
         WHERE S.ID = p_site_id AND S.STATUS = '1'
           AND (S.ID = p_home_site
                OR EXISTS (SELECT 1 FROM HR_EMPLOYEE_SITES ES
                            WHERE ES.EMPLOYEE_ID = p_employee_id AND ES.SITE_ID = S.ID AND ES.STATUS = '1'));
        RETURN l > 0;
    END;

    -- ================================================================================ today
    PROCEDURE TODAY (p_auth IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB) IS
        e        t_emp;
        l_in     BOOLEAN;
        l_out    BOOLEAN;
        l_in_at  VARCHAR2(10);
        l_out_at VARCHAR2(10);
        l_in_site NUMBER;
        l_state  VARCHAR2(10);
        l_sites  CLOB;
        l_msg    VARCHAR2(1000);
        l_data   CLOB;
    BEGIN
        IF NOT WHO(p_auth, e, p_status, p_json) THEN RETURN; END IF;
        DAY_STATE(e.employee_id, l_in, l_out, l_in_at, l_out_at, l_in_site);
        l_state := CASE WHEN l_out THEN 'DONE' WHEN l_in THEN 'IN' ELSE 'NONE' END;

        SELECT NVL(JSON_ARRAYAGG(JSON_OBJECT(
                   'id'       VALUE S.ID,
                   'code'     VALUE S.CODE,
                   'nameAr'   VALUE NVL(S.ARABIC_NAME, S.NAME),
                   'nameEn'   VALUE NVL(S.NAME, S.ARABIC_NAME),
                   'isHome'   VALUE CASE WHEN S.ID = e.site_id THEN 'true' ELSE 'false' END FORMAT JSON,
                   'action'   VALUE CASE l_state WHEN 'DONE' THEN 'DONE' WHEN 'IN' THEN 'OUT' ELSE 'IN' END,
                   'locations' VALUE (
                       SELECT NVL(JSON_ARRAYAGG(JSON_OBJECT(
                                  'id'           VALUE L.ID,
                                  'nameAr'       VALUE NVL(L.ARABIC_NAME, L.NAME),
                                  'nameEn'       VALUE NVL(L.NAME, L.ARABIC_NAME),
                                  'latitude'     VALUE APP_ATTENDANCE_PKG.NUM(L.LATITUDE),
                                  'longitude'    VALUE APP_ATTENDANCE_PKG.NUM(L.LONGITUDE),
                                  'zoneType'     VALUE L.ZONE_TYPE,
                                  'radiusMeters' VALUE L.ZONE_RADIUS,
                                  'bounds'       VALUE JSON_OBJECT(
                                                       'north' VALUE APP_ATTENDANCE_PKG.NUM(L.ZONE_LAT_NORTH),
                                                       'south' VALUE APP_ATTENDANCE_PKG.NUM(L.ZONE_LAT_SOUTH),
                                                       'east'  VALUE APP_ATTENDANCE_PKG.NUM(L.ZONE_LNG_EAST),
                                                       'west'  VALUE APP_ATTENDANCE_PKG.NUM(L.ZONE_LNG_WEST)),
                                  'isMine'       VALUE CASE WHEN L.ID = e.location_id THEN 'true' ELSE 'false' END FORMAT JSON)
                                  ORDER BY L.ID RETURNING CLOB), '[]')
                         FROM HR_SITE_LOCATIONS L
                        WHERE L.SITE_ID = S.ID AND L.STATUS = '1'
                          AND (e.location_id IS NULL OR L.ID = e.location_id
                               OR NOT EXISTS (SELECT 1 FROM HR_SITE_LOCATIONS M
                                               WHERE M.ID = e.location_id AND M.SITE_ID = S.ID AND M.STATUS = '1'))
                   ) FORMAT JSON)
                   ORDER BY CASE WHEN S.ID = e.site_id THEN 0 ELSE 1 END, S.ID RETURNING CLOB), '[]')
          INTO l_sites
          FROM HR_SITES S
         WHERE S.STATUS = '1'
           AND (S.ID = e.site_id
                OR EXISTS (SELECT 1 FROM HR_EMPLOYEE_SITES ES
                            WHERE ES.EMPLOYEE_ID = e.employee_id AND ES.SITE_ID = S.ID AND ES.STATUS = '1'));

        IF l_state = 'DONE' THEN
            l_msg := 'DONE';
        END IF;
        SELECT JSON_OBJECT(
                   'date'       VALUE TO_CHAR(SYSDATE, 'YYYY-MM-DD'),
                   'serverTime' VALUE TO_CHAR(SYSDATE, 'HH24:MI'),
                   'allowed'    VALUE CASE WHEN e.by_location = 1 OR e.by_face = 1 THEN 'true' ELSE 'false' END FORMAT JSON,
                   'methods'    VALUE JSON_OBJECT('location' VALUE CASE WHEN e.by_location = 1 THEN 'true' ELSE 'false' END FORMAT JSON,
                                                  'face' VALUE CASE WHEN e.by_face = 1 THEN 'true' ELSE 'false' END FORMAT JSON),
                   'state'      VALUE l_state,
                   'checkInAt'  VALUE l_in_at,
                   'checkOutAt' VALUE l_out_at,
                   'checkInSiteId' VALUE l_in_site,
                   'message'    VALUE (CASE WHEN l_state = 'DONE' THEN JSON_OBJECT(
                                       'ar' VALUE 'تم تسجيل انصرافك اليوم، أنت منصرف',
                                       'en' VALUE 'You already checked out today') END) FORMAT JSON,
                   'policy'     VALUE JSON_OBJECT('mockLocation' VALUE APP_ATT_MOCK_POLICY(e.company_id)),
                   'sites'      VALUE l_sites FORMAT JSON
                   RETURNING CLOB)
          INTO l_data FROM DUAL;
        p_status := 200;
        p_json   := APP_AUTH_PKG.OK_RESPONSE(l_data);
    END;

    -- ================================================================================ check
    PROCEDURE CHECK_IN_OUT (p_auth IN VARCHAR2, p_body IN CLOB, p_ip IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB) IS
        e          t_emp;
        l_site     NUMBER;
        l_type     VARCHAR2(10);
        l_lat      NUMBER;
        l_lng      NUMBER;
        l_acc      NUMBER;
        l_mock     NUMBER;
        l_face     NUMBER;
        l_has_in   BOOLEAN;
        l_has_out  BOOLEAN;
        l_in_at    VARCHAR2(10);
        l_out_at   VARCHAR2(10);
        l_in_site  NUMBER;
        l_expect   VARCHAR2(10);
        l_loc_id   NUMBER;
        l_nearest  NUMBER;
        l_d        NUMBER;
        l_inside   BOOLEAN;
        l_new_id   NUMBER;
        l_time     VARCHAR2(5) := TO_CHAR(SYSDATE, 'HH24:MI');
        l_data     CLOB;
        l_loc_name_ar VARCHAR2(250);
        l_loc_name_en VARCHAR2(250);
    BEGIN
        IF NOT WHO(p_auth, e, p_status, p_json) THEN RETURN; END IF;
        IF p_body IS NULL OR DBMS_LOB.GETLENGTH(p_body) = 0 OR NOT (p_body IS JSON) THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 400, 'VALIDATION_ERROR', 'تعذّر قراءة البيانات المرسلة', 'The request body is missing or is not valid JSON');
            RETURN;
        END IF;
        SELECT j.site_id, UPPER(TRIM(j.check_type)), APP_ATTENDANCE_PKG.NUM(j.latitude), APP_ATTENDANCE_PKG.NUM(j.longitude), APP_ATTENDANCE_PKG.NUM(j.accuracy),
               CASE WHEN j.is_mock = 'true' THEN 1 ELSE 0 END, CASE WHEN j.face = 'true' THEN 1 ELSE 0 END
          INTO l_site, l_type, l_lat, l_lng, l_acc, l_mock, l_face
          FROM JSON_TABLE(p_body, '$' COLUMNS (
                   site_id    NUMBER        PATH '$.siteId',
                   check_type VARCHAR2(10)  PATH '$.checkType',
                   latitude   VARCHAR2(40)  PATH '$.latitude',
                   longitude  VARCHAR2(40)  PATH '$.longitude',
                   accuracy   VARCHAR2(40)  PATH '$.accuracyMeters',
                   is_mock    VARCHAR2(10)  PATH '$.isMockLocation',
                   face       VARCHAR2(10)  PATH '$.faceVerified')) j;

        -- 1. may this employee check in from the app at all?
        IF e.by_location <> 1 AND e.by_face <> 1 THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 403, 'CHECKIN_NOT_ALLOWED',
                'التحضير من التطبيق غير مفعّل لك، تواصل مع الموارد البشرية', 'Check-in from the app is not enabled for you');
            RETURN;
        END IF;
        -- 2. a site of this employee
        IF l_site IS NULL THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 400, 'VALIDATION_ERROR', 'siteId مطلوب', 'siteId is required');
            RETURN;
        END IF;
        IF NOT HAS_SITE(e.employee_id, e.site_id, l_site) THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 403, 'SITE_NOT_ALLOWED', 'هذا الموقع غير مخصص لك', 'This site is not assigned to you');
            RETURN;
        END IF;
        -- 3. the day's state decides IN or OUT
        DAY_STATE(e.employee_id, l_has_in, l_has_out, l_in_at, l_out_at, l_in_site);
        IF l_has_out THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 409, 'ALREADY_LEFT',
                'تم تسجيل انصرافك اليوم، أنت منصرف', 'You already checked out today');
            RETURN;
        END IF;
        l_expect := CASE WHEN l_has_in THEN 'OUT' ELSE 'IN' END;
        IF l_type IS NOT NULL AND l_type NOT IN ('IN', 'OUT') THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 400, 'VALIDATION_ERROR', 'checkType يجب أن يكون IN أو OUT', 'checkType must be IN or OUT');
            RETURN;
        END IF;
        IF l_type = 'IN' AND l_has_in THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 409, 'ALREADY_CHECKED_IN',
                'سجّلت حضورك اليوم الساعة ' || l_in_at, 'You already checked in today at ' || l_in_at);
            RETURN;
        END IF;
        IF l_type = 'OUT' AND NOT l_has_in THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 400, 'NOT_CHECKED_IN', 'لم تسجّل حضورك اليوم', 'You have not checked in today');
            RETURN;
        END IF;
        l_type := l_expect;

        -- 4. coordinates are always needed, and must be real
        IF l_lat IS NULL OR l_lng IS NULL OR l_lat NOT BETWEEN -90 AND 90 OR l_lng NOT BETWEEN -180 AND 180 THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 400, 'LOCATION_REQUIRED', 'تعذّر تحديد موقعك', 'Your location is required');
            RETURN;
        END IF;
        -- a fake location: the company decides (APP_ATT_SETTINGS) to refuse it or to record it
        IF l_mock = 1 AND APP_ATT_MOCK_POLICY(e.company_id) <> 'RECORD' THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 403, 'MOCK_LOCATION', 'تم اكتشاف موقع وهمي', 'A fake location was detected');
            RETURN;
        END IF;
        -- 5. the face check, when this employee has it
        IF e.by_face = 1 AND l_face <> 1 THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 403, 'FACE_REQUIRED', 'التحقق من الوجه مطلوب', 'The face check is required');
            RETURN;
        END IF;

        -- 6. the work area: the employee's own location when it is in this site, else any location of the site
        FOR r IN (SELECT L.ID, L.NAME, L.ARABIC_NAME, L.ZONE_TYPE, L.ZONE_RADIUS,
                         APP_ATTENDANCE_PKG.NUM(L.LATITUDE) LAT, APP_ATTENDANCE_PKG.NUM(L.LONGITUDE) LNG,
                         APP_ATTENDANCE_PKG.NUM(L.ZONE_LAT_NORTH) N, APP_ATTENDANCE_PKG.NUM(L.ZONE_LAT_SOUTH) S, APP_ATTENDANCE_PKG.NUM(L.ZONE_LNG_EAST) E, APP_ATTENDANCE_PKG.NUM(L.ZONE_LNG_WEST) W
                    FROM HR_SITE_LOCATIONS L
                   WHERE L.SITE_ID = l_site AND L.STATUS = '1'
                     AND (e.location_id IS NULL OR L.ID = e.location_id
                          OR NOT EXISTS (SELECT 1 FROM HR_SITE_LOCATIONS M
                                          WHERE M.ID = e.location_id AND M.SITE_ID = l_site AND M.STATUS = '1'))
                   ORDER BY L.ID) LOOP
            l_inside := (r.ZONE_TYPE IN ('CIRCLE', 'BOTH') AND r.ZONE_RADIUS IS NOT NULL AND r.LAT IS NOT NULL AND r.LNG IS NOT NULL
                         AND DISTANCE_M(r.LAT, r.LNG, l_lat, l_lng) <= r.ZONE_RADIUS)
                     OR (r.ZONE_TYPE IN ('RECT', 'BOTH') AND r.N IS NOT NULL AND r.S IS NOT NULL AND r.E IS NOT NULL AND r.W IS NOT NULL
                         AND l_lat BETWEEN r.S AND r.N AND l_lng BETWEEN r.W AND r.E);
            IF l_inside THEN
                l_loc_id := r.ID; l_loc_name_ar := NVL(r.ARABIC_NAME, r.NAME); l_loc_name_en := NVL(r.NAME, r.ARABIC_NAME);
                EXIT;
            END IF;
            IF r.LAT IS NOT NULL AND r.LNG IS NOT NULL THEN
                l_d := DISTANCE_M(r.LAT, r.LNG, l_lat, l_lng);
                IF l_nearest IS NULL OR l_d < l_nearest THEN l_nearest := l_d; END IF;
            END IF;
        END LOOP;
        IF l_mock = 1 THEN
            l_loc_id := NULL;   -- RECORD: accepted without the area check, flagged for HR below
        ELSIF e.by_location = 1 AND l_loc_id IS NULL THEN
            SELECT JSON_OBJECT('success' VALUE 'false' FORMAT JSON,
                       'error' VALUE JSON_OBJECT(
                           'code' VALUE 'OUTSIDE_AREA',
                           'message_ar' VALUE 'أنت خارج منطقة العمل',
                           'message_en' VALUE 'You are outside your work area',
                           'distanceMeters' VALUE CASE WHEN l_nearest IS NULL THEN NULL ELSE ROUND(l_nearest) END ABSENT ON NULL)
                       RETURNING CLOB) INTO p_json FROM DUAL;
            p_status := 403;
            RETURN;
        END IF;

        -- 7. write the row, with the server's clock
        BEGIN
            INSERT INTO HR_ATTENDANCE_LOG (EMPLOYEE_ID, SITES_ID, LOCATION_ID, CHECK_TYPE, CHECK_METHOD, ATTENDANCE_DATE, ACTUAL_TIME,
                                           CHECK_DATETIME, LATITUDE, LONGITUDE, IS_FAKE, FAKE_LATITUDE, FAKE_LONGITUDE, MANUAL_USER_ID, STATUS, NOTES, CREATED_BY, CREATED_BY_USER_ID, CREATED_DATE)
            VALUES (e.employee_id, l_site, l_loc_id, l_type, 'MOBILE', TRUNC(SYSDATE), l_time,
                    SYSTIMESTAMP, ROUND(l_lat, 8), ROUND(l_lng, 8), l_mock,
                    CASE WHEN l_mock = 1 THEN TO_CHAR(ROUND(l_lat, 8)) END, CASE WHEN l_mock = 1 THEN TO_CHAR(ROUND(l_lng, 8)) END,
                    e.user_id, c_active,
                    SUBSTR('APP' || CASE WHEN l_mock = 1 THEN ' FAKE-LOCATION' END || CASE WHEN e.by_face = 1 THEN ' face' END || CASE WHEN e.by_location = 1 THEN ' location' END
                           || CASE WHEN l_acc IS NOT NULL THEN ' acc=' || ROUND(l_acc) || 'm' END
                           || CASE WHEN p_ip IS NOT NULL THEN ' ip=' || p_ip END, 1, 250),
                    e.username, e.user_id, SYSDATE)
            RETURNING ID INTO l_new_id;
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                IF SQLCODE BETWEEN -20999 AND -20000 THEN
                    APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 423, 'PERIOD_LOCKED',
                        'فترة الحضور مقفلة ولا يمكن التسجيل فيها', 'The attendance period is closed');
                    RETURN;
                END IF;
                RAISE;
        END;
        -- no COMMIT here: ORDS commits when the request ends well

        SELECT JSON_OBJECT(
                   'id'         VALUE l_new_id,
                   'checkType'  VALUE l_type,
                   'time'       VALUE l_time,
                   'date'       VALUE TO_CHAR(SYSDATE, 'YYYY-MM-DD'),
                   'siteId'     VALUE l_site,
                   'location'   VALUE (CASE WHEN l_loc_id IS NULL THEN NULL
                                        ELSE JSON_OBJECT('id' VALUE l_loc_id, 'nameAr' VALUE l_loc_name_ar, 'nameEn' VALUE l_loc_name_en) END) FORMAT JSON,
                   'isFakeLocation' VALUE CASE WHEN l_mock = 1 THEN 'true' ELSE 'false' END FORMAT JSON,
                   'state'      VALUE CASE l_type WHEN 'IN' THEN 'IN' ELSE 'DONE' END,
                   'checkInAt'  VALUE CASE l_type WHEN 'IN' THEN l_time ELSE l_in_at END,
                   'checkOutAt' VALUE CASE l_type WHEN 'OUT' THEN l_time END
                   ABSENT ON NULL RETURNING CLOB)
          INTO l_data FROM DUAL;
        p_status := 201;
        p_json   := APP_AUTH_PKG.OK_RESPONSE(l_data);
    END;

    -- ================================================================================ month
    -- What each day was, with the ERP's own rules (the same sources as the attendance
    -- reports):
    --   PRESENT   a check-in in HR_ATTENDANCE_LOG (VW_ATTENDANCE_LOG); onOffDay = it was a
    --             weekly rest day, an official holiday or a compensatory day (a star on screen)
    --   LEAVE     an approved leave request covers the day
    --   MISSION   an approved mission covers the day
    --   ABSENT    a registered absence (HR_ABSENCE_LOG), or nothing at all on a working day
    --   OFF       weekly rest (WEEKLY_OFF), official holiday (HOLIDAY), compensatory rest
    --             (COMP) or a part-time rest day (PART_TIME_OFF)
    --   TODAY     today, nothing yet      FUTURE   a day that has not come
    -- Fixed-shift employees only; rotating shifts (HR_SHIFT_SCHEDULE) answer supported=false.
    PROCEDURE MONTH_SUMMARY (p_auth IN VARCHAR2, p_month IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB) IS
        e         t_emp;
        l_from    DATE;
        l_to      DATE;
        l_cur     DATE := TRUNC(SYSDATE, 'MM');
        l_shift   NUMBER;
        l_rel     NUMBER;
        l_type    NUMBER;
        l_wk_ref  DATE;
        l_days    CLOB;
        l_sum     CLOB;
        l_data    CLOB;
    BEGIN
        IF NOT WHO(p_auth, e, p_status, p_json) THEN RETURN; END IF;
        BEGIN
            l_from := CASE WHEN TRIM(p_month) IS NULL THEN l_cur ELSE TO_DATE(TRIM(p_month) || '-01', 'YYYY-MM-DD') END;
        EXCEPTION
            WHEN OTHERS THEN
                APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 400, 'VALIDATION_ERROR', 'الشهر غير صحيح (YYYY-MM)', 'Invalid month (YYYY-MM)');
                RETURN;
        END;
        l_from := TRUNC(l_from, 'MM');
        IF l_from > l_cur OR l_from < ADD_MONTHS(l_cur, -36) THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 400, 'VALIDATION_ERROR', 'الشهر خارج المدى المتاح', 'The month is out of range');
            RETURN;
        END IF;
        l_to := LAST_DAY(l_from);

        SELECT H.WORK_SHIFT_ID, H.RELIGION, H.WORK_SHIFT_TYPE_ID
          INTO l_shift, l_rel, l_type
          FROM HR_EMPLOYEES H WHERE H.EMPLOYEE_ID = e.employee_id;
        SELECT MAX(TRUNC(WEEK_REF_DATE)) INTO l_wk_ref FROM SYSTEM_SETTINGS;

        IF NVL(l_type, 2) <> 2 THEN
            SELECT JSON_OBJECT('month' VALUE TO_CHAR(l_from, 'YYYY-MM'), 'supported' VALUE 'false' FORMAT JSON,
                       'message' VALUE JSON_OBJECT('ar' VALUE 'ملخص الشهر غير متاح لنظام المناوبات بعد',
                                                   'en' VALUE 'The month summary is not available for rotating shifts yet'),
                       'days' VALUE '[]' FORMAT JSON RETURNING CLOB)
              INTO l_data FROM DUAL;
            p_status := 200;
            p_json   := APP_AUTH_PKG.OK_RESPONSE(l_data);
            RETURN;
        END IF;

        WITH D AS (
            SELECT l_from + LEVEL - 1 AS DAY FROM DUAL CONNECT BY LEVEL <= l_to - l_from + 1
        ), S AS (
            SELECT D.DAY,
                   NVL((SELECT ESH.WORK_SHIFT_ID FROM HR_EMPLOYEE_SHIFT_HISTORY ESH
                         WHERE ESH.EMPLOYEE_ID = e.employee_id
                           AND D.DAY BETWEEN ESH.EFFECTIVE_DATE AND NVL(ESH.END_DATE, DATE '9999-12-31')
                         FETCH FIRST 1 ROW ONLY), l_shift) AS SHIFT_ID
              FROM D
        ), X AS (
            SELECT S.DAY, S.SHIFT_ID,
                   A.HAS_IN, A.HAS_OUT, A.CHECK_IN_TIME_D, A.CHECK_OUT_TIME_D, A.WORKING_HOURS, A.IS_OFF_DAY,
                   (SELECT 1 FROM DUAL WHERE EXISTS (
                        SELECT 1 FROM HR_WORK_SHIF_DAYS SD
                         WHERE SD.SHIFT_ID = S.SHIFT_ID AND SD.IS_OFF = 1
                           AND SD.DAY_ID = MOD(TRUNC(S.DAY) - l_wk_ref, 7) + 1)) AS WEEKLY_OFF,
                   (SELECT MAX(NVL(HT.ARABIC_NAME, HT.NAME)) KEEP (DENSE_RANK FIRST ORDER BY PH.ID)
                      FROM HR_OFFICIAL_HOLIDAYS PH LEFT JOIN HR_HOLIDAY_TYPES HT ON HT.ID = PH.HOLIDAY_TYPE_ID
                     WHERE PH.HOLIDAY_DATE = S.DAY AND PH.STATUS = 1
                       AND (PH.RELIGION_ID IS NULL OR PH.RELIGION_ID = l_rel)
                       AND (PH.SHIFT_ID IS NULL OR PH.SHIFT_ID = S.SHIFT_ID)) AS HOLIDAY_AR,
                   (SELECT MAX(NVL(HT.NAME, HT.ARABIC_NAME)) KEEP (DENSE_RANK FIRST ORDER BY PH.ID)
                      FROM HR_OFFICIAL_HOLIDAYS PH LEFT JOIN HR_HOLIDAY_TYPES HT ON HT.ID = PH.HOLIDAY_TYPE_ID
                     WHERE PH.HOLIDAY_DATE = S.DAY AND PH.STATUS = 1
                       AND (PH.RELIGION_ID IS NULL OR PH.RELIGION_ID = l_rel)
                       AND (PH.SHIFT_ID IS NULL OR PH.SHIFT_ID = S.SHIFT_ID)) AS HOLIDAY_EN,
                   (SELECT 1 FROM DUAL WHERE EXISTS (
                        SELECT 1 FROM VW_SHIFT_COMPENSATORY_DAYS CD
                         WHERE CD.WORK_SHIFT_ID = S.SHIFT_ID AND CD.COMP_DATE = S.DAY)) AS COMP_DAY,
                   (SELECT 1 FROM DUAL WHERE EXISTS (
                        SELECT 1 FROM HR_PART_TIME_CALENDAR PC JOIN HR_PART_TIME_REQUESTS PR ON PR.ID = PC.REQUEST_ID
                         WHERE PC.EMPLOYEE_ID = e.employee_id AND PC.CALENDAR_DATE = S.DAY
                           AND PR.STATUS_ID = 2 AND PC.DAY_TYPE = 'PART_TIME_OFF')) AS PART_TIME_OFF,
                   (SELECT MAX(LT.ARABIC_NAME) KEEP (DENSE_RANK FIRST ORDER BY LR.ID)
                      FROM HR_EMPLOYEE_LEAVE_REQUESTS LR JOIN HR_LEAVE_TYPES LT ON LT.ID = LR.LEAVE_TYPE_ID
                     WHERE LR.EMPLOYEE_ID = e.employee_id AND LR.STATUS_ID = 4
                       AND S.DAY BETWEEN TRUNC(LR.START_DATE) AND TRUNC(NVL(LR.ACTUAL_RETURN_DATE, LR.END_DATE))) AS LEAVE_AR,
                   (SELECT MAX(LT.NAME) KEEP (DENSE_RANK FIRST ORDER BY LR.ID)
                      FROM HR_EMPLOYEE_LEAVE_REQUESTS LR JOIN HR_LEAVE_TYPES LT ON LT.ID = LR.LEAVE_TYPE_ID
                     WHERE LR.EMPLOYEE_ID = e.employee_id AND LR.STATUS_ID = 4
                       AND S.DAY BETWEEN TRUNC(LR.START_DATE) AND TRUNC(NVL(LR.ACTUAL_RETURN_DATE, LR.END_DATE))) AS LEAVE_EN,
                   (SELECT MAX(NVL(MT.ARABIC_NAME, MT.NAME)) KEEP (DENSE_RANK FIRST ORDER BY M.ID)
                      FROM HR_EMPLOYEE_MISSIONS M LEFT JOIN HR_MISSION_TYPES MT ON MT.ID = M.MISSION_TYPE_ID
                     WHERE M.EMPLOYEE_ID = e.employee_id AND M.STATUS_ID = 4
                       AND S.DAY BETWEEN TRUNC(M.START_DATE) AND TRUNC(NVL(M.ACTUAL_RETURN_DATE, NVL(M.RETURN_DATE, M.END_DATE)))) AS MISSION_AR,
                   (SELECT MAX(NVL(MT.NAME, MT.ARABIC_NAME)) KEEP (DENSE_RANK FIRST ORDER BY M.ID)
                      FROM HR_EMPLOYEE_MISSIONS M LEFT JOIN HR_MISSION_TYPES MT ON MT.ID = M.MISSION_TYPE_ID
                     WHERE M.EMPLOYEE_ID = e.employee_id AND M.STATUS_ID = 4
                       AND S.DAY BETWEEN TRUNC(M.START_DATE) AND TRUNC(NVL(M.ACTUAL_RETURN_DATE, NVL(M.RETURN_DATE, M.END_DATE)))) AS MISSION_EN,
                   (SELECT 1 FROM DUAL WHERE EXISTS (
                        SELECT 1 FROM HR_ABSENCE_LOG AB
                         WHERE AB.EMPLOYEE_ID = e.employee_id AND AB.STATUS = '1'
                           AND S.DAY BETWEEN TRUNC(AB.ABSENCE_DATE) AND TRUNC(NVL(AB.END_DATE, AB.ABSENCE_DATE)))) AS ABSENCE_LOGGED
              FROM S
              LEFT JOIN (SELECT * FROM VW_ATTENDANCE_LOG
                          WHERE EMPLOYEE_ID = e.employee_id AND ATTENDANCE_DATE BETWEEN l_from AND l_to) A
                ON A.ATTENDANCE_DATE = S.DAY
        ), Y AS (
            SELECT X.*,
                   CASE
                       WHEN NVL(X.HAS_IN, 0) = 1 THEN 'PRESENT'
                       WHEN X.LEAVE_AR IS NOT NULL THEN 'LEAVE'
                       WHEN X.MISSION_AR IS NOT NULL THEN 'MISSION'
                       WHEN X.ABSENCE_LOGGED = 1 THEN 'ABSENT'
                       WHEN X.HOLIDAY_AR IS NOT NULL THEN 'OFF'
                       WHEN X.COMP_DAY = 1 OR X.PART_TIME_OFF = 1 OR X.WEEKLY_OFF = 1 THEN 'OFF'
                       WHEN X.DAY > TRUNC(SYSDATE) THEN 'FUTURE'
                       WHEN X.DAY = TRUNC(SYSDATE) THEN 'TODAY'
                       ELSE 'ABSENT'
                   END AS STATUS,
                   CASE
                       WHEN NVL(X.HAS_IN, 0) = 1 THEN NULL
                       WHEN X.LEAVE_AR IS NOT NULL THEN 'LEAVE'
                       WHEN X.MISSION_AR IS NOT NULL THEN 'MISSION'
                       WHEN X.ABSENCE_LOGGED = 1 THEN 'ABSENCE'
                       WHEN X.HOLIDAY_AR IS NOT NULL THEN 'HOLIDAY'
                       WHEN X.COMP_DAY = 1 THEN 'COMP'
                       WHEN X.PART_TIME_OFF = 1 THEN 'PART_TIME_OFF'
                       WHEN X.WEEKLY_OFF = 1 THEN 'WEEKLY_OFF'
                       ELSE NULL
                   END AS REASON
              FROM X
        )
        SELECT JSON_ARRAYAGG(JSON_OBJECT(
                   'date'        VALUE TO_CHAR(Y.DAY, 'YYYY-MM-DD'),
                   'status'      VALUE Y.STATUS,
                   'reason'      VALUE Y.REASON,
                   'workedOnOff' VALUE CASE WHEN Y.STATUS = 'PRESENT' AND (NVL(Y.IS_OFF_DAY, 0) = 1 OR Y.WEEKLY_OFF = 1 OR Y.HOLIDAY_AR IS NOT NULL OR Y.COMP_DAY = 1)
                                            THEN 'true' ELSE 'false' END FORMAT JSON,
                   'nameAr'      VALUE CASE Y.REASON WHEN 'LEAVE' THEN Y.LEAVE_AR WHEN 'MISSION' THEN Y.MISSION_AR WHEN 'HOLIDAY' THEN Y.HOLIDAY_AR
                                         ELSE CASE WHEN Y.STATUS = 'PRESENT' THEN Y.HOLIDAY_AR END END,
                   'nameEn'      VALUE CASE Y.REASON WHEN 'LEAVE' THEN Y.LEAVE_EN WHEN 'MISSION' THEN Y.MISSION_EN WHEN 'HOLIDAY' THEN Y.HOLIDAY_EN
                                         ELSE CASE WHEN Y.STATUS = 'PRESENT' THEN Y.HOLIDAY_EN END END,
                   'checkIn'     VALUE Y.CHECK_IN_TIME_D,
                   'checkOut'    VALUE CASE WHEN Y.HAS_OUT = 1 THEN Y.CHECK_OUT_TIME_D END,
                   'hours'       VALUE CASE WHEN Y.HAS_OUT = 1 THEN Y.WORKING_HOURS END
                   ABSENT ON NULL RETURNING CLOB) ORDER BY Y.DAY RETURNING CLOB),
               JSON_OBJECT(
                   'present'   VALUE NVL(SUM(CASE WHEN Y.STATUS = 'PRESENT' THEN 1 END), 0),
                   'absent'    VALUE NVL(SUM(CASE WHEN Y.STATUS = 'ABSENT' THEN 1 END), 0),
                   'off'       VALUE NVL(SUM(CASE WHEN Y.STATUS = 'OFF' THEN 1 END), 0),
                   'leave'     VALUE NVL(SUM(CASE WHEN Y.STATUS = 'LEAVE' THEN 1 END), 0),
                   'mission'   VALUE NVL(SUM(CASE WHEN Y.STATUS = 'MISSION' THEN 1 END), 0),
                   'workedOnOff' VALUE NVL(SUM(CASE WHEN Y.STATUS = 'PRESENT' AND (NVL(Y.IS_OFF_DAY, 0) = 1 OR Y.WEEKLY_OFF = 1 OR Y.HOLIDAY_AR IS NOT NULL OR Y.COMP_DAY = 1) THEN 1 END), 0),
                   'hours'     VALUE NVL(SUM(CASE WHEN Y.HAS_OUT = 1 THEN Y.WORKING_HOURS END), 0)
                   RETURNING CLOB)
          INTO l_days, l_sum
          FROM Y;

        SELECT JSON_OBJECT(
                   'month'     VALUE TO_CHAR(l_from, 'YYYY-MM'),
                   'supported' VALUE 'true' FORMAT JSON,
                   'prev'      VALUE CASE WHEN ADD_MONTHS(l_from, -1) >= ADD_MONTHS(l_cur, -36) THEN TO_CHAR(ADD_MONTHS(l_from, -1), 'YYYY-MM') END,
                   'next'      VALUE CASE WHEN l_from < l_cur THEN TO_CHAR(ADD_MONTHS(l_from, 1), 'YYYY-MM') END,
                   'summary'   VALUE l_sum FORMAT JSON,
                   'days'      VALUE NVL(l_days, '[]') FORMAT JSON
                   ABSENT ON NULL RETURNING CLOB)
          INTO l_data FROM DUAL;
        p_status := 200;
        p_json   := APP_AUTH_PKG.OK_RESPONSE(l_data);
    END;

END APP_ATTENDANCE_PKG;
/
