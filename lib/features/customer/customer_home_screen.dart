import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/ticket.dart';
import '../../utils/enums.dart';
import '../../widgets/home_header.dart';
import '../../widgets/progress_stepper.dart';
import '../../widgets/status_badge.dart';
import 'speed_test_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  // Full name from the user's profile (users/{uid}.fullName).
  String? _fullName;

  @override
  void initState() {
    super.initState();
    _loadFullName();
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

    // Solid brand-blue status bar with light icons, so it reads as part of
    // the header. Only this tab changes the style; the others keep the theme's.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.statusBarOnPrimary,
      child: Scaffold(
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('tickets')
              .where('customerId', isEqualTo: firebaseUser.uid)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s4),
                  child: Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: AppText.body.copyWith(color: AppColors.cancelledFg),
                  ),
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

            return CustomerHomeContent(
              title: 'Welcome, ${userName.split(' ').first}',
              assignedCount: assignedCount,
              inProgressCount: inProgressCount,
              resolvedCount: resolvedCount,
              activeTicket: activeTicket,
              activeTechnicianName: activeTechnicianName,
            );
          },
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

  const CustomerHomeContent({
    super.key,
    required this.title,
    required this.assignedCount,
    required this.inProgressCount,
    required this.resolvedCount,
    this.activeTicket,
    this.activeTechnicianName,
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
          HomeHeader(
            title: title,
            subtitle: 'Customer Portal',
            overlapChild: _CountersCard(
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

                // Active Ticket
                if (activeTicket != null) ...[
                  _ActiveTicketCard(
                    ticket: activeTicket!,
                    technicianName: activeTechnicianName,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                ],

                // Submit New Ticket (primary action)
                const _SubmitTicketCard(),

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
    return Material(
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
                child: const Icon(
                  Icons.add_task_rounded,
                  color: AppColors.accentStrong,
                ),
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
                      'Need help? Report an issue now.',
                      style: AppText.body.copyWith(color: AppColors.onPrimary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.onPrimary),
            ],
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
