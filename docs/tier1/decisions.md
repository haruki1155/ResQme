# Tier 1 decisions and blockers

Status: proposed defaults only, 2026-10-25. The project owner and school stakeholders must approve relevant external-service, privacy, and emergency-content decisions before those flows are presented as operational. Until then, use synthetic data and emulator-only development.

| Decision | Proposed default / present consequence | Required owner |
| --- | --- | --- |
| Intended Git repository | This workspace has no `.git`; identify the canonical repository before creating `feature/tier1-foundation` or commits. Documentation in this copy remains uncommitted. | Project owner |
| Target platform | Build and physically validate Android first. iOS remains unclaimed until selected and tested. | Product owner |
| Dev Firebase project | Use a dedicated nonproduction project and local Auth/Firestore/Functions emulators. Do not infer a project ID or deploy from this copy. | Project owner |
| QR launch/rotation | Require in-app scanning; use an approved HTTPS URL with one server-issued opaque token while active. Revocation/replacement invalidates the old token. Decide domain and external-camera fallback before printing cards. | Product owner |
| Student identity, consent, guardian verification | Use synthetic records until the school defines enrollment verification, consent retention, contact verification, and authorized ownership/admin proof. Email alone is insufficient. | School privacy lead |
| Admin role assignment | Trusted administrator provisioning only. Students must not self-assign roles. Define approver and initial admin bootstrap. | School administrator |
| Locked QR behavior | Deny student-linked actions and display a neutral status; keep independent public help available. Approve reactivation/replacement proof and lost-ID handling. | Product owner / school administrator |
| Hotline directory | No numbers are invented. Obtain approved locality/school list with source, reviewer, version, and review date before enabling call actions. | School/clinic/DRRM reviewers |
| Offline medical/emergency guidance | Bundle only approved general guidance with reviewer and version metadata. No real medical records or unreviewed advice. | School/clinic/DRRM reviewers |
| Masked call relay | Keep protected calling blocked until a vetted bridging provider, billing/abuse policy, contact consent, and physical privacy test exist. A `tel:` link is not an acceptable substitute. | Product owner / privacy lead / telecom provider |
| Medical Alert entry | Confirmation plus explicit “protected medical access is not enabled in Tier 1” message and public help only. Do not imply live medical access. | School/medical lead |
| Release | No production deployment, real student records, or billable telephony without explicit approval and the M9 acceptance evidence. | Project owner / school privacy lead |

These decisions should be recorded with dates and approvers as they are resolved. Their unresolved state blocks production Tier 1 acceptance, not emulator-only security groundwork.
