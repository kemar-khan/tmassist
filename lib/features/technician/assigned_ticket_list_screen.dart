import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import '../../utils/cancelled_status.dart';
import '../../utils/ticket_filter_request.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_chip_row.dart';
import '../../widgets/ticket_card.dart';
import '../../widgets/stream_error.dart';

class AssignedTicketsScreen extends StatefulWidget {
  /// A request from another tab to select a status filter. When its id
  /// changes the screen selects the status, clears the search text and
  /// scrolls the chip into view.
  final TicketFilterRequest? filterRequest;

  /// For tests: the tickets stream and technician id to use instead of the
  /// Firestore query and the signed-in user.
  final Stream<QuerySnapshot>? ticketsStream;
  final String? technicianId;

  const AssignedTicketsScreen({
    super.key,
    this.filterRequest,
    this.ticketsStream,
    this.technicianId,
  });

  @override
  State<AssignedTicketsScreen> createState() => _AssignedTicketsScreenState();
}

class _AssignedTicketsScreenState extends State<AssignedTicketsScreen> {
  // The stored values the filter works on, in the order the chips appear.
  static const List<String> _filterKeys = [
    'All',
    'ASSIGNED',
    'IN_PROGRESS',
    'RESOLVED',
    'CLOSED',
    'CANCELLED',
  ];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  // 'All' excludes cancelled tickets; only the Cancelled chip shows them.
  String _selectedFilter = 'All';

  // Bumped by every filter request, so the chip row scrolls the selected chip
  // into view even when the requested status is already selected.
  int _revealCount = 0;

  String? _uid;

  // Created once: a stream made inside build() would re-subscribe (and flash
  // the spinner) on every keystroke or chip tap.
  Stream<QuerySnapshot>? _ticketStream;

  @override
  void initState() {
    super.initState();
    _uid = widget.technicianId ?? FirebaseAuth.instance.currentUser?.uid;
    _createStream();
  }

  // Also used by "Try Again", which needs a fresh subscription.
  void _createStream() {
    final uid = _uid;
    if (uid == null) return;
    _ticketStream =
        widget.ticketsStream ??
        FirebaseFirestore.instance
            .collection('tickets')
            .where('technicianId', isEqualTo: uid)
            .orderBy('updatedAt', descending: true)
            .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AssignedTicketsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final request = widget.filterRequest;
    if (request == null || request.id == oldWidget.filterRequest?.id) return;

    setState(() {
      _selectedFilter = request.status;
      _searchController.clear();
      _searchQuery = "";
      _revealCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    if (uid == null || _ticketStream == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: const EmptyState(
          icon: Icons.person_off_outlined,
          title: "User not logged in",
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s4,
              AppSpacing.s4,
              AppSpacing.s4,
              0,
            ),
            child: AppTextField(
              label: '',
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              hint: "Search by ID or Title...",
              prefixIcon: Icons.search,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          FilterChipRow(
            labels: [for (final key in _filterKeys) _filterLabel(key)],
            selected: _filterLabel(_selectedFilter),
            revealRequest: _revealCount,
            onSelected: (label) {
              final key = _filterKeys.firstWhere(
                (k) => _filterLabel(k) == label,
              );
              setState(() => _selectedFilter = key);
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _ticketStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData &&
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return StreamError(
                    error: snapshot.error,
                    onRetry: () => setState(_createStream),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                final showingCancelled =
                    _selectedFilter == CancelledStatus.value;

                final assignedTickets = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final isCancelled = CancelledStatus.isCancelled(
                    data['status'],
                  );
                  // 'All' never includes cancelled tickets (not active work).
                  // The Cancelled chip shows only this technician's own.
                  if (showingCancelled) {
                    if (!isCancelled || data['technicianId'] != uid) {
                      return false;
                    }
                  } else if (isCancelled) {
                    return false;
                  }

                  // Status chips (Assigned, In Progress, Resolved, Closed).
                  if (_selectedFilter != 'All' && !showingCancelled) {
                    final status = (data['status'] ?? '')
                        .toString()
                        .toUpperCase();
                    if (status != _selectedFilter) return false;
                  }

                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final id = doc.id.toLowerCase();
                  final query = _searchQuery.toLowerCase();

                  return title.contains(query) || id.contains(query);
                }).toList();

                if (assignedTickets.isEmpty) {
                  if (showingCancelled) {
                    return _buildEmptyState(
                      title: "No cancelled tickets",
                      subtitle:
                          "Tickets cancelled by customers will appear here.",
                    );
                  }
                  if (_selectedFilter != 'All') {
                    return _buildEmptyState(
                      title: "No matching tickets",
                      subtitle: "You have no tickets with this status.",
                    );
                  }
                  return _buildEmptyState();
                }

                return ListView.separated(
                  // The floating nav bar sits over the bottom of the screen.
                  // Inside a Scaffold with extendBody, the body's bottom
                  // padding already includes the bar and the device's safe
                  // area, so only a gap is added here.
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.s4,
                    AppSpacing.s4,
                    AppSpacing.s4,
                    MediaQuery.paddingOf(context).bottom + AppSpacing.s4,
                  ),
                  itemCount: assignedTickets.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.s3),
                  itemBuilder: (context, index) {
                    final doc = assignedTickets[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildTicketCard(context, doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(
    BuildContext context,
    String ticketId,
    Map<String, dynamic> data,
  ) {
    final title = (data['title'] ?? '').toString();
    final description = (data['description'] ?? '').toString();
    final address = (data['address'] ?? '').toString();
    final status = (data['status'] ?? 'ASSIGNED').toString().toUpperCase();
    final createdAt = data['createdAt'];

    String formattedDate = '-';
    if (createdAt is Timestamp) {
      final date = createdAt.toDate();
      formattedDate = '${date.day}/${date.month}/${date.year}';
    }

    return TicketCard(
      id: ticketId,
      title: title,
      description: description,
      address: address,
      status: status,
      dateText: formattedDate,
      onTap: () {
        Navigator.pushNamed(context, '/tech/ticket', arguments: ticketId);
      },
      // A visual hint only: tapping anywhere on the card opens the job, and
      // the job is started from Job Details.
      action: status == 'ASSIGNED' ? const _StartJobHint() : null,
    );
  }

  String _filterLabel(String value) {
    switch (value) {
      case 'ASSIGNED':
        return 'Assigned';
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'RESOLVED':
        return 'Resolved';
      case 'CLOSED':
        return 'Closed';
      case 'CANCELLED':
        return CancelledStatus.label;
      default:
        return value;
    }
  }

  Widget _buildEmptyState({
    String title = "No active tasks",
    String subtitle = "All your assigned tickets are completed or closed.",
  }) {
    return EmptyState(
      icon: Icons.assignment_turned_in_outlined,
      title: title,
      subtitle: subtitle,
    );
  }
}

/// "Start Job" shown on ASSIGNED cards. Not a button: the card's own tap opens
/// the job.
class _StartJobHint extends StatelessWidget {
  const _StartJobHint();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s3,
            vertical: AppSpacing.s1,
          ),
          decoration: BoxDecoration(
            color: AppColors.accentTint,
            borderRadius: AppRadius.brSm,
          ),
          child: Text(
            'Start Job',
            style: AppText.bodyStrong.copyWith(color: AppColors.accentStrong),
          ),
        ),
      ),
    );
  }
}
