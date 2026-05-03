// lib/screens/admin/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/property_provider.dart';
import '../../providers/admin_auth_provider.dart';
import '../../services/flutterwave_service.dart';
import 'admin_add_property_screen.dart';
import 'admin_manage_property_screen.dart';
import 'admin_commission_dashboard.dart';
import 'admin_analytics_screen.dart';
import 'admin_users_screen.dart';
import 'admin_inspections_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FlutterwaveService _flwService = FlutterwaveService();
  Map<String, dynamic> _statistics = {};
  Map<String, dynamic> _commissionStats = {};
  bool _isLoadingStats = true;
  bool _isLoadingCommissions = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
    _loadCommissions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PropertyProvider>(context, listen: false).fetchProperties();
    });
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoadingStats = true);
    final stats = await Provider.of<PropertyProvider>(context, listen: false)
        .getPropertyStatistics();
    if (mounted) setState(() { _statistics = stats; _isLoadingStats = false; });
  }

  Future<void> _loadCommissions() async {
    setState(() => _isLoadingCommissions = true);
    final stats = await _flwService.getTotalCommissions();
    if (mounted) setState(() { _commissionStats = stats; _isLoadingCommissions = false; });
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadStatistics(),
      _loadCommissions(),
      Provider.of<PropertyProvider>(context, listen: false).fetchProperties(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshAll),
          IconButton(icon: const Icon(Icons.logout), onPressed: _showLogoutDialog),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeSection(),
              const SizedBox(height: 24),
              _buildCommissionOverview(),
              const SizedBox(height: 24),
              _buildStatisticsSection(),
              const SizedBox(height: 24),
              _buildQuickActions(),
              const SizedBox(height: 24),
              _buildRecentActivity(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Welcome Back, Admin!',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionOverview() {
    if (_isLoadingCommissions) {
      return const Card(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())));
    }
    final fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final total = _commissionStats['totalCommissions'] ?? 0.0;
    final today = _commissionStats['todayCommissions'] ?? 0.0;
    final month = _commissionStats['thisMonthCommissions'] ?? 0.0;

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCommissionDashboard())),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.green.shade600, Colors.green.shade400],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total Revenue', style: TextStyle(color: Colors.white70, fontSize: 16)),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
            ),
          ]),
          const SizedBox(height: 16),
          Text(fmt.format(total),
              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Today', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(fmt.format(today), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ])),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('This Month', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(fmt.format(month), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ])),
          ]),
          const SizedBox(height: 12),
          const Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('View Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 4),
            Icon(Icons.arrow_forward, color: Colors.white, size: 16),
          ]),
        ]),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    if (_isLoadingStats) return const Center(child: CircularProgressIndicator());
    final total = _statistics['totalProperties'] ?? 0;
    final active = _statistics['activeProperties'] ?? 0;
    final sold = _statistics['soldProperties'] ?? 0;
    final views = _statistics['totalViews'] ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Properties Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _statCard(Icons.home_work, 'Total', total.toString(), Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _statCard(Icons.check_circle, 'Active', active.toString(), Colors.green)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _statCard(Icons.sell, 'Sold', sold.toString(), Colors.orange)),
        const SizedBox(width: 12),
        Expanded(child: _statCard(Icons.visibility, 'Views', _fmt(views), Colors.purple)),
      ]),
    ]);
  }

  Widget _statCard(IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ])),
      ]),
    );
  }

  Widget _buildQuickActions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _actionCard(Icons.add_home, 'Add Property', Colors.blue,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAddPropertyScreen())))),
        const SizedBox(width: 12),
        Expanded(child: _actionCard(Icons.list, 'Manage', Colors.orange,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminManagePropertiesScreen())))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _actionCard(Icons.account_balance_wallet, 'Commissions', Colors.green,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCommissionDashboard())))),
        const SizedBox(width: 12),
        // FIX: navigates to AdminAnalyticsScreen now
        Expanded(child: _actionCard(Icons.bar_chart, 'Analytics', Colors.purple,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAnalyticsScreen())))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _actionCard(Icons.people, 'Users', Colors.teal,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersScreen())))),
        const SizedBox(width: 12),
        Expanded(child: _actionCard(Icons.event_available, 'Inspections', Colors.indigo,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminInspectionsScreen())))),
      ]),
    ]);
  }

  Widget _actionCard(IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Recent Properties', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminManagePropertiesScreen())),
          child: const Text('View All'),
        ),
      ]),
      const SizedBox(height: 16),
      Consumer<PropertyProvider>(builder: (context, pp, _) {
        if (pp.isLoading) return const Center(child: CircularProgressIndicator());
        final recent = pp.properties.take(3).toList();
        if (recent.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: const Center(child: Column(children: [
              Icon(Icons.home_work_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text('No properties yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
            ])),
          );
        }
        return Column(children: recent.map((p) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                p.images.isNotEmpty ? p.images.first : '',
                width: 60, height: 60, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 60, height: 60, color: Colors.grey.shade300, child: const Icon(Icons.home)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('₦${_fmt(p.price.toInt())}',
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: p.status == 'active' ? Colors.green.shade100 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(p.status.toUpperCase(),
                  style: TextStyle(
                      color: p.status == 'active' ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold, fontSize: 10)),
            ),
          ]),
        )).toList());
      }),
    ]);
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await Provider.of<AdminAuthProvider>(context, listen: false).logoutAdmin();
              if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}