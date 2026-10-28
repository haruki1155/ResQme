# Tier 1 requirements matrix

Status as of 2026-10-25, based on source inspection of this workspace and the supplied master plan. “Missing” means no implementation evidence in this copy; “Blocked” identifies a required external decision or approval. The product scope PDF was not supplied for independent comparison.

| Area | Status | Repository evidence / required next slice |
| --- | --- | --- |
| Flutter shell, navigation, state | Partial | `lib/main.dart` has only the template counter screen and local state. Replace its home only when the first public emergency flow is ready. |
| Supported mobile targets | Blocked | Android/iOS runners exist, but neither has feature permissions or device validation. Confirm Android/iOS target. |
| Firebase dev isolation and emulators | Missing | No Firebase config or dependencies. First M1 slice. |
| Student/admin authentication and trusted roles | Missing | No auth or backend. Role provisioning policy required. |
| Firestore deny-by-default rules and tests | Missing | No rules or rules tests. First M1 slice. |
| Consent-backed enrollment and ownership | Blocked | No model/UI/backend. School identity and consent policy required before real data. |
| QR issuance, printable output, secure token | Missing | No QR packages, credential model, or issuer. Must be backend issued and contain no PII. |
| Online QR status, scanner, safe landing | Missing | No camera, parser, resolver, or emergency dashboard. |
| Public hotline directory and calling | Blocked | No directory or calling integration. Need approved numbers, locale, owner and review date. |
| First-aid/DRRM guides offline | Blocked | No content assets or guide UI. Need reviewed content and approval. |
| Protected contact calling | Blocked | No private contact/relay. A normal `tel:` link would expose the private number. Need approved provider and verified contact process. |
| Emergency Medical Alert boundary | Missing | No entry UI. Tier 1 should confirm and explain unavailable protected access without fetching medical records. |
| Lost-ID report, lock/reactivate/replace and audit | Missing | No data model, operations, admin UI, or audit trail. Verification/transition policy required. |
| Accessibility and error states | Missing | Template UI has no emergency-specific states, camera/offline handling, or accessibility evidence. |
| CI, integration/security/device tests | Missing | One template widget test only; no CI or integration tests. |
| Tier 2 medical-data access | Out of scope | None found. Keep absent in Tier 1. |

Acceptance reference: the supplied plan's T1-01 through T1-18. None is currently demonstrated. `flutter analyze` and the one counter widget test pass but do not satisfy those cases.
