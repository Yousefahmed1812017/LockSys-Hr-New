-- Mobile leave API, step 5: ORDS handlers to create a leave request. Run with UTF-8 after
-- 13_APP_LEAVE_CREATE_PKG.sql. Adds two POST handlers to the existing module MobileLeave
-- (/mobile/leave/v1/, template 'requests' comes from 07): POST requests (create) and POST requests/preview (days + rule check,
-- writes nothing). Body: JSON (see 13_APP_LEAVE_CREATE_PKG.sql). Authorization: Bearer <token>.
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

BEGIN
    ORDS.DEFINE_HANDLER(p_module_name => 'MobileLeave', p_pattern => 'requests', p_method => 'POST', p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source => q'[DECLARE
    l_s NUMBER;
    l_j CLOB;
BEGIN
    APP_LEAVE_NEW_PKG.CREATE_REQUEST(:auth, :body_text, l_s, l_j);
    :status_code := l_s;
    APP_AUTH_PKG.WRITE_RESPONSE(l_j);
END;]');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileLeave', p_pattern => 'requests', p_method => 'POST', p_name => 'Authorization',
        p_bind_variable_name => 'auth', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');

    ORDS.DEFINE_TEMPLATE(p_module_name => 'MobileLeave', p_pattern => 'requests/preview');
    ORDS.DEFINE_HANDLER(p_module_name => 'MobileLeave', p_pattern => 'requests/preview', p_method => 'POST', p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source => q'[DECLARE
    l_s NUMBER;
    l_j CLOB;
BEGIN
    APP_LEAVE_NEW_PKG.PREVIEW(:auth, :body_text, l_s, l_j);
    :status_code := l_s;
    APP_AUTH_PKG.WRITE_RESPONSE(l_j);
END;]');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileLeave', p_pattern => 'requests/preview', p_method => 'POST', p_name => 'Authorization',
        p_bind_variable_name => 'auth', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
    COMMIT;
END;
/

SELECT 'MobileLeave ' || t.uri_template || ' ' || h.method AS endpoint
  FROM user_ords_templates t JOIN user_ords_handlers h ON h.template_id = t.id
  JOIN user_ords_modules m ON m.id = t.module_id WHERE m.name = 'MobileLeave' ORDER BY 1;
