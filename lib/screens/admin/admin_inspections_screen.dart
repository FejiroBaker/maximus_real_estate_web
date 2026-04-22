// lib/screens/admin/admin_inspections_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminInspectionsScreen extends StatefulWidget {
  const AdminInspectionsScreen({super.key});

  @override
  State<AdminInspectionsScreen> createState() => _AdminInspectionsScreenState();
}

class _AdminInspectionsScreenState extends State<AdminInspectionsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _filterStatus = 'all';
  List<Map<String, dynamic>> _inspections = [];
  bool _isLoading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _fetchInspections();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchInspections() async {
    try {
      setState(() => _isLoading = true);
      final data = await _supabase
          .from('inspections')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _inspections = List<Map<String, dynamic>>.from(data as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeRealtime() {
    _channel = _supabase
        .channel('inspections_admin')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inspections',
          callback: (_) => _fetchInspections(),
        )
        .subscribe();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filterStatus == 'all') return _inspections;
    return _inspections
        .where((d) => (d['booking_status'] ?? 'pending') == _filterStatus)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection Bookings'),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchInspections),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                {'value': 'all', 'label': 'All'},
                {'value': 'pending', 'label': 'Pending'},
                {'value': 'confirmed', 'label': 'Confirmed'},
                {'value': 'completed', 'label': 'Completed'},
                {'value': 'cancelled', 'label': 'Cancelled'},
              ].map((item) {
                final selected = _filterStatus == item['value'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(item['label']!),
                    selected: selected,
                    selectedColor:
                        Theme.of(context).primaryColor.withValues(alpha: 0.2),
                    onSelected: (_) =>
                        setState(() => _filterStatus = item['value']!),
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No inspection bookings',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.grey)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchInspections,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final data = _filtered[index];
                            return _buildInspectionCard(
                                data['id']?.toString() ?? '', data);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionCard(String id, Map<String, dynamic> data) {
    final payStatus = data['payment_status'] ?? 'pending';
    final bookStatus = data['booking_status'] ?? 'pending';
    final dateStr = data['inspection_date'] as String?;
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    final fee = (data['inspection_fee'] ?? 0.0).toDouble();
    final fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    Color statusColor;
    switch (bookStatus) {
      case 'confirmed':
        statusColor = Colors.green;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      case 'completed':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(
            payStatus == 'paid' ? Icons.check_circle : Icons.pending,
            color: statusColor,
          ),
        ),
        title: Text(
          data['property_title'] ?? 'Unknown Property',
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Buyer: ${data['user_name'] ?? ''}'),
            Text(
              date != null
                  ? '${date.day}/${date.month}/${date.year} • ${data['time_slot'] ?? ''}'
                  : 'Date not set',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _badge(bookStatus, statusColor),
            const SizedBox(height: 4),
            Text(fmt.format(fee),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green)),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: [
              _row('Buyer Email', data['user_email'] ?? ''),
              _row('Phone', data['user_phone'] ?? 'N/A'),
              _row('Payment Status', payStatus.toUpperCase()),
              _row('Booking Status', bookStatus.toUpperCase()),
              _row('Fee', fmt.format(fee)),
              _row('Reference', data['payment_reference'] ?? ''),
              const SizedBox(height: 12),
              const Text('Update Booking Status:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                for (final s in ['confirmed', 'completed', 'cancelled'])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ElevatedButton(
                        onPressed:
                            bookStatus == s ? null : () => _updateStatus(id, s),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              bookStatus == s ? Colors.grey : statusColor,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(s[0].toUpperCase() + s.substring(1),
                            style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.bold)),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );

  Future<void> _updateStatus(String docId, String newStatus) async {
    try {
      await _supabase.from('inspections').update({
        'booking_status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', docId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Booking status updated to ${newStatus.toUpperCase()}'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
