import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/cancelled_status.dart';

class AssignedTicketsScreen extends StatefulWidget {
  const AssignedTicketsScreen({super.key});

  @override
  State<AssignedTicketsScreen> createState() => _AssignedTicketsScreenState();
}

class _AssignedTicketsScreenState extends State<AssignedTicketsScreen> {
  String _searchQuery = "";
  // 'All' excludes cancelled tickets; only the Cancelled chip shows them.
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: const Center(child: Text("User not logged in")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'My Tasks',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF005CAB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar + filter chips
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF005CAB),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search by ID or Title...",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'All'),
                      _buildFilterChip('Assigned', 'ASSIGNED'),
                      _buildFilterChip('In Progress', 'IN_PROGRESS'),
                      _buildFilterChip('Resolved', 'RESOLVED'),
                      _buildFilterChip('Closed', 'CLOSED'),
                      _buildFilterChip(
                        CancelledStatus.label,
                        CancelledStatus.value,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Ticket List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tickets')
                  .where('technicianId', isEqualTo: currentUser.uid)
                  .orderBy('updatedAt', descending: true)
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
                        'Error: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
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
                    if (!isCancelled ||
                        data['technicianId'] != currentUser.uid) {
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

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: assignedTickets.length,
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
    final address = (data['address'] ?? 'Cyberjaya, Selangor').toString();
    final status = (data['status'] ?? 'ASSIGNED').toString().toUpperCase();
    final createdAt = data['createdAt'];

    String formattedDate = '-';
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pushNamed(context, '/tech/ticket', arguments: ticketId);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusBadge(status),
                    Text(
                      formattedDate,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  ticketId,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: CancelledStatus.titleStyle(
                    const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                    status,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "View Details",
                      style: TextStyle(
                        color: Color(0xFF005CAB),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Color(0xFF005CAB),
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'ASSIGNED':
        color = Colors.blue;
        label = 'ASSIGNED';
        break;
      case 'IN_PROGRESS':
        color = Colors.purple;
        label = 'IN PROGRESS';
        break;
      case 'RESOLVED':
        color = Colors.green;
        label = 'RESOLVED';
        break;
      case 'CLOSED':
        color = Colors.grey;
        label = 'CLOSED';
        break;
      case 'CANCELLED':
        color = CancelledStatus.textColor;
        label = CancelledStatus.label.toUpperCase();
        break;
      default:
        color = Colors.orange;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: CancelledStatus.isCancelled(status)
            ? CancelledStatus.backgroundColor
            : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF005CAB),
            fontWeight: FontWeight.w600,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedFilter = value),
        selectedColor: Colors.white,
        backgroundColor: Colors.white.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.25),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    String title = "No active tasks",
    String subtitle = "All your assigned tickets are completed or closed.",
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_turned_in_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[400]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
