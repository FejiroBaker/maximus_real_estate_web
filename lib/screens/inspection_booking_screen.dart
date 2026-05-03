// lib/screens/inspection_booking_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/property_model.dart';
import '../providers/auth_provider.dart';
import '../services/flutterwave_service.dart';
import 'flutterwave_webview_screen.dart';

class InspectionBookingScreen extends StatefulWidget {
  final PropertyModel property;
  const InspectionBookingScreen({super.key, required this.property});

  @override
  State<InspectionBookingScreen> createState() =>
      _InspectionBookingScreenState();
}

class _InspectionBookingScreenState extends State<InspectionBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final FlutterwaveService _flwService = FlutterwaveService();
  final SupabaseClient _supabase = Supabase.instance.client;

  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  final _phoneController = TextEditingController();
  bool _isProcessing = false;

  double get _inspectionFee => widget.property.inspectionFee;
  bool get _isFree => _inspectionFee <= 0;

  final List<String> _timeSlots = [
    '9:00 AM - 10:00 AM',
    '10:00 AM - 11:00 AM',
    '11:00 AM - 12:00 PM',
    '2:00 PM - 3:00 PM',
    '3:00 PM - 4:00 PM',
    '4:00 PM - 5:00 PM',
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1565C0)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _processBookingAndPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select date and time')));
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to continue')));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final txRef = _flwService.generateReference();
      final now = DateTime.now().toIso8601String();

      // Insert booking record (pending)
      final inserted = await _supabase
          .from('inspections')
          .insert({
            'property_id': widget.property.id,
            'property_title': widget.property.title,
            'user_id': user.id,
            'user_name': user.name,
            'user_email': user.email,
            'user_phone': _phoneController.text.trim(),
            'inspection_date': _selectedDate!.toIso8601String(),
            'time_slot': _selectedTimeSlot!,
            'inspection_fee': _inspectionFee,
            'payment_status': _isFree ? 'free' : 'pending',
            'booking_status': _isFree ? 'confirmed' : 'pending',
            'payment_reference': txRef,
            'created_at': now,
            'updated_at': now,
          })
          .select()
          .single();

      final bookingId = inserted['id']?.toString() ?? '';

      if (_isFree) {
        setState(() => _isProcessing = false);
        _showSuccessDialog(free: true);
        return;
      }

      // Paid inspection — launch Flutterwave
      final paymentResult = await _flwService.chargeForInspection(
        property: widget.property,
        buyer: user,
        txRef: txRef,
      );

      if (paymentResult != null && paymentResult['status'] == true) {
        final paymentUrl = paymentResult['payment_url'] as String?;
        if (paymentUrl != null && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FlutterwaveWebViewScreen(
                paymentUrl: paymentUrl,
                txRef: txRef,
                onSuccess: (ref) async {
                  final success = await _flwService.processInspectionPayment(
                    ref,
                    widget.property,
                    user,
                  );
                  // Update booking row on success
                  if (success && bookingId.isNotEmpty) {
                    await _supabase.from('inspections').update({
                      'payment_status': 'paid',
                      'booking_status': 'confirmed',
                      'flutterwave_reference': ref,
                      'paid_at': DateTime.now().toIso8601String(),
                      'updated_at': DateTime.now().toIso8601String(),
                    }).eq('id', bookingId);
                  }
                  if (mounted) {
                    setState(() => _isProcessing = false);
                    if (success) {
                      _showSuccessDialog(free: false);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Payment verification failed. Please contact support.'),
                        backgroundColor: Colors.red,
                      ));
                    }
                  }
                },
                onCancel: () {
                  if (mounted) {
                    setState(() => _isProcessing = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Payment cancelled')));
                  }
                },
              ),
            ),
          );
        } else {
          setState(() => _isProcessing = false);
        }
      } else {
        throw Exception(paymentResult?['message'] ?? 'Payment initialisation failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Booking failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ));
      }
    }
  }

  void _showSuccessDialog({required bool free}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Booking Confirmed!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            free
                ? 'Your free inspection has been booked successfully.'
                : 'Your inspection has been booked and payment confirmed.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          if (_selectedDate != null)
            Text(
              'Date: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          if (_selectedTimeSlot != null)
            Text('Time: $_selectedTimeSlot',
                style: const TextStyle(color: Colors.grey)),
        ]),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Book Inspection'), elevation: 0),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Property summary card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(children: [
                  const Icon(Icons.home, color: Color(0xFF1565C0), size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.property.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                          '${widget.property.location.city}, ${widget.property.location.state}',
                          style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              // Inspection fee display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isFree ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: _isFree
                          ? Colors.green.shade200
                          : Colors.orange.shade200),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Inspection Fee:',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(
                        _isFree ? 'FREE' : formatter.format(_inspectionFee),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _isFree
                              ? Colors.green
                              : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                  if (!_isFree) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Platform service fee (10%): ${formatter.format(_inspectionFee * 0.10)}',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 24),

              // Phone number
              const Text('Contact Phone Number',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Enter your phone number',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (v.length < 10) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Select date
              const Text('Select Inspection Date',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedDate == null
                            ? 'Choose a date'
                            : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                        style: TextStyle(
                          fontSize: 16,
                          color: _selectedDate == null
                              ? Colors.grey
                              : Colors.black87,
                        ),
                      ),
                      const Icon(Icons.calendar_today,
                          color: Color(0xFF1565C0)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Select time slot
              const Text('Select Time Slot',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _timeSlots.map((slot) {
                  final isSelected = _selectedTimeSlot == slot;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTimeSlot = slot),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1565C0)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isSelected
                                ? const Color(0xFF1565C0)
                                : Colors.grey.shade300),
                      ),
                      child: Text(slot,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _isProcessing ? null : _processBookingAndPayment,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor:
                        _isFree ? Colors.green : const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          _isFree
                              ? 'Book Free Inspection'
                              : 'Book & Pay ${formatter.format(_inspectionFee)}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What to expect:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 8),
                    Text(
                      '• Professional property inspection\n'
                      '• Detailed inspection report\n'
                      '• 1-hour inspection duration\n'
                      '• Agent will meet you at the property\n'
                      '• Payment is secure via Flutterwave',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}