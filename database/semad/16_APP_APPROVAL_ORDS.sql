-- Mobile approvals API, step 2: ORDS module MobileApprovals. Run with UTF-8 after
-- 15_APP_APPROVAL_PKG.sql. Adds ONLY a new module (ORDS.ENABLE_SCHEMA is not called).
-- Base URL: https://<host>/ords/<schema alias>/mobile/approvals/v1/   (Authorization: Bearer <token>)
--   GET  items?tab=waiting|later|done&limit=&offset=   what is waiting for me / later / done
--   GET  items/:id                                      my stage, the request and its chain
--   POST items/:id/approve                              body {"notes":"..."} (optional)
--   POST items/:id/reject                               body {"notes":"..."} (required)
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

BEGIN
    BEGIN ORDS.DELETE_MODULE(p_module_name => 'MobileApprovals'); EXCEPTION WHEN OTHERS THEN NULL; END;
    ORDS.DEFINE_MODULE(p_module_name => 'MobileApprovals', p_base_path => '/mobile/approvals/v1/', p_items_per_page => 0, p_status => 'PUBLISHED',
                       p_comments => 'Mobile app: leave requests waiting for my approval. Package APP_APPROVAL_PKG.');

    ORDS.DEFINE_TEMPLATE(p_module_name => 'MobileApprovals', p_pattern => 'items');
    ORDS.DEFINE_HANDLER(p_module_name => 'MobileApprovals', p_pattern => 'items', p_method => 'GET', p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source => q'[DECLARE
    l_s NUMBER;
    l_j CLOB;
BEGIN
    APP_APPROVAL_PKG.LIST_ITEMS(:auth, :p_tab, :p_limit, :p_offset, l_s, l_j);
    :status_code := l_s;
    APP_AUTH_PKG.WRITE_RESPONSE(l_j);
END;]');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileApprovals', p_pattern => 'items', p_method => 'GET', p_name => 'Authorization',
        p_bind_variable_name => 'auth', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileApprovals', p_pattern => 'items', p_method => 'GET', p_name => 'tab',
        p_bind_variable_name => 'p_tab', p_source_type => 'URI', p_param_type => 'STRING', p_access_method => 'IN');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileApprovals', p_pattern => 'items', p_method => 'GET', p_name => 'limit',
        p_bind_variable_name => 'p_limit', p_source_type => 'URI', p_param_type => 'STRING', p_access_method => 'IN');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileApprovals', p_pattern => 'items', p_method => 'GET', p_name => 'offset',
        p_bind_variable_name => 'p_offset', p_source_type => 'URI', p_param_type => 'STRING', p_access_method => 'IN');

    ORDS.DEFINE_TEMPLATE(p_module_name => 'MobileApprovals', p_pattern => 'items/:id');
    ORDS.DEFINE_HANDLER(p_module_name => 'MobileApprovals', p_pattern => 'items/:id', p_method => 'GET', p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source => q'[DECLARE
    l_s NUMBER;
    l_j CLOB;
BEGIN
    APP_APPROVAL_PKG.GET_ITEM(:auth, :id, l_s, l_j);
    :status_code := l_s;
    APP_AUTH_PKG.WRITE_RESPONSE(l_j);
END;]');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileApprovals', p_pattern => 'items/:id', p_method => 'GET', p_name => 'Authorization',
        p_bind_variable_name => 'auth', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');

    ORDS.DEFINE_TEMPLATE(p_module_name => 'MobileApprovals', p_pattern => 'items/:id/approve');
    ORDS.DEFINE_HANDLER(p_module_name => 'MobileApprovals', p_pattern => 'items/:id/approve', p_method => 'POST', p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source => q'[DECLARE
    l_s NUMBER;
    l_j CLOB;
BEGIN
    APP_APPROVAL_PKG.DECIDE(:auth, :id, 'APPROVED', :body_text, l_s, l_j);
    :status_code := l_s;
    APP_AUTH_PKG.WRITE_RESPONSE(l_j);
END;]');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileApprovals', p_pattern => 'items/:id/approve', p_method => 'POST', p_name => 'Authorization',
        p_bind_variable_name => 'auth', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');

    ORDS.DEFINE_TEMPLATE(p_module_name => 'MobileApprovals', p_pattern => 'items/:id/reject');
    ORDS.DEFINE_HANDLER(p_module_name => 'MobileApprovals', p_pattern => 'items/:id/reject', p_method => 'POST', p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source => q'[DECLARE
    l_s NUMBER;
    l_j CLOB;
BEGIN
    APP_APPROVAL_PKG.DECIDE(:auth, :id, 'REJECTED', :body_text, l_s, l_j);
    :status_code := l_s;
    APP_AUTH_PKG.WRITE_RESPONSE(l_j);
END;]');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileApprovals', p_pattern => 'items/:id/reject', p_method => 'POST', p_name => 'Authorization',
        p_bind_variable_name => 'auth', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');
    COMMIT;
END;
/

SELECT 'MobileApprovals ' || t.uri_template || ' ' || h.method AS endpoint
  FROM user_ords_templates t JOIN user_ords_handlers h ON h.template_id = t.id
  JOIN user_ords_modules m ON m.id = t.module_id WHERE m.name = 'MobileApprovals' ORDER BY 1;
