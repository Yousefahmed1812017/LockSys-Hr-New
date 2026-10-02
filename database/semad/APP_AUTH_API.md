# Mobile Auth API (Semad)

Base: `https://semaderp.locksys.co/ords/locksysapp/mobile/auth/v1/` (module `MobileAuth`).
Run order: `01_APP_AUTH_TABLES.sql`, `02_APP_USERS_LOGIN_V2.sql`, `03_APP_AUTH_PKG.sql`, `04_APP_AUTH_ORDS.sql`.
Nothing existing is modified (old view `APP_USERS_LOGIN` and module `Users` untouched).

| Method | Path | Auth | Body |
|---|---|---|---|
| POST | login/password | - | username, password, deviceUuid |
| POST | login/otp/request | - | identifierType (phone/email), identifier, channel (sms/whatsapp/email) |
| POST | login/otp/verify | - | otpId, code, deviceUuid |
| POST | password/forgot/request | - | same as login/otp/request |
| POST | password/forgot/verify | - | otpId, code -> resetToken |
| POST | password/reset | - | resetToken, newPassword |
| POST | password/change | Bearer | oldPassword, newPassword |
| GET | me | Bearer | - |
| POST | logout | Bearer | - |

Envelope: `{success:true,data}` or `{success:false,error:{code,message_ar,message_en,retryAfterSeconds?,attemptsLeft?}}`.

## OTP delivery (temporary)
Config `APP_AUTH_CONFIG`: `OTP_DELIVERY=LOG_ONLY` (nothing is sent) and `EXPOSE_DEV_OTP=1` (the request response carries `devCode` so the app can show it).
To go live: `OTP_DELIVERY=LIVE`, `EXPOSE_DEV_OTP=0`. SMS uses `GNL_SMS_PKG`, e-mail uses `PKG_SEND_MAIL` (`GMAIL_MAIN`); WhatsApp returns `CHANNEL_NOT_AVAILABLE` until wired (`WHATSAPP_ENABLED`).
An unknown/shared/ineligible phone or e-mail gets an identical response (no `devCode`) so accounts cannot be enumerated.

## Decisions / caveats
- Tokens are random 64-hex values, stored only as salted SHA-256 (`APP_AUTH_SESSIONS`), 30 days (`SESSION_DAYS`).
- Lockout: 5 wrong passwords per user / 30 per IP -> 15 min (`APP_AUTH_ATTEMPTS`). OTP: 6 digits, 5 min, 5 tries, 60 s resend, 5 per hour.
- Allowed: user type EMPLOYEE, employment status 1 and 4, `IS_MOBILE_APP=1`, not locked. Device bound on first sign in (as the old API).
- `SEC_USERS.PASSWORD` is still plaintext (6-20 chars); `DBMS_CRYPTO` is not granted. Ask a DBA for it to hash passwords later.
- Reset/change revokes other sessions.
