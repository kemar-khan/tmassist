import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChecklistScreen extends StatefulWidget {
  final String ticketId;

  const ChecklistScreen({super.key, required this.ticketId});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  bool _isGenerating = false;

  Future<void> _handleGenerate() async {
    setState(() => _isGenerating = true);

    try {
      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .update({
            'checklistItems': [
              'Check router power',
              'Inspect modem indicators',
              'Test cable connection',
              'Restart equipment',
              'Verify internet access',
            ],
            'checklistDone': [false, false, false, false, false],
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Standard Maintenance Checklist Generated"),
            backgroundColor: Color(0xFF005CAB),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to generate checklist: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleToggle(
    List<bool> checklistDone,
    int index,
    bool value,
  ) async {
    try {
      final updated = List<bool>.from(checklistDone);
      updated[index] = value;

      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .update({
            'checklistDone': updated,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update checklist: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text("Loading"),
              backgroundColor: const Color(0xFF005CAB),
              foregroundColor: Colors.white,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text("Error")),
            body: Center(child: Text("Error: ${snapshot.error}")),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text("Error")),
            body: const Center(child: Text("Ticket not found")),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final ticketTitle = (data['title'] ?? '').toString();
        final checklistItems = List<String>.from(data['checklistItems'] ?? []);
        final checklistDoneDynamic = List.from(data['checklistDone'] ?? []);
        final checklistDone = checklistDoneDynamic
            .map((e) => e == true)
            .toList();

        final hasChecklist = checklistItems.isNotEmpty;
        final totalItems = checklistItems.length;
        final doneItems = checklistDone.where((d) => d).length;
        final progress = totalItems > 0 ? doneItems / totalItems : 0.0;

        return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              // Top Section: TM Blue Header
              Container(
                height: 200,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF005CAB),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(50),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                              "Maintenance Checklist",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(left: 48.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ticketTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Progress Bar
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor: Colors.white
                                            .withOpacity(0.2),
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              Colors.orange,
                                            ),
                                        minHeight: 8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    "${(progress * 100).toInt()}%",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Main Content Section
              Expanded(
                child: !hasChecklist
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: totalItems,
                        itemBuilder: (context, index) {
                          final item = checklistItems[index];
                          final isDone = index < checklistDone.length
                              ? checklistDone[index]
                              : false;
                          return _buildChecklistItem(
                            index,
                            item,
                            isDone,
                            checklistDone,
                          );
                        },
                      ),
              ),

              if (hasChecklist && progress == 1.0)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text("TICKET READY FOR REPORT"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChecklistItem(
    int index,
    String label,
    bool isDone,
    List<bool> checklistDone,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDone ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDone ? Colors.green.withOpacity(0.2) : Colors.grey[200]!,
        ),
      ),
      child: CheckboxListTile(
        value: isDone,
        onChanged: (val) => _handleToggle(
          index == -1 ? [] : checklistDone,
          index,
          val ?? false,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            decoration: isDone ? TextDecoration.lineThrough : null,
            color: isDone ? Colors.grey : Colors.black87,
          ),
        ),
        activeColor: Colors.green,
        checkColor: Colors.white,
        controlAffinity: ListTileControlAffinity.leading,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checklist_rounded, size: 80, color: Colors.grey[200]),
            const SizedBox(height: 24),
            const Text(
              "No checklist active",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Click below to generate a standard maintenance checklist for this issue.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _handleGenerate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6600),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isGenerating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "GENERATE CHECKLIST",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
