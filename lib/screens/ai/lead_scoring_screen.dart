// lib/screens/ai/lead_scoring_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/gemini_service.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class LeadScoringScreen extends StatefulWidget {
  const LeadScoringScreen({super.key});

  @override
  State<LeadScoringScreen> createState() => _LeadScoringScreenState();
}

class _LeadScoringScreenState extends State<LeadScoringScreen> {
  final GeminiService _gemini = GeminiService();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<_LeadItem> _leads = [];
  bool _isLoading = true;
  bool _isScoring = false;

  @override
  void initState() {
    super.initState();
    _loadLeads();
  }

  Future<void> _loadLeads() async {
    setState(() => _isLoading = true);

    final authProvider =
        Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Load all inspections for this seller's properties
      final inspections = await _supabase
          .from('inspections')
          .select()
          .order('created_at', ascending: false);

      // Load properties owned by this seller to cross-reference
      final properties = await _supabase
          .from('properties')
          .select('id, title, price, owner_id')
          .eq('owner_id', user.id);

      final myPropertyIds =
          (properties as List).map((p) => p['id'].toString()).toSet();

      final myLeads = (inspections as List)
          .where((i) =>
              myPropertyIds.contains(i['property_id']?.toString()))
          .map((i) {
        final propRow = (properties).firstWhere(
            (p) => p['id'].toString() == i['property_id']?.toString(),
            orElse: () => <String, dynamic>{});
        return _LeadItem(
          inspectionId: i['id']?.toString() ?? '',
          buyerName: i['user_name'] ?? 'Unknown',
          buyerEmail: i['user_email'] ?? '',
          buyerPhone: i['user_phone'] ?? '',
          propertyTitle: i['property_title'] ?? propRow['title'] ?? '',
          propertyPrice: (propRow['price'] ?? 0.0).toDouble(),
          bookingStatus: i['booking_status'] ?? 'pending',
          paymentStatus: i['payment_status'] ?? 'pending',
          inspectionDate: i['inspection_date'] != null
              ? DateTime.parse(i['inspection_date'])
              : DateTime.now(),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _leads = myLeads;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _scoreAllLeads() async {
    if (_leads.isEmpty) return;
    setState(() => _isScoring = true);

    for (int i = 0; i < _leads.length; i++) {
      final lead = _leads[i];
      if (lead.scoreResult != null) continue; // already scored

      final result = await _gemini.scoreLead(
        buyerName: lead.buyerName,
        buyerEmail: lead.buyerEmail,
        buyerPhone: lead.buyerPhone,
        propertyTitle: lead.propertyTitle,
        propertyPrice: lead.propertyPrice,
        bookingStatus: lead.bookingStatus,
        paymentStatus: lead.paymentStatus,
        inspectionDate: lead.inspectionDate,
        hasUnlockedContact: lead.paymentStatus == 'paid',
        savedPropertiesCount: 1,
      );

      if (mounted) {
        setState(() {
          _leads[i] = lead.copyWith(scoreResult: result);
        });
      }

      // Small delay to avoid rate limit
      await Future.delayed(const Duration(milliseconds: 400));
    }

    if (mounted) setState(() => _isScoring = false);
  }

  @override
  Widget build(BuildContext context) {
    final sortedLeads = List<_LeadItem>.from(_leads)
      ..sort((a, b) {
        final aScore = a.scoreResult?['score'] as int? ?? -1;
        final bScore = b.scoreResult?['score'] as int? ?? -1;
        return bScore.compareTo(aScore);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lead Scoring'),
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _loadLeads),
        ],
      ),
      body: Column(
        children: [
          // Header banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF2196F3)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text('AI Lead Scoring',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ]),
                const SizedBox(height: 4),
                const Text(
                  'Gemini AI ranks your buyer leads by purchase likelihood',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  _statChip('${_leads.length}', 'Total leads'),
                  const SizedBox(width: 12),
                  _statChip(
                      '${_leads.where((l) => l.paymentStatus == 'paid').length}',
                      'Paid'),
                  const SizedBox(width: 12),
                  _statChip(
                      '${_leads.where((l) => l.scoreResult != null).length}',
                      'Scored'),
                ]),
              ],
            ),
          ),

          // Score button
          if (_leads.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isScoring ? null : _scoreAllLeads,
                  icon: _isScoring
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.psychology),
                  label: Text(_isScoring
                      ? 'Scoring leads with AI...'
                      : 'Score All Leads with AI'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFF1565C0),
                  ),
                ),
              ),
            ),

          // Lead list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : sortedLeads.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text('No leads yet',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.grey)),
                            const SizedBox(height: 8),
                            const Text(
                                'Buyers who book inspections will appear here',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadLeads,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: sortedLeads.length,
                          itemBuilder: (context, index) =>
                              _LeadCard(lead: sortedLeads[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      );
}

class _LeadCard extends StatelessWidget {
  final _LeadItem lead;
  const _LeadCard({required this.lead});

  @override
  Widget build(BuildContext context) {
    final score = lead.scoreResult?['score'] as int?;
    final label = lead.scoreResult?['label'] as String?;
    final advice = lead.scoreResult?['advice'] as String?;
    final fmt = DateFormat('dd MMM yyyy');

    Color labelColor;
    switch (label) {
      case 'Hot':
        labelColor = Colors.red;
        break;
      case 'Warm':
        labelColor = Colors.orange;
        break;
      default:
        labelColor = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: Text(
                  lead.buyerName.isNotEmpty
                      ? lead.buyerName[0].toUpperCase()
                      : 'B',
                  style: const TextStyle(
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lead.buyerName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text(lead.propertyTitle,
                        style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (score != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$score',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: labelColor)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: labelColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(label ?? '',
                          style: TextStyle(
                              color: labelColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Not scored',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              ],
            ]),
            const SizedBox(height: 12),
            // Score bar
            if (score != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: score / 100,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(labelColor),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(children: [
              _chip(Icons.calendar_today,
                  fmt.format(lead.inspectionDate), Colors.grey),
              const SizedBox(width: 8),
              _chip(
                  lead.paymentStatus == 'paid'
                      ? Icons.check_circle
                      : Icons.pending,
                  lead.paymentStatus.toUpperCase(),
                  lead.paymentStatus == 'paid'
                      ? Colors.green
                      : Colors.orange),
              const SizedBox(width: 8),
              _chip(
                  Icons.event,
                  lead.bookingStatus.toUpperCase(),
                  lead.bookingStatus == 'confirmed'
                      ? Colors.blue
                      : Colors.grey),
            ]),
            if (advice != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        color: Colors.blue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(advice,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                              height: 1.4)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

// ── Data class ────────────────────────────────────────────────────────────────
class _LeadItem {
  final String inspectionId;
  final String buyerName;
  final String buyerEmail;
  final String buyerPhone;
  final String propertyTitle;
  final double propertyPrice;
  final String bookingStatus;
  final String paymentStatus;
  final DateTime inspectionDate;
  final Map<String, dynamic>? scoreResult;

  const _LeadItem({
    required this.inspectionId,
    required this.buyerName,
    required this.buyerEmail,
    required this.buyerPhone,
    required this.propertyTitle,
    required this.propertyPrice,
    required this.bookingStatus,
    required this.paymentStatus,
    required this.inspectionDate,
    this.scoreResult,
  });

  _LeadItem copyWith({Map<String, dynamic>? scoreResult}) => _LeadItem(
        inspectionId: inspectionId,
        buyerName: buyerName,
        buyerEmail: buyerEmail,
        buyerPhone: buyerPhone,
        propertyTitle: propertyTitle,
        propertyPrice: propertyPrice,
        bookingStatus: bookingStatus,
        paymentStatus: paymentStatus,
        inspectionDate: inspectionDate,
        scoreResult: scoreResult ?? this.scoreResult,
      );
}