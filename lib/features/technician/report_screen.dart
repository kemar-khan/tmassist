import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReportScreen extends StatefulWidget {
  final String ticketId;

  const ReportScreen({super.key, required this.ticketId});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _contentController = TextEditingController();
  bool _isGenerating = false;
  bool _isSaving = false;
  bool _hasInitializedContent = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _handleGenerate(Map<String, dynamic> data) async {
    setState(() => _isGenerating = true);

    await Future.delayed(const Duration(seconds: 1));

    final customerName = (data['customerName'] ?? 'Customer').toString();
    final category = (data['category'] ?? 'General').toString();
    final title = (data['title'] ?? '').toString();
    final description = (data['description'] ?? '').toString();
    final address = (data['address'] ?? '-').toString();
    final status = (data['status'] ?? 'IN_PROGRESS').toString();

    final generatedReport =
        '''
Service Report

Customer Name:
$customerName

Issue Category:
$category

Ticket Title:
$title

Issue Description:
$description

Service Location:
$address

Work Performed:
Technician attended the site, inspected the reported issue, carried out the required troubleshooting steps, and verified the service condition.

Findings:
The issue was checked and appropriate technical action was taken based on on-site inspection.

Final Status:
$status

Technician Notes:
Please review and update this section with the actual work completed, replaced parts, test results, and final confirmation.
''';

    if (!mounted) return;

    setState(() {
      _contentController.text = generatedReport;
      _isGenerating = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("AI Report Generated Successfully"),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_contentController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .update({
            'reportContent': _contentController.text.trim(),
            'reportUpdatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Report saved successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save report: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Column(
              children: [
                Container(
                  height: 180,
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
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
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

        if (!_hasInitializedContent) {
          final existingReport = (data['reportContent'] ?? '').toString();
          if (existingReport.isNotEmpty) {
            _contentController.text = existingReport;
          }
          _hasInitializedContent = true;
        }

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
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(50),
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
                                      "${_contentController.text.trim().split(RegExp(r'\\s+')).length} words",
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
                              onChanged: (_) {
                                setState(() {});
                              },
                              decoration: const InputDecoration(
                                hintText:
                                    "Click 'GENERATE AI REPORT' to start...",
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
                              : () => _handleGenerate(data),
                          icon: _isGenerating
                              ? const SizedBox.shrink()
                              : const Icon(Icons.auto_awesome),
                          label: _isGenerating
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
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
                          onPressed:
                              _contentController.text.trim().isEmpty ||
                                  _isSaving
                              ? null
                              : _handleSave,
                          icon: _isSaving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
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
      },
    );
  }
}
