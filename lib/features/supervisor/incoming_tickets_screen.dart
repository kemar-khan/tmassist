import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import '../../utils/cancelled_status.dart';
import '../../utils/ticket_filter_request.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_chip_row.dart';
import '../../widgets/ticket_card.dart';
import '../../widgets/stream_error.dart';

class IncomingTicketsScreen extends StatefulWidget {
  /// When this changes (a different [TicketFilterRequest.id]), the screen
  /// selects the requested status and clears the search text.
  final TicketFilterRequest? filterRequest;

  const IncomingTicketsScreen({super.key, this.filterRequest});

  @override
  State<IncomingTicketsScreen> createState() => _IncomingTicketsScreenState();
}

class _IncomingTicketsScreenState extends State<IncomingTicketsScreen> {
  // The stored values the filter works on, in the order the chips appear.
  static const List<String> _filterKeys = [
    'All',
    'NEW',
    'ASSIGNED',
    'IN_PROGRESS',
    'RESOLVED',
    'CLOSED',
    'CANCELLED',
  ];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedFilter = "All";

  // Bumped by every filter request, so the chip row scrolls the selected chip
  // into view even when the requested status is already selected.
  int _revealCount = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(IncomingTicketsScreen oldWidget) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoming Tickets'),
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
            labels: [for (final key in _filterKeys) _formatStatusLabel(key)],
            selected: _formatStatusLabel(_selectedFilter),
            revealRequest: _revealCount,
            onSelected: (label) {
              final key = _filterKeys.firstWhere(
                (k) => _formatStatusLabel(k) == label,
              );
              setState(() => _selectedFilter = key);
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tickets')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  // The stream is built inline, so a rebuild subscribes again.
                  return StreamError(
                    error: snapshot.error,
                    onRetry: () => setState(() {}),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                final filteredTickets = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final id = doc.id.toLowerCase();
                  final status = (data['status'] ?? '')
                      .toString()
                      .toUpperCase();
                  final query = _searchQuery.toLowerCase();

                  final matchesSearch =
                      title.contains(query) || id.contains(query);

                  final matchesFilter =
                      _selectedFilter == 'All' || status == _selectedFilter;

                  return matchesSearch && matchesFilter;
                }).toList();

                if (filteredTickets.isEmpty) {
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
                  itemCount: filteredTickets.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.s3),
                  itemBuilder: (context, index) {
                    final doc = filteredTickets[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildIncomingTicketCard(context, doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingTicketCard(
    BuildContext context,
    String ticketId,
    Map<String, dynamic> data,
  ) {
    final title = (data['title'] ?? 'No Title').toString();
    final description = (data['description'] ?? '').toString();
    final status = (data['status'] ?? 'NEW').toString().toUpperCase();
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
      status: status,
      dateText: formattedDate,
      onTap: () {
        Navigator.pushNamed(context, '/supervisor/ticket', arguments: ticketId);
      },
      action: status == 'NEW'
          ? _AssignNowButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/supervisor/assign',
                  arguments: ticketId,
                );
              },
            )
          : null,
    );
  }

  String _formatStatusLabel(String value) {
    switch (value) {
      case 'NEW':
        return 'New';
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
      case 'All':
        return 'All';
      default:
        return value;
    }
  }

  Widget _buildEmptyState() {
    String message;
    if (_selectedFilter == 'All') {
      message = "There are no tickets at the moment.";
    } else {
      message =
          "There are no ${_formatStatusLabel(_selectedFilter).toLowerCase()} tickets at the moment.";
    }

    return EmptyState(
      icon: Icons.assignment_turned_in_outlined,
      title: "All caught up!",
      subtitle: message,
    );
  }
}

/// Compact "Assign Now" pill for NEW tickets. The visible pill is small; the
/// tap area around it is 44dp high.
class _AssignNowButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _AssignNowButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: 'Assign Now',
      child: SizedBox(
        height: 44,
        child: InkWell(
          borderRadius: AppRadius.brSm,
          onTap: onPressed,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s3,
                vertical: AppSpacing.s1,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: AppRadius.brSm,
              ),
              child: Text(
                'Assign Now',
                style: AppText.bodyStrong.copyWith(color: AppColors.primary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
