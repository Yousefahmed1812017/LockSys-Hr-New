-- Mobile leave API, step 3: ORDS module MobileLeave (read side). Run with UTF-8 after
-- 06_APP_LEAVE_PKG.sql. Adds ONLY a new module; ORDS.ENABLE_SCHEMA is not called, so the
-- schema alias and the existing modules stay as they are.
-- Base URL: https://<host>/ords/<schema alias>/mobile/leave/v1/   (Authorization: Bearer <token>)
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

BEGIN
    BEGIN ORDS.DELETE_MODULE(p_module_name => 'MobileLeave'); EXCEPTION WHEN OTHERS THEN NULL; END;
    ORDS.DEFINE_MODULE(p_module_name => 'MobileLeave', p_base_path => '/mobile/leave/v1/', p_items_per_page => 0, p_status => 'PUBLISHED',
                       p_comments => 'Mobile app: my leave requests, balances and leave types. Package APP_LEAVE_PKG.');


    ORDS.DEFINE_TEMPLATE(p_module_name => 'MobileLeave', p_pattern => 'requests');
    ORDS.DEFINE_HANDLER(p_module_name => 'MobileLeave', p_pattern => 'requests', p_method => 'GET', p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source => q'[DECLARE
    l_s NUMBER;
    l_j CLOB;
BEGIN
    APP_LEAVE_PKG.LIST_REQUESTS(:auth, :p_state, :p_year, :p_type_id, :p_limit, :p_offset, l_s, l_j);
    :status_code := l_s;
    APP_AUTH_PKG.WRITE_RESPONSE(l_j);
END;]');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileLeave', p_pattern => 'requests', p_method => 'GET', p_name => 'Authorization',
        p_bind_variable_name => 'auth', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileLeave', p_pattern => 'requests', p_method => 'GET', p_name => 'state',
        p_bind_variable_name => 'p_state', p_source_type => 'URI', p_param_type => 'STRING', p_access_method => 'IN');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileLeave', p_pattern => 'requests', p_method => 'GET', p_name => 'year',
        p_bind_variable_name => 'p_year', p_source_type => 'URI', p_param_type => 'STRING', p_access_method => 'IN');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileLeave', p_pattern => 'requests', p_method => 'GET', p_name => 'typeId',
        p_bind_variable_name => 'p_type_id', p_source_type => 'URI', p_param_type => 'STRING', p_access_method => 'IN');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileLeave', p_pattern => 'requests', p_method => 'GET', p_name => 'limit',
        p_bind_variable_name => 'p_limit', p_source_type => 'URI', p_param_type => 'STRING', p_access_method => 'IN');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileLeave', p_pattern => 'requests', p_method => 'GET', p_name => 'offset',
        p_bind_variable_name => 'p_offset', p_source_type => 'URI', p_param_type => 'STRING', p_access_method => 'IN');

    ORDS.DEFINE_TEMPLATE(p_module_name => 'MobileLeave', p_pattern => 'requests/:id');
    ORDS.DEFINE_HANDLER(p_module_name => 'MobileLeave', p_pattern => 'requests/:id', p_method => 'GET', p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source => q'[DECLARE
    l_s NUMBER;
    l_j CLOB;
BEGIN
    APP_LEAVE_PKG.GET_REQUEST(:auth, :id, l_s, l_j);
    :status_code := l_s;
    APP_AUTH_PKG.WRITE_RESPONSE(l_j);
END;]');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileLeave', p_pattern => 'requests/:id', p_method => 'GET', p_name => 'Authorization',
        p_bind_variable_name => 'auth', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');

    ORDS.DEFINE_TEMPLATE(p_module_name => 'MobileLeave', p_pattern => 'balances');
    ORDS.DEFINE_HANDLER(p_module_name => 'MobileLeave', p_pattern => 'balances', p_method => 'GET', p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source => q'[DECLARE
    l_s NUMBER;
    l_j CLOB;
BEGIN
    APP_LEAVE_PKG.BALANCES(:auth, :p_year, l_s, l_j);
    :status_code := l_s;
    APP_AUTH_PKG.WRITE_RESPONSE(l_j);
END;]');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileLeave', p_pattern => 'balances', p_method => 'GET', p_name => 'Authorization',
        p_bind_variable_name => 'auth', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileLeave', p_pattern => 'balances', p_method => 'GET', p_name => 'year',
        p_bind_variable_name => 'p_year', p_source_type => 'URI', p_param_type => 'STRING', p_access_method => 'IN');

    ORDS.DEFINE_TEMPLATE(p_module_name => 'MobileLeave', p_pattern => 'types');
    ORDS.DEFINE_HANDLER(p_module_name => 'MobileLeave', p_pattern => 'types', p_method => 'GET', p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source => q'[DECLARE
    l_s NUMBER;
    l_j CLOB;
BEGIN
    APP_LEAVE_PKG.TYPES(:auth, l_s, l_j);
    :status_code := l_s;
    APP_AUTH_PKG.WRITE_RESPONSE(l_j);
END;]');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileLeave', p_pattern => 'types', p_method => 'GET', p_name => 'Authorization',
        p_bind_variable_name => 'auth', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');

    COMMIT;
END;
/

SELECT 'MobileLeave ' || t.uri_template || ' ' || h.method AS endpoint
  FROM user_ords_templates t JOIN user_ords_handlers h ON h.template_id = t.id
  JOIN user_ords_modules m ON m.id = t.module_id WHERE m.name = 'MobileLeave' ORDER BY 1;
