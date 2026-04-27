import 'package:flutter/material.dart';
import '../../core/services/ticket_service.dart';

class SubmitTicketScreen extends StatefulWidget {
  const SubmitTicketScreen({super.key});

  @override
  State<SubmitTicketScreen> createState() => _SubmitTicketScreenState();
}

class _SubmitTicketScreenState extends State<SubmitTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final TicketService _ticketService = TicketService();

  String? _category;
  String? _title;
  String? _description;
  String? _address;
  String? _contactNumber;

  bool _isSubmitting = false;

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _ticketService.createTicket(
        category: _category!,
        title: _title!,
        description: _description!,
        address: _address!,
        contactNumber: _contactNumber!,
        attachmentUrl: null, // add file upload later
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit ticket: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Submit Ticket',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF005CAB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('Issue Details'),
              _buildCard(
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: _inputDecoration(
                        'Issue Category',
                        Icons.category_outlined,
                      ),
                      items: ['Network', 'Hardware', 'Software', 'Other']
                          .map(
                            (e) => DropdownMenuItem<String>(
                              value: e,
                              child: Text(e),
                            ),
                          )
                          .toList(),
                      validator: (val) =>
                          val == null ? 'Please select a category' : null,
                      onSaved: (val) => _category = val,
                      onChanged: (String? value) {},
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: _inputDecoration(
                        'Ticket Title',
                        Icons.title_outlined,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                      onSaved: (val) => _title = val?.trim(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: _inputDecoration(
                        'Description',
                        Icons.description_outlined,
                      ),
                      maxLines: 4,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please describe the issue';
                        }
                        return null;
                      },
                      onSaved: (val) => _description = val?.trim(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('Location'),
              _buildCard(
                child: Column(
                  children: [
                    TextFormField(
                      decoration: _inputDecoration(
                        'Service Address',
                        Icons.location_on_outlined,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter an address';
                        }
                        return null;
                      },
                      onSaved: (val) => _address = val?.trim(),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        // add current location feature later
                      },
                      icon: const Icon(
                        Icons.my_location,
                        color: Color(0xFF005CAB),
                      ),
                      label: const Text(
                        'Use Current Location',
                        style: TextStyle(
                          color: Color(0xFF005CAB),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF005CAB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('Additional Info'),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      decoration: _inputDecoration(
                        'Contact Number',
                        Icons.phone_outlined,
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter a contact number';
                        }
                        if (val.trim().length < 10) {
                          return 'Please enter a valid contact number';
                        }
                        return null;
                      },
                      onSaved: (val) => _contactNumber = val?.trim(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Attachment',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Attachment upload not added yet'),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              size: 32,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to upload image or file',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6600),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Ticket',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: child,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey[600]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF005CAB), width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
