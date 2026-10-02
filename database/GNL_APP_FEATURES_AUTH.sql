-- Sign-in feature tree for the mobile app. Run as LOCKSYS_API using UTF-8, after
-- GNL_APP_FEATURES_TREE.sql. Re-runnable: insert-only, never touches grants.
--
--   auth                                  Sign in
--   |- auth.password                      Username + password
--   |- auth.phone                         Mobile number, one-time code (OTP)
--   |  |- auth.phone.via_sms                code sent by SMS
--   |  |- auth.phone.via_whatsapp           code sent by WhatsApp
--   |  '- auth.phone.via_email              code sent by e-mail
--   |- auth.email                         E-mail address, one-time code (OTP)
--   |  |- auth.email.via_sms / via_whatsapp / via_email
--   '- auth.forgot                        Forgot password (always ends in an OTP)
--      |- auth.forgot.email                 identify by e-mail
--      |  '- ...via_sms / via_whatsapp / via_email
--      '- auth.forgot.phone                 identify by mobile number
--         '- ...via_sms / via_whatsapp / via_email
--
-- A "via_*" row only states what the COMPANY allows. It works once the backend has
-- a gateway for that channel (SMS provider, WhatsApp Business, SMTP).
-- Give a company a feature with:
--   BEGIN GNL_APP_FEATURES_PKG.SET_ENABLED('1000', 'auth.phone.via_sms', 1); COMMIT; END;
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

BEGIN
    IF USER <> 'LOCKSYS_API' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Run this migration as LOCKSYS_API.');
    END IF;
END;
/

DECLARE
    PROCEDURE add_feature (p_code VARCHAR2, p_parent VARCHAR2, p_ar VARCHAR2, p_en VARCHAR2, p_order NUMBER) IS
    BEGIN
        INSERT INTO GNL_APP_FEATURES (CODE, PARENT_ID, ARABIC_NAME, NAME, DISPLAY_ORDER)
        SELECT p_code,
               (SELECT ID FROM GNL_APP_FEATURES WHERE CODE = p_parent),
               p_ar, p_en, p_order
          FROM DUAL
         WHERE NOT EXISTS (SELECT 1 FROM GNL_APP_FEATURES WHERE CODE = p_code);
    END;

    -- The same three delivery channels hang under every method that sends an OTP.
    PROCEDURE add_channels (p_parent VARCHAR2) IS
    BEGIN
        add_feature(p_parent || '.via_sms',      p_parent, 'إرسال الرمز برسالة SMS',             'Code by SMS',      10);
        add_feature(p_parent || '.via_whatsapp', p_parent, 'إرسال الرمز عبر واتساب',             'Code by WhatsApp', 20);
        add_feature(p_parent || '.via_email',    p_parent, 'إرسال الرمز عبر البريد الإلكتروني',  'Code by email',    30);
    END;
BEGIN
    add_feature('auth', NULL, 'تسجيل الدخول', 'Sign in', 10);

    add_feature('auth.password', 'auth', 'اسم المستخدم وكلمة المرور', 'Username and password', 10);

    add_feature('auth.phone', 'auth', 'الدخول برقم الموبايل (رمز تحقق)', 'Sign in with mobile number', 20);
    add_channels('auth.phone');

    add_feature('auth.email', 'auth', 'الدخول بالبريد الإلكتروني (رمز تحقق)', 'Sign in with email', 30);
    add_channels('auth.email');

    add_feature('auth.forgot', 'auth', 'نسيت كلمة المرور', 'Forgot password', 40);
    add_feature('auth.forgot.email', 'auth.forgot', 'الاسترجاع بالبريد الإلكتروني', 'Recover by email', 10);
    add_channels('auth.forgot.email');
    add_feature('auth.forgot.phone', 'auth.forgot', 'الاسترجاع برقم الموبايل', 'Recover by mobile number', 20);
    add_channels('auth.forgot.phone');
END;
/
COMMIT;
