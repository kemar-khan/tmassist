# Supervisor role: how it exists in the code today

Read-only investigation. Sources: `lib/features/supervisor/*.dart` (7 files, about 4,700 lines), `lib/router.dart`, `lib/features/auth/login_screen.dart`, `lib/core/services/*`, `pubspec.yaml`.
Nothing under `lib/features/supervisor/` uses `lib/core/theme/` or `lib/widgets/`. The only shared import is `lib/utils/cancelled_status.dart`.

---

## 1. SCREEN INVENTORY

| Screen | File | Class | Route | Shared? | Supervisor-only? |
|---|---|---|---|---|---|
| Login | `features/auth/login_screen.dart` | `LoginScreen` | `/login` (and `home:` of the app) | shared by all roles | no |
| Supervisor shell (4 tabs) | `supervisor/supervisor_main_screen.dart` | `SupervisorMainScreen` | `/supervisor` | no | yes |
| Tab 1 Home (dashboard) | `supervisor/supervisor_home_screen.dart` | `SupervisorHomeScreen` | none (tab) | no | yes |
| Tab 2 Tickets | `supervisor/incoming_tickets_screen.dart` | `IncomingTicketsScreen` (AppBar title "Incoming Tickets") | none (tab) | no | yes |
| Tab 3 Analytics | `supervisor/technician_performance_screen.dart` | `TechnicianPerformanceScreen` (AppBar "Performance Overview") | none (tab) | no | yes |
| Tab 4 Profile | `supervisor/profile_screen.dart` | `SupervisorProfileScreen` (AppBar "Supervisor Profile") | none (tab) | no | yes |
| Assign Ticket | `supervisor/assign_ticket_screen.dart` | `AssignTicketScreen` | `/supervisor/assign`, argument = ticketId `String` | no | yes |
| Ticket detail ("Supervisor View") | `supervisor/ticket_detail_screen.dart` | `SupervisorTicketDetailScreen` | `/supervisor/ticket`, argument = ticketId `String` | no | yes |

**Dialogs, sheets and menus**
- One `Dialog` with `InteractiveViewer`: pinch-zoom of the technician's proof photo (`ticket_detail_screen.dart`, `_buildReportViewCard`).
- The technician selector is a `DropdownButtonFormField`, so its popup is the only menu-like element (`assign_ticket_screen.dart`).
- The PDF export goes through `ReportPdfService.export` (`core/services/report_pdf_service.dart`, uses `printing`/`pdf`). I did not inspect the UI it opens.
- Does not exist: bottom sheets, popup menus, drawers, confirmation dialogs (assign, sign-off and logout all act immediately), an AlertDialog of any kind.

**Loading, empty and error states today**

| Screen | Loading | Empty | Error |
|---|---|---|---|
| Home | `Scaffold` with centred `CircularProgressIndicator` (no AppBar, no header) | the Recent Tickets area shows plain text "No tickets found." | centred text `Error: …` |
| Tickets | centred spinner | custom `_buildEmptyState`: 80px grey icon, "All caught up!", "There are no tickets at the moment." or "There are no <status> tickets at the moment." | centred text `Error: …` |
| Analytics | centred spinner (three nested streams each show their own) | "No technicians found" (icon `person_off_rounded`); "No technicians matching your search" (`search_off_rounded`); a "No Activity This Week" card when nobody has weekly activity | `_buildErrorState`: red icon, "Something went wrong", message, Retry button (`setState(() {})`) |
| Profile | AppBar plus spinner | none | a Scaffold with AppBar "Error" and text `Error: …` |
| Assign | spinner Scaffold with no AppBar (so no back button) | "No technicians available." (orange box); "Ticket not found" | AppBar "Error" plus text |
| Ticket detail | spinner Scaffold with no AppBar | "Ticket not found" under AppBar "Error" | AppBar "Error" plus text |
| Detail: report section | small centred spinner while the report future loads | hidden entirely when the ticket has no report | none (a failed future just hides it) |

---

## 2. NAVIGATION

**Entry**
- `App` shows `LoginScreen` as `home`. After sign-in it reads `users/{uid}.role`.
- `role == 'supervisor'` goes to `pushReplacementNamed('/supervisor')`, which builds `SupervisorMainScreen`. The first tab is Home (index 0).
- `'customer'` goes to `/customer` and `'technician'` to `/tech`. Any other value or a missing role shows "User role not found."

**Shell** (`SupervisorMainScreen`)
- An `IndexedStack` of the four tabs, so tab state is preserved.
- Bottom bar: a Material 3 `NavigationBar`, 56px high, white, inside `Padding(8,0,8,8)` and `ClipRRect(16)`. It is not the shared `AppBottomNav`. The Scaffold does not use `extendBody`.
- Label behaviour is `onlyShowSelected`. No drawer and no AppBar actions anywhere in the role.

| # | Label | Icon (outlined / selected) |
|---|---|---|
| 0 | Home | `dashboard_outlined` / `dashboard_rounded` |
| 1 | Tickets | `confirmation_number_outlined` / `confirmation_number_rounded` |
| 2 | Analytics | `analytics_outlined` / `analytics_rounded` |
| 3 | Profile | `person_outline` / `person_rounded` |

**Flow map**
- Home: "View All" calls the shell's `onViewAllTickets`, which switches to tab 1 (no route). A ticket card goes to `/supervisor/ticket` (ticketId). "Assign" (NEW tickets only) goes to `/supervisor/assign` (ticketId). If the callback is null, "View All" instead pushes `IncomingTicketsScreen` directly (not reachable inside the shell today).
- Tickets: a card goes to `/supervisor/ticket`; "Assign Now" (NEW only) goes to `/supervisor/assign`.
- Analytics: no navigation out.
- Profile: Logout calls `signOut()`, then `pushNamedAndRemoveUntil('/login')`.
- Ticket detail: "ASSIGN TECHNICIAN" (NEW) and "Reassign Technician" (ASSIGNED) go to `/supervisor/assign` (ticketId).
- Assign: back arrow, "Cancel" and a successful assign all `Navigator.pop`. After a successful assign it pops back to wherever it was opened from.
- The `/supervisor/ticket` route casts the argument unchecked (`as String`). `/supervisor/assign` shows "Invalid ticket ID" if the argument is not a String.

---

## 3. WHAT THE SUPERVISOR CAN DO

**Home** (all read-only)
- Tap a category tile (Network / Hardware / Software / Other) to filter the Recent Tickets list locally. Tapping the same tile again clears it.
- "Clear" removes the filter. "View All" switches to the Tickets tab.
- Tap a ticket card to open its detail. "Assign" (NEW only) opens the assign screen.
- The header's person `IconButton` has an empty `onPressed` (comment says "Notifications").
- No pull to refresh (the data is a live stream).

**Tickets** (all read-only)
- Search field filters by title or document id, substring, case-insensitive (the query is not trimmed).
- Horizontal chips: All, NEW, ASSIGNED, IN_PROGRESS, RESOLVED, CANCELLED. There is no CLOSED chip.
- Tap a card to open the detail. "Assign Now" (NEW only) opens the assign screen.

**Analytics** (read-only)
- Search technicians by name (300 ms debounce).
- Touch a bar in the chart to see a tooltip "<name>\n<n> tickets". Retry on the error state.

**Profile**
- Logout: Firebase Auth `signOut()` (the only write in this tab), then returns to `/login`. No confirmation.

**Assign** (writes to Firestore)
- Pick a technician from the dropdown (name plus optional specialization pill).
- "CONFIRM ASSIGNMENT" reads the ticket and refuses if it is CANCELLED (orange snack "This ticket was cancelled by the customer."). Otherwise it updates `tickets/{id}` with `technicianId`, `technicianName`, `supervisorId`, `status: 'ASSIGNED'`, `assignmentType: 'MANUAL'` and `updatedAt`.
- It pops, then shows the snack "Ticket assigned to <name>". The button is disabled while loading or when there are no technicians.
- "Cancel" text button and the back arrow pop. Validation: "Please select a technician".

**Ticket detail** (writes where noted)
- Action card by status: NEW has "ASSIGN TECHNICIAN"; the other statuses show an info card only.
- "Reassign Technician" (ASSIGNED only) opens the assign screen.
- Tap the proof image to open a zoomable dialog.
- "Save Comment" calls `ReportService.addSupervisorComment` and writes to `reports/{ticketId}`. It is visible only when the report is not signed.
- RESOLVED and unsigned: a signature pad with Clear and "SIGN OFF & CLOSE". Sign-off checks a comment exists ("Add a comment before signing") and a signature exists ("Please sign in the box"). It runs one batch that updates `reports/{id}` (`supervisorComments`, `supervisorSignature` base64 PNG, `supervisorName`, `signedAt`, `updatedAt`) and `tickets/{id}` (`status: 'CLOSED'`, `updatedAt`).
- "Export Report as PDF" (read-only, only when a report exists).
- The technician card shows a phone `IconButton` with an empty handler when the assignment is not AUTO.
- Snacks on this screen: "Report signed and ticket closed", "Sign-off failed: …", "Comment saved successfully", "Failed to save comment: …", "PDF export failed: …".

---

## 4. DATA SHOWN ON EACH SCREEN

**Statuses stored** (uppercase strings in `tickets.status`): `NEW`, `ASSIGNED`, `IN_PROGRESS`, `RESOLVED`, `CLOSED`, `CANCELLED`. There is **no priority field** anywhere. Categories: `Network`, `Hardware`, `Software`, `Other` (anything else is counted as Other on Home). Areas (`ServiceAreas.all`): Puchong, Subang Jaya, Shah Alam, Petaling Jaya, Kuala Lumpur, Klang, Other.

**Home** (one `tickets` stream ordered by `createdAt` descending, plus `users/{uid}` for the name)
- Header: "Welcome back," and "<fullName or email or 'Supervisor'> | Supervisor".
- Seven counters. CANCELLED tickets are excluded from all of them, from the chart and from the list. Tickets are mapped to a small map: id, title, status, technicianId, technicianName, createdAt, area, category.
  - Total Tickets = count after excluding cancelled.
  - New Complaints = status NEW. Assigned, In Progress, Resolved and Closed = count of their status.
- Status Distribution: one stacked bar, each segment's `flex` is its count, plus a legend (New, Assigned, In Progress, Resolved, Closed). Grey placeholder bar when there are no tickets.
- Weekly Ticket Volume: 7 bars Mon–Sun. A ticket counts if `createdAt` is on or after this week's Monday (computed as now minus `weekday-1` days). Bar height = `100 * count/max`, minimum factor 0.1. Bars under half height get 30% opacity, others 80%.
- Tickets by Category: four tiles with a count each; helper text "Tap a card to filter the ticket list below."
- Recent Tickets: newest first, 5 rows (10 when a category filter is active). Each row has title (1 line, ellipsis), status badge, and assignee line ("Assigned: <technicianName>", "Assigned (ID: <first 8 chars>...)", or "Unassigned"). When filtering it shows "Showing: <cat> (<n>)".
- Status badge labels: New, Assigned, In Progress, Resolved, Closed, Cancelled.

**Tickets** (`tickets` stream, newest first)
- Per card: status badge (labels are UPPERCASE, from `_formatStatusLabel`; CLOSED falls to the default and shows "CLOSED"), date `d/m/yyyy`, the full document id, title (no line limit; strikethrough if cancelled), description (2 lines), and "Assign Now" on NEW.

**Analytics** (streams: `users` where role is technician, all `tickets`, all `reports`)
- Per technician, ignoring CANCELLED tickets:
  - `total` = tickets with `technicianId == tech.id`.
  - `assigned`, `inProgress`, `resolved` and `closed` = counts per status.
  - `completionRate` = (resolved + closed) / total × 100, or 0 when total is 0.
  - `resolvableTickets` = tickets that are RESOLVED or CLOSED; `reportsSubmitted` = how many of those have a document in `reports` with the same id.
  - Weekly activity = tickets of that technician whose `updatedAt` is after "now minus (weekday-1) days" (this keeps the current time of day, so it is not exactly Monday 00:00).
- Header band: "Total Techs" (number of technician users) and "Resolved" (sum of resolved + closed over technicians).
- "TOP PERFORMER" card: the technician with the most weekly activity (first wins ties), text "<n> activities this week". Otherwise the "No Activity This Week" card.
- Bar chart "Ticket Volume by Technician" (x = first name, y = `total`, fixed height 180).
- Rankings: sorted by completion rate descending. Each card has rank number (top 3 blue gradient), name, specialization (fallback "Generalist"), "NN% Success", a progress bar, four chips (Assigned, In Progress, Resolved, Closed), coverage-area chips (or "No coverage areas set"), and "Reports submitted (of completed tickets)" with "x / y" or "N/A".
- Progress colour: above 80 green, above 50 orange, otherwise red.

**Profile** (`users/{uid}`)
- Initial letter avatar, fullName (fallback email, then "Supervisor"), "SUPERVISOR" pill, Email Address, Staff ID (`staffId`, else `employeeId`, else the hard-coded fallback "TM-99821"), Department (`department`, else the fallback "Field Technician Supervisor"). The Staff ID row uses a phone icon.

**Assign** (`tickets/{id}` stream and `users` where role is technician)
- Ticket Summary (title, description). If `assignmentType == 'AUTO'` and `technicianId != null`: banner "This ticket was auto-assigned by AI. You can override it below."
- "Override Assignment" dropdown "Available Technicians": `fullName` (fallback "Unnamed Technician") plus `specialization` pill.

**Ticket detail** (`tickets/{id}` stream; report loaded with a one-off `getReport`)
- Fields: status, title, description, category, address, customerName, technicianName/Id, createdAt, updatedAt, assignmentNote, assignmentType.
- Top card by status:
  - NEW: "Ticket is Unassigned"
  - RESOLVED: "Resolved. Review the report and sign off to close it."
  - CLOSED: "This ticket is Closed"
  - CANCELLED: "This ticket was cancelled by the customer"
  - otherwise: "Technician is currently working on this"
- Ticket Progress: 4 steps (New, Assigned, In Progress, Resolved). CLOSED completes all four; CANCELLED completes none.
- Assigned Technician: name, caption "Assigned Technician", the assignment note box, "AUTO" pill when `assignmentType == 'AUTO'`, phone icon otherwise.
- Ticket Info: Customer Name, Ticket ID (`#UPPERCASE`), Category, Submitted (`d/m/yyyy`), Address, Issue Description (title, description).
- Activity Log (newest first, dates `d/m`):
  - Ticket Created: "Logged in system."
  - Assigned: "Assigned to <name>."
  - Work Started: "Technician is on site."
  - Resolved: "Technician marked as resolved."
  - Closed: "Supervisor closed the ticket."
  - Cancelled: "The customer cancelled this ticket."
  - All later entries reuse `updatedAt` for their date.
- Service Report (only if a report exists): Issue Summary, Steps Taken, Resolution Summary, Technician Notes ("No additional notes." when empty), Proof of Completion image (200px, tap to zoom), Technician Sign-off image plus "<technicianName> • <date>".
- Then: Supervisor Comments (4-line field, read-only once signed), Sign-off card (signed: image plus name and date; RESOLVED unsigned: pad; CLOSED without a signature: "Closed without sign-off"), and "Export Report as PDF".

---

## 5. CHARTS, TABLES, MAPS AND SPECIAL WIDGETS

- **`fl_chart` `BarChart`**: Analytics only, tickets per technician with a background rod, grid lines and a tooltip.
- **Hand-built charts on Home** (no package): the stacked status bar (`Row` of `Expanded` with `flex`) and the weekly volume bars (`Container` heights).
- **`signature` package** (`Signature`, `SignatureController`): the sign-off pad on the detail screen, exported as PNG and stored as base64.
- **`Image.network`**: the proof photo. **`Image.memory`**: signatures decoded from base64.
- **`printing` + `pdf`** (via `ReportPdfService`): PDF export. `ticket_detail_screen.dart` also imports `printing`, `pdf` and `pdf/widgets`, which I could not see being used there.
- Does not exist: maps, calendars, data tables or grids, WebViews, custom painters.
- Packages used by supervisor code: `flutter` (Material), `cloud_firestore`, `firebase_auth`, `fl_chart`, `signature`, `printing`, `pdf`, plus `dart:async`, `dart:convert`, `dart:typed_data`. `google_fonts` arrives only through the app theme.

---

## 6. LISTS AND LONG CONTENT

- No pagination anywhere. Every screen streams the whole `tickets` collection (Analytics also streams all `reports` and all technician `users`) and filters on the client.
- **Home recent list**: `ListView` with `shrinkWrap` inside the page scroll, 5 (or 10) rows. Each row shows 3 things: title (1 line, ellipsis), status badge, assignee text (no line limit). Page is one `SingleChildScrollView`.
- **Tickets list**: full-height `ListView`, 16px padding. Each card shows 6 things: status, date, id (about 20 characters), title (unlimited lines), description (2 lines), optional Assign button. Horizontal scroll: the chip row in the blue header (6 chips).
- **Analytics rankings**: a `ListView` of tall cards (rank, name with ellipsis, specialization without a limit, percentage, bar, 4 chips, coverage chips that wrap, report row). The bar chart shows every technician on one 180px-high axis with no scrolling, so many technicians will crowd the first-name labels.
- **Assign**: one dropdown; item rows are name (ellipsis, `Flexible`) plus a pill.
- **Detail**: long text fields (description, report summaries) are unlimited and wrap; the page is one `SingleChildScrollView`.
- Typical lengths: titles are free text from customers (tickets can be anywhere from a few words to full sentences); technician names are `fullName`; addresses are full Malaysian addresses.

---

## 7. CURRENT UI PROBLEMS (supervisor only)

Counts of hard-coded colour/size usage per file (`withOpacity` / `Color(0x…)` / `Colors.*` / `fontSize`):

| File | withOpacity | Color(0x) | Colors.* | fontSize |
|---|---|---|---|---|
| `supervisor_home_screen.dart` | 11 | 15 | 50 | 20 |
| `technician_performance_screen.dart` | 11 | 8 | 50 | 27 |
| `ticket_detail_screen.dart` | 4 | 31 | 53 | 30 |
| `incoming_tickets_screen.dart` | 10 | 6 | 28 | 6 |
| `assign_ticket_screen.dart` | 5 | 7 | 16 | 8 |
| `profile_screen.dart` | 3 | 9 | 11 | 6 |
| `supervisor_main_screen.dart` | 1 | 1 | 1 | 0 |

**Inconsistencies with the restyled customer screens**
- Every AppBar sets its own blue background, white foreground and bold title (`incoming_tickets_screen.dart`, `technician_performance_screen.dart`, `profile_screen.dart`, `ticket_detail_screen.dart`). The theme's light AppBar is ignored. The Assign screen has no AppBar at all (a 200px blue header with a 60px bottom-left radius).
- Shell: its own `NavigationBar` (`supervisor_main_screen.dart`) instead of `AppBottomNav`; uses `withOpacity`; not floating over the body, so the pages do not pad for it.
- Home header: a hard-coded 60px top padding (`supervisor_home_screen.dart:131`) instead of `HomeHeader`/safe area; the status bar is not handled.
- **Duplicated status badges, with different colours per screen**:
  - Home `_buildStatusBadge`: NEW red, ASSIGNED blue, IN_PROGRESS purple.
  - Tickets `_buildStatusBadge`: IN_PROGRESS orange, labels UPPERCASE.
  - Analytics `_statusChip`: orange.
  - Detail `_buildInfoStatusCard`.
  - None match `statusStyle` in `lib/widgets/status_style.dart`.
- **Duplicated ticket cards**: `_buildRecentTicketCard` (Home) and `_buildIncomingTicketCard` (Tickets); neither uses `TicketCard`.
- **Duplicated helpers in the detail screen**: `_buildCard`, `_buildSectionTitle`, `_buildInfoRow`, `_buildDivider`, `_buildActivityLogCard` and its own 4-step timeline (orange ring on the current step).
- Colours: Home KPI, legend and status bar use `Colors.red`/`blue`/`purple`/`green`/`grey`; orange `0xFFFF6600` hard-coded for Assign, Sign-off, Export and Confirm buttons.
- **Missing SafeArea**: none of the supervisor screens use it except the Assign header. Screens rely on AppBar/padding only.
- **Tap targets under 44dp**: Home "Assign" (`SizedBox(height: 30)`); the filter chips on Tickets are default chips; Analytics search-clear `IconButton` is icon size 20 without constraints.
- **Icon-only buttons without tooltip/Semantics**: Home header person button (also does nothing), Assign back arrow, Analytics search-clear, detail phone button (does nothing).
- **Possible overflow**:
  - `profile_screen.dart` `_buildProfileItem`: the label/value `Column` sits in a `Row` without `Expanded`, so a long email or department overflows.
  - `technician_performance_screen.dart`: the "Reports submitted (of completed tickets)" `Row` has a `Spacer` and no `Flexible` on the label; the top-performer name and the specialization text have no overflow handling.
  - `assign_ticket_screen.dart`: the dropdown item `Row` with name and pill.
  - Home KPI/category tiles use fixed 11–12px labels.
- Assign screen specifics: white scaffold, 32px padding, two stacked `SizedBox(16)`, fixed-height 55 button, a `CircularProgressIndicator` unsized inside the button. A heading uses blue text while other screens use neutral ink.
- Detail screen: `_buildActionCard` has a "CLOSE TICKET" spinner branch that can never run (see section 10).
- Performance fonts: weights `w800`/`w900` with negative letter spacing; card radius 24 and big soft shadows differ from `AppRadius`/`AppShadows`.

---

## 8. REUSE

**Usable as they are**
- `StatusBadge` + `statusStyle` (all status badges and chips; this also standardises the colours).
- `FilterChipRow` (Tickets filter; labels and order from the current chips, plus a CLOSED chip if you decide to add one).
- `SectionCard` (every card on detail and profile), `InfoRow` (Ticket Info, Profile rows), `EmptyState` (all empty states), `AppTextField` (comment field, search fields), `AppSnack` (all snackbars), `AppButtonStyles.destructive` (Logout).
- `AppBottomNav` with 4 `AppNavItem`s, `HomeHeader` + `HeaderOverlap` for the Home dashboard.
- `AppPickerField` + `showPickerSheet` for the technician selector (it needs a subtitle per option, for the specialization; today it only supports an optional leading icon).
- `TicketCard` with small additions: an optional assignee line and an optional trailing action ("Assign").

**Needs extending**
- `VerticalStatusTimeline` was changed to 3 steps (Assigned, In Progress, Resolved) for the customer screen. The supervisor detail screen shows New / Assigned / In Progress / Resolved, so it would need a parameter or its own widget.

**New shared widgets you would likely need**
- KPI/counter tile (icon, number, label, accent).
- Stacked status distribution bar with legend.
- Mini weekly bar chart (or an `fl_chart` theme helper so the technician chart matches the tokens).
- Selectable category tile.
- Technician ranking card (rank badge, name, specialization, percentage, completion bar, four count chips, coverage chips, report ratio row).
- Top-performer highlight card.
- Info banner / callout (auto-assign note, assignment note).
- Signature pad card with Clear and confirm buttons.
- Report text row (label above multi-line value).
- Technician row for the assigned-technician card and the picker.

---

## 9. SAMPLE REAL DATA (from code strings, invented names and numbers)

- **Titles** (example sentences from the AI dialog): "My internet is not working since this morning", "The WiFi router keeps disconnecting", "My TV box shows no signal", "Internet has been down since morning".
- **Ticket ids**: Firestore auto ids, e.g. `7fQ2kLmZpX9aB3cD4eRt` (20 characters).
- **Technicians** (invented): Aisyah Rahman, Daniel Lim, Farah Nabila, Hakim Yusof. Specializations: "Fiber Optics / Broadband" (the technician-profile fallback), "Network", "Hardware", "Software", "Generalist".
- **Coverage areas**: Puchong, Subang Jaya, Shah Alam, Petaling Jaya, Kuala Lumpur, Klang.
- **Supervisor profile fallbacks in code**: Staff ID "TM-99821", Department "Field Technician Supervisor".
- **Auto-assign notes** (`assignmentNote`): "Outside coverage area", "No matching specialist, assigned to general technician", "No matching specialist or coverage, assigned by workload".
- **Counts** (plausible): total 42, New 6, Assigned 9, In Progress 11, Resolved 8, Closed 8; categories Network 20, Hardware 9, Software 7, Other 6; weekly Mon–Sun 4, 7, 5, 9, 6, 2, 1.
- **Analytics**: Aisyah 12 tickets, 92% Success, Assigned 1, In Progress 0, Resolved 4, Closed 7, reports 11 / 11; Daniel 9 tickets, 67%, reports 5 / 6.
- **Report fields**: Issue Summary, Steps Taken, Resolution Summary, Technician Notes, Proof of Completion photo, technician signature, supervisor comment, supervisor signature.

---

## 10. QUESTIONS / AMBIGUITIES / DEAD CODE

- Home header's person `IconButton` has an empty handler with a "// Notifications" comment. The detail technician card's phone button is also an empty handler. There is no notifications screen.
- Tickets has no CLOSED chip, so closed tickets can only be found under "All" (they show an uppercase grey "CLOSED" badge), although CLOSED is a real status that Home counts.
- Detail screen's `_buildActionCard` still contains a `_isUpdating && buttonLabel == "CLOSE TICKET"` branch, but `_isUpdating` is never set to true: dead code left from before the sign-off flow.
- Analytics: `avgResolutionHours` is read in `_buildTechnicianCard` but is never populated, so `avgTimeLabel` is computed and never shown.
- Home has a stray `;` after the `closedTickets` calculation and a duplicated "// Bottom row of KPIs" comment (harmless).
- `SupervisorHomeScreen.onViewAllTickets` has a fallback that pushes `IncomingTicketsScreen` when null; inside the shell it is always set.
- `_sigController` (the signature pad controller) is not disposed in `dispose()`.
- The weekly boundary (Home vs Analytics) differs: Home uses tickets created since this week's Monday; Analytics uses `updatedAt` after (now − weekday+1 days), which keeps the current time of day.
- `lib/models/ticket.dart` and `lib/utils/enums.dart` (`UserRole` has `admin`, `technician`, `customer`, no supervisor) look unused by the supervisor code. The role string `'supervisor'` is only compared as plain text in the login screen.
- NEW tickets: `TicketService` calls `AutoAssignmentService.assignBestTechnician` right after creation, so a ticket normally becomes ASSIGNED by itself; the "Assign" flow is for tickets the auto-assignment did not handle or that the supervisor wants to override. Please confirm that is the intended flow, since the mockups will give NEW a lot of prominence.
- The detail report block uses a `FutureBuilder` on `getReport` inside the stream builder, so it re-fetches on each ticket update. Not a visual issue, but worth knowing when designing loading states.
- The Profile tab shows made-up fallbacks ("TM-99821", "Field Technician Supervisor") when the user document has no such fields. Decide whether to keep them in the redesign.
- I did not inspect `report_pdf_service.dart`, `checklist_service.dart` or any technician screens; supervisor-visible report fields were taken from the detail screen.
