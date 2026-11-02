# TMAssist: UI/UX Design Document

> Describes the **current** UI/UX of the app as found in the code on 2026-11-02.
> It was written by reading the source; the app was not run to produce it, and no code was changed.
> Where something could not be confirmed from the code, it says so.

---

## 1. Overview

**What the app does.** TMAssist is a Flutter app (Firebase back end) for handling Telekom Malaysia (TM) service tickets. Customers report problems. Tickets are auto-assigned to a technician. Technicians work through an AI-generated troubleshooting checklist, write a service report and sign it. Supervisors monitor everything, can reassign tickets, review the report and sign off to close the ticket. The login screen tagline is "AI - Assisted Ticketing System".

**Roles** (stored as `users/{uid}.role`: `customer`, `technician`, `supervisor`):

| Role | Can register in the app? | Main flow |
|---|---|---|
| **Customer** | Yes ("Register" on the login screen) | Sign in → Home → **Submit Ticket** (manual form or AI Mode) → track it in **Tickets** → can **cancel** while it is New/Assigned → optionally run the **Internet Speed Test** from Profile |
| **Technician** | No registration screen found (accounts are created outside the app) | Sign in → **My Jobs** / **My Tasks** → open a ticket → **Start Job** → **Checklist** (AI) → **Report** (notes, proof photo, signature) → submit, which resolves the ticket. Can edit **Coverage Areas** on the profile. Has an **Analytics** tab |
| **Supervisor** | No registration screen found | Sign in → dashboard → **Tickets** list → open a ticket → **Assign** manually if needed → when the ticket is **Resolved**, review the report, add comments, **sign off** (closes the ticket) and export a PDF. **Analytics** tab ranks technicians |

**Ticket status flow** (stored uppercase): `NEW` → `ASSIGNED` → `IN_PROGRESS` → `RESOLVED` → `CLOSED`, plus `CANCELLED` (customer cancel from NEW/ASSIGNED).

---

## 2. Screen inventory

All screens live under `lib/features/<role>/`. "Reached from" lists what navigates to the screen; "Goes to" lists what it navigates to.

### 2.1 Auth (all roles)

| Screen | File | Purpose | Main widgets | Reached from → Goes to |
|---|---|---|---|---|
| Login | `auth/login_screen.dart` | Sign in | 300px blue header block (bottom-left radius 80, router icon, "TM Assist", tagline), "Sign In" title, email + password fields (obscure toggle), "Forgot password?", inline error box, Sign In button, "Register" link | App start (`home:`) → `/forgot-password`, `/register`; after login → `/customer`, `/supervisor` or `/tech` by role |
| Register (customer) | `auth/register_customer_screen.dart` | Create a customer account | AppBar with back arrow, fields: Full Name, Email, Phone Number, Home Address, Password, Confirm Password (inline validators; phone must be 10–15 digits) | Login → on success `/customer` (clears the stack) |
| Forgot password | `auth/forgot_password_screen.dart` | Send a Firebase reset email | AppBar "Forgot Password", "Reset Password" heading, email field, SEND RESET LINK, snackbars | Login → pops back |
| `auth_gate.dart`, `role_router.dart` | `auth/` | A signed-in check and a role switch | **Defined but never used anywhere** (see §3) | – |

### 2.2 Customer

| Screen | File | Purpose | Main widgets | Reached from → Goes to |
|---|---|---|---|---|
| Customer shell | `customer/customer_main_screen.dart` | Bottom navigation host | `IndexedStack` + floating `NavigationBar` (Home, Tickets, Profile) | `/customer` → hosts the three tabs |
| Home | `customer/customer_home_screen.dart` | Overview | Blue rounded header ("Welcome, <first name>", "Customer Portal"), profile card (avatar, full name, "Valued Customer", "Active" pill), counters row (Assigned, In Progress, Resolved, Closed), orange gradient "Submit New Ticket" card, "Recent Tickets" (up to 3) with "View All" | Tab → `/customer/submit`, `/customer/tickets` (View All), `/customer/ticket_details` |
| Tickets | `customer/my_tickets_screen.dart` | List and search own tickets | Search field, horizontal filter chips (All, New, Assigned, In Progress, Resolved, Cancelled), ticket cards (id, status badge, title, 2-line description, date, "View Details") | Tab or Home "View All" → `/customer/ticket_details` |
| Ticket details | `customer/ticket_details_screen.dart` | Track one ticket | AppBar "Ticket Details"; sections: Ticket Status (badge + 4-step vertical timeline), red outlined **Cancel Ticket** button (New/Assigned only, with confirm dialog), Ticket Info, Technician Info (`TechnicianInfoCard`), Customer Info, Activity Log, Attachments | Tickets/Home → pops after cancel |
| Submit ticket | `customer/submit_ticket_screen.dart` | Create a ticket | AppBar; **Fill Form / AI Mode** toggle; AI "Describe Your Issue" card; cards: Issue Details (category dropdown, title, description), Location (address, area dropdown, "Use Current Location"), Additional Info (contact number, attachment box with preview, Replace/Remove); orange Submit button | Home → pops on success |
| Profile | `customer/profile_screen.dart` | View account, tools, logout | AppBar "My Profile", avatar + name, Contact Information (phone, address), **Internet Speed Test** tile, Logout button | Tab → `SpeedTestScreen` (plain `MaterialPageRoute`), `/login` on logout |
| Speed test | `customer/speed_test_screen.dart` | Run speedtest.net inside the app | AppBar with refresh, linear progress bar, `WebViewWidget`; on a main-page load failure a "Could not load…" message with a Retry button | Profile → back |

### 2.3 Technician

| Screen | File | Purpose | Main widgets | Reached from → Goes to |
|---|---|---|---|---|
| Technician shell | `technician/technician_main_screen.dart` | Bottom nav host | `IndexedStack` + `NavigationBar` (Home, Tasks, Analytics, Profile) | `/tech` |
| My Jobs (home) | `technician/tech_home_screen.dart` | Today's jobs | AppBar "My Jobs / Technician Portal" with logout icon, blue header with counters (Assigned, In Progress, Resolved, Closed), filter chips (All, Assigned, In Progress, Resolved, Closed, Cancelled), job cards ("START JOB >" hint on assigned) | Tab → `/tech/ticket` |
| My Tasks | `technician/assigned_ticket_list_screen.dart` | Searchable list of own tickets | AppBar "My Tasks", blue search bar, status chips (same six), ticket cards (badge, date, id, title, description, address, "View Details") | Tab → `/tech/ticket` |
| Ticket detail | `technician/ticket_detail_screen.dart` | Work one ticket | Sections: Update Job Status (status card + **START JOB** or a hint card), Actions (**CHECKLIST**, **REPORT** buttons; hidden for cancelled), Progress Timeline, Ticket Info, Activity Log, Attachments | Lists → `/tech/checklist`, `/tech/report` |
| Checklist | `technician/checklist_screen.dart` | AI troubleshooting checklist | Blue header with title, category pill, progress bar; empty state "No checklist yet" + **GENERATE AI CHECKLIST**; items (checkbox, title, detail, priority, time); **Regenerate Checklist** (dialog: Replace All / Add New Items); "TICKET READY FOR REPORT" when all done | Ticket detail → pops |
| Report | `technician/report_screen.dart` | Write and submit the service report | Sections: Issue Summary, Steps Taken, Resolution Summary (read-only, generated from a template), Technician Notes (editable), Proof of Completion (optional photo/PDF with Replace/Remove), Technician Sign-off (required signature pad), supervisor comments and sign-off (read-only after submit); buttons: Generate Report → then Export as PDF + Submit Report side by side | Ticket detail → pops after submit |
| Analytics | `technician/tech_analytics_screen.dart` | Personal stats | "My Analytics" header; Performance Summary (Total Assigned, In Progress, Resolved, Resolution Rate); Checklist Performance; Quick Analytics (Resolved This Week bars, Tickets by Category) | Tab |
| Profile | `technician/profile_screen.dart` | Account + coverage | "My Profile", avatar, name, "FIELD TECHNICIAN" pill, Staff ID, Email, Specialization, **Coverage Areas** chip grid (tap toggles and saves immediately), LOGOUT | Tab → `/login` |
| `complete_ticket_screen.dart`, `troubleshooting_screen.dart` | `technician/` | – | **Empty files (0 bytes)**, not used | – |

### 2.4 Supervisor

| Screen | File | Purpose | Main widgets | Reached from → Goes to |
|---|---|---|---|---|
| Supervisor shell | `supervisor/supervisor_main_screen.dart` | Bottom nav host | `IndexedStack` + `NavigationBar` (Home, Tickets, Analytics, Profile) | `/supervisor` |
| Home | `supervisor/supervisor_home_screen.dart` | Dashboard | Tall blue header ("Welcome back,", name), **Overview** (six KPI cards), **Quick Analytics** (Status Distribution stacked bar + legend, Weekly Ticket Volume bars), **Tickets by Category** (4 tappable filter cards), **Recent Tickets** (5 or 10) with "View All" (switches to the Tickets tab) | Tab → `/supervisor/ticket`, `/supervisor/assign` |
| Tickets | `supervisor/incoming_tickets_screen.dart` | All tickets | AppBar "Incoming Tickets", blue search + chips (All, New, Assigned, In Progress, Resolved, Cancelled), cards with "Assign Now" for New | Tab → `/supervisor/ticket`, `/supervisor/assign` |
| Ticket detail | `supervisor/ticket_detail_screen.dart` | Review, assign, sign off | AppBar "Supervisor View"; state card (Assign Technician for New), Ticket Progress, Assigned Technician (+ assignment note), Ticket Info, Activity Log, **Service Report** (report view with proof and technician signature, supervisor comments card, sign-off pad "SIGN OFF & CLOSE", orange **Export Report as PDF**) | Lists → `/supervisor/assign` |
| Assign | `supervisor/assign_ticket_screen.dart` | Manual assignment | Ticket summary, notice "This ticket was auto-assigned by AI. You can override it below." when applicable, technician picker, confirm button (exact picker widgets not fully reviewed) | Lists/detail → pops |
| Analytics | `supervisor/technician_performance_screen.dart` | Rank technicians | AppBar "Performance Overview"; blue KPI header (Total Techs, Resolved); top performer card; fl_chart bar chart of tickets per technician; search; "Technician Rankings" cards (specialization, status chips, coverage-area chips, completion bar, reports submitted) | Tab |
| Profile | `supervisor/profile_screen.dart` | Account | "Supervisor Profile", avatar, name, "SUPERVISOR" pill, Email, Staff ID, Department, LOGOUT | Tab → `/login` |

---

## 3. Navigation structure

**Mechanism:** Flutter's classic `Navigator` with named routes through `onGenerateRoute` in `lib/router.dart`. There is no `go_router`/`auto_route`.

**Entry point.** `lib/app.dart` sets `home: const LoginScreen()`. It does **not** use `AuthGate` or `RoleRouter`, which exist in `lib/features/auth/` but are referenced nowhere. In practice the app always opens on the login screen. From the code, a user who is still signed in with Firebase would also see the login screen on each launch. I did not verify this by running the app.

**Role routing after login.** `LoginScreen._handleLogin` signs in, reads `users/{uid}.role`, and calls `pushReplacementNamed` to `/customer`, `/supervisor` or `/tech`. An unknown role shows "User role not found." There is no route guard: roles are not checked when a named route is pushed.

**Routes** (`router.dart`):

| Route | Screen | Argument |
|---|---|---|
| `/login`, `/register`, `/forgot-password` | Login, Register, Forgot password | – |
| `/customer` | Customer shell | – |
| `/customer/tickets`, `/customer/profile` | Standalone copies of the **tab** screens | – |
| `/customer/submit` | Submit ticket | – |
| `/customer/ticket_details` | Customer ticket details | ticket id (String) |
| `/tech` | Technician shell | – |
| `/tech/ticket`, `/tech/checklist`, `/tech/report` | Detail, checklist, report | ticket id (String) |
| `/supervisor` | Supervisor shell | – |
| `/supervisor/ticket` | Supervisor ticket detail | ticket id (String), cast without a null check |
| `/supervisor/assign` | Assign | ticket id (String), validated |
| *(none)* | Speed test | pushed with `MaterialPageRoute` from the customer Profile |

**Bottom navigation.** All three shells use the same pattern: `IndexedStack` (tabs keep their state) and a floating `NavigationBar` (height 56, white, inside a `ClipRRect` radius 16 with 8px margins, `labelBehavior: onlyShowSelected`, indicator = blue at 10% opacity, icons 20px / selected 22px).

| Role | Tabs |
|---|---|
| Customer | Home · Tickets · Profile |
| Technician | Home · Tasks · Analytics · Profile |
| Supervisor | Home · Tickets · Analytics · Profile |

No drawers, tab bars or nested navigators are used. Back navigation uses the AppBar arrow or system back. Logout: `pushNamedAndRemoveUntil('/login')` from each profile (the technician home also has a logout icon in the AppBar).

**Quirk:** the customer Home "View All" pushes `/customer/tickets` as a full-screen route (no bottom bar), while the supervisor Home "View All" switches to the Tickets tab instead.

---

## 4. Current theme

**There is no app theme.** `MaterialApp` in `lib/app.dart` sets only `title`, `debugShowCheckedModeBanner: false`, `home` and `onGenerateRoute`: no `theme`, `darkTheme`, `ColorScheme`, `TextTheme` or component themes anywhere in `lib/`. `Theme.of(context)` is never called. The app therefore runs on Flutter's default Material theme, and its look comes from **hard-coded values repeated in each widget**. There is no dark mode.

### 4.1 Colors (hard-coded)

| Hex | Role (as used) | Approx. uses in `lib/features` |
|---|---|---|
| `#005CAB` | **Primary blue**: headers, AppBars, primary/outlined buttons, links, selected states | ~140 |
| `#FF6600` | **Accent orange**: main call-to-action buttons (Submit, Assign, Sign off, Export PDF), "Start Job" hint | ~27 |
| `#FF8800` | End of the orange gradient on the "Submit New Ticket" card | 1 |
| `#CC5200` | Darker orange (one use) | 1 |
| `#F5F5F5` | Page background | ~25 |
| `#333333` | Main text / headings | ~50 |
| `#1A1A1A` / `#555555` | Darker headings (technician performance) / secondary text | 5 / 2 |
| `#005CAB` at 10% (`0x1A005CAB`) | Navigation indicator tint | 1 |

Beyond these there are ~650 uses of Material `Colors.*` (greys, green, red, purple, orange, blue) and ~113 `withOpacity(...)` calls (deprecated in current Flutter).

### 4.2 Status colors

Status colour is chosen separately in each screen. The values differ:

| Status | Customer screens | Supervisor Home | Supervisor Tickets list | Technician screens |
|---|---|---|---|---|
| NEW | orange | red | red | red (only shown if ever present) |
| ASSIGNED | blue | blue | blue | blue |
| IN_PROGRESS | purple | purple | **orange** | purple |
| RESOLVED | green | green | green | green |
| CLOSED | grey | grey | grey (default case) | grey |
| CANCELLED | `red.shade700` on `red.shade50` (shared helper `lib/utils/cancelled_status.dart`) | same | same | same |

### 4.3 Typography

- **Font family:** no custom fonts or `google_fonts`; nothing declared in `pubspec.yaml`. The platform default is used (Roboto on Android).
- **Sizes in use** (count of occurrences): 12 (49), 13 (48), 14 (34), 18 (28), 16 (24), 11 (16), 15 (11), 24 (10), 10 (9), 22 (6), plus 9, 17, 20 and 40. Roughly 14 distinct sizes with no named scale.
- **Weights:** `FontWeight.bold` 175 uses, `w600` 27, others few (`w500`, `w700`, `w800`, `w900`).
- **Common patterns:** screen title in AppBar bold; section title 18 bold `#333333`; card title 16 bold; body 13–14 grey; badge text 10–12 bold; big hero text 24–32 bold white on blue.

### 4.4 Shape, elevation, spacing

- **Corner radius:** 12 (39), 16 (38), 10 (31), 15 (30), 20 (16), 8 (9). Cards are usually 15–16, inputs and buttons 10–12, badges 12–20.
- **Elevation:** almost none. Cards use white fill with a soft `BoxShadow` (black at 3–10% opacity, blur ~10, offset (0,4)); AppBars use `elevation: 0`.
- **Spacing:** page padding mostly 16–20, card padding 16–20, gaps of 8/12/16/24; there are no spacing constants.

### 4.5 Components

- **AppBar:** `backgroundColor #005CAB`, `foregroundColor white`, `elevation 0`, bold title: set per screen. Many screens skip the AppBar and draw a custom blue header block with bottom radius 30 (or 80 on login).
- **Primary button:** `ElevatedButton`, orange (`#FF6600`) or blue, white text, radius 10–12, vertical padding 14–16.
- **Secondary button:** `OutlinedButton` with blue border and blue text, same radius.
- **Text buttons:** blue text.
- **Inputs:** `OutlineInputBorder` radius 10, grey-300 border, blue 2px focus border, light grey fill (`grey[50]`), prefix icon, content padding 16×14. Defined once in `submit_ticket_screen._inputDecoration` and re-written inline elsewhere (login, register, forgot password).
- **Chips:** `ChoiceChip` (selected = blue on white-bg lists, white on blue-bg lists).
- **Status badge:** small rounded container, tinted background (10% of the status colour), bold coloured text.
- **Navigation bar:** see §3.
- **Feedback:** `SnackBar` with explicit colours (green success, red error, orange warning); `AlertDialog` radius 16 for confirmations.

---

## 5. Reusable widgets / components

There is **no shared widgets folder** (`lib/widgets` does not exist). Almost every component is a private method repeated inside each screen file.

**Genuinely shared (cross-file):**

| Item | File | Used by |
|---|---|---|
| `CancelledStatus` (colours, label, `isCancelled`, strikethrough title style) | `lib/utils/cancelled_status.dart` | 10+ screens |
| `pickImageWithChoice()` (bottom sheet: Take photo / Choose from gallery / Choose PDF) | `lib/utils/image_picker_helper.dart` | Submit ticket, Report |
| `ServiceAreas.all` (area list for dropdowns and chips) | `lib/core/constants/service_areas.dart` | Submit ticket, technician profile, AI prompt |
| `TicketStatus` enum + `displayName` | `lib/utils/enums.dart` | Customer home only |
| `TechnicianInfoCard` (public widget) | defined inside `customer/ticket_details_screen.dart` | That screen only |

**Duplicated private helpers** (same job, written separately per file):

| Helper | Defined in |
|---|---|
| `_buildStatusBadge` | 7 files (customer home, my tickets, customer details, supervisor home, incoming tickets, tech home, assigned list) |
| `_buildEmptyState` | 7 files |
| `_buildCard` | 5 files |
| `_buildSectionTitle` | 4 files |
| `_buildFilterChip` | 4 files |
| `_buildInfoRow` | 4 files |
| `_buildInfoCard`, `_buildActivityLogCard` | 3 files each |
| `_buildStatusTimelineCard` | 2 files (supervisor, technician) |
| `_buildCounter` | 2 files |
| `_buildLegendItem` | 2 files |
| `_formatTimestamp` | 3 files |
| Status label helpers (`_statusLabel`, `_displayStatus`, `_formatStatusLabel`, `_formatFilterLabel`) | 4 files |

---

## 6. UI states: loading, empty, error

General pattern: `StreamBuilder` (23 uses) or `FutureBuilder` (3) wraps the data; `ConnectionState.waiting` shows a centred `CircularProgressIndicator`; `hasError` shows centred text `Error: <message>`.

| Screen | Loading | Empty | Error |
|---|---|---|---|
| Login / Register / Forgot password | Spinner inside the button | – | Login: inline red error box; Register/Forgot: snackbar |
| Customer Home | Centred spinner | "No tickets found" icon + text | `Error: …` text |
| Customer Tickets | Centred spinner | Icon + title + subtitle (different text for "no tickets" vs "no match for filter") | "Something went wrong:…" text |
| Customer Ticket details | Centred spinner | "Ticket not found." | "Something went wrong:…"; cancel errors in snackbar |
| Submit ticket | Spinners in buttons (extract, location, upload) | – | Snackbars (red/orange/green) |
| Customer / Supervisor / Technician Profile | Centred spinner | "User profile not found" / "Error" scaffold | `Error` text |
| Speed test | Linear progress bar | – | Message + **Retry** button on main-page failure (only screen with a retry) |
| Tech Home / My Tasks | Centred spinner | Icon + text ("No assigned tickets yet" / "No active tasks"); chip-specific texts | `Error: …` text |
| Technician Ticket detail | Spinner | "Ticket not found" scaffold | snackbars |
| Checklist | Spinner; "Generating…" on button | "No checklist yet" + generate button | Snackbar |
| Report | Spinner | – | Snackbars |
| Tech Analytics | Spinner | – (shows zeros) | `Error: …` text |
| Supervisor Home / Tickets / Analytics | Spinner | Icon + text (Tickets: "All caught up!") | `Error: …` text |
| Supervisor ticket detail | Spinner | "Ticket not found" | Snackbars |
| Assign | Spinner | – | Error scaffolds and snackbars |

**Not handled anywhere:** pull-to-refresh (`RefreshIndicator` is not used), skeleton/shimmer loading, offline messages, retry buttons (except the speed test).

---

## 7. AI features in the UI

Gemini (`gemini-2.5-flash`) is called directly from the app in two places.

### 7.1 Ticket auto-fill: Submit Ticket screen
1. At the top of the form is a segmented toggle, **Fill Form | AI Mode** (white pill, selected side filled blue, `auto_awesome` icon on AI Mode).
2. In AI Mode a card appears titled **"Describe Your Issue"** (sparkle icon) with a 5-line text field (hint: "e.g. My internet has been down since morning, I'm at Puchong…") and a blue **Extract Details** button (spinner and "Extracting…" while running).
3. On success the **same form below the card** is filled in: Category, Title, Description, Service Address (only if the text mentioned a place) and Area (only if it is one of the known areas). A green snackbar says "Details extracted! Please review and complete the form."
4. The filled fields are ordinary fields: the user can edit anything. Contact number and attachment are not filled by AI.
5. If the text is not a service complaint, an "Invalid Input" dialog with example sentences is shown and nothing is filled. Failures show a red snackbar.
6. There is **no visual marker** on the AI-filled fields (no "AI" tag, highlight or per-field undo), and the AI card stays visible above the form after extraction.

### 7.2 Troubleshooting checklist: Technician Checklist screen
- Empty state "No checklist yet" with the button **GENERATE AI CHECKLIST**.
- Items show a checkbox, title, detail text, a priority chip and an estimated time. The header shows a progress bar of completed items.
- **Regenerate Checklist** opens a dialog: *Replace All* or *Add New Items*.
- Items can only be ticked; they cannot be edited or deleted.
- When all items are done, a **TICKET READY FOR REPORT** button appears.

### 7.3 Related, not AI
- **Generate Report** on the Report screen builds the report from the ticket description and checklist with a fixed template; it does not call Gemini, though the wording could suggest it does.
- **Auto-assignment** (scoring by skill, area, workload, history) has no AI call. It is described to the supervisor as "auto-assigned by AI" on the Assign screen, which is not accurate.

---

## 8. Packages affecting the UI

| Package | Version | UI role |
|---|---|---|
| `flutter` Material | SDK | Entire UI (Material widgets, default theme, `NavigationBar`) |
| `fl_chart` | ^1.2.0 | Supervisor Analytics bar chart (other charts are hand-built `Container` bars) |
| `webview_flutter` | ^4.14.1 | Speed test screen |
| `signature` | ^6.4.0 | Technician and supervisor signature pads |
| `image_picker` | ^1.1.2 | Take photo / gallery |
| `file_picker` | ^8.0.7 | PDF choice (and previous image picker in `CloudinaryService.uploadFile`) |
| `pdf`, `printing` | ^3.10.8, ^5.12.0 | PDF export and print dialog |
| `geolocator`, `geocoding` | ^12.0.0, ^3.0.0 | "Use Current Location" address autofill |
| `google_generative_ai` | ^0.4.3 | AI features (§7) |
| `cupertino_icons` | ^1.0.8 | Declared, **no usage found** |
| `provider` | ^6.1.5+1 | Declared, **not imported anywhere** |

**State management:** plain `setState` (~74 calls) plus Firestore `StreamBuilder`/`FutureBuilder`. No Provider, Bloc, Riverpod or similar is used. **Navigation:** Navigator 1.0 named routes. **Not present:** localization packages (all text is hard-coded English), custom fonts, theming packages.

---

## 9. UI problems noticed

**Theme and styling**
1. **No central theme.** Colours, radii, font sizes and paddings are repeated literally in every widget (≈250 `Color(0x…)` literals, ≈650 `Colors.*`). Changing the brand blue means editing ~140 places.
2. **Status colours are inconsistent** between screens (NEW is orange on customer screens but red on supervisor/technician screens; IN_PROGRESS is orange on the supervisor Tickets list but purple elsewhere).
3. **Too many near-identical radii** (8/10/12/15/16/20) and ~14 font sizes with no scale; `FontWeight.bold` used for 175 of ~230 weights, so hierarchy relies on size rather than weight.
4. **Two header styles** are mixed: standard blue `AppBar` on some screens, a custom tall blue rounded header on others (login, customer/tech/supervisor home, profiles, analytics, checklist). The back-arrow and title placement differ.
5. **Deprecated API:** `withOpacity` appears ~113 times.

**Duplication**
6. A status badge, empty state, card, section title, filter chip and info row are each re-implemented 4–7 times (§5), with small visual differences between copies.
7. Status labels and colours are chosen in at least 10 separate switch statements; the `TicketStatus` enum is used by only one screen, and `UserRole` has `admin`, `technician`, `customer` but no `supervisor`, so it does not match the roles the app uses.

**Navigation and structure**
8. `AuthGate` and `RoleRouter` are unused; the app always starts on the login screen.
9. `/customer/tickets` and `/customer/profile` push duplicate full-screen copies of tab screens (no bottom bar).
10. Two empty screen files remain (`complete_ticket_screen.dart`, `troubleshooting_screen.dart`).
11. `/supervisor/ticket` casts its argument without checking for null.

**States and feedback**
12. No pull-to-refresh, skeleton loaders, offline state or retry buttons (apart from the speed test).
13. Error text is raw (`Error: <exception>`) on most list screens.
14. Spinners use the default colour rather than the brand blue.

**Responsiveness and accessibility**
15. Headers use fixed top paddings (for example `fromLTRB(20, 60, 20, 30)`) rather than `SafeArea`; `SafeArea` appears in only 3 files and `MediaQuery`/`LayoutBuilder` nowhere. Behaviour on notched or small screens was not tested.
16. No `Semantics` widgets and only 2 tooltips; many tappable `GestureDetector`/`InkWell` areas have no labels.
17. All UI text is hard-coded English; there is no localization.

**Content and wording**
18. The supervisor Home chart titled **"Weekly Ticket Volume"** actually counts all tickets by weekday of creation, not the last seven days.
19. "Generate Report" and the "auto-assigned by AI" notice may mislead users, because neither uses AI (§7.3).
20. The checklist cannot be edited, and AI-filled ticket fields are not marked, so users cannot tell which values came from AI.

---

*To keep this document accurate, update §2 and §4 when screens or styles change.*
