-- HR_SHOW_LEAVE_BALANCES: prints the leave balances of one employee as HTML with HTP.P,
-- for an APEX region of type "PL/SQL Dynamic Content" (or any HTP page). Run in GSPLUS.
--
-- In the APEX region (source):
--     HR_SHOW_LEAVE_BALANCES(:P0_EMPLOYEE_ID);
--   or just  HR_SHOW_LEAVE_BALANCES;  (it then reads V('P0_EMPLOYEE_ID') itself)
--
-- The numbers are the ones of VW_EMPLOYEE_BALANCE for the current year (stored
-- entitlement and carried-forward, USED and REMAINING counted from the approved
-- requests): annual leave and casual leave. Arabic (RTL) or English follows V('P_LANG').
-- Everything printed is escaped. Only HTML and its own <style> are written, no JavaScript.
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

CREATE OR REPLACE PROCEDURE HR_SHOW_LEAVE_BALANCES (
    P_EMPLOYEE_ID IN NUMBER DEFAULT NULL
) IS
    l_emp      NUMBER;
    l_lang     VARCHAR2(10) := LOWER(NVL(V('P_LANG'), 'ar'));
    l_ar       BOOLEAN := l_lang = 'ar';
    l_year     NUMBER  := EXTRACT(YEAR FROM SYSDATE);
    l_name     VARCHAR2(400);
    l_code     VARCHAR2(100);
    b          VW_EMPLOYEE_BALANCE%ROWTYPE;

    FUNCTION T (p_ar IN VARCHAR2, p_en IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE WHEN l_ar THEN p_ar ELSE p_en END;
    END;

    -- 12.5 -> "12.5", 12 -> "12" (never "12,0" whatever the NLS settings are)
    FUNCTION N (p IN NUMBER) RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE WHEN p IS NULL THEN '-'
                    ELSE RTRIM(TRIM(TO_CHAR(p, 'FM999990.99', 'NLS_NUMERIC_CHARACTERS=''.,''')), '.') END;
    END;

    -- one card: title, the days left in a small tinted square, a bar, and three figures
    PROCEDURE CARD (p_title IN VARCHAR2, p_left IN NUMBER, p_total IN NUMBER,
                    p_l1 IN VARCHAR2, p_v1 IN NUMBER,
                    p_l2 IN VARCHAR2, p_v2 IN NUMBER,
                    p_l3 IN VARCHAR2, p_v3 IN NUMBER) IS
        l_pct NUMBER := CASE WHEN NVL(p_total, 0) <= 0 THEN 0
                             ELSE LEAST(100, GREATEST(0, ROUND(p_left / p_total * 100))) END;
        PROCEDURE FIGURE (p_label IN VARCHAR2, p_value IN NUMBER) IS
        BEGIN
            IF p_label IS NULL THEN RETURN; END IF;
            HTP.P('<div class="lb-fig"><b>' || N(p_value) || '</b><span>' || APEX_ESCAPE.HTML(p_label) || '</span></div>');
        END;
    BEGIN
        HTP.P('<div class="lb-card">');
        HTP.P('  <div class="lb-top">');
        HTP.P('    <div class="lb-title">' || APEX_ESCAPE.HTML(p_title) || '</div>');
        HTP.P('    <div class="lb-left"><b>' || N(p_left) || '</b><span>' || APEX_ESCAPE.HTML(T('يوم متبقي', 'days left')) || '</span></div>');
        HTP.P('  </div>');
        HTP.P('  <div class="lb-bar"><i style="width:' || l_pct || '%"></i></div>');
        HTP.P('  <div class="lb-figs">');
        FIGURE(p_l1, p_v1);
        FIGURE(p_l2, p_v2);
        FIGURE(p_l3, p_v3);
        HTP.P('  </div>');
        HTP.P('</div>');
    END;
BEGIN
    l_emp := P_EMPLOYEE_ID;
    IF l_emp IS NULL THEN
        BEGIN
            l_emp := TO_NUMBER(V('P0_EMPLOYEE_ID'));
        EXCEPTION
            WHEN OTHERS THEN l_emp := NULL;
        END;
    END IF;

    HTP.P('<style>'
       || '.lb{font-family:inherit;max-width:760px;margin:0 auto}'
       || '.lb-head{display:flex;align-items:baseline;gap:10px;flex-wrap:wrap;margin:0 0 12px}'
       || '.lb-head h3{margin:0;font-size:18px;color:#071F3D}.lb-head span{color:#536477;font-size:13px}'
       || '.lb-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:12px}'
       || '.lb-card{background:#fff;border:1px solid #DCE7F3;border-radius:8px;padding:16px;box-shadow:0 1px 2px rgba(7,31,61,.06)}'
       || '.lb-top{display:flex;align-items:center;justify-content:space-between;gap:12px}'
       || '.lb-title{font-size:20px;font-weight:700;color:#071F3D;line-height:1.3}'
       || '.lb-left{background:#EAF4FF;border:1px solid #BFD3EA;border-radius:8px;padding:6px 12px;text-align:center;min-width:64px}'
       || '.lb-left b{display:block;font-size:18px;color:#126BFF;line-height:1.2}'
       || '.lb-left span{display:block;font-size:11px;color:#536477}'
       || '.lb-bar{height:6px;background:#EAF4FF;border-radius:3px;margin:14px 0 12px;overflow:hidden}'
       || '.lb-bar i{display:block;height:100%;background:#168BFF;border-radius:3px}'
       || '.lb-figs{display:flex;justify-content:space-around;gap:8px;text-align:center}'
       || '.lb-fig{flex:1}.lb-fig b{display:block;font-size:15px;color:#071F3D}'
       || '.lb-fig span{display:block;font-size:12px;color:#536477}'
       || '.lb-empty{background:#F5FAFF;border:1px solid #DCE7F3;border-radius:8px;padding:16px;color:#536477;text-align:center}'
       || '</style>');
    HTP.P('<div class="lb" dir="' || CASE WHEN l_ar THEN 'rtl' ELSE 'ltr' END || '">');

    IF l_emp IS NULL THEN
        HTP.P('<div class="lb-empty">' || APEX_ESCAPE.HTML(T('اختر موظفًا لعرض أرصدته', 'Choose an employee to see the balances')) || '</div></div>');
        RETURN;
    END IF;

    BEGIN
        SELECT CASE WHEN l_lang = 'ar' THEN NVL(FULL_NAME_AR, FULL_NAME_EN) ELSE NVL(FULL_NAME_EN, FULL_NAME_AR) END, CODE
          INTO l_name, l_code
          FROM HR_EMPLOYEES WHERE EMPLOYEE_ID = l_emp;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            HTP.P('<div class="lb-empty">' || APEX_ESCAPE.HTML(T('الموظف غير موجود', 'Employee not found')) || '</div></div>');
            RETURN;
    END;
    HTP.P('<div class="lb-head"><h3>' || APEX_ESCAPE.HTML(TRIM(l_name)) || '</h3><span>'
          || APEX_ESCAPE.HTML(T('الرقم ', 'No. ') || l_code || ' · ' || T('أرصدة ', 'Balances ') || l_year) || '</span></div>');

    BEGIN
        SELECT * INTO b FROM VW_EMPLOYEE_BALANCE WHERE EMPLOYEE_ID = l_emp AND BALANCE_YEAR = l_year AND ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            HTP.P('<div class="lb-empty">' || APEX_ESCAPE.HTML(T('لا يوجد رصيد مسجّل لهذه السنة', 'No balance is recorded for this year')) || '</div></div>');
            RETURN;
    END;

    HTP.P('<div class="lb-grid">');
    CARD(T('الإجازة السنوية', 'Annual leave'), b.ANNUAL_REMAINING, b.TOTAL_AVAILABLE,
         T('المرحّل', 'Carried forward'), b.CARRIED_FORWARD,
         T('الاستحقاق', 'Entitlement'), b.ANNUAL_ENTITLEMENT,
         T('المستخدم', 'Used'), b.ANNUAL_USED);
    CARD(T('الإجازة العارضة', 'Casual leave'), b.CASUAL_REMAINING, b.CASUAL_ENTITLEMENT,
         T('الاستحقاق', 'Entitlement'), b.CASUAL_ENTITLEMENT,
         T('المستخدم', 'Used'), b.CASUAL_USED,
         NULL, NULL);
    HTP.P('</div></div>');
END HR_SHOW_LEAVE_BALANCES;
/
