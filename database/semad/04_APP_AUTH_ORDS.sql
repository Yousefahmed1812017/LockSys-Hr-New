-- Mobile auth API, step 4: ORDS module MobileAuth under the existing GSPLUS mapping.
-- Run with UTF-8 after 03_APP_AUTH_PKG.sql. Adds ONLY a new module; it does not call
-- ORDS.ENABLE_SCHEMA, so the schema alias and the existing modules stay as they are.
-- Base URL: https://<host>/ords/<schema alias>/mobile/auth/v1/
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

BEGIN
    BEGIN ORDS.DELETE_MODULE(p_module_name => 'MobileAuth'); EXCEPTION WHEN OTHERS THEN NULL; END;
    ORDS.DEFINE_MODULE(p_module_name => 'MobileAuth', p_base_path => '/mobile/auth/v1/', p_items_per_page => 0, p_status => 'PUBLISHED',
                       p_comments => 'Mobile app sign in: password, OTP, forgot password. Package APP_AUTH_PKG.');


    ORDS.DEFINE_TEMPLATE(p_module_name => 'MobileAuth', p_pattern => 'login/password');
    ORDS.DEFINE_HANDLER(p_module_name => 'MobileAuth', p_pattern => 'login/password', p_method => 'POST', p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source => q'[DECLARE
    l_s NUMBER;
    l_j CLOB;
BEGIN
    APP_AUTH_PKG.LOGIN_PASSWORD(:body_text, APP_AUTH_PKG.CLIENT_IP, l_s, l_j);
    :status_code := l_s;
    APP_AUTH_PKG.WRITE_RESPONSE(l_j);
END;]');

    ORDS.DEFINE_TEMPLATE(p_module_name => 'MobileAuth', p_pattern => 'login/otp/request');
    ORDS.DEFINE_HANDLER(p_module_name => 'MobileAuth', p_pattern => 'login/otp/request', p_method => 'POST', p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source => q'[DECLARE
    l_s NUMBER;
    l_j CLOB;
BEGIN
    APP_AUTH_PKG.OTP_REQUEST('LOGIN', :body_text, APP_AUTH_PKG.CLIENT_IP, l_s, l_j);
    :status_code := l_s;
    APP_AUTH_PKG.WRITE_RESPONSE(l_j);
END;]');

    ORDS.DEFINE_TEMPLATE(p_module_name => 'MobileAuth', p_pattern => 'login/otp/verify');
    ORDS.DEFINE_HANDLER(p_module_name => 'MobileAuth', p_pattern => 'login/otp/verify', p_method => 'POST', p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source => q'[DECLARE
    l_s NUMBER;
    l_j CLOB;
BEGIN
    APP_AUTH_PKG.OTP_VERIFY_LOGIN(:body_text, APP_AUTH_PKG.CLIENT_IP, l_s, l_j);
    :status_code := l_s;
    APP_AUTH_PKG.WRITE_RESPONSE(l_j);
END;]');

    ORDS.DEFINE_TEMPLATE(p_module_name => 'MobileAuth', p_pattern => 'password/forgot/request');
    ORDS.DEFINE_HANDLER(p_module_name => 'MobileAuth', p_pattern => 'password/forgot/request', p_method => 'POST', p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source => q'[DECLARE
    l_s NUMBER;
    l_j CLOB;
BEGIN
    APP_AUTH_PKG.OTP_REQUEST('RESET', :body_text, APP_AUTH_PKG.CLIENT_IP, l_s, l_j);
    :status_code := l_s;
    APP_AUTH_PKG.WRITE_RESPONSE(l_j);
END;]');

    ORDS.DEFINE_TEMPLATE(p_module_name => 'MobileAuth', p_pattern => 'password/forgot/verify');
    ORDS.DEFINE_HANDLER(p_module_name => 'MobileAuth', p_pattern => 'password/forgot/verify', p_method => 'POST', p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source => q'[DECLARE
    l_s NUMBER;
    l_j CLOB;
BEGIN
    APP_AUTH_PKG.OTP_VERIFY_RESET(:body_text, APP_AUTH_PKG.CLIENT_IP, l_s, l_j);
    :status_code := l_s;
    APP_AUTH_PKG.WRITE_RESPONSE(l_j);
END;]');

    ORDS.DEFINE_TEMPLATE(p_module_name => 'MobileAuth', p_pattern => 'password/reset');
    ORDS.DEFINE_HANDLER(p_module_name => 'MobileAuth', p_pattern => 'password/reset', p_method => 'POST', p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source => q'[DECLARE
    l_s NUMBER;
    l_j CLOB;
BEGIN
    APP_AUTH_PKG.PASSWORD_RESET(:body_text, APP_AUTH_PKG.CLIENT_IP, l_s, l_j);
    :status_code := l_s;
    APP_AUTH_PKG.WRITE_RESPONSE(l_j);
END;]');

    ORDS.DEFINE_TEMPLATE(p_module_name => 'MobileAuth', p_pattern => 'password/change');
    ORDS.DEFINE_HANDLER(p_module_name => 'MobileAuth', p_pattern => 'password/change', p_method => 'POST', p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source => q'[DECLARE
    l_s NUMBER;
    l_j CLOB;
BEGIN
    APP_AUTH_PKG.PASSWORD_CHANGE(:auth, :body_text, l_s, l_j);
    :status_code := l_s;
    APP_AUTH_PKG.WRITE_RESPONSE(l_j);
END;]');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileAuth', p_pattern => 'password/change', p_method => 'POST', p_name => 'Authorization',
        p_bind_variable_name => 'auth', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');

    ORDS.DEFINE_TEMPLATE(p_module_name => 'MobileAuth', p_pattern => 'logout');
    ORDS.DEFINE_HANDLER(p_module_name => 'MobileAuth', p_pattern => 'logout', p_method => 'POST', p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source => q'[DECLARE
    l_s NUMBER;
    l_j CLOB;
BEGIN
    APP_AUTH_PKG.LOGOUT(:auth, l_s, l_j);
    :status_code := l_s;
    APP_AUTH_PKG.WRITE_RESPONSE(l_j);
END;]');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileAuth', p_pattern => 'logout', p_method => 'POST', p_name => 'Authorization',
        p_bind_variable_name => 'auth', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');

    ORDS.DEFINE_TEMPLATE(p_module_name => 'MobileAuth', p_pattern => 'me');
    ORDS.DEFINE_HANDLER(p_module_name => 'MobileAuth', p_pattern => 'me', p_method => 'GET', p_source_type => ORDS.SOURCE_TYPE_PLSQL,
        p_source => q'[DECLARE
    l_s NUMBER;
    l_j CLOB;
BEGIN
    APP_AUTH_PKG.ME(:auth, l_s, l_j);
    :status_code := l_s;
    APP_AUTH_PKG.WRITE_RESPONSE(l_j);
END;]');
    ORDS.DEFINE_PARAMETER(p_module_name => 'MobileAuth', p_pattern => 'me', p_method => 'GET', p_name => 'Authorization',
        p_bind_variable_name => 'auth', p_source_type => 'HEADER', p_param_type => 'STRING', p_access_method => 'IN');

    COMMIT;
END;
/

SELECT 'MobileAuth ' || t.uri_template || ' ' || h.method AS endpoint
  FROM user_ords_templates t JOIN user_ords_handlers h ON h.template_id = t.id
  JOIN user_ords_modules m ON m.id = t.module_id WHERE m.name = 'MobileAuth' ORDER BY 1;
