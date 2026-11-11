import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import '../../utils/cancelled_status.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_chip_row.dart';
import '../../widgets/ticket_card.dart';
import '../../widgets/stream_error.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
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

  String _searchQuery = '';
  String _selectedFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Tickets')),
        body: const Center(child: Text('No logged in user found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Tickets')),
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
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: AppText.body.copyWith(color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'Search by title...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          FilterChipRow(
            labels: [for (final key in _filterKeys) _formatFilterLabel(key)],
            selected: _formatFilterLabel(_selectedFilter),
            onSelected: (label) {
              final key = _filterKeys.firstWhere(
                (k) => _formatFilterLabel(k) == label,
              );
              setState(() => _selectedFilter = key);
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tickets')
                  .where('customerId', isEqualTo: currentUser.uid)
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

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const EmptyState(
                    icon: Icons.confirmation_number_outlined,
                    title: 'No tickets found',
                    subtitle: 'You have not submitted any tickets yet.',
                  );
                }

                final docs = snapshot.data!.docs;

                final filteredTickets = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final status = (data['status'] ?? '')
                      .toString()
                      .toUpperCase();
                  final query = _searchQuery.trim().toLowerCase();

                  final matchesSearch = query.isEmpty || title.contains(query);

                  final matchesFilter =
                      _selectedFilter == 'All' || status == _selectedFilter;

                  return matchesSearch && matchesFilter;
                }).toList();

                if (filteredTickets.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No tickets found',
                    subtitle: 'Try adjusting your filters or search query.',
                  );
                }

                return ListView.separated(
                  // The floating nav bar sits over the bottom of the screen.
                  // Inside a Scaffold with extendBody, the body's bottom
                  // padding already includes the bar and the device's safe
                  // area, so only a gap is added here.
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.s4,
                    AppSpacing.s3,
                    AppSpacing.s4,
                    MediaQuery.paddingOf(context).bottom + AppSpacing.s4,
                  ),
                  itemCount: filteredTickets.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.s3),
                  itemBuilder: (context, index) {
                    final doc = filteredTickets[index];
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
    final title = (data['title'] ?? 'No Title').toString();
    final description = (data['description'] ?? '').toString();
    final status = (data['status'] ?? 'UNKNOWN').toString().toUpperCase();
    final createdAt = data['createdAt'];

    String formattedDate = 'Date not available';
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
        Navigator.pushNamed(
          context,
          '/customer/ticket_details',
          arguments: ticketId,
        );
      },
    );
  }

  String _formatFilterLabel(String label) {
    switch (label) {
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'NEW':
        return 'New';
      case 'ASSIGNED':
        return 'Assigned';
      case 'RESOLVED':
        return 'Resolved';
      case 'CLOSED':
        return 'Closed';
      case 'CANCELLED':
        return CancelledStatus.label;
      default:
        return label;
    }
  }
}
