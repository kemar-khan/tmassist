import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
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
        appBar: AppBar(
          title: const Text('My Tickets'),
          backgroundColor: const Color(0xFF005CAB),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('No logged in user found.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'My Tickets',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF005CAB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search by title...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All'),
                      _buildFilterChip('NEW'),
                      _buildFilterChip('ASSIGNED'),
                      _buildFilterChip('IN_PROGRESS'),
                      _buildFilterChip('RESOLVED'),
                    ],
                  ),
                ),
              ],
            ),
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
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Something went wrong:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(
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
                  return _buildEmptyState(
                    title: 'No tickets found',
                    subtitle: 'Try adjusting your filters or search query.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredTickets.length,
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

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(
          _formatFilterLabel(label),
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedFilter = label);
          }
        },
        selectedColor: const Color(0xFF005CAB),
        backgroundColor: Colors.grey[100],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? const Color(0xFF005CAB) : Colors.grey[300]!,
          ),
        ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/customer/ticket_details',
            arguments: ticketId,
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      ticketId,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: Colors.grey[200], height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formattedDate,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const Row(
                    children: [
                      Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF005CAB),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: Color(0xFF005CAB),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;

    switch (status) {
      case 'NEW':
        color = Colors.orange;
        break;
      case 'ASSIGNED':
        color = Colors.blue;
        break;
      case 'IN_PROGRESS':
        color = Colors.purple;
        break;
      case 'RESOLVED':
        color = Colors.green;
        break;
      case 'CLOSED':
        color = Colors.grey;
        break;
      default:
        color = Colors.black54;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _formatFilterLabel(status).toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState({required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[400],
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
      default:
        return label;
    }
  }
}
