import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/services/checklist_service.dart';

class ChecklistScreen extends StatefulWidget {
  final String ticketId;

  const ChecklistScreen({super.key, required this.ticketId});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  bool _isGenerating = false;
  final ChecklistService _checklistService = ChecklistService();

  Future<void> _handleGenerate(Map<String, dynamic> ticketData) async {
    final checklistItems = List<Map<String, dynamic>>.from(
      (ticketData['checklistItems'] ?? []).map(
        (e) => Map<String, dynamic>.from(e),
      ),
    );
    final hasExisting = checklistItems.isNotEmpty;

    // If existing checklist, show options dialog
    if (hasExisting) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Regenerate Checklist',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'What would you like to do with the current checklist?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'replace'),
              child: const Text(
                'Replace All',
                style: TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF005CAB),
              ),
              child: const Text(
                'Add New Items',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (choice == null) return;
      await _generate(ticketData, addToExisting: choice == 'add');
    } else {
      await _generate(ticketData, addToExisting: false);
    }
  }

  Future<void> _generate(
    Map<String, dynamic> ticketData, {
    required bool addToExisting,
  }) async {
    setState(() => _isGenerating = true);

    try {
      final category = ticketData['category']?.toString() ?? 'Other';
      final title = ticketData['title']?.toString() ?? '';
      final description = ticketData['description']?.toString() ?? '';

      // Get existing items if adding
      List<Map<String, String>>? existingItems;
      if (addToExisting) {
        final raw = List<Map<String, dynamic>>.from(
          (ticketData['checklistItems'] ?? []).map(
            (e) => Map<String, dynamic>.from(e),
          ),
        );
        existingItems = raw
            .map(
              (e) => {
                'title': e['title']?.toString() ?? '',
                'detail': e['detail']?.toString() ?? '',
                'priority': e['priority']?.toString() ?? 'Medium',
                'estimatedTime': e['estimatedTime']?.toString() ?? '10 mins',
              },
            )
            .toList();
      }

      final newItems = await _checklistService.generateChecklist(
        ticketId: widget.ticketId,
        category: category,
        title: title,
        description: description,
        existingItems: existingItems,
        addToExisting: addToExisting,
      );

      // Combine or replace
      final finalItems = addToExisting && existingItems != null
          ? [...existingItems, ...newItems]
          : newItems;

      // Build done list
      List<bool> donelist;
      if (addToExisting && existingItems != null) {
        final existingDone = List<bool>.from(ticketData['checklistDone'] ?? []);
        donelist = [...existingDone, ...List.filled(newItems.length, false)];
      } else {
        donelist = List.filled(finalItems.length, false);
      }

      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .update({
            'checklistItems': finalItems,
            'checklistDone': donelist,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checklist generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate checklist: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
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
            content: Text('Failed to update: $e'),
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
              title: const Text('Loading'),
              backgroundColor: const Color(0xFF005CAB),
              foregroundColor: Colors.white,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('Ticket not found')),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final ticketTitle = (data['title'] ?? '').toString();
        final category = (data['category'] ?? '').toString();

        final rawItems = List.from(data['checklistItems'] ?? []);
        final checklistItems = rawItems
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        final checklistDoneDynamic = List.from(data['checklistDone'] ?? []);
        final checklistDone = checklistDoneDynamic
            .map((e) => e == true)
            .toList();

        final hasChecklist = checklistItems.isNotEmpty;
        final totalItems = checklistItems.length;
        final doneItems = checklistDone.where((d) => d).length;
        final progress = totalItems > 0 ? doneItems / totalItems : 0.0;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF005CAB),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(50),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 24, 24),
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
                            const Text(
                              'AI Checklist',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'AI POWERED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  category,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
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
                                  const SizedBox(width: 12),
                                  Text(
                                    '$doneItems/$totalItems',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${(progress * 100).toInt()}%)',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
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

              // Content
              Expanded(
                child: !hasChecklist
                    ? _buildEmptyState(data)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: totalItems + 1,
                        itemBuilder: (context, index) {
                          // Last item is the regenerate button
                          if (index == totalItems) {
                            return _buildRegenerateButton(data);
                          }
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

              // Done button
              if (hasChecklist && progress == 1.0)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('TICKET READY FOR REPORT'),
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
    Map<String, dynamic> item,
    bool isDone,
    List<bool> checklistDone,
  ) {
    final title = item['title']?.toString() ?? '';
    final detail = item['detail']?.toString() ?? '';
    final priority = item['priority']?.toString() ?? 'Medium';
    final estimatedTime = item['estimatedTime']?.toString() ?? '10 mins';

    Color priorityColor;
    switch (priority.toLowerCase()) {
      case 'high':
        priorityColor = Colors.red;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        break;
      default:
        priorityColor = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDone ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone ? Colors.green.withOpacity(0.2) : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            GestureDetector(
              onTap: () => _handleToggle(checklistDone, index, !isDone),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? Colors.green : Colors.transparent,
                  border: Border.all(
                    color: isDone ? Colors.green : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: isDone
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Priority badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDone
                                ? Colors.grey
                                : const Color(0xFF333333),
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: priorityColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          priority,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: priorityColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Detail
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDone ? Colors.grey[400] : Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Time estimate
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        estimatedTime,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegenerateButton(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: OutlinedButton.icon(
        onPressed: _isGenerating ? null : () => _handleGenerate(data),
        icon: _isGenerating
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(
                Icons.auto_awesome,
                color: Color(0xFF005CAB),
                size: 18,
              ),
        label: Text(
          _isGenerating ? 'Generating...' : 'Regenerate Checklist',
          style: const TextStyle(
            color: Color(0xFF005CAB),
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Color(0xFF005CAB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Map<String, dynamic> data) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            const Text(
              'No checklist yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tap below to generate an AI-powered checklist customized for this specific issue.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : () => _handleGenerate(data),
                icon: _isGenerating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.auto_awesome, color: Colors.white),
                label: Text(
                  _isGenerating ? 'Generating...' : 'GENERATE AI CHECKLIST',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF005CAB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
