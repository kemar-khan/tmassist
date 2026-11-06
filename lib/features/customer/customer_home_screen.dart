import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/ticket.dart';
import '../../utils/enums.dart';
import '../../utils/greeting.dart';
import '../../widgets/header_icon_badge.dart';
import '../../widgets/home_header.dart';
import '../../widgets/progress_stepper.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/status_style.dart';
import '../../widgets/ticket_stub_pattern.dart';
import 'speed_test_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  // Full name from the user's profile (users/{uid}.fullName).
  String? _fullName;

  // Created once (and again only on "Try Again"): a stream made inside build()
  // would re-subscribe on every rebuild.
  Stream<QuerySnapshot>? _ticketStream;

  @override
  void initState() {
    super.initState();
    _createStream();
    _loadFullName();
  }

  void _createStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _ticketStream = FirebaseFirestore.instance
        .collection('tickets')
        .where('customerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _loadFullName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final name = (doc.data()?['fullName'] ?? '').toString().trim();
      if (mounted && name.isNotEmpty) {
        setState(() => _fullName = name);
      }
    } catch (_) {
      // Keep the email-based fallback if the profile can't be read.
    }
  }

  TicketStatus _parseStatus(String status) {
    switch (status.toUpperCase()) {
      case 'NEW':
        return TicketStatus.newTicket;
      case 'ASSIGNED':
        return TicketStatus.assigned;
      case 'IN_PROGRESS':
        return TicketStatus.inProgress;
      case 'RESOLVED':
        return TicketStatus.resolved;
      case 'CLOSED':
        return TicketStatus.closed;
      case 'CANCELLED':
        return TicketStatus.cancelled;
      default:
        return TicketStatus.newTicket;
    }
  }

  Ticket _mapDocToTicket(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Ticket(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      status: _parseStatus(data['status'] ?? 'NEW'),
      createdBy: data['customerId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      assignedTo: data['technicianId'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    final userName =
        _fullName ?? firebaseUser.email?.split('@').first ?? 'User';
    final title =
        '${timeOfDayGreeting(DateTime.now())}, ${userName.split(' ').first}';

    // Solid brand-blue status bar with light icons, so it reads as part of
    // the header. Only this tab changes the style; the others keep the theme's.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.statusBarOnPrimary,
      child: Scaffold(
        body: StreamBuilder<QuerySnapshot>(
          stream: _ticketStream,
          builder: (context, snapshot) {
            // Only the first load shows the spinner; once data has arrived a
            // rebuild keeps showing it. The header stays visible meanwhile.
            if (!snapshot.hasData &&
                snapshot.connectionState == ConnectionState.waiting) {
              return CustomerHomeFrame(
                title: title,
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return CustomerHomeFrame(
                title: title,
                body: CustomerHomeLoadError(
                  onRetry: () => setState(_createStream),
                ),
              );
            }

            final tickets = (snapshot.data?.docs ?? [])
                .map((doc) => _mapDocToTicket(doc))
                .toList();

            // Calculate ticket counts
            final assignedCount = tickets
                .where((t) => t.status == TicketStatus.assigned)
                .length;
            final inProgressCount = tickets
                .where((t) => t.status == TicketStatus.inProgress)
                .length;
            // Resolved includes CLOSED: a closed ticket was resolved first.
            final resolvedCount = tickets
                .where(
                  (t) =>
                      t.status == TicketStatus.resolved ||
                      t.status == TicketStatus.closed,
                )
                .length;

            // Active ticket: the most recently updated ASSIGNED / IN_PROGRESS
            // one, taken from the same list (no extra query).
            final activeTickets = tickets
                .where(
                  (t) =>
                      t.status == TicketStatus.assigned ||
                      t.status == TicketStatus.inProgress,
                )
                .toList();
            final Ticket? activeTicket = activeTickets.isEmpty
                ? null
                : activeTickets.reduce(
                    (a, b) => b.updatedAt.isAfter(a.updatedAt) ? b : a,
                  );

            // The technician's name is already on the loaded ticket document.
            String? activeTechnicianName;
            if (activeTicket != null) {
              for (final doc in snapshot.data?.docs ?? const []) {
                if (doc.id == activeTicket.id) {
                  final name =
                      ((doc.data() as Map<String, dynamic>)['technicianName'] ??
                              '')
                          .toString()
                          .trim();
                  if (name.isNotEmpty) activeTechnicianName = name;
                }
              }
            }

            // The newest ticket (the query is ordered by createdAt, newest
            // first), with its real creation date or none.
            final docs = snapshot.data?.docs ?? const [];
            final Ticket? lastTicket = tickets.isEmpty ? null : tickets.first;
            DateTime? lastTicketDate;
            if (docs.isNotEmpty) {
              final created =
                  (docs.first.data() as Map<String, dynamic>)['createdAt'];
              if (created is Timestamp) lastTicketDate = created.toDate();
            }

            return CustomerHomeContent(
              title: title,
              assignedCount: assignedCount,
              inProgressCount: inProgressCount,
              resolvedCount: resolvedCount,
              activeTicket: activeTicket,
              activeTechnicianName: activeTechnicianName,
              lastTicket: lastTicket,
              lastTicketDate: lastTicketDate,
            );
          },
        ),
      ),
    );
  }
}

/// The blue header with the stub pattern and the customer icon. The counters
/// card, when given, overlaps its bottom edge.
Widget _buildHeader(String title, {Widget? counters}) {
  return HomeHeader(
    title: title,
    subtitle: 'Customer Portal',
    background: const TicketStubPattern(),
    trailing: const HeaderIconBadge(asset: 'assets/images/customer_icon.png'),
    overlapChild: counters,
  );
}

/// The header with [body] filling the space under it (loading and error).
class CustomerHomeFrame extends StatelessWidget {
  final String title;
  final Widget body;

  const CustomerHomeFrame({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(title),
        Expanded(child: body),
      ],
    );
  }
}

class CustomerHomeLoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const CustomerHomeLoadError({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.cancelledBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 32,
                  color: AppColors.cancelledFg,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Could not load your tickets.',
              textAlign: TextAlign.center,
              style: AppText.heading.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: AppSpacing.s2),
            TextButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}

/// Maps a ticket status to the stored value the shared status widgets expect.
String _statusValue(TicketStatus status) {
  switch (status) {
    case TicketStatus.newTicket:
      return 'NEW';
    case TicketStatus.assigned:
      return 'ASSIGNED';
    case TicketStatus.inProgress:
      return 'IN_PROGRESS';
    case TicketStatus.resolved:
      return 'RESOLVED';
    case TicketStatus.closed:
      return 'CLOSED';
    case TicketStatus.cancelled:
      return 'CANCELLED';
  }
}

/// The visible part of the customer home: header with overlapping counters,
/// the Submit New Ticket card and the recent tickets. It only draws what it
/// is given; the data and the counts come from [CustomerHomeScreen].
class CustomerHomeContent extends StatelessWidget {
  final String title;
  final int assignedCount;
  final int inProgressCount;
  final int resolvedCount;

  /// The ticket being worked on (ASSIGNED or IN_PROGRESS), if any.
  final Ticket? activeTicket;
  final String? activeTechnicianName;

  /// The newest ticket, shown in the "no active tickets" layout, and its
  /// creation date when the ticket has one.
  final Ticket? lastTicket;
  final DateTime? lastTicketDate;

  const CustomerHomeContent({
    super.key,
    required this.title,
    required this.assignedCount,
    required this.inProgressCount,
    required this.resolvedCount,
    this.activeTicket,
    this.activeTechnicianName,
    this.lastTicket,
    this.lastTicketDate,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // The floating nav bar sits over the bottom of the screen. Inside a
      // Scaffold with extendBody, the body's bottom padding already includes
      // the bar and the device's safe area, so only a gap is added here.
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(
            title,
            counters: _CountersCard(
              counters: [
                _Counter('Assigned', assignedCount, AppColors.assignedFg),
                _Counter('In Progress', inProgressCount, AppColors.progressFg),
                _Counter('Resolved', resolvedCount, AppColors.resolvedFg),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.s4),

                if (activeTicket != null) ...[
                  // Active Ticket, then the primary action.
                  _ActiveTicketCard(
                    ticket: activeTicket!,
                    technicianName: activeTechnicianName,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  const _SubmitTicketCard(),
                ] else ...[
                  // Nothing active: say so, keep the primary action, then the
                  // newest ticket (if the customer has any).
                  const _NoActiveTicketsCard(),
                  const SizedBox(height: AppSpacing.s3),
                  const _SubmitTicketCard(),
                  if (lastTicket != null) ...[
                    const SizedBox(height: AppSpacing.s3),
                    _LastTicketCard(
                      ticket: lastTicket!,
                      createdAt: lastTicketDate,
                    ),
                  ],
                ],

                const SizedBox(height: AppSpacing.s3),

                // Speed Test
                const _SpeedTestTile(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Counter {
  final String label;
  final int count;
  final Color color;

  const _Counter(this.label, this.count, this.color);
}

/// White card with the ticket counters in equal columns split by hairlines.
class _CountersCard extends StatelessWidget {
  final List<_Counter> counters;

  const _CountersCard({required this.counters});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.card,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < counters.length; i++) ...[
              if (i > 0) Container(width: 1, color: AppColors.border),
              Expanded(
                child: Semantics(
                  container: true,
                  label: '${counters[i].label}: ${counters[i].count}',
                  excludeSemantics: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        counters[i].count.toString(),
                        style: AppText.display.copyWith(
                          color: counters[i].color,
                        ),
                      ),
                      Text(
                        counters[i].label,
                        textAlign: TextAlign.center,
                        style: AppText.caption.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-width orange card that opens the submit ticket form.
class _SubmitTicketCard extends StatelessWidget {
  const _SubmitTicketCard();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Submit New Ticket. Need help? Report an issue now',
      excludeSemantics: true,
      child: Material(
        // accentStrong, not accent: white text needs the darker orange.
        color: AppColors.accent,
        borderRadius: AppRadius.brLg,
        child: InkWell(
          borderRadius: AppRadius.brLg,
          onTap: () {
            Navigator.pushNamed(context, '/customer/submit');
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceCard,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: AppColors.accentStrong),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Submit New Ticket',
                        style: AppText.heading.copyWith(
                          color: AppColors.onPrimary,
                        ),
                      ),
                      Text(
                        'Need help? Report an issue now',
                        style: AppText.body.copyWith(
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.onPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when no ticket is being worked on.
class _NoActiveTicketsCard extends StatelessWidget {
  const _NoActiveTicketsCard();

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4,
          AppSpacing.s6,
          AppSpacing.s4,
          AppSpacing.s6,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: AppRadius.brLg,
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'No active tickets',
              textAlign: TextAlign.center,
              style: AppText.heading.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: AppSpacing.s1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                'Everything is running smoothly. Having a problem with your service? Tell us and we will sort it out.',
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The newest ticket, when none is active. The whole card opens its details.
class _LastTicketCard extends StatelessWidget {
  final Ticket ticket;

  /// When the ticket was created; null when it has no creation time.
  final DateTime? createdAt;

  const _LastTicketCard({required this.ticket, required this.createdAt});

  @override
  Widget build(BuildContext context) {
    final status = _statusValue(ticket.status);
    final date = createdAt == null
        ? null
        : '${createdAt!.day.toString().padLeft(2, '0')}/'
              '${createdAt!.month.toString().padLeft(2, '0')}/'
              '${createdAt!.year}';

    return Semantics(
      button: true,
      label:
          'Last ticket: ${ticket.title}, ${statusStyle(status).label}${date == null ? '' : ', $date'}',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: AppRadius.brLg,
          boxShadow: AppShadows.card,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppRadius.brLg,
            onTap: () {
              Navigator.pushNamed(
                context,
                '/customer/ticket_details',
                arguments: ticket.id,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s4,
                vertical: AppSpacing.s3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Last ticket',
                          style: AppText.bodyStrong.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      StatusBadge(status: status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ticket.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.heading.copyWith(color: AppColors.ink),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.primary),
                    ],
                  ),
                  if (date != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: AppColors.inkFaint,
                        ),
                        const SizedBox(width: AppSpacing.s1),
                        Text(
                          date,
                          style: AppText.caption.copyWith(
                            color: AppColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ticket currently being worked on: status, progress and technician.
/// The whole card opens the ticket details, like "View Details" does.
class _ActiveTicketCard extends StatelessWidget {
  final Ticket ticket;
  final String? technicianName;

  const _ActiveTicketCard({required this.ticket, this.technicianName});

  void _open(BuildContext context) {
    Navigator.pushNamed(
      context,
      '/customer/ticket_details',
      arguments: ticket.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusValue(ticket.status);
    final name = technicianName;
    final hasTechnician = name != null && name.isNotEmpty;

    final track = TextButton.icon(
      onPressed: () => _open(context),
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.chevron_right),
      label: const Text('Track'),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.brLg,
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Active Ticket',
                        style: AppText.bodyStrong.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    StatusBadge(status: status),
                  ],
                ),
                const SizedBox(height: AppSpacing.s3),
                Text(
                  ticket.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.heading.copyWith(color: AppColors.ink),
                ),
                Text(
                  ticket.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(color: AppColors.inkFaint),
                ),
                const SizedBox(height: AppSpacing.s4),
                HorizontalStatusStepper(status: status),
                const SizedBox(height: AppSpacing.s3),
                const Divider(height: 1, thickness: 1, color: AppColors.border),
                const SizedBox(height: AppSpacing.s2),
                if (hasTechnician)
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryTint,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s3),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyStrong.copyWith(
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      track,
                    ],
                  )
                else
                  Align(alignment: Alignment.centerRight, child: track),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the same Speed Test screen as the Profile tab.
class _SpeedTestTile extends StatelessWidget {
  const _SpeedTestTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.brLg,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SpeedTestScreen()),
            );
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryTint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.speed, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Speed Test',
                          style: AppText.bodyStrong.copyWith(
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          'Test your internet',
                          style: AppText.caption.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.inkFaint),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
