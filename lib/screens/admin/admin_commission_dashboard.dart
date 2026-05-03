// lib/screens/admin/admin_commission_dashboard.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/flutterwave_service.dart';

class AdminCommissionDashboard extends StatefulWidget {
  const AdminCommissionDashboard({super.key});

  @override
  State<AdminCommissionDashboard> createState() =>
      _AdminCommissionDashboardState();
}

class _AdminCommissionDashboardState extends State<AdminCommissionDashboard>
    with SingleTickerProviderStateMixin {
  final FlutterwaveService _flwService =
      FlutterwaveService();
  final SupabaseClient _supabase = Supabase.instance.client;

  Map<String, dynamic> _commissionStats = {};
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCommissionStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCommissionStats() async {
    setState(() => _isLoading = true);
    final stats = await _flwService.getTotalCommissions();
    if (mounted) {
      setState(() {
        _commissionStats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commission Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadCommissionStats),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Transactions'),
            Tab(text: 'Subscriptions'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _loadCommissionStats,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildTotalEarningsCard(fmt),
                      const SizedBox(height: 16),
                      _buildRevenueBreakdown(fmt),
                      const SizedBox(height: 16),
                      _buildTransactionStats(fmt),
                    ],
                  ),
                ),
                _buildTransactionsTab(),
                _buildSubscriptionsTab(fmt),
              ],
            ),
    );
  }

  Widget _buildTotalEarningsCard(NumberFormat fmt) {
    return Card(
      elevation: 4,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF2196F3)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Total Platform Revenue',
              style:
                  TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            fmt.format(_commissionStats['totalCommissions'] ?? 0),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(children: [
            _miniStat('Today',
                fmt.format(_commissionStats['todayCommissions'] ?? 0)),
            const SizedBox(width: 24),
            _miniStat('This Month',
                fmt.format(_commissionStats['thisMonthCommissions'] ?? 0)),
          ]),
        ]),
      ),
    );
  }

  Widget _miniStat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      );

  Widget _buildRevenueBreakdown(NumberFormat fmt) {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('Revenue Breakdown',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _revenueRow(
              'Contact Unlocks',
              '${_commissionStats['contactUnlocks'] ?? 0} unlocks',
              Colors.purple),
          _revenueRow(
              'Inspection Commissions',
              fmt.format(
                  _commissionStats['inspectionCommissions'] ?? 0),
              Colors.orange),
          _revenueRow(
              'Property Sale Commissions',
              fmt.format(_commissionStats['salesCommissions'] ?? 0),
              Colors.green),
          const Divider(),
          _revenueRow(
              'Pending Seller Payouts',
              fmt.format(
                  _commissionStats['pendingSellerPayouts'] ?? 0),
              Colors.red),
        ]),
      ),
    );
  }

  Widget _revenueRow(String label, String value, Color color) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Container(
              width: 12,
              height: 12,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color)),
        ]),
      );

  Widget _buildTransactionStats(NumberFormat fmt) {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('Transaction Stats',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _statCard(
                    'Total Transactions',
                    '${_commissionStats['totalTransactions'] ?? 0}',
                    Colors.blue)),
            const SizedBox(width: 12),
            Expanded(
                child: _statCard(
                    'Auto Split',
                    '${_commissionStats['autoSplitCount'] ?? 0}',
                    Colors.green)),
          ]),
        ]),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // FIX: was `.withValues(alpha: 0.1)` — use `.withOpacity()` for
          // compatibility across all Flutter versions in this project.
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade700)),
        ]),
      );

  Widget _buildTransactionsTab() {
    return FutureBuilder(
      future: _supabase
          .from('commission_transactions')
          .select()
          .order('created_at', ascending: false)
          .limit(50),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
          return const Center(child: Text('No transactions yet'));
        }
        final fmt =
            NumberFormat.currency(symbol: '₦', decimalDigits: 0);
        final rows = snapshot.data as List;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final t = rows[i] as Map<String, dynamic>;
            // FIX: was `as double` — Supabase returns NUMERIC as num,
            // which can be int. Use .toDouble() to avoid a cast crash.
            final commission =
                (t['commission_amount'] ?? 0).toDouble();
            final amount = fmt.format(commission);
            final type =
                (t['type'] ?? '').toString().replaceAll('_', ' ');
            final date = t['created_at'] != null
                ? DateFormat('dd MMM yyyy')
                    .format(DateTime.parse(t['created_at']))
                : '';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Colors.blue.withOpacity(0.1),
                  child:
                      const Icon(Icons.receipt, color: Colors.blue),
                ),
                title: Text(
                    type.isNotEmpty
                        ? type[0].toUpperCase() + type.substring(1)
                        : '',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${t['buyer_name'] ?? ''} → '
                    '${t['property_title'] ?? ''}\n$date'),
                trailing: Text(amount,
                    style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold)),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSubscriptionsTab(NumberFormat fmt) {
    return FutureBuilder(
      future: _supabase
          .from('seller_subscriptions')
          .select()
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
          return const Center(child: Text('No subscriptions yet'));
        }
        final rows = snapshot.data as List;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final s = rows[i] as Map<String, dynamic>;
            final isActive = s['is_active'] == true;
            final expiryStr = s['expiry_date'] as String?;
            final expiry = expiryStr != null
                ? DateTime.tryParse(expiryStr)
                : null;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isActive
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  child: Icon(Icons.star,
                      color:
                          isActive ? Colors.green : Colors.red),
                ),
                title: Text(s['seller_name'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${(s['plan'] ?? '').toUpperCase()} • '
                    '${s['seller_email'] ?? ''}\n'
                    'Expiry: ${expiry != null ? DateFormat('dd MMM yyyy').format(expiry) : 'N/A'}'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                      isActive ? 'ACTIVE' : 'EXPIRED',
                      style: TextStyle(
                          color: isActive
                              ? Colors.green
                              : Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}