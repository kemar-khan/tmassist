import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/in_memory_store.dart';

class ChecklistScreen extends StatefulWidget {
  final String ticketId;

  const ChecklistScreen({super.key, required this.ticketId});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  bool _isGenerating = false;

  void _handleGenerate(InMemoryStore store) async {
    setState(() => _isGenerating = true);

    // Simulate minor delay for UX
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      store.generateChecklistMock(ticketId: widget.ticketId);
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Standard Maintenance Checklist Generated"),
          backgroundColor: Color(0xFF005CAB),
        ),
      );
    }
  }

  void _handleToggle(int index, bool value, InMemoryStore store) {
    store.toggleChecklistItem(
      ticketId: widget.ticketId,
      index: index,
      value: value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<InMemoryStore>();
    final ticket = store.getTicketById(widget.ticketId);

    if (ticket == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: const Center(child: Text("Ticket not found")),
      );
    }

    final hasChecklist = ticket.checklistItems.isNotEmpty;
    final totalItems = ticket.checklistItems.length;
    final doneItems = ticket.checklistDone.where((d) => d).length;
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
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(50)),
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
                            ticket.title,
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
                                    backgroundColor: Colors.white.withOpacity(
                                      0.2,
                                    ),
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
                ? _buildEmptyState(store)
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: totalItems,
                    itemBuilder: (context, index) {
                      final item = ticket.checklistItems[index];
                      final isDone = ticket.checklistDone[index];
                      return _buildChecklistItem(index, item, isDone, store);
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
  }

  Widget _buildChecklistItem(
    int index,
    String label,
    bool isDone,
    InMemoryStore store,
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
        onChanged: (val) => _handleToggle(index, val ?? false, store),
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

  Widget _buildEmptyState(InMemoryStore store) {
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
                onPressed: _isGenerating ? null : () => _handleGenerate(store),
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
