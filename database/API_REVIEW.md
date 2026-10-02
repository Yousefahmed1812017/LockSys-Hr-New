# Central directory API review

Reviewed on 2026-09-30 in `LOCKSYS_API`.

## Published endpoint

`GET https://erp.lock-sys.com/ords/locksys/app/v1/companies/{code}`

The published `app_v1` ORDS module invokes `GNL_APP_API_PKG.RESOLVE_COMPANY`.
The package and body compile successfully. Responses contain UTF-8 JSON.
Use `User-Agent: LockSysHR/1.0`: the site's Cloudflare configuration rejected
the default Python client signature with error 1010 before ORDS.

Verified over HTTPS: valid/lowercase company codes return 200; unknown company
404; inactive company 403; wrong or absent Basic credentials 401.
An oversized company code originally returned ORDS 555. The isolated migration
`GNL_APP_API_PKG_FIX_CODE.sql` validates its length after authentication and
returns the standard 404 envelope. It does not reset passwords or company data.

## Integration scope

`main.dart` now injects `ApiCompanyRegistry`. The client maps API `baseUrl` to
the saved model's `apiBaseUrl`, ignores unknown feature keys, checks HTTPS,
disables redirects for credential-bearing requests, and handles service failures,
inactive companies and maintenance. The mock remains available for unit tests.

Development configuration is in ignored `.local/api.json`, with string keys
`API_USER` and `API_PASSWORD`. Run:

```powershell
flutter run -d emulator-5554 --dart-define-from-file=.local/api.json
flutter test integration_test/company_api_flow_test.dart -d emulator-5554 --dart-define-from-file=.local/api.json
```

The integration test uses isolated preferences and the real directory API:
unknown company -> inactive company -> valid company -> save -> login screen.

## Remaining boundaries

- The company's downstream URLs are still the seeded example values. Their
  validity for employee services has not been established.
- Employee login is still a UI demo; there is no real employee session API in
  the reviewed module. Reaching the login screen does not verify authentication.
- Company features now come from the feature tree (`GNL_APP_FEATURES_TREE.sql`):
  `GNL_APP_FEATURES` (tree catalog) + `GNL_APP_COMPANY_FEATURES` (per-company
  grants); the endpoint returns the effective codes. `GNL_APP_COMPANIES.FEATURES`
  is deprecated and no longer read. Per-employee grants are not built yet, and an
  OTP channel switch only states what the company allows: no SMS/WhatsApp/e-mail
  gateway or OTP endpoint exists in this module.
- The mobile client currently consumes the company name, URL and feature keys;
  language policy and minimum app version are returned but not enforced.
- Shared Basic credentials identify the app, not the employee. Build defines
  keep them out of source but cannot make them secret inside a distributed app.
  Employee permissions must be enforced by authenticated backend endpoints.
- Password storage currently uses a single salted SHA-256 hash and API account
  uniqueness is case-sensitive while lookup is case-insensitive. These are
  production hardening items, not changed by this directory integration.
