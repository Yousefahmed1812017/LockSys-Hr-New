-- Mobile approvals API, step 1: package APP_APPROVAL_PKG (what is waiting for ME to approve
-- or reject, one request with its chain, and the decision). Run in the ERP schema (GSPLUS)
-- with UTF-8, after 06_APP_LEAVE_PKG.sql.
--
-- The chain is HR_LEAVE_REQUEST_STAGES (EMPLOYEE, SUBSTITUTE, DIRECT_MANAGER, DEPARTMENT_HEAD,
-- HR_MANAGER ...). A stage can be decided only by its approver, only while it is PENDING, and
-- only when no earlier stage of the request is still PENDING. The decision itself is made by
-- the ERP procedure HR_APPROVE_REJECT_STAGE_V2 (it moves the request to the next stage,
-- approves it when the chain is finished, or rejects it and the later stages) so the app and
-- the ERP always agree. That procedure commits.
--   tab = waiting : my stage is PENDING and it is my turn
--   tab = later   : my stage is PENDING but an earlier stage must decide first (who is shown)
--   tab = done    : stages I approved or rejected
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

CREATE OR REPLACE VIEW APP_APPROVAL_STAGES_V2 AS
SELECT
    S.ID                    AS STAGE_ROW_ID,
    S.LEAVE_REQUEST_ID      AS REQUEST_ID,
    S.LEAVE_TYPE_STAGE_ID   AS TYPE_STAGE_ID,
    S.EMPLOYEE_ID           AS APPROVER_ID,
    S.STAGE_ORDER,
    S.STATUS                AS STAGE_STATUS,
    S.STATUS_DATE           AS STAGE_DATE,
    S.NOTES                 AS STAGE_NOTES,
    A.CODE                  AS STAGE_CODE,
    A.NAME                  AS STAGE_NAME_EN,
    A.ARABIC_NAME           AS STAGE_NAME_AR,
    R.STATUS_ID             AS REQUEST_STATUS_ID,
    R.EMPLOYEE_ID           AS REQUESTER_ID,
    E.FULL_NAME_AR          AS REQUESTER_NAME_AR,
    E.FULL_NAME_EN          AS REQUESTER_NAME_EN,
    R.START_DATE,
    R.CREATED_DATE          AS REQUEST_CREATED,
    -- the earliest earlier stage that has not decided yet (NULL = it is this stage's turn)
    (SELECT MIN(P.STAGE_ORDER) FROM HR_LEAVE_REQUEST_STAGES P
      WHERE P.LEAVE_REQUEST_ID = S.LEAVE_REQUEST_ID AND P.STAGE_ORDER < S.STAGE_ORDER AND P.STATUS = 'PENDING')
                            AS BLOCKING_ORDER
FROM HR_LEAVE_REQUEST_STAGES S
JOIN HR_EMPLOYEE_LEAVE_REQUESTS R ON R.ID = S.LEAVE_REQUEST_ID
JOIN HR_LEAVE_APPROVAL_STAGES A   ON A.ID = S.STAGE_ID
JOIN HR_EMPLOYEES E               ON E.EMPLOYEE_ID = R.EMPLOYEE_ID;

CREATE OR REPLACE PACKAGE APP_APPROVAL_PKG AS
    -- p_tab: waiting | later | done
    PROCEDURE LIST_ITEMS (p_auth IN VARCHAR2, p_tab IN VARCHAR2, p_limit IN VARCHAR2, p_offset IN VARCHAR2,
                          p_status OUT NUMBER, p_json OUT CLOB);
    PROCEDURE GET_ITEM   (p_auth IN VARCHAR2, p_id IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB);
    -- p_action: APPROVED | REJECTED; body {"notes":"..."} (notes are required to reject)
    PROCEDURE DECIDE     (p_auth IN VARCHAR2, p_id IN VARCHAR2, p_action IN VARCHAR2, p_body IN CLOB,
                          p_status OUT NUMBER, p_json OUT CLOB);
    -- public only because SQL statements call it
    FUNCTION ITEM_JSON (p_stage_row_id IN NUMBER) RETURN CLOB;
END APP_APPROVAL_PKG;
/

CREATE OR REPLACE PACKAGE BODY APP_APPROVAL_PKG AS

    c_max_limit CONSTANT NUMBER := 100;

    FUNCTION TO_INT (p IN VARCHAR2) RETURN NUMBER IS
    BEGIN
        RETURN CASE WHEN p IS NULL THEN NULL ELSE TO_NUMBER(TRIM(p)) END;
    EXCEPTION
        WHEN VALUE_ERROR THEN RETURN -1;
    END;

    FUNCTION WHO (p_auth IN VARCHAR2, p_user OUT NUMBER, p_username OUT VARCHAR2, p_employee_id OUT NUMBER,
                  p_status OUT NUMBER, p_json OUT CLOB) RETURN BOOLEAN IS
    BEGIN
        APP_AUTH_PKG.AUTHENTICATE(p_auth, p_user, p_status, p_json);
        IF p_json IS NOT NULL THEN RETURN FALSE; END IF;
        SELECT MAX(EMPLOYEE_ID), MAX(USERNAME) INTO p_employee_id, p_username FROM APP_USERS_LOGIN_V2 WHERE USER_ID = p_user;
        IF p_employee_id IS NULL THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 403, 'NO_EMPLOYEE',
                'هذا الحساب غير مرتبط بموظف', 'This account is not linked to an employee');
            RETURN FALSE;
        END IF;
        RETURN TRUE;
    END;

    -- ===================================================================== one item
    -- my stage + the request + who asked + (when it is not my turn yet) who must decide first
    FUNCTION ITEM_JSON (p_stage_row_id IN NUMBER) RETURN CLOB IS
        l CLOB;
    BEGIN
        SELECT JSON_OBJECT(
            'requestId'  VALUE V.REQUEST_ID,
            'stage'      VALUE JSON_OBJECT('code' VALUE V.STAGE_CODE, 'nameAr' VALUE V.STAGE_NAME_AR, 'nameEn' VALUE V.STAGE_NAME_EN,
                                           'order' VALUE V.STAGE_ORDER, 'status' VALUE V.STAGE_STATUS,
                                           'date' VALUE TO_CHAR(V.STAGE_DATE, 'YYYY-MM-DD"T"HH24:MI:SS'), 'notes' VALUE V.STAGE_NOTES),
            'canDecide'  VALUE CASE WHEN V.STAGE_STATUS = 'PENDING' AND V.BLOCKING_ORDER IS NULL
                                     AND V.REQUEST_STATUS_ID IN (1, 2, 3) THEN 'true' ELSE 'false' END FORMAT JSON,
            'requester'  VALUE JSON_OBJECT('employeeId' VALUE V.REQUESTER_ID, 'nameAr' VALUE V.REQUESTER_NAME_AR, 'nameEn' VALUE V.REQUESTER_NAME_EN),
            'waitingFor' VALUE (CASE WHEN V.STAGE_STATUS = 'PENDING' AND V.BLOCKING_ORDER IS NOT NULL THEN
                                   (SELECT JSON_OBJECT('stageAr' VALUE A.ARABIC_NAME, 'stageEn' VALUE A.NAME,
                                                       'nameAr' VALUE E.FULL_NAME_AR, 'nameEn' VALUE E.FULL_NAME_EN)
                                      FROM HR_LEAVE_REQUEST_STAGES P
                                      JOIN HR_LEAVE_APPROVAL_STAGES A ON A.ID = P.STAGE_ID
                                      LEFT JOIN HR_EMPLOYEES E ON E.EMPLOYEE_ID = P.EMPLOYEE_ID
                                     WHERE P.LEAVE_REQUEST_ID = V.REQUEST_ID AND P.STAGE_ORDER = V.BLOCKING_ORDER
                                       AND ROWNUM = 1) END) FORMAT JSON,
            'request'    VALUE APP_LEAVE_PKG.REQUEST_JSON(V.REQUEST_ID) FORMAT JSON
            RETURNING CLOB)
          INTO l FROM APP_APPROVAL_STAGES_V2 V WHERE V.STAGE_ROW_ID = p_stage_row_id;
        RETURN l;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN NULL;
    END;

    -- ========================================================================== list
    PROCEDURE LIST_ITEMS (p_auth IN VARCHAR2, p_tab IN VARCHAR2, p_limit IN VARCHAR2, p_offset IN VARCHAR2,
                          p_status OUT NUMBER, p_json OUT CLOB) IS
        l_user   NUMBER;
        l_name   VARCHAR2(200);
        l_emp    NUMBER;
        l_tab    VARCHAR2(10) := LOWER(NVL(TRIM(p_tab), 'waiting'));
        l_limit  NUMBER := NVL(TO_INT(p_limit), 20);
        l_offset NUMBER := NVL(TO_INT(p_offset), 0);
        l_total  NUMBER;
        l_items  CLOB;
        l_data   CLOB;
    BEGIN
        IF NOT WHO(p_auth, l_user, l_name, l_emp, p_status, p_json) THEN RETURN; END IF;
        IF l_tab NOT IN ('waiting', 'later', 'done') OR l_limit < 1 OR l_offset < 0 THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 400, 'VALIDATION_ERROR',
                'قيمة غير صحيحة في المعاملات (tab, limit, offset)', 'Invalid query parameter (tab, limit, offset)');
            RETURN;
        END IF;
        l_limit := LEAST(l_limit, c_max_limit);

        SELECT COUNT(*) INTO l_total FROM APP_APPROVAL_STAGES_V2 V
         WHERE V.APPROVER_ID = l_emp
           AND ((l_tab = 'waiting' AND V.STAGE_STATUS = 'PENDING' AND V.BLOCKING_ORDER IS NULL AND V.REQUEST_STATUS_ID IN (1, 2, 3))
             OR (l_tab = 'later'   AND V.STAGE_STATUS = 'PENDING' AND V.BLOCKING_ORDER IS NOT NULL AND V.REQUEST_STATUS_ID IN (1, 2, 3))
             OR (l_tab = 'done'    AND V.STAGE_STATUS IN ('APPROVED', 'REJECTED') AND V.STAGE_CODE <> 'EMPLOYEE'));

        SELECT NVL(JSON_ARRAYAGG(APP_APPROVAL_PKG.ITEM_JSON(X.STAGE_ROW_ID) FORMAT JSON
                                 ORDER BY X.SORT_DATE DESC, X.STAGE_ROW_ID DESC RETURNING CLOB), '[]')
          INTO l_items
          FROM (SELECT V.STAGE_ROW_ID, CASE WHEN l_tab = 'done' THEN V.STAGE_DATE ELSE V.REQUEST_CREATED END AS SORT_DATE
                  FROM APP_APPROVAL_STAGES_V2 V
                 WHERE V.APPROVER_ID = l_emp
                   AND ((l_tab = 'waiting' AND V.STAGE_STATUS = 'PENDING' AND V.BLOCKING_ORDER IS NULL AND V.REQUEST_STATUS_ID IN (1, 2, 3))
                     OR (l_tab = 'later'   AND V.STAGE_STATUS = 'PENDING' AND V.BLOCKING_ORDER IS NOT NULL AND V.REQUEST_STATUS_ID IN (1, 2, 3))
                     OR (l_tab = 'done'    AND V.STAGE_STATUS IN ('APPROVED', 'REJECTED') AND V.STAGE_CODE <> 'EMPLOYEE'))
                 ORDER BY SORT_DATE DESC, V.STAGE_ROW_ID DESC
                OFFSET l_offset ROWS FETCH NEXT l_limit ROWS ONLY) X;

        SELECT JSON_OBJECT(
                   'items'   VALUE l_items FORMAT JSON,
                   'paging'  VALUE JSON_OBJECT('total' VALUE l_total, 'limit' VALUE l_limit, 'offset' VALUE l_offset,
                                               'hasMore' VALUE CASE WHEN l_offset + l_limit < l_total THEN 'true' ELSE 'false' END FORMAT JSON),
                   'summary' VALUE (SELECT JSON_OBJECT(
                                        'waiting' VALUE NVL(SUM(CASE WHEN V.STAGE_STATUS = 'PENDING' AND V.BLOCKING_ORDER IS NULL AND V.REQUEST_STATUS_ID IN (1, 2, 3) THEN 1 END), 0),
                                        'later'   VALUE NVL(SUM(CASE WHEN V.STAGE_STATUS = 'PENDING' AND V.BLOCKING_ORDER IS NOT NULL AND V.REQUEST_STATUS_ID IN (1, 2, 3) THEN 1 END), 0),
                                        'done'    VALUE NVL(SUM(CASE WHEN V.STAGE_STATUS IN ('APPROVED', 'REJECTED') AND V.STAGE_CODE <> 'EMPLOYEE' THEN 1 END), 0))
                                      FROM APP_APPROVAL_STAGES_V2 V WHERE V.APPROVER_ID = l_emp) FORMAT JSON
                   RETURNING CLOB)
          INTO l_data FROM DUAL;
        p_status := 200;
        p_json   := APP_AUTH_PKG.OK_RESPONSE(l_data);
    END;

    -- ======================================================================== detail
    -- One request I am in the chain of: my stage, the request and the whole chain.
    PROCEDURE GET_ITEM (p_auth IN VARCHAR2, p_id IN VARCHAR2, p_status OUT NUMBER, p_json OUT CLOB) IS
        l_user   NUMBER;
        l_name   VARCHAR2(200);
        l_emp    NUMBER;
        l_id     NUMBER := TO_INT(p_id);
        l_row    NUMBER;
        l_item   CLOB;
        l_stages CLOB;
        l_data   CLOB;
    BEGIN
        IF NOT WHO(p_auth, l_user, l_name, l_emp, p_status, p_json) THEN RETURN; END IF;
        -- the stage of mine that matters: the pending one, else the latest one
        SELECT MAX(STAGE_ROW_ID) KEEP (DENSE_RANK FIRST ORDER BY CASE WHEN STAGE_STATUS = 'PENDING' THEN 0 ELSE 1 END, STAGE_ORDER DESC)
          INTO l_row FROM APP_APPROVAL_STAGES_V2 WHERE REQUEST_ID = l_id AND APPROVER_ID = l_emp;
        IF l_id IS NULL OR l_id < 0 OR l_row IS NULL THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 404, 'REQUEST_NOT_FOUND', 'الطلب غير موجود', 'Request not found');
            RETURN;
        END IF;
        l_item := ITEM_JSON(l_row);

        SELECT NVL(JSON_ARRAYAGG(JSON_OBJECT(
                       'order'    VALUE S.STAGE_ORDER,
                       'code'     VALUE A.CODE,
                       'nameAr'   VALUE A.ARABIC_NAME,
                       'nameEn'   VALUE A.NAME,
                       'status'   VALUE S.STATUS,
                       'date'     VALUE TO_CHAR(S.STATUS_DATE, 'YYYY-MM-DD'),
                       'notes'    VALUE S.NOTES,
                       'isMe'     VALUE CASE WHEN S.EMPLOYEE_ID = l_emp THEN 'true' ELSE 'false' END FORMAT JSON,
                       'approver' VALUE (CASE WHEN E.EMPLOYEE_ID IS NULL THEN NULL
                                         ELSE JSON_OBJECT('nameAr' VALUE E.FULL_NAME_AR, 'nameEn' VALUE E.FULL_NAME_EN) END) FORMAT JSON)
                   ORDER BY S.STAGE_ORDER RETURNING CLOB), '[]')
          INTO l_stages
          FROM HR_LEAVE_REQUEST_STAGES S
          LEFT JOIN HR_LEAVE_APPROVAL_STAGES A ON A.ID = S.STAGE_ID
          LEFT JOIN HR_EMPLOYEES E ON E.EMPLOYEE_ID = S.EMPLOYEE_ID
         WHERE S.LEAVE_REQUEST_ID = l_id;

        SELECT JSON_OBJECT('item' VALUE l_item FORMAT JSON, 'approvalStages' VALUE l_stages FORMAT JSON RETURNING CLOB)
          INTO l_data FROM DUAL;
        p_status := 200;
        p_json   := APP_AUTH_PKG.OK_RESPONSE(l_data);
    END;

    -- ======================================================================= decision
    PROCEDURE DECIDE (p_auth IN VARCHAR2, p_id IN VARCHAR2, p_action IN VARCHAR2, p_body IN CLOB,
                      p_status OUT NUMBER, p_json OUT CLOB) IS
        l_user    NUMBER;
        l_name    VARCHAR2(200);
        l_emp     NUMBER;
        l_id      NUMBER := TO_INT(p_id);
        l_action  VARCHAR2(10) := UPPER(TRIM(p_action));
        l_notes   VARCHAR2(1000);
        l_row     NUMBER;
        l_lts     NUMBER;
        l_status  NUMBER;
        l_blocked NUMBER;
        l_block_n VARCHAR2(400);
        l_block_e VARCHAR2(400);
        l_result  VARCHAR2(20);
        l_msg     VARCHAR2(4000);
        l_item    CLOB;
        l_data    CLOB;
    BEGIN
        IF NOT WHO(p_auth, l_user, l_name, l_emp, p_status, p_json) THEN RETURN; END IF;
        IF l_action NOT IN ('APPROVED', 'REJECTED') THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 400, 'VALIDATION_ERROR', 'الإجراء غير صحيح', 'Invalid action');
            RETURN;
        END IF;
        IF p_body IS NOT NULL AND DBMS_LOB.GETLENGTH(p_body) > 0 THEN
            IF p_body IS NOT JSON THEN
                APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 400, 'VALIDATION_ERROR', 'بيانات الطلب غير صحيحة', 'The request body is not valid JSON');
                RETURN;
            END IF;
            l_notes := TRIM(JSON_VALUE(p_body, '$.notes' RETURNING VARCHAR2(1000)));
        END IF;
        IF l_action = 'REJECTED' AND l_notes IS NULL THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 422, 'NOTES_REQUIRED', 'اكتب سبب الرفض', 'A reason is required to reject');
            RETURN;
        END IF;

        -- my pending stage of this request (the lowest one when I have more than one)
        SELECT MAX(STAGE_ROW_ID) KEEP (DENSE_RANK FIRST ORDER BY STAGE_ORDER),
               MAX(TYPE_STAGE_ID) KEEP (DENSE_RANK FIRST ORDER BY STAGE_ORDER),
               MAX(REQUEST_STATUS_ID), MAX(BLOCKING_ORDER) KEEP (DENSE_RANK FIRST ORDER BY STAGE_ORDER)
          INTO l_row, l_lts, l_status, l_blocked
          FROM APP_APPROVAL_STAGES_V2 WHERE REQUEST_ID = l_id AND APPROVER_ID = l_emp AND STAGE_STATUS = 'PENDING';
        IF l_id IS NULL OR l_id < 0 OR l_row IS NULL THEN
            -- not in the chain / already decided answer alike
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 404, 'NOTHING_TO_DECIDE',
                'لا يوجد طلب بانتظار قرارك', 'There is nothing waiting for your decision on this request');
            RETURN;
        END IF;
        IF l_status NOT IN (1, 2, 3) THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 409, 'REQUEST_CLOSED',
                'الطلب لم يعد مفتوحًا (معتمد أو مرفوض أو ملغي)', 'The request is no longer open (approved, rejected or cancelled)');
            RETURN;
        END IF;
        IF l_blocked IS NOT NULL THEN
            SELECT MAX(E.FULL_NAME_AR), MAX(E.FULL_NAME_EN) INTO l_block_n, l_block_e
              FROM HR_LEAVE_REQUEST_STAGES P LEFT JOIN HR_EMPLOYEES E ON E.EMPLOYEE_ID = P.EMPLOYEE_ID
             WHERE P.LEAVE_REQUEST_ID = l_id AND P.STAGE_ORDER = l_blocked;
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 409, 'WAIT_PREVIOUS',
                'بانتظار قرار ' || NVL(l_block_n, 'المرحلة السابقة') || ' أولًا',
                'Waiting for ' || NVL(l_block_e, 'the previous stage') || ' to decide first');
            RETURN;
        END IF;

        HR_APPROVE_REJECT_STAGE_V2(l_id, l_lts, l_emp, l_action, l_notes, l_name, l_user, l_result, l_msg);
        IF l_result <> 'SUCCESS' THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 422, 'DECISION_FAILED', 'تعذر تسجيل القرار', NVL(l_msg, 'The decision could not be saved'));
            RETURN;
        END IF;

        l_item := ITEM_JSON(l_row);
        SELECT JSON_OBJECT('item' VALUE l_item FORMAT JSON,
                           'requestStatusId' VALUE (SELECT STATUS_ID FROM HR_EMPLOYEE_LEAVE_REQUESTS WHERE ID = l_id)
                           RETURNING CLOB) INTO l_data FROM DUAL;
        p_status := 200;
        p_json   := APP_AUTH_PKG.OK_RESPONSE(l_data);
    EXCEPTION
        WHEN OTHERS THEN
            APP_AUTH_PKG.FAIL_RESPONSE(p_status, p_json, 500, 'SERVER_ERROR', 'تعذر تنفيذ الطلب', 'The request could not be completed');
    END;

END APP_APPROVAL_PKG;
/

SHOW ERRORS
