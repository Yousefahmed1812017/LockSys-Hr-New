-- Mobile attendance API, step 2: ORDS module MobileAttendance. Run with UTF-8 after
-- 09_APP_ATTENDANCE_PKG.sql. Adds ONLY a new module; ORDS.ENABLE_SCHEMA is not called.
-- Base URL: https://<host>/ords/<schema alias>/mobile/attendance/v1/   (Authorization: Bearer <token>)
--   GET  today   the employee's sites with their work areas, and today's state (none / in / done)
--   POST check   check in or out at a site (the server decides IN or OUT and the time)
--   GET  month   one month day by day (?month=YYYY-MM): present / absent / off / leave / mission
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

BEGIN
    BEGIN ORDS.DELETE_MODULE(p_module_name => 'MobileAttendance'); EXCEPTION WHEN OTHERS THEN NULL; END;
    ORDS.DEFINE_MODULE(p_module_name => 'MobileAttendance', p_base_path => '/mobile/attendance/v1/', p_items_per_page => 0, p_status => 'PUBLISHED',
                       p_comments => 'Mobile app attendance: sites, work areas, check in / out. Package APP_ATTENDANCE_PKG.');

    ORDS.DEFINE_TEMPLATE(p_module_name => 'MobileAttendance', p_pattern => 'today');
    ORDS.DEFINE_HANDLER(p_module_name => 'MobileAttendance', p_pattern => 'today', p_method => 'GET', p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source => q'[DECLARE
    l_s NUMBER;
    l_j CLOB;
BEGIN
    APP_ATTENDANCE_PKG.TODAY(:auth, l_s, l_j);
    :status_code := l_s;
    APP_AUTH_PKG.WRITE_RESPONSE(l_j);
END;]');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileAttendance', p_pattern => 'today', p_method => 'GET', p_name => 'Authorization',
        p_bind_variable_name => 'auth', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');

    ORDS.DEFINE_TEMPLATE(p_module_name => 'MobileAttendance', p_pattern => 'check');
    ORDS.DEFINE_HANDLER(p_module_name => 'MobileAttendance', p_pattern => 'check', p_method => 'POST', p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source => q'[DECLARE
    l_s NUMBER;
    l_j CLOB;
BEGIN
    APP_ATTENDANCE_PKG.CHECK_IN_OUT(:auth, :body_text, APP_AUTH_PKG.CLIENT_IP, l_s, l_j);
    :status_code := l_s;
    APP_AUTH_PKG.WRITE_RESPONSE(l_j);
END;]');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileAttendance', p_pattern => 'check', p_method => 'POST', p_name => 'Authorization',
        p_bind_variable_name => 'auth', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');

    ORDS.DEFINE_TEMPLATE(p_module_name => 'MobileAttendance', p_pattern => 'month');
    ORDS.DEFINE_HANDLER(p_module_name => 'MobileAttendance', p_pattern => 'month', p_method => 'GET', p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source => q'[DECLARE
    l_s NUMBER;
    l_j CLOB;
BEGIN
    APP_ATTENDANCE_PKG.MONTH_SUMMARY(:auth, :p_month, l_s, l_j);
    :status_code := l_s;
    APP_AUTH_PKG.WRITE_RESPONSE(l_j);
END;]');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileAttendance', p_pattern => 'month', p_method => 'GET', p_name => 'Authorization',
        p_bind_variable_name => 'auth', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileAttendance', p_pattern => 'month', p_method => 'GET', p_name => 'month',
        p_bind_variable_name => 'p_month', p_source_type => 'URI', p_param_type => 'STRING', p_access_method => 'IN');
    COMMIT;
END;
/

SELECT 'MobileAttendance ' || t.uri_template || ' ' || h.method AS endpoint
  FROM user_ords_templates t JOIN user_ords_handlers h ON h.template_id = t.id
  JOIN user_ords_modules m ON m.id = t.module_id WHERE m.name = 'MobileAttendance' ORDER BY 1;
