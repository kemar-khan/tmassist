import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/in_memory_store.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _contentController = TextEditingController();
  bool _isGenerating = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _handleGenerate(InMemoryStore store) async {
    setState(() => _isGenerating = true);

    // Simulate AI generation delay
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      final report = store.generateReportMock();
      setState(() {
        _contentController.text = report.content;
        _isGenerating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("AI Report Generated Successfully"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // We don't necessarily need the ticketId here if generateReportMock
    // uses the technician's recent tickets, but the UI should look good.
    final store = context.watch<InMemoryStore>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Top Section: TM Blue Header
          Container(
            height: 180,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF005CAB),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(50)),
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
                      "AI Service Report",
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

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Service Summary",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF005CAB),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Review and refine the AI-generated report for your recent jobs.",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  // Report Editor
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(15),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.edit_note,
                                size: 20,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "Report Content",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              const Spacer(),
                              if (_contentController.text.isNotEmpty)
                                Text(
                                  "${_contentController.text.split(' ').length} words",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        TextField(
                          controller: _contentController,
                          maxLines: 15,
                          decoration: const InputDecoration(
                            hintText: "Click 'GENERATE AI REPORT' to start...",
                            contentPadding: EdgeInsets.all(16),
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Generate Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating
                          ? null
                          : () => _handleGenerate(store),
                      icon: _isGenerating
                          ? const SizedBox.shrink()
                          : const Icon(Icons.auto_awesome),
                      label: _isGenerating
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "GENERATE AI REPORT",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6600),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      onPressed: _contentController.text.isEmpty
                          ? null
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Report Saved Locally"),
                                ),
                              );
                              Navigator.pop(context);
                            },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text("FINALIZE & CLOSE"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF005CAB),
                        side: const BorderSide(color: Color(0xFF005CAB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
