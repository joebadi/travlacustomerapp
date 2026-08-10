# Travla Customer Mobile App — Product and Implementation Plan

**Document owner:** Travla product and engineering  
**Application:** `travlacustomerapp` (`ng.com.travla.customer`)  
**Platforms:** Android first, iOS supported  
**Last reviewed:** 9 August 2026  
**Planning baseline:** GitHub `main` at commit `4300404`  
**Backend:** `https://travla.com.ng/api/v1`

This is the controlling delivery checklist for the Travla customer mobile app.
It translates the completed web product and the root product specifications into
a native mobile roadmap. Update this file in the same commit whenever the status
of a mobile feature changes.

---

## 1. Status rules

| Mark | Meaning |
|---|---|
| ✅ | Code is implemented and `flutter analyze` passes. |
| 🧪 | Code is implemented, but physical-device acceptance testing is still required. |
| 🟡 | Partially implemented; the user cannot yet complete the whole workflow. |
| ⬜ | Not started in the Flutter app. |
| ⏸ | Intentionally deferred or dependent on an external decision/integration. |

### Definition of done for a mobile feature

A feature is product-complete only when all applicable items below are true:

- [ ] The corresponding web workflow and backend business rules were reviewed first.
- [ ] The mobile flow uses the real production API; it is not a visual placeholder.
- [ ] Server-side pricing, eligibility and authorization remain the source of truth.
- [ ] Loading, empty, offline, validation, success and error states are designed.
- [ ] Destructive or financial actions require clear confirmation.
- [ ] Money is displayed from integer kobo values and never calculated from labels.
- [ ] Dates use ISO-8601 API values and display in the device's local timezone.
- [ ] Accessibility labels, touch targets, text scaling and keyboard behavior pass.
- [ ] Portrait phones are the primary layout; tablets and landscape remain usable.
- [ ] `flutter analyze` passes with no issues.
- [ ] Relevant unit/widget tests pass.
- [ ] The flow is smoke-tested on a physical Android device by the product owner.
- [ ] The implementation and device-QA status in this document are updated.

An item marked ✅ below means its code is present. Unless physical-device QA is
explicitly checked, it must still be treated as 🧪 before release.

---

## 2. Product boundary and sources of truth

### App role

This repository is the **customer app only**. Agent, rider and fuel-attendant
applications will remain separate Flutter projects so each app has a focused
permission model, navigation structure and release cycle.

### Source priority

When behavior differs or is unclear, use this order:

1. Current Laravel backend rules and API resources.
2. Current React web customer workflow and approved UI behavior.
3. Root specifications in `../../docs/`, particularly:
   - `ROADMAP.md`
   - `JOURNEYS.md`
   - `CLAIMS_FILING.md`
   - `FLEET_ORGANISATION_MODEL.md`
   - `NIID_VERIFIER.md`
4. `oldtravla` as historical reference only—not as code to copy.

### Mobile adaptation rule

The web app defines workflow completeness, not the mobile layout. Before building
each mobile module:

1. Trace the complete web journey, API requests, eligibility rules and failure states.
2. Preserve those rules and data requirements.
3. Recompose the interface for touch, smaller screens and interrupted sessions.
4. Avoid desktop tables, hover-only actions, very wide modals and nested sidebars.
5. Persist safe drafts for long forms and uploads where practical.

---

## 3. Approved information architecture

### Primary bottom navigation

1. **Home** — wallet/readiness summary, pending actions and quick access.
2. **Vehicles** — owned vehicles, incoming vehicles and vehicle actions.
3. **Journeys** — record, save and follow routes; road intelligence.
4. **News** — admin-published vehicle, road, law and traffic articles.
5. **More** — all secondary products and account tools.

Marketplace remains under **More**. It must not replace News in the bottom bar.

### Global dashboard header

- Travla logo.
- Notification bell with unread count and recent-notification menu.
- Profile image/initials menu with account summary and logout.

### More menu target structure

- Marketplace
- Renewals and registrations
- Ownership transfers
- Driver's licence
- Fleet organisations
- Insurance and claims
- Transactions and wallet
- Car Talk forum
- Stolen vehicle registry
- Vehicle tracking
- Support
- Profile and security
- Notification preferences
- Legal, privacy and app information

Items may be progressively enabled, but disabled placeholders must clearly say
“Coming later” and must not look like working buttons.

---

## 4. Current completeness snapshot

| Area | Build status | Device QA | Notes |
|---|---:|---:|---|
| Flutter project and native shells | ✅ | 🧪 | Android/iOS scaffolds and production API configuration exist. |
| Brand, splash and app icon | ✅ | 🧪 | White Travla road mark on a green-gradient adaptive icon, Android themed icon and branded splash are present. |
| First-launch onboarding | ✅ | 🧪 | Persistent onboarding-completed state is implemented. |
| Login/session/logout | ✅ | 🧪 | Sanctum bearer token and secure storage are implemented. |
| Registration/OTP/admin gate/reCAPTCHA | ✅ | 🧪 | Mirrors registration availability settings and OTP flow. |
| Five-tab customer shell | ✅ | 🧪 | Home, Vehicles, Journeys, News and More. |
| Dashboard wallet/garage/quick actions | ✅ | 🧪 | Real customer and garage data. |
| Dashboard notification/profile menus | ✅ | 🧪 | Live unread count, recent items, account summary and logout. |
| Notifications centre | ✅ | 🧪 | Read state, mark-all, polling and pull-to-refresh. |
| Latest News list/article reading | ✅ | 🧪 | Public newsroom content is available in-app. |
| Vehicle garage/list/readiness | ✅ | 🧪 | Owned and incoming vehicle summary is connected. |
| Add an existing vehicle | ✅ | 🧪 | Canonical make/model/category data and validation. |
| Register a new vehicle | ✅ | 🧪 | Four-stage flow, uploads, handover and server quote. |
| Vehicle workspace | ✅ | 🧪 | Overview, audit-aware editing, gallery, document vault, service ordering/history and tracker-source management are coded. |
| Transactions/wallet funding | 🟡 | 🧪 | Native balance, credit/debit ledger, filters, virtual account and verified Paystack top-up are coded; receipts, pagination and hybrid service shortfall remain. |
| Vehicle-paper renewal | 🟡 | 🧪 | Native eligibility, multi-paper quote, wallet checkout, order history, processing/delivery progress, OTP and cancellation are coded; hybrid card continuation remains. |
| Driver's-licence renewal | 🧪 | — | Licence list, add-licence (with document upload), eligibility-gated renewal with delivery/city/wallet quote and order handoff are coded. Hybrid card top-up remains. |
| Ownership transfer | 🟡 | 🧪 | Managed/offline creation, records, detail timeline, consent, evidence, correction resubmission and permitted cancellation are coded; hybrid wallet top-up remains. |
| Marketplace | 🟡 | 🧪 | Seller activation, owned-vehicle picker, eligibility-aware listing creation and seller listing summary are coded; browse, offers, wanted and settlement remain. |
| Fleet | ⬜ | — | Backend/web complete; native mobile module pending. |
| Journeys | 🟡 | — | Navigation placeholder; native GPS client is the main remaining work. |
| Car Talk forum | ⬜ | — | News is separate and complete; forum remains. |
| Stolen vehicle registry | ⬜ | — | Report, search, sighting and map workflows remain. |
| Insurance and claims | 🧪 | — | Insurance: policies, add-with-doc, NIID verify, buy+renew, cert download. Claims: rollout gate, list+timeline, file draft, evidence, submit (fee), messages, disputes+NAICOM. Combined-checkout + geolocation remain. |
| Vehicle tracking/live map | 🧪 | — | Live map (flutter_map/OSM) of all vehicles' latest positions, selected-vehicle trail overlay, phone-as-tracker with **background** foreground-service streaming, and Traccar-device add (from hub + per-vehicle tab). |
| Support/profile/security | 🟡 | 🧪 | Full profile, avatar, personal/NIN editing, Paystack bank verification and password change are coded; support and legal/preferences pages remain. |
| Push notifications and deep links | 🧪 | — | FCM wired end-to-end (client register/tap-route + backend HTTP v1 sender from NotificationService); needs on-device QA. iOS needs an APNs key; foreground-Android banner + richer per-screen deep links are follow-ups. |
| Release hardening/store submission | ⬜ | — | Privacy, signing, QA, telemetry and store assets remain. |

---

## 5. Delivery phases and detailed checklist

### Phase 0 — Engineering foundation

**Goal:** A stable, separately deployable customer application foundation.

- [x] Create standalone Flutter repository.
- [x] Configure Android application ID `ng.com.travla.customer`.
- [x] Configure iOS bundle ID `ng.com.travla.customer`.
- [x] Add production API base URL with `--dart-define` override.
- [x] Add `X-App-Type: customer` to API traffic.
- [x] Implement Material 3 Travla colors and typography.
- [x] Reduce global visual density for practical phone sizing.
- [x] Add full Travla logo and customer-app icon assets.
- [x] Add native/Flutter splash behavior.
- [x] Add first-launch onboarding persistence.
- [x] Establish Riverpod state management.
- [x] Establish GoRouter navigation and authentication redirects.
- [x] Establish Dio API client and consistent API failure messages.
- [x] Establish secure token storage.
- [ ] Add environment labels for development/staging/production builds.
- [ ] Add a central structured logger that removes secrets and personal data.
- [ ] Add crash reporting only after privacy review and admin configuration.
- [ ] Add CI checks for `flutter analyze` and tests on every pull request.

**Acceptance:** App launches to onboarding/login, restores a valid session, and
routes an expired/invalid session back to login without exposing protected pages.

### Phase 1 — Authentication, launch controls and account entry

**Goal:** Registration and login must honor the same administrative controls as web.

- [x] Premium mobile login form.
- [x] Password visibility and validation behavior.
- [x] Login error and submission states.
- [x] Token-based authenticated session restoration.
- [x] Token-revoking logout with local fallback.
- [x] Registration form using first name and last name.
- [x] Registration availability gate from admin settings.
- [x] reCAPTCHA availability and challenge handling.
- [x] OTP verification screen and resend-ready architecture.
- [x] Transfer-invitation parameters accepted on the registration route.
- [x] Pre-populated transfer-invite registration data supported by API contract.
- [ ] Forgot-password request screen.
- [ ] Password reset/deep-link completion screen.
- [ ] Email/phone change reverification.
- [ ] Optional biometric unlock for an already authenticated device.
- [ ] Session/device management page.
- [ ] Account-deletion request with clear consequences and reauthentication.

**Device QA:**

- [ ] Registration disabled by admin hides/blocks every mobile entry point.
- [ ] Registration enabled without reCAPTCHA completes successfully.
- [ ] Registration enabled with reCAPTCHA completes successfully.
- [ ] Transfer invitation opens registration with the expected pre-population.
- [ ] OTP verification signs the user in and preserves pending transfer context.

### Phase 2 — Application shell, dashboard, profile and notifications

**Goal:** The home screen tells the customer what needs attention and provides
immediate paths to the highest-value actions.

#### Navigation and dashboard

- [x] Five-destination bottom navigation.
- [x] Marketplace moved under More.
- [x] News retained as a primary destination.
- [x] Compact green-gradient dashboard header.
- [x] Wallet balance summary.
- [x] Garage/readiness summary from real vehicle data.
- [x] Empty-garage onboarding actions.
- [x] Quick actions for renewals, transfers, journeys and registration.
- [x] Pending incoming-transfer alert from garage data.
- [ ] Post-registration guided tour focused on adding/registering a first vehicle.
- [ ] Dashboard consolidated action desk for expired papers, pending payments,
      transfer approvals and deliveries.
- [ ] Pull-to-refresh the complete dashboard snapshot.
- [ ] Dashboard offline/cache state with last-updated time.

#### Notification menu and centre

- [x] Notification icon replaces the Customer label.
- [x] Live unread-count badge.
- [x] Recent four-notification dropdown.
- [x] Notification polling every 30 seconds while observed.
- [x] Full notifications page.
- [x] Expand/read a selected notification.
- [x] Mark one notification read.
- [x] Mark all notifications read.
- [x] Pull-to-refresh notifications.
- [x] Map supported `action_url` values to native destination routes.
- [ ] Notification preferences page for email, SMS, WhatsApp and document reminders.
- [ ] Paginated/infinite notification history beyond the first 50 items.
- [x] FCM device registration and push delivery (backend FcmV1Client → HTTP v1, fanned out from NotificationService; Android live, iOS pending APNs key).
- [x] Push tap routing and cold-start deep links (tap opens the notification in-app via getInitialMessage/onMessageOpenedApp).

#### Profile menu and account

- [x] Profile image/initials icon replaces the Customer label.
- [x] Dropdown shows name, email, phone and verification state.
- [x] Logout is available from the dropdown.
- [x] Full profile screen.
- [x] Edit name, phone and profile image with reverification where required.
- [x] NIN submission and verification-status display.
- [x] Bank-account entry and Paystack verification status.
- [x] First/last-name match explanations for protected-payment eligibility.
- [x] Security settings and password change.
- [ ] Legal/privacy/support links.

### Phase 3 — Vehicles and document vault

**Goal:** Every customer can add, inspect and maintain a trustworthy vehicle record.

#### Garage

- [x] Load owned vehicles.
- [x] Load pending/incoming transfer vehicles.
- [x] Show high-level document readiness.
- [x] Empty-state add/register actions.
- [ ] Search, sort and filter garage vehicles.
- [ ] Distinguish owned, incoming, fleet-linked and marketplace-reserved states.
- [ ] Greyed incoming vehicle cards with direct transfer-detail link.
- [x] Vehicle thumbnails and image fallback states.

#### Add an existing vehicle

- [x] Load make/model catalogue from backend.
- [x] Load active vehicle categories from backend.
- [x] Auto-resolve and lock category from make/model.
- [x] Block submission early if the resolved category is not configured.
- [x] Validate plate, VIN/chassis and required engine number.
- [x] Submit to the real vehicle API.
- [ ] Handle duplicate/stolen match with the web-equivalent dispute or sighting path.
- [ ] Add vehicle images during onboarding.
- [ ] Resume a safe draft after app interruption.

#### Vehicle detail

- [x] Premium vehicle overview with status, identity and document-readiness action.
- [x] Swipeable vehicle image gallery viewing.
- [x] Vehicle image upload/removal with six-image and 5 MB-per-file limits.
- [ ] Vehicle image reordering (requires a persistent backend ordering contract).
- [x] Premium document-vault dashboard with current/attention/other-file readiness totals.
- [x] Flat mobile document cards for renewable papers and other records with direct viewing and secure-file state.
- [x] Document detail and version history with signed file opening.
- [x] Guided three-stage add-document sheet with issue date, locked one-year expiry preview, animated file states and anchored save action.
- [x] Server-owned expiry submission: mobile never sends an expiry date.
- [x] Auto-renew toggle for renewable documents.
- [x] Confirmed document removal and workspace refresh.
- [x] Edit permitted vehicle identifiers with audit-aware confirmation.
- [x] Keep VIN immutable and auto-resolve/lock category from canonical make/model.
- [x] Other Services catalogue, requirements, service-city/delivery form and order history.
- [x] Fixed-fee wallet submission, quoted-order payment and pending-order cancellation.
- [x] Sell-on-marketplace entry point and eligibility explanation.
- [x] Ownership-transfer entry point.
- [x] Tracking tab with latest fix, trail summary and external map opening.
- [x] Hardware/API tracker creation, activation, key rotation and removal.
- [ ] Background phone-as-tracker streaming (native location/offline phase).

### Phase 4 — Transactions, wallet and payments

**Goal:** Customers understand every naira entering or leaving Travla and can fund
the wallet before time-sensitive renewals.

- [x] Rename/use one native **Transactions** destination.
- [x] Wallet balance (the current API does not expose a separate held balance).
- [x] Unified credit/debit ledger for every transaction returned by the wallet API.
- [ ] Filter by transaction type, service and date.
- [ ] Transaction-detail receipt with references and fee allocation.
- [x] Paystack wallet top-up initialization.
- [ ] Paystack callback/deep-link completion.
- [x] Server verification before displaying a successful credit.
- [ ] Hybrid wallet/card shortfall payment.
- [ ] Correct display of wallet portion versus Paystack portion.
- [ ] Offline-deposit request/status if this remains enabled for customers.
- [ ] Refund and reversal visibility.
- [ ] Download/share receipt without exposing sensitive identifiers.

**Financial acceptance:** The server quote is displayed verbatim; the app never
reconstructs commission or payment amounts independently.

### Phase 5 — Vehicle papers, driver’s licence and new registration

#### Vehicle-paper renewals

- [x] Renewal eligibility and missing-document explanations.
- [x] Select one or several eligible renewable documents.
- [x] Quote all document prices and a single applicable delivery fee.
- [x] Pickup/door-to-door selection and covered-city validation.
- [ ] Hybrid wallet/card payment continuation after a wallet shortfall.
- [x] Wallet payment with explicit shortfall route to Transactions.
- [x] Renewal order and grouped document progress.
- [x] Agent-processing timeline.
- [x] Rider delivery live progress and external live-location map when out for delivery.
- [x] Handover OTP display/instructions.
- [x] Completed document automatically visible in the vehicle vault through the shared backend record.
- [x] Cancel/refund behavior where the backend permits it.

#### Driver’s licence

- [x] Licence record/list.
- [x] Add licence with class, number, issue and expiry information (+ optional document upload).
- [x] Eligibility and expiry state (renewable flag, status pills, days-to-expiry).
- [x] Licence-renewal quote and checkout (delivery/city/wallet, server-priced).
- [x] Shared processing/delivery timeline (reuses the renewal order screen).
- [ ] Updated licence data after completion (verify on device).
- [ ] Hybrid wallet-shortfall card top-up continuation.

#### New vehicle registration

- [x] Four-stage mobile workflow based on the web journey.
- [x] Canonical make and model dropdowns.
- [x] Auto-selected locked vehicle category and category-specific base fee.
- [x] Required engine number and VIN validation.
- [x] Standard/custom plate choice and tinted-permit option.
- [x] Configurable required-document uploads.
- [x] Configurable paid options.
- [x] Vehicle photos.
- [x] Pickup/door-to-door handover and covered city.
- [x] Server quote with every line item including delivery.
- [x] Wallet-balance and shortfall display.
- [x] Multipart request submission.
- [x] Success state with tracking number and total.
- [ ] Registration requests list and status filters.
- [ ] Registration detail/timeline.
- [ ] Payment-shortfall route to wallet top-up and return to the draft.
- [ ] Created vehicle deep link after completion.
- [ ] Delivery/handover tracking.

### Phase 6 — Ownership transfers

**Goal:** Native transfer behavior must preserve the approved admin-first
verification sequence and distinguish Travla-managed versus offline paperwork.

- [x] Sent/received transfer lists with clear states.
- [x] Transfer-readiness check before form entry.
- [x] Start from a selected vehicle without repeating known details.
- [x] Reason defaults to **Select**; sale, gift and other supported reasons.
- [x] Online/agent-prepared transfer path.
- [x] Offline-completed transfer with customer document uploads.
- [x] Recipient phone-first lookup.
- [x] Populate and lock matched account email/details.
- [x] Required recipient NIN handling.
- [x] Prevent phone/email from resolving to separate accounts.
- [x] Document issue dates with server-derived one-year expiry.
- [x] Category/city/delivery fee breakdown and wallet submission.
- [ ] Wallet-shortfall gateway top-up/hybrid payment continuation.
- [x] Admin verification pending state before recipient notification.
- [x] Admin correction query shown to sender with edit/resubmit path.
- [x] Recipient consent code entry only after admin approval.
- [x] Immediate ownership completion after valid recipient consent when approved.
- [x] Cancel a permitted transfer and correctly unwind linked marketplace state.
- [x] Full transfer detail and audit trail.
- [ ] Incoming transfer dashboard prompt in portrait-safe layout.
- [ ] Accepted NIN populates recipient profile according to backend rules.
- [ ] Transferred renewable/other documents appear automatically for recipient.

### Phase 7 — Marketplace

**Goal:** Support selling, buying, wanted requests and protected payment without
exposing buyer contact details by default.

- [x] Marketplace is located under More.
- [ ] Premium browse with search/filter/sort and pagination.
- [ ] Listing detail, image gallery, documents/readiness summary and seller name.
- [x] Create listing from an eligible owned vehicle.
- [x] One-time verified seller activation gate.
- [x] New-vehicle exemption versus used-vehicle required-paper gate.
- [x] Use existing vehicle images by default.
- [x] Listing-only hide/show image controls.
- [x] New listing images propagate to the main vehicle gallery.
- [ ] Edit, pause, manually remove and relist.
- [ ] Make/counter/revise/reject/accept offers.
- [ ] Buyer-seller private messaging without default phone/email disclosure.
- [ ] Seller chooses offline sale/Travla transfer or protected payment.
- [ ] Pickup or door-to-door buyer parameters.
- [ ] Seller delivery-fee proposal and final acceptance.
- [ ] Complete buyer fee/terms review.
- [ ] Protected payment identity gate: NIN and verified bank account.
- [ ] Vehicle handover OTP before transfer begins.
- [ ] Held funds, release, refund and non-refundable delivery fee visibility.
- [ ] Sold-offline flow pre-fills transfer and supports cancellation.
- [ ] Marketplace activity: listings, offers, purchases, sales and messages.
- [ ] Wanted “Post a Request” flow.
- [ ] Seller vehicle bids and requester acceptance.

### Phase 8 — News, Car Talk and vehicle security

#### News

- [x] News is a primary bottom-navigation destination.
- [x] Admin-published articles load from the public API.
- [x] News filters/search behavior implemented in the native page.
- [x] Article reading page.
- [ ] Share article using the public canonical URL.
- [ ] Cache recently read articles for poor connectivity.

#### Forum

- [ ] Retro-style topic directory adapted to touch.
- [ ] Category/search/sort/pagination.
- [ ] Create topic and reply.
- [ ] Likes and reply activity.
- [ ] Pinned/locked states and sensitive-information reminders.
- [ ] User’s topics/replies view.

#### Stolen vehicle registry

- [ ] Plate/identity search and safety guidance.
- [ ] Public report directory and filters.
- [ ] Report one of the user’s vehicles stolen.
- [ ] Police reference, timestamps, evidence and reward fields.
- [ ] Map-based last-known location.
- [ ] Report a sighting with optional anonymous identity.
- [ ] Sighting location, direction, time and photos.
- [ ] Owner sighting moderation.
- [ ] Mark recovered/closed.
- [ ] Clear warning never to pursue or confront a suspected stolen vehicle.

### Phase 9 — Fleet organisations

**Goal:** Let verified business customers operate one or several organisations
without mixing organisation data or permissions.

- [ ] Block fleet creation until customer identity requirements are satisfied.
- [ ] Create fleet organisation.
- [ ] Organisation selector for multi-company users.
- [ ] Fleet details and edit screen.
- [ ] Soft-delete organisation, restore window and permanent-delete policy.
- [ ] Accept organisation invitation.
- [ ] Green-gradient fleet module navigation with orange active state.
- [ ] Overview: total vehicles, renewal status and wallet/funding readiness.
- [ ] Vehicles tab and document readiness.
- [ ] Live map and tracking states.
- [ ] Drivers, regions, teams and member permissions.
- [ ] Fuel control, cards, allocations and transaction queue visibility.
- [ ] Role/region-scoped actions based only on server capabilities.
- [ ] Fleet renewal planning and wallet-funding prompts.
- [ ] Fleet notifications and action desk.
- [ ] Later: fleet journeys, approved routes and deviation alerts.

### Phase 10 — Journeys and vehicle tracking

The detailed behavioral source is `../../docs/JOURNEYS.md`.

#### Journeys v1

- [ ] MapLibre GL and OpenStreetMap native map foundation.
- [ ] Permission education for foreground/background location.
- [ ] Android persistent recording notification.
- [ ] iOS background-location indicator and permission strings.
- [ ] Start/pause/resume/finish recording.
- [ ] Adaptive distance-aware GPS sampling.
- [ ] Local SQLite buffer with idempotent batch upload.
- [ ] Live distance, duration, average speed, GPS accuracy and connectivity.
- [ ] Add waypoint, text note, photo and voice note.
- [ ] Saved journeys list/detail/edit/delete.
- [ ] Follow exact trail and reverse-with-warning modes.
- [ ] Off-route audio/haptic alert with noise suppression.
- [ ] Road Intelligence nearby sync and on-device proximity alerts.
- [ ] Report/vote on road issues.
- [ ] Trail-only, cached-map, city/state pack and route-corridor offline modes.
- [ ] Private-by-default sharing with expiry and hidden home/end segments.
- [ ] Permanent local/server delete.

#### Vehicle tracking

- [ ] Latest vehicle position and position freshness.
- [ ] Position history/trail.
- [ ] Phone-as-tracker start/stop controls and visible privacy state.
- [ ] Tracker-source management and one-time key handling.
- [ ] Active stolen-report live-location integration.
- [ ] Geofence/idle alerts when backend capability is added.

#### Deferred journey phases

- [ ] ⏸ Routing-engine selection and native rerouting.
- [ ] ⏸ On-device map matching and high-confidence wrong-way alerting.
- [ ] ⏸ Passive anonymised road-pattern detection.
- [ ] ⏸ Fleet-approved routes and deviation analytics.

### Phase 11 — Insurance, claims and support

#### Insurance

- [x] Vehicle policies list and status. (`lib/features/insurance/`)
- [x] Add/upload an existing policy.
- [x] NIID verification state and recheck action.
- [x] Insurance home: expiring-soon list + per-vehicle workspace + cancel policy.
- [x] Buy/renew policy through configured provider or Travla agent (automated instant vs agent delivery; shared renewal-order handoff).
- [x] Policy certificate view/download (signed URL, opens externally).
- [ ] Expiry push reminders. (blocked on Firebase/FCM provisioning)
- [⏸] Include insurance in combined paper-renewal checkout where allowed. Deferred — standalone buy/renew already covers the capability; merge only saves one shared delivery fee, and weaving it through the 3-step renewal wizard is a larger change. Backend already supports it (insurance_renew_policy_ids / insurance_buy_coverage_types).

#### Claims

- [x] Claims rollout/allowlist gate from system settings (coming-soon 403 → in-app gate).
- [x] Claims list and lifecycle status (+ progress timeline).
- [x] Incident/party/witness form + severity + fault/third-party.
- [x] Damage images and document uploads (evidence add/remove + required-doc checklist).
- [x] Police-report fee payment on submit (wallet).
- [x] Claim detail: correspondence thread (reply), disputes + NAICOM escalation, delete draft.
- [ ] Geolocation capture on the incident form.
- [ ] Cover/fault-basis eligibility pre-check (currently server-enforced on submit).
- [ ] Draft edit/resume of already-entered fields (create + evidence + submit works; field edit TBD).
- [ ] Correspondence timeline and Travla claim alias.
- [ ] Assessment, decision, excess and settlement display.
- [ ] Dispute and post-insurer NAICOM escalation flow.

#### Support

- [ ] Support entry points contextual to orders and transactions.
- [ ] Create support request with attachments.
- [ ] Conversation/inbox and unread state.
- [ ] FAQ and contact information available offline.
- [ ] Emergency language must not imply Travla is an emergency service.

### Phase 12 — Quality, privacy and release readiness

#### Security and privacy

- [ ] Threat-model authentication, payments, OTPs, uploads and deep links.
- [ ] Never log tokens, NINs, bank details, OTPs or full document URLs.
- [ ] Screenshot/privacy behavior reviewed on sensitive identity pages.
- [ ] Android network security config permits production HTTPS only.
- [ ] iOS transport security config reviewed.
- [ ] Root/jailbreak response policy decided without blocking legitimate users blindly.
- [ ] NDPR privacy notice and consent records.
- [ ] Data export and account-deletion request paths.
- [ ] Location collection has clear active indicators and can always be stopped.

#### Reliability and performance

- [ ] Central connectivity/offline state.
- [ ] Retry policy avoids duplicate financial or mutating requests.
- [ ] Idempotency keys used where backend accepts them.
- [ ] Upload compression/resume policy.
- [ ] Paginate large lists and virtualize expensive views.
- [ ] Cache only non-sensitive data needed for usability.
- [ ] Test cold start, resume, token expiry and low-memory restoration.
- [ ] Test slow/unstable Nigerian mobile networks.
- [ ] Meet reasonable startup and scrolling performance targets on mid-range Android.

#### Automated tests

- [x] Theme test foundation.
- [x] Garage model test foundation.
- [ ] Authentication repository/controller tests.
- [ ] Registration gate/reCAPTCHA tests.
- [ ] Vehicle catalogue/category-resolution tests.
- [x] Vehicle detail parsing, document grouping and expiry-derivation tests.
- [x] Vehicle service payment-state and tracker workspace parsing tests.
- [ ] Registration quote/submission tests.
- [ ] Notifications repository and read-state tests.
- [ ] Router/deep-link tests.
- [ ] Wallet/payment presentation tests.
- [ ] Transfer and marketplace state-machine tests.
- [ ] Golden tests for core phone widths where stable.

#### Release operations

- [ ] Development/staging/production application variants.
- [ ] Android upload/release signing managed outside Git.
- [ ] iOS certificates/profiles managed outside Git.
- [ ] Versioning and release-note policy.
- [ ] Google Play privacy/data-safety declaration.
- [ ] Apple App Privacy declaration.
- [ ] Store screenshots and descriptions.
- [ ] Support URL, privacy URL and terms URL.
- [ ] Internal testing track and named acceptance-test group.
- [ ] Crash/ANR monitoring and rollback plan.
- [ ] Production smoke checklist after every release.

---

## 6. API integration map

The backend remains authoritative. This list is intentionally grouped rather
than duplicating every route in Laravel.

| Mobile domain | Primary API groups |
|---|---|
| Authentication | `/auth/*`, public platform/registration configuration |
| Dashboard | `/auth/me`, `/vehicles`, pending/incoming transfers |
| Notifications | `/notifications*`, `/notification-preferences` |
| News | Public news/article endpoints |
| Vehicle catalogue | `/catalogue/vehicles`, `/catalogue/categories`, `/catalogue/service-cities` |
| Vehicles/documents | `/vehicles*`, vehicle documents and signed document URLs |
| Registration | `/registrations*`, registration config and quote |
| Renewals/licence | `/renewals*`, `/drivers-license*` |
| Transfers | `/transfers*`, readiness, recipient lookup and consent |
| Wallet/transactions | `/wallet*`, Paystack initialization/verification |
| Marketplace | `/marketplace/listings*`, offers, sales, requests, bids and messages |
| Fleet | `/fleet*`, organisations, members, regions, vehicles, drivers, fuel and tracking |
| Journeys | `/journeys*`, `/road-reports*` |
| Security | `/stolen*`, sightings and vehicle matching |
| Insurance/claims | `/insurance*`, `/claims*`, correspondence and disputes |
| Support | `/support*` |

Before implementing a domain, confirm current route names from Laravel rather
than relying exclusively on this high-level map.

---

## 7. Mobile UX standards

- Use flat, professional surfaces with restrained shadows and consistent radii.
- Travla green is structural; orange `#FA4710` is for actions and active emphasis.
- Minimum practical touch target: 44–48 logical pixels.
- Use bottom sheets or full pages instead of desktop-sized modal replicas.
- Keep one clear primary action per step.
- Long workflows show progress, save safe drafts and explain what comes next.
- Canonical values use dropdown/search selection; do not allow arbitrary make/model/category.
- Auto-derived values are visible, explained and locked.
- Fee review shows **every** line item, delivery, wallet use, card shortfall and total.
- Never claim a payment, delivery, approval or transfer succeeded before server confirmation.
- Empty states must offer the correct next action, not generic decoration.
- Errors must say what the customer can do next without exposing server internals.
- Support text should use Nigerian vehicle terminology consistently.

---

## 8. Recommended delivery order from the current baseline

This order unlocks complete customer journeys before expanding to specialist modules.

1. **Finish vehicle actions** — build marketplace/transfer eligibility and native entry points.
2. **Profile/security and Transactions/wallet** — required identity and payment foundation.
3. **Vehicle-paper and driver’s-licence renewals** — Travla’s primary revenue product.
4. **Complete registration list/detail/delivery tracking** — closes the already-built form.
5. **Ownership transfers** — including admin-first review and invitation deep links.
6. **Marketplace** — depends on vehicles, identity, wallet and transfers.
7. **Stolen registry and forum** — News is already available; complete Car Talk/security.
8. **Fleet** — high-value business product, built after shared vehicle/payment components.
9. **Insurance and claims** — observe rollout flags and external integration readiness.
10. **Journeys and tracking** — native location/offline work with a dedicated QA cycle.
11. **Push notifications, deep-link coverage and release hardening.**

---

## 9. Physical-device acceptance matrix

Run the applicable scenarios on at least one mid-range Android phone before a
milestone is accepted:

| Condition | Required checks |
|---|---|
| Screen | Small portrait, normal portrait and landscape; no clipped menus/modals. |
| Text | Default and enlarged font scale. |
| Keyboard | Email, phone, numeric and text keyboards; fields remain visible. |
| Network | Wi-Fi, mobile data, slow connection, loss and recovery. |
| Session | Fresh login, restored login, expired token and logout. |
| Files | Camera/gallery/document permission grant and denial; size/type errors. |
| Payments | Sufficient wallet, shortfall, cancelled Paystack and verified success. |
| Links | Cold/warm transfer invite, notification and payment callback. |
| Location | Permission denial, approximate/precise, background, GPS loss and recovery. |
| Accessibility | Screen-reader labels, contrast, touch targets and logical focus order. |

Record the device model, Android/iOS version, app commit and result in the pull
request or release checklist. A VPS `flutter analyze` pass is necessary but is
not a substitute for this physical-device acceptance.

---

## 10. Plan maintenance

- Every mobile feature commit should update its relevant checkbox.
- Do not mark a workflow complete if only its landing page exists.
- If backend or web behavior changes, update this plan before adapting mobile.
- Add newly discovered gaps under the correct phase; do not hide them in commit notes.
- At each release candidate, review the completeness snapshot and device matrix.
- Keep tokens, signing keys, `.env` files, NINs, bank data and production documents out of Git.
