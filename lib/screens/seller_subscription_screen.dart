// lib/screens/seller_subscription_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/flutterwave_service.dart';
import '../models/transaction_model.dart';
import 'flutterwave_webview_screen.dart';

class SellerSubscriptionScreen extends StatefulWidget {
  const SellerSubscriptionScreen({Key? key}) : super(key: key);

  @override
  State<SellerSubscriptionScreen> createState() =>
      _SellerSubscriptionScreenState();
}

class _SellerSubscriptionScreenState
    extends State<SellerSubscriptionScreen> {
  final FlutterwaveService _flwService = FlutterwaveService();
  SellerSubscription? _currentSubscription;
  int _propertyCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final results = await Future.wait([
      _flwService.getSellerSubscription(user.id),
      _flwService.getSellerPropertyCount(user.id),
    ]);

    if (!mounted) return;
    setState(() {
      _currentSubscription = results[0] as SellerSubscription?;
      _propertyCount = results[1] as int;
      _isLoading = false;
    });
  }

  Future<void> _subscribe(String plan) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to subscribe')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await _flwService.paySellerSubscription(
      seller: user,
      plan: plan,
    );

    if (!mounted) return;
    Navigator.pop(context); // remove loading

    if (result == null || result['status'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result?['message'] ?? 'Failed to initialize payment'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final paymentUrl = result['payment_url'] as String?;
    final txRef = result['tx_ref'] as String;

    if (paymentUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Payment URL not received'),
          backgroundColor: Colors.red));
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlutterwaveWebViewScreen(
          paymentUrl: paymentUrl,
          txRef: txRef,
          onSuccess: (ref) async {
            final success = await _flwService.processSubscriptionPayment(
              ref,
              user.id,
              plan,
            );
            if (mounted) {
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('✅ Subscription activated successfully!'),
                  backgroundColor: Colors.green,
                ));
                _loadData();
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
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment cancelled')));
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seller Subscription'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFreeListingCard(),
                    const SizedBox(height: 16),

                    if (_currentSubscription != null) ...[
                      _buildCurrentSubscription(),
                      const SizedBox(height: 24),
                    ],

                    const Text('Choose Your Plan',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      'Unlock unlimited listings and premium features',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),

                    _buildPlanCard(
                      plan: 'basic',
                      name: 'Basic Plan',
                      price: FlutterwaveService.basicPlanFee,
                      features: [
                        'List up to 20 properties',
                        'Standard property visibility',
                        'Email support',
                        'Basic analytics',
                        'Flutterwave payment integration',
                      ],
                      color: Colors.blue,
                      isRecommended: false,
                    ),
                    const SizedBox(height: 16),

                    _buildPlanCard(
                      plan: 'premium',
                      name: 'Premium Plan',
                      price: FlutterwaveService.premiumPlanFee,
                      features: [
                        'Unlimited property listings',
                        'Featured property spots',
                        'Priority support',
                        'Advanced analytics',
                        'Top search placement',
                        'Professional badge',
                        'Priority customer support',
                      ],
                      color: Colors.amber,
                      isRecommended: true,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFreeListingCard() {
    final bool usedFree = _propertyCount > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: usedFree
              ? [Colors.grey.shade400, Colors.grey.shade500]
              : [Colors.green.shade400, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Icon(
          usedFree ? Icons.check_circle : Icons.card_giftcard,
          color: Colors.white,
          size: 36,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                usedFree ? 'Free Listing Used' : '1 Free Listing Available',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                usedFree
                    ? 'Subscribe to list more properties.'
                    : 'Your first property listing is completely free!',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildCurrentSubscription() {
    final sub = _currentSubscription!;
    final daysLeft = sub.expiryDate.difference(DateTime.now()).inDays;
    final isActive = sub.isActive && !sub.isExpired;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [Colors.green.shade600, Colors.green.shade400]
              : [Colors.grey.shade600, Colors.grey.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isActive ? Colors.green : Colors.grey).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Current Subscription',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                isActive ? 'ACTIVE' : 'EXPIRED',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Text('${sub.plan.toUpperCase()} PLAN',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Text(
              isActive
                  ? '$daysLeft days remaining'
                  : 'Expired ${-daysLeft} days ago',
              style: const TextStyle(color: Colors.white70),
            ),
          ]),
          if (!isActive) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _subscribe(sub.plan),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.grey.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                child: const Text('Renew Subscription'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String plan,
    required String name,
    required double price,
    required List<String> features,
    required Color color,
    required bool isRecommended,
  }) {
    final isCurrentPlan = _currentSubscription?.plan == plan &&
        _currentSubscription?.isActive == true &&
        !_currentSubscription!.isExpired;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
            color: isRecommended ? color : Colors.grey.shade300,
            width: isRecommended ? 3 : 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRecommended)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14))),
              child: const Text('⭐ RECOMMENDED',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color)),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('₦${price.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 36, fontWeight: FontWeight.bold)),
                  const Text('/month',
                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                ]),
                const SizedBox(height: 20),
                ...features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(children: [
                        Icon(Icons.check_circle, color: color, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(f,
                                style: const TextStyle(fontSize: 14))),
                      ]),
                    )),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isCurrentPlan ? null : () => _subscribe(plan),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: isCurrentPlan ? Colors.grey : color,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: Text(
                      isCurrentPlan ? 'Current Plan' : 'Subscribe Now',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}