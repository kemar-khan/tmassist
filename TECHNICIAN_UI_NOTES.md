# Technician role: how it exists in the code today

Read-only survey. Nothing was changed except creating this file. Line numbers refer to the files as they are now.
"Not verified" marks anything I inferred from reading and did not run. No technician screen was run against Firebase.

Files in `lib/features/technician/`:
`technician_main_screen.dart` (72 lines), `tech_home_screen.dart` (556), `assigned_ticket_list_screen.dart` (415), `ticket_detail_screen.dart` (892), `checklist_screen.dart` (658), `report_screen.dart` (1015), `tech_analytics_screen.dart` (610), `profile_screen.dart` (395), plus two 1-line empty files, `complete_ticket_screen.dart` and `troubleshooting_screen.dart` (not imported, not routed).
Services used: `core/services/checklist_service.dart` (Gemini checklist), `report_service.dart`, `report_pdf_service.dart`, `cloudinary_service.dart`, `utils/image_picker_helper.dart`, `utils/cancelled_status.dart`.
There are no technician-specific shared widgets. Every card, chip, badge and timeline is a private method inside its screen, and no technician file imports anything from `lib/widgets/` or `lib/core/theme/`.

Routes (`lib/router.dart`): `/tech` → `TechnicianMainScreen`; `/tech/ticket` (ticketId) → `TicketDetailScreen`; `/tech/checklist` (ticketId) → `ChecklistScreen`; `/tech/report` (ticketId) → `ReportScreen`. The three ticket routes cast the argument unchecked (`as String`).
Entry: `LoginScreen` reads `users/{uid}.role`; `'technician'` goes to `pushReplacementNamed('/tech')` (`login_screen.dart:62-63`).

---

## 9. THE SHELL (`technician_main_screen.dart`)

- `IndexedStack` of four tabs; `_screens` is a `const` list (line 17).
- Bottom bar: a Material `NavigationBar` (lines 34-69): height 56, white, inside `Padding(8,0,8,8)` and `ClipRRect(16)`, `labelBehavior: onlyShowSelected`, indicator `0xFF005CAB` with `withOpacity(0.10)`. The Scaffold has no `extendBody`; it is not `AppBottomNav`.

| # | Label | Icon (outlined / selected) | Screen | Its title |
|---|---|---|---|---|
| 0 | Home | `home_outlined` / `home_rounded` | `TechHomeScreen` | AppBar "My Jobs" + "Technician Portal" |
| 1 | Tasks | `assignment_outlined` / `assignment_rounded` | `AssignedTicketsScreen` | AppBar "My Tasks" |
| 2 | Analytics | `bar_chart_outlined` / `bar_chart_rounded` | `TechAnalyticsScreen` | no AppBar; header text "My Analytics" |
| 3 | Profile | `person_outline` / `person_rounded` | `TechnicianProfileScreen` | AppBar "My Profile" |

- Leftover comments: `// ADD THIS` at lines 4, 20 and 57.
- Controls in AppBars: only `TechHomeScreen` has an action: a logout `IconButton` (`Icons.logout_rounded`, tooltip "Logout", lines 153-157). The Profile tab also has a "LOGOUT" button (see section 8).
- No drawer, no other AppBar actions.

---

## 1. SCREENS

### 1.1 Home / My Jobs (`tech_home_screen.dart`, class `TechHomeScreen`)

**Purpose / open**: tab 0. AppBar: Column "My Jobs" (bold 20) over "Technician Portal" (12), blue (`0xFF005CAB`), white text.

**Layout, top to bottom**
1. AppBar (above) with the logout `IconButton` (tooltip "Logout").
2. Blue rounded header (30px bottom corners): a white card with an orange circle avatar (person icon), `technicianName` (blue, 18 bold), the literal "Field Technician" (grey 14), and on the right "Today" over today's date (`d/m/yyyy`). Below it four counters (white number, label, 3px colour bar): "Assigned", "In Progress", "Resolved", "Closed".
3. Horizontal filter chips (`ChoiceChip`): All, Assigned, In Progress, Resolved, Closed, and `CancelledStatus.label` ("Cancelled").
4. Job list (`ListView.builder`, padding 16): per card: title (bold 16, strikethrough if cancelled) + status badge (UPPERCASE text such as "IN PROGRESS"), description (2 lines), calendar icon + date `d/m`, and on the right "START JOB >" (orange bold, only when ASSIGNED) or a chevron.

**States**
- Loading: a `Scaffold` with centred spinner and no AppBar (lines 51-55).
- Error: `'Error: ${snapshot.error}'` centred (no AppBar).
- Empty (no active tickets and not on Cancelled): icon, "No assigned tickets yet.", "Please wait for supervisor to assign a ticket."
- Filter empty: "No cancelled tickets." (Cancelled chip) or "No jobs matching this filter."

**Data**
- `users/{uid}.fullName` (fallback: auth email, then "Technician").
- Tickets query: `tickets` where `technicianId == uid`, ordered by `updatedAt` descending, streamed (lines 44-49).
- Cancelled tickets are removed from the list, counters and "All". The Cancelled chip shows only the cancelled ones with `technicianId == uid`.
- Counters count non-cancelled tickets by `status` (ASSIGNED, IN_PROGRESS, RESOLVED, CLOSED).
- Card fields: `title`, `description`, `status` (default 'ASSIGNED' if missing), `createdAt`.

**Taps**
- Chip: local filter only (read-only).
- Card: `pushNamed('/tech/ticket', arguments: ticketId)`.
- Logout icon: `FirebaseAuth.signOut()` then `pushReplacementNamed('/login')` (the Profile tab uses `pushNamedAndRemoveUntil` instead).
- No Firestore writes on this screen.

### 1.2 Tasks / My Tasks (`assigned_ticket_list_screen.dart`, class `AssignedTicketsScreen`)

**Purpose / open**: tab 1. AppBar "My Tasks" (blue). Same tickets as Home plus search.

**Layout**
1. Blue panel: search field (hint "Search by ID or Title...", white text on a 15%-white fill, search icon) and horizontal chips: All, Assigned, In Progress, Resolved, Closed, Cancelled. Filter values: 'All', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED', 'CLOSED', 'CANCELLED'.
2. List of cards: status badge (UPPERCASE) + date `d/m/yyyy` on top; ticket id (grey, bold 12); title (bold 17, strikethrough if cancelled, no line limit); description (2 lines); a row with an orange location icon, `address` (ellipsis, grey 12), and "View Details" + chevron (blue).

**States**
- Loading: centred spinner (inside the body, AppBar kept).
- Error: `'Error: …'`.
- Empty: default "No active tasks" / "All your assigned tickets are completed or closed."; Cancelled chip: "No cancelled tickets" / "Tickets cancelled by customers will appear here."; other chip: "No matching tickets" / "You have no tickets with this status."
- No user: AppBar "Error", "User not logged in".

**Data**
- Same query as Home (`technicianId == uid`, `orderBy updatedAt desc`, streamed in `build`).
- 'All' excludes cancelled tickets. The filter and search are client-side. Search matches title or document id, case-insensitive substring (the search field has no controller).
- Address shows `address`, falling back to the literal "Cyberjaya, Selangor" (line 187).

**Taps**: card → `/tech/ticket` (ticketId). No writes.

### 1.3 Job Details (`ticket_detail_screen.dart`, class `TicketDetailScreen`)

**Open**: `/tech/ticket` from either list. AppBar "Job Details" (blue, back button from the route). The error and not-found Scaffolds use AppBar "Error".
Streams `tickets/{id}`; a one-off `ref.get()` runs inside START JOB.

**Layout (top to bottom)**, each under an 18px bold section title:
1. "Update Job Status" card.
2. "Actions" (hidden for CANCELLED).
3. "Progress Timeline".
4. "Ticket Info".
5. "Activity Log".
6. "Attachments".

**1. Update Job Status card**: "Current Job Status" caption (+ small orange spinner while updating). A tinted status box with an icon and the UPPERCASE status text (e.g. "IN PROGRESS"; `_displayStatus(status).toUpperCase()`). Then per status:

| Status | Content below the status box |
|---|---|
| ASSIGNED | Orange full-width button **START JOB** |
| IN_PROGRESS | Hint card: "Complete the checklist, then submit your report to resolve this ticket." |
| RESOLVED | Green hint: "Job completed. Waiting for supervisor to close the ticket." |
| CLOSED | Grey hint: "This ticket has been closed." |
| CANCELLED | Red-tint box: "This ticket was cancelled by the customer. No further action is needed." |
| NEW / anything else | nothing (orange "info" icon style) |

While updating a `LinearProgressIndicator` (orange) shows under the card.

**2. Actions** (a `Row` of two `ElevatedButton.icon`s, shown for every status except CANCELLED):
- **CHECKLIST** (`checklist_rtl_rounded`, orange): enabled only when status is IN_PROGRESS; opens `/tech/checklist`.
- **REPORT** (`summarize_rounded`, blue): enabled when `(IN_PROGRESS and every checklistDone is true and the list is non-empty) or RESOLVED or CLOSED` (line 500; the precedence is `a && b || c || d`); opens `/tech/report`.
- Disabled buttons are grey (`shade300` background, `shade500` label), with no explanatory text. For ASSIGNED both are disabled.

**3. Progress Timeline**: 3 steps "Assigned", "In Progress", "Completed" (index: ASSIGNED 0, IN_PROGRESS 1, RESOLVED and CLOSED 2, else -1 so none complete). Completed steps are filled blue circles with a check; the current one has an orange ring.

**4. Ticket Info** rows: Customer Name, Ticket ID (`#UPPERCASE`), Category, Priority (orange), Submitted (`d/m/yyyy`), Address, then "Issue Description" with title (bold) and description.
Fields: `customerName`, `category`, `priority`, `createdAt`, `address`, `title`, `description` (see list B for the fallbacks).

**5. Activity Log** (newest first, dates `d/m h:mm`):
- "Ticket Created" / "System logged ticket."
- "Assigned" / "Assigned to your queue." (shown for any status other than NEW)
- "In Progress" / "You started working." (IN_PROGRESS, RESOLVED, CLOSED)
- "Resolved" / "You marked the job as resolved." (RESOLVED, CLOSED)
- Cancelled label / "The customer cancelled this ticket."

**6. Attachments**: image (`attachmentUrl`, height 250) or "No attachment uploaded".

**Writes**: START JOB only.
- It first reads the ticket; if the stored status is not ASSIGNED it shows an orange snackbar: "This ticket was cancelled by the customer." (if cancelled) or "This ticket can no longer be started."
- Otherwise it updates `status: 'IN_PROGRESS'` and `updatedAt`, then a green snackbar "Status updated to In Progress" (1 s). On failure a red snackbar "Failed to update status: $e".
- Resolving happens only through the report (see 1.5).

**Differences by status**: see the tables above. CLOSED and RESOLVED enable REPORT (read-only report when one exists). CANCELLED hides Actions entirely and shows no timeline progress.

### 1.4 Checklist (`checklist_screen.dart`, class `ChecklistScreen`)

**Open**: `/tech/checklist` from the CHECKLIST button (IN_PROGRESS only). No AppBar: a custom blue header with a back arrow (`arrow_back_ios`, no tooltip) and "Checklist Generation" (22 bold), the ticket title (1 line), a category pill, and a progress row: orange bar, `done/total` and `(NN%)`. Loading AppBar title is "Loading"; error AppBars say "Error"; not found: "Ticket not found".

**States**
- No checklist yet: auto_awesome icon, "No checklist yet", "Tap below to generate an AI-powered checklist customized for this specific issue.", and a full-width button "GENERATE AI CHECKLIST" (becomes "Generating..." with a spinner while running).
- With a checklist: one card per item, then an outlined button "Regenerate Checklist" (becomes "Generating..." with a small spinner).
- When all items are done (`progress == 1.0`) a green button appears at the bottom: "TICKET READY FOR REPORT" (it only calls `Navigator.pop`).

**Item card**: round 24px checkbox (a `GestureDetector`, no label or tooltip), title (bold 14, strikethrough and grey when done), a priority pill ("High" red, "Medium" orange, anything else green), `detail`, and a clock icon with `estimatedTime`. No notes field exists.

**How it is generated**
1. Button → `_handleGenerate`. If a checklist already exists, an `AlertDialog` "Regenerate Checklist" asks "What would you like to do with the current checklist?" with "Replace All" (red text) and "Add New Items" (filled blue). Dismissing does nothing.
2. `ChecklistService.generateChecklist(ticketId, category, title, description, existingItems, addToExisting)`:
   - Classifies a subcategory with keyword rules (`_detectSubcategory`) and loads a built-in knowledge base for it.
   - Reads up to 5 past tickets with the same `category` and status RESOLVED or CLOSED as context (on failure the context becomes "Could not retrieve similar tickets.").
   - Calls Gemini `gemini-2.5-flash` with a prompt asking for 5 to 8 items, each with `title`, `detail`, `priority`, `estimatedTime`, as a JSON array.
   - Parses the response with a regex (`_parseJsonArray`).
3. Saved to `tickets/{id}`: `checklistItems` (list of maps), `checklistDone` (list of bools, all false for new items; existing flags kept when adding), `updatedAt`.
4. Success snackbar (green) "Checklist generated successfully!".

**Checking an item**: tap writes `checklistDone` (whole list) and `updatedAt` to the ticket; the UI updates from the stream (no optimistic change). Failure: red snackbar "Failed to update: $e".

**Failure / slow AI**
- Any exception becomes "Checklist generation failed: …", shown as a red snackbar "Failed to generate checklist: …". No timeout is configured and there is no retry or cancel.
- If the AI returns text with no parseable items, the service returns an empty list; the screen then saves an empty checklist and still shows the green "Checklist generated successfully!" (the code comments say "no fallback list exists"). Not run.
- The loading indicator is only the button spinner and label.

### 1.5 Service Report (`report_screen.dart`, class `ReportScreen`)

**Open**: `/tech/report` from REPORT. No AppBar: a custom blue header with a back arrow (`arrow_back_ios`, no tooltip) and "Service Report". Loading: centred spinner; no ticket: "Ticket not found".
Data is loaded once in `initState` (`_loadData`): the ticket, an existing report (`reports/{id}`) and a draft (`drafts/{id}`); errors are swallowed (the screen just stops loading). Nothing is streamed.

**Sections (cards with an icon and a bold 14 title)**
1. Banner (only when a report exists): "Report submitted. View only mode."
2. "Issue Summary", "Steps Taken", "Resolution Summary": read-only text. Empty text shows the italic hint "Tap Generate Report to fill this section".
3. "Technician Notes": the only editable text, a 4-line `TextField`, hint "Add parts replaced, observations, or additional findings...". Read-only after submission ("No additional notes." if empty).
4. "Proof of Completion" (label "Optional" before submission):
   - Empty: a box with an icon and "Tap to attach a photo as proof" (becomes "Uploading..." with an hourglass).
   - Picking uses `pickImageWithChoice` (camera or gallery sheet) then `CloudinaryService().uploadFromPath`; a null pick shows an orange snackbar "No photo selected"; failure: red "Upload failed: $e". The new URL is saved to the draft.
   - With a proof: image (height 200, tap to zoom in a dialog) or, for a PDF URL, a red PDF icon with the file name. Before submission, two text buttons: "Replace" and "Remove" (red, no confirmation).
   - After submission: "No proof attached." if none.
5. "Technician Sign-off" (shown after Generate Report, or when a signature exists): label "Required"; text "Sign below to confirm this report before submitting."; a 160px `Signature` pad; a "Clear" text button. After submission: the saved image (100px) and "Signed by $name on d/m/yyyy".
6. After submission only: "Supervisor Comments" (if non-empty) and "Supervisor Sign-off" ("Signed by <supervisorName or Supervisor> on <date>") when a supervisor signature exists. Both are read-only.

**Button flow**
- No report generated: **Generate Report** (blue; "Generating..." with a spinner). It builds the text locally (no AI): Issue Summary = the ticket `description`; Steps Taken = each checklist title prefixed with a tick or cross; Resolution Summary = the fixed sentence "Issue has been resolved by the assigned technician. All critical checklist items have been completed successfully." It saves a draft (not awaited) and shows a green snackbar "Report generated successfully!".
- After generating: a row with **Export as PDF** (outlined, blue) and **Submit Report** (orange).
- After submission: only **Export as PDF**, full width.
- Export: `ReportPdfService.export(...)`. `_exportPdf` has no try/catch.

**Validation and messages**: Submit does nothing if no report is generated; empty pad: orange "Please sign before submitting"; unreadable signature: red "Could not read signature. Please sign again."; save failure: red "Failed to submit report: $e". There is no confirmation dialog.

**Submitting writes**
- `reports/{ticketId}` (set): `ticketId`, `ticketTitle`, `category`, `customerName`, `technicianName`, `address`, `createdAt`, `issueSummary`, `stepsTaken`, `resolutionSummary`, `technicianNotes`, `supervisorComments` (''), `proofUrl`, `technicianSignature` (base64 PNG), `technicianSignedAt`, plus `status: 'SUBMITTED'`, `submittedAt`, `updatedAt`.
- `tickets/{id}` update: `hasReport: true`, `status: 'RESOLVED'`, `updatedAt`.
- Then the draft is deleted, a green snackbar "Report submitted successfully!" shows, and the screen pops.
- Read-only after submission: everything (all texts, notes, proof Replace/Remove, signature).

### 1.6 Analytics (`tech_analytics_screen.dart`, class `TechAnalyticsScreen`, a `StatelessWidget`)

**Open**: tab 2. No AppBar. Header (hard-coded 60px top padding): "My Analytics" and "Your personal performance overview".
Data: `tickets` where `technicianId == uid` (no ordering), streamed; cancelled tickets are excluded from everything.

| Element | Text | Calculation |
|---|---|---|
| KPI card | "Total Assigned" | number of non-cancelled tickets |
| KPI card | "In Progress" | status IN_PROGRESS |
| KPI card | "Resolved" | status RESOLVED or CLOSED |
| KPI card | "Resolution Rate" | `(resolved / total × 100)` rounded, with "%" ("0%" when total is 0) |
| Card "Checklist Performance" | "Avg. Checklist Completion" NN%, bar, "Based on N ticket(s) with checklist data" | average over tickets whose `checklistDone` is a non-empty list of (done / total) |
| Card "Quick Analytics" → "Resolved This Week" | 7 bars Mon–Sun (no numbers shown) | tickets with status RESOLVED or CLOSED whose `createdAt` is on or after `now − (weekday−1) days` (time of day kept), bucketed by the weekday of `createdAt`; height `100 × count/max`, min factor 0.1; bars under half height are paler |
| Card "Tickets by Category" | stacked bar + legend "Network (n)", "Hardware (n)", "Software (n)", "Other (n)" | counts by `category`; unknown categories count as Other |

- The Assigned count is computed and never shown (warning `unused_local_variable` at line 66).
- Empty state: no dedicated message. With no tickets all numbers are 0 and the category bar is a grey placeholder.
- Loading: centred spinner; error: `'Error: …'`.
- No charts package is used (hand-built bars).

### 1.7 Profile (`profile_screen.dart`, class `TechnicianProfileScreen`)

**Open**: tab 3. AppBar "My Profile" (blue); the error state AppBar says "Error".
Data: `users/{uid}` streamed.

**Layout**
1. Blue header: avatar with the first letter of the name (fallback 'T'), name, and a pill "FIELD TECHNICIAN" (hard-coded).
2. Rows: "Staff ID" (`staffId`, else `employeeId`, else "TECH-4402"), "Email Address" (`email`, else auth email, else "-"), "Specialization" (`specialization`, else "Fiber Optics / Broadband").
3. "Coverage Areas" card: header shows "No Areas Assigned" or "n area(s) assigned"; a 2-column grid of toggle chips, one per area in `ServiceAreas.all` except 'Other': Puchong, Subang Jaya, Shah Alam, Petaling Jaya, Kuala Lumpur, Klang. Selected = blue with a check icon, unselected = grey with a plus icon. Helper text: "Tap an area to add or remove it. New tickets in these areas are assigned to you first."
4. "LOGOUT" outlined red button.

**Behaviour**
- Tapping an area immediately writes the whole new list to `users/{uid}.coverageAreas` (an `update`, with no try/catch, no snackbar and no loading indication). The UI changes when the stream returns.
- LOGOUT: `FirebaseAuth.signOut()`, then `pushNamedAndRemoveUntil('/login', (route) => false)` (checked `context.mounted`). No confirmation.

---

## A. DEAD OR NO-OP CONTROLS

- `complete_ticket_screen.dart` and `troubleshooting_screen.dart`: one-line empty files, never imported or routed.
- `ticket_detail_screen.dart:859` `_allowedStatuses()`: never referenced (analyzer warning).
- `tech_analytics_screen.dart:66` the `assigned` count: computed, never shown.
- `report_screen.dart:5-7`: `printing`, `pdf` and `pdf/widgets` imports unused (analyzer warnings).
- `lib/features/auth/auth_gate.dart` and `role_router.dart` (which contains a technician branch) are not used: nothing references `AuthGate`, and the app's `home` is `LoginScreen`. Not verified at runtime.
- "TICKET READY FOR REPORT" (`checklist_screen.dart:398`) only pops the screen; it does not open the report.
- The "START JOB >" text on a Home card is not a button; the whole card opens the detail screen.
- `NEW` is handled by badge and label code in a few places, but a technician never sees NEW tickets (the queries are for tickets assigned to them).

## B. MADE-UP OR HARD-CODED FALLBACK VALUES

- `ticket_detail_screen.dart:122` category fallback "Hardware Issue".
- `ticket_detail_screen.dart:123` address fallback "123 Tech Lane, Block B, Floor 4".
- `ticket_detail_screen.dart:125` priority fallback "High". The app has no `priority` field elsewhere, so this shows "High" for every ticket (value shown in orange, line 653).
- `ticket_detail_screen.dart:126` customer name fallback "Azka".
- `ticket_detail_screen.dart:746-756` the activity-log times for "Assigned" and "In Progress" are `updatedAt` minus 1 hour and minus 15 minutes: invented timestamps. Only "Ticket Created" and "Resolved" use real dates.
- `assigned_ticket_list_screen.dart:187` address fallback "Cyberjaya, Selangor".
- `tech_home_screen.dart:212` literal "Field Technician" and `:141` "Technician Portal".
- `profile_screen.dart:51` staff ID fallback "TECH-4402"; `:54` specialization fallback "Fiber Optics / Broadband"; `:118` pill "FIELD TECHNICIAN"; `:50` email fallback "-".
- `report_screen.dart:128-130` the Resolution Summary is a fixed sentence that says "All critical checklist items have been completed successfully" whatever the checklist state.
- Status defaults: a missing `status` is treated as 'ASSIGNED' on Home, Tasks and the detail screen.
- Checklist item defaults: priority "Medium", estimated time "10 mins" when the AI omits them.

## C. TEXT-CONTRAST PROBLEMS

- `assigned_ticket_list_screen.dart:364-367, 371-372` (filter chips on the blue header): the label colour is `0xFF005CAB` for both states. Selected has a white fill (fine). Unselected has `Colors.white.withOpacity(0.15)` over the same blue header, so the label is blue on blue and effectively unreadable.
- `assigned_ticket_list_screen.dart:53` the search hint is white at 60% on a 15%-white fill over blue (low contrast; not measured).
- `assigned_ticket_list_screen.dart:235-238` ticket id in `grey[400]` on white (about 2:1); `:228` date `grey[500]` (about 2.7:1).
- `tech_home_screen.dart:455-462` "START JOB >" orange `0xFFFF6600` at size 12 on white (about 2.9:1).
- `tech_home_screen.dart:509-524` and `assigned_ticket_list_screen.dart:337-353` status badges: 10px text in `Colors.blue`, `Colors.purple`, `Colors.green` on a 10% tint of the same colour (small text, roughly 3:1 or less; not measured).
- `ticket_detail_screen.dart:526-527` disabled CHECKLIST/REPORT buttons: `grey.shade500` text on `grey.shade300` (about 2.6:1).
- `ticket_detail_screen.dart:653` Priority value in orange on white.
- `checklist_screen.dart:537` done-item detail text `grey[400]`; `:519-526` priority pill text at size 10 on a 10% tint.
- `report_screen.dart:771, 875` "Required" / "Optional" at size 11 in `grey[500]`; `:702` the notes hint `grey[400]`.
- Chip label colours that are fine: `tech_home_screen.dart:354-357` (white on blue when selected, `black87` on white otherwise).

## D. HARD-CODED COLOURS, SIZES AND FONTS

Counts per file (`withOpacity` / `Color(0x…)` / `Colors.*` / `fontSize`):

| File | withOpacity | Color(0x) | Colors.* | fontSize |
|---|---|---|---|---|
| `ticket_detail_screen.dart` | 9 | 17 | 43 | 18 |
| `report_screen.dart` | 6 | 16 | 49 | 14 |
| `checklist_screen.dart` | 8 | 9 | 37 | 10 |
| `tech_analytics_screen.dart` | 5 | 11 | 31 | 14 |
| `tech_home_screen.dart` | 4 | 10 | 30 | 14 |
| `profile_screen.dart` | 5 | 15 | 20 | 10 |
| `assigned_ticket_list_screen.dart` | 6 | 7 | 24 | 8 |
| `technician_main_screen.dart` | 1 | 1 | 1 | 0 |

- All eight files use them; no technician file uses the theme tokens.
- Most common values: `0xFF005CAB` (brand blue), `0xFFFF6600` (orange, including behind white text on buttons), `0xFFF5F5F5` (page background), `0xFF333333` (text), many `Colors.grey[...]`, `Colors.blue/purple/green/orange/red` for statuses and priorities, blur-10 `BoxShadow`s, radius 12/15/16/20 and font sizes 10–24.
- `withOpacity` appears about 44 times in this role.
- The custom blue AppBar/header pattern (blue background, white text, 30px or 50px rounded corner) is repeated in every screen.

**Shared widgets that could be reused as they are**
- `StatusBadge` + `statusStyle` (the three duplicated badge methods in Home, Tasks and detail, plus the UPPERCASE labels).
- `TicketCard` (the Tasks card; Home would need an optional trailing action, which `TicketCard.action` already supports).
- `FilterChipRow` (Home and Tasks chips; it also fixes the unselected-label colour).
- `SectionCard`, `InfoRow` (detail Ticket Info, report sections, profile rows), `EmptyState` (all empty/error states).
- `AppTextField` (search; the notes field is multi-line), `AppBottomNav` (4 tabs fit), `HomeHeader` (+ `TicketStubPattern`, `HeaderIconBadge`), `AppSnack` (all snackbars), `AppButtonStyles.destructive` (Logout).
- `VerticalStatusTimeline` (3 steps: Assigned, In Progress, Resolved; the technician timeline's third label is "Completed", not "Resolved").
- `AppPickerField` / `showPickerSheet`: not needed unless a picker is introduced.
- No shared widget exists for the checklist item, the signature pad frame, the photo proof row or the coverage-area toggle chips.

## E. OVERFLOW RISKS AND ALL-CAPS TEXT

Overflow (not verified by running):
- `profile_screen.dart:227-247` `_buildProfileItem`: the label/value `Column` is a `Row` child without `Expanded`, so a long email or specialization will overflow.
- `profile_screen.dart:324-384` coverage grid: `childAspectRatio: 3.4` gives each tile a fixed height, and the label in each tile has no ellipsis, so long names or large text scale ("Petaling Jaya", "Kuala Lumpur") can clip.
- `checklist_screen.dart:266-285` header `Row`: back button + "Checklist Generation" (22 bold) are not wrapped in `Expanded`, so large text scale can overflow at 360dp.
- `tech_home_screen.dart:245-265` four counters in a `Row` with `spaceAround`: tight at large text scale.
- `tech_home_screen.dart:130-148` AppBar title with two lines (20 + 12) in the default toolbar height.
- `ticket_detail_screen.dart` Ticket Info `Flexible` value (right-aligned): long addresses wrap; the long id has no word-break handling beyond the default.
- Ticket titles in the Home and Tasks cards have no line limit (they wrap).
- A very long `technicianName` in the Home header card is in an `Expanded` without `maxLines`.

ALL CAPS visible text: "START JOB" (detail button), "START JOB >" (Home card), "CHECKLIST", "REPORT", "GENERATE AI CHECKLIST", "TICKET READY FOR REPORT", "LOGOUT", "FIELD TECHNICIAN", every status badge ("ASSIGNED", "IN PROGRESS", "RESOLVED", "CLOSED", "CANCELLED", from literals and `.toUpperCase()`), the status box text on the detail screen.

## F. BEHAVIOUR THAT LOOKS LIKE A BUG OR RISK

- **Streams created in `build()`** (each re-subscribe on `setState` and can flash a full-screen spinner):
  - `tech_home_screen.dart:34-49`: both the user stream and the tickets stream; changing a filter chip calls `setState`.
  - `assigned_ticket_list_screen.dart:88-92`: `setState` on every search keystroke and chip tap.
  - `ticket_detail_screen.dart:82-86`: START JOB calls `setState(_isUpdating)`, so the screen is replaced by the loading Scaffold during the update.
  - `checklist_screen.dart:191-195`: `_isGenerating` `setState` re-subscribes, so the "Loading" screen can replace the page while generating, instead of the button spinner staying visible.
  - `tech_analytics_screen.dart:19`: a `StatelessWidget`, so it does not re-subscribe on its own.
  - `profile_screen.dart:17`: a `StatelessWidget`.
- **Duplicate logout**: an icon in the Home AppBar and a button on Profile, using different navigation (`pushReplacementNamed` vs `pushNamedAndRemoveUntil`).
- **Analytics "Resolved This Week"** counts by `createdAt`, not by when the ticket was resolved, and the week start keeps the current time of day. The supervisor Home chart uses Monday 00:00; the supervisor Analytics tab uses the report's `submittedAt`. The technician numbers will not match the supervisor's.
- **Report gating**: from IN_PROGRESS the REPORT button needs a non-empty, fully ticked checklist, so the technician must generate a checklist first. If Gemini fails or returns nothing parseable the flow is blocked; an empty result is still saved and reported as success.
- **Demo risk, AI**: the checklist depends on the Gemini API key (`flutter_dotenv`) and network; no timeout, retry or offline message. `checklist_service.dart` contains many `TEMP-DEBUG` `debugPrint`/`print` calls (lines 862, 865).
- **Demo risk, report**: `_exportPdf` has no error handling (an export failure becomes an unhandled exception); `_generateReport` shows its snackbar without a `mounted` check; the draft save is not awaited and its failure is not handled; the Resolution Summary text claims the checklist is complete regardless.
- **Coverage toggle** has no error handling, feedback or in-progress state, and rewrites the whole list (two quick taps could overwrite each other).
- **Fabricated activity-log times** (see list B).
- **Inconsistent with the customer and supervisor roles**: every screen has a custom blue header or AppBar, hard-coded colours, no `SafeArea` except in the checklist and report headers, a non-floating bottom bar, uppercase labels, a logout icon in an AppBar, and `Analytics` with a hard-coded 60px top padding instead of the status-bar inset.
- The checklist and report screens have no AppBar and the back arrow has no tooltip or semantic label (`checklist_screen.dart:268`, `report_screen.dart:351`). The checklist checkbox is 24x24 (below 44dp).
- Report: no confirmation before "Submit Report", and Remove for the proof photo has no confirmation.
- The three ticket routes crash on a missing argument (`as String` with no check).

## G. UNREACHABLE OR MISSING ACTIONS

- Screens never reached by navigation: `complete_ticket_screen.dart` and `troubleshooting_screen.dart` (empty), `AuthGate`/`RoleRouter` (see A).
- A technician cannot: edit the generated Issue Summary, Steps Taken or Resolution Summary (only the notes); add or edit a checklist item by hand or delete a checklist (only regenerate); redo or amend a report after submitting; start a job from the list card; open the checklist or report for an ASSIGNED ticket (both disabled with no explanation); see a ticket's report or checklist once it is cancelled.
- There is no pull-to-refresh anywhere (all lists stream live), no notifications screen and no settings screen.
- The "Report" screen can only be reached from the detail screen.
