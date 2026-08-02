import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AssignTicketScreen extends StatefulWidget {
  final String ticketId;

  const AssignTicketScreen({super.key, required this.ticketId});

  @override
  State<AssignTicketScreen> createState() => _AssignTicketScreenState();
}

class _AssignTicketScreenState extends State<AssignTicketScreen> {
  String? _selectedTechnicianId;
  String? _selectedTechnicianName;
  bool _isLoading = false;

  Future<void> _handleAssign() async {
    if (_selectedTechnicianId == null || _selectedTechnicianName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a technician")),
      );
      return;
    }

    final supervisor = FirebaseAuth.instance.currentUser;
    if (supervisor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No logged in supervisor found")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .update({
            'technicianId': _selectedTechnicianId,
            'technicianName': _selectedTechnicianName,
            'supervisorId': supervisor.uid,
            'status': 'ASSIGNED',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Ticket assigned to $_selectedTechnicianName"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .snapshots(),
      builder: (context, ticketSnapshot) {
        if (ticketSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (ticketSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text("Error")),
            body: Center(child: Text("Error: ${ticketSnapshot.error}")),
          );
        }

        if (!ticketSnapshot.hasData || !ticketSnapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text("Error")),
            body: const Center(child: Text("Ticket not found")),
          );
        }

        final ticketData = ticketSnapshot.data!.data() as Map<String, dynamic>;
        final ticketTitle = (ticketData['title'] ?? 'No Title').toString();
        final ticketDescription =
            (ticketData['description'] ?? 'No description').toString();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'technician')
              .snapshots(),
          builder: (context, techSnapshot) {
            if (techSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (techSnapshot.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text("Error")),
                body: Center(child: Text("Error: ${techSnapshot.error}")),
              );
            }

            final technicians = techSnapshot.data?.docs ?? [];

            return Scaffold(
              backgroundColor: Colors.white,
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    // Top Section: TM Blue Header
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFF005CAB),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(60),
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.arrow_back_ios,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "Assign Ticket",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Content Section
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ticket Summary Card
                          const Text(
                            "Ticket Summary",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF005CAB),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ticketTitle,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  ticketDescription,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Technician Selection
                          // Show current auto assignment if exists
                          if (ticketData['assignmentType'] == 'AUTO' &&
                              ticketData['technicianId'] != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF005CAB,
                                ).withOpacity(0.05),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: const Color(
                                    0xFF005CAB,
                                  ).withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.auto_awesome,
                                    color: Color(0xFF005CAB),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'This ticket was auto-assigned by AI. You can override it below.',
                                      style: TextStyle(
                                        color: Color(0xFF005CAB),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Technician Selection
                          const Text(
                            "Override Assignment",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF005CAB),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const SizedBox(height: 16),

                          if (technicians.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                ),
                              ),
                              child: const Text(
                                "No technicians available.",
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else
                            DropdownButtonFormField<String>(
                              value: _selectedTechnicianId,
                              items: technicians.map((techDoc) {
                                final data =
                                    techDoc.data() as Map<String, dynamic>;
                                final techName =
                                    (data['fullName'] ?? 'Unnamed Technician')
                                        .toString();

                                final specialization =
                                    (data['specialization'] ?? '').toString();
                                return DropdownMenuItem<String>(
                                  value: techDoc.id,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          techName,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (specialization.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF005CAB,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            specialization,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF005CAB),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val == null) return;

                                final selectedDoc = technicians.firstWhere(
                                  (doc) => doc.id == val,
                                );
                                final data =
                                    selectedDoc.data() as Map<String, dynamic>;

                                setState(() {
                                  _selectedTechnicianId = val;
                                  _selectedTechnicianName =
                                      (data['fullName'] ?? 'Unnamed Technician')
                                          .toString();
                                });
                              },
                              decoration: InputDecoration(
                                labelText: "Available Technicians",
                                prefixIcon: const Icon(
                                  Icons.person_search_outlined,
                                  color: Colors.orange,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),

                          const SizedBox(height: 48),

                          // Assign Button
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _isLoading || technicians.isEmpty
                                  ? null
                                  : _handleAssign,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6600),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text(
                                      "CONFIRM ASSIGNMENT",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
