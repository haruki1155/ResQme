# Public QR HTTP observer — offline preparation, 2026-11-10

Scope: test-only preparation. No emulator, listener, synthetic Firebase resource,
hosted request, dependency installation, production change, commit, or push.

## Exact integration point

`functions/test/helpers/qr_http_observer.ts` wraps the public SDK `HttpsFunction`
interface `(req, res)`. It reads the existing Express `req.ip` projection and
delegates to the original `resolveTier1Qr(req, res)` exactly once. It returns the
original return value/promise and propagates original errors unchanged. It neither
replaces nor proxies requests, responses, data, headers, IP getters, authentication,
response methods, the callable callback, or the limiter. Observer exceptions are
contained. The additional IP read assumes the normal side-effect-free Express IP
getter; an exotic stateful custom getter is outside this guarantee.

Only discovery descriptors `__endpoint` and `__trigger` are copied to the wrapper.
No `.run()` is used or exposed by this wrapper.

## Installed SDK evidence

Inspected installed `firebase-functions` **7.4.0**, not a remote reference:

- `lib/v2/providers/https.js:103-170`: `onCall` builds `func` through
  `onCallHandler(..., fixedLen, "gcfv2")`, then applies initialization/tracing.
  The separate `.run` member wraps only the callback at line 165.
- `lib/common/providers/https.js:410-425`: returned HTTP handler performs CORS
  and invokes `wrapOnCallHandler` with the incoming `req` and `res`.
- Same file, lines 453-551: validates the callable envelope, sets
  `context.rawRequest = req`, checks tokens, decodes `req.body.data`, constructs
  the v2 callable argument and invokes the callback.
- Same file, lines 555-569: SDK encodes the result and sends the callable response.
- `lib/v2/providers/https.d.ts`: `HttpsFunction` publicly supports the Express
  request/response interface; `.run` is explicitly documented for unit testing.

SHA-256 of inspected SDK JavaScript:

| File | SHA-256 |
| --- | --- |
| v2/providers/https.js | D04105582D3F850C4E4729C94963A4F832FD2F4826E689DE0BF67E11A3C0A964 |
| common/providers/https.js | 805C70EEB1D683F2040BC1C270E06449E2CA4105F64FD28439CC2E0467FA57DB |

This integration therefore surrounds the SDK's real HTTP callable implementation.
It does not reconstruct a callable request or invoke a unit-test shortcut.

## Privacy and diagnostic limit

The sink receives exactly `{ipMetadata, admission:'unknown'}`. IP categories are
`missing`, `invalid`, `usable`, or `unavailable` (getter failure). Classification
uses the current resolver's string-length bounds. No IP value/hash, QR payload,
UID, auth token, headers, request body, student data, response content, or error
text is retained or logged by the observer. The isolated entry adds only the
constant diagnostic tag `qr_http_metadata`.

**Usable IP metadata does not establish admission.** There is no supported SDK
hook into this resolver's private limiter decision. This observer cannot distinguish
rate-limit rejection, validation failure, or downstream eligibility rejection. It
also observes HTTP arrivals that the SDK may reject before the resolver callback.
The production limiter and existing response behavior remain authoritative.
The earlier `.run()` diagnostic remains untouched and is not HTTP evidence.

## Isolated entry, pending separate startup authorization

`functions/test/qr_http_observer_entry.ts` re-exports the existing 16 functions,
overriding only the resolver with this HTTP wrapper. Module loading requires both
`RESQME_QR_HTTP_OBSERVER=1` and `GCLOUD_PROJECT=demo-resqme`. This is a local misuse
guard, not network isolation or deployment authorization.

After separate authorization, a fresh isolated profile can set its **copied**
Functions package entry to `lib/test/qr_http_observer_entry.js`, preserving the
same function name, URL, SDK implementation, and discovery metadata. No repository
package/configuration or existing isolated profile has been changed. Production
`functions/package.json` still targets `lib/src/index.js`; production source has
no diagnostic import/export. The guard alone is not sufficient for startup:
the prior credential, loopback, project, resource, and process checks still apply.

## Offline evidence

The added tests use in-process HTTP-interface fixtures: **no listening sockets**.
They execute the real SDK HTTP function, including decoding, callable-envelope
rejection, CORS preflight, token-check path with absent credentials, and result
encoding. They check raw-request identity, single delegation, exact return/promise
identity, original error propagation, sink failure containment, safe categories,
discovery metadata, isolated-entry gating, and the unchanged 16-export inventory.
Twenty-nine malformed-data HTTP calls followed by the actual limiter's final
permit/exhaustion checks establish one limiter consumption per HTTP call without
database access. Authenticated transport and actual emulator IP projection remain
unverified.

Commands (local installed binaries; no npm downloads):

```powershell
node_modules\.bin\tsc.cmd
node --test lib/test/qr_http_observer.test.js lib/test/resolve_tier1_qr.test.js
```

Verification runtime was Node **24.18.0**, not the prepared profile's Node 22.
TypeScript passed. Focused suite: **12 passed, 0 failed**. Expected SDK logs for
the invalid-envelope case are not observer output. A test-first stub produced
the expected missing-observation assertion failures before implementation.

Preservation baseline: 344 existing tracked/untracked files hashed, 104 pre-existing
Git status entries, 23 production source files. All existing file hashes/status
entries and HEAD remained unchanged. Additions are this report and three test-only
TypeScript files. Build output is ignored. No production or prior diagnostic file
was edited. Full suites and emulator acceptance were not run.

**Stopped after offline verification. Emulator startup requires separate approval.**
