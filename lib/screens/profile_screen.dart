// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/admin_auth_provider.dart';
import '../models/property_model.dart';
import '../services/flutterwave_service.dart';
import '../config/app_config.dart';
import 'seller_subscription_screen.dart';
import 'favorites_screen.dart';
import 'property_details_screen.dart';
import 'auth/login_screen.dart';
import 'admin/admin_dashboard_screen.dart';
// ── AI feature imports ──────────────────────────────────────────────────────
import 'ai/ai_chat_screen.dart';
import 'ai/pdf_summariser_screen.dart';
import 'ai/lead_scoring_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final adminProvider = Provider.of<AdminAuthProvider>(context);
    final user = authProvider.currentUser;
    final isAdmin = adminProvider.isAdmin;
    final isSeller = user?.userType == 'seller' || user?.userType == 'agent';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), elevation: 0),
      body: user == null && !isAdmin
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(children: [
                // ── Profile Header ─────────────────────────────────────────
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFF1E88E5), Color(0xFF1565C0)]),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      child: user?.photoUrl != null
                          ? ClipOval(
                              child: Image.network(user!.photoUrl!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                      isAdmin
                                          ? Icons.admin_panel_settings
                                          : Icons.person,
                                      size: 50,
                                      color: const Color(0xFF1565C0))))
                          : Icon(
                              isAdmin
                                  ? Icons.admin_panel_settings
                                  : Icons.person,
                              size: 50,
                              color: const Color(0xFF1565C0)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isAdmin ? 'Administrator' : (user?.name ?? 'User'),
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAdmin
                          ? FlutterwaveService.appOwnerEmail
                          : (user?.email ?? ''),
                      style:
                          const TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                    if (user?.phone != null && !isAdmin) ...[
                      const SizedBox(height: 4),
                      Text(user!.phone!,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.white60)),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        isAdmin
                            ? 'ADMIN'
                            : (user?.userType.toUpperCase() ?? 'USER'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                  ]),
                ),

                // ── Menu Items ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    if (isAdmin)
                      _menuItem(context,
                          icon: Icons.dashboard,
                          title: 'Admin Dashboard',
                          subtitle: 'Manage properties & commissions',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const AdminDashboardScreen()))),

                    if (!isAdmin) ...[
                      _menuItem(context,
                          icon: Icons.person_outline,
                          title: 'Edit Profile',
                          subtitle: 'Update your name, phone & photo',
                          onTap: () =>
                              _showEditProfileDialog(context, authProvider)),

                      if (isSeller) ...[
                        _menuItem(context,
                            icon: Icons.subscriptions,
                            title: 'Manage Subscription',
                            subtitle: 'View and manage your seller plan',
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const SellerSubscriptionScreen()))),
                        _menuItem(context,
                            icon: Icons.home_work_outlined,
                            title: 'My Properties',
                            subtitle: 'View all your listed properties',
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        MyPropertiesScreen(userId: user!.id)))),
                        // ── AI Lead Scoring — sellers only ─────────────────
                        _menuItem(context,
                            icon: Icons.psychology,
                            title: 'AI Lead Scoring',
                            subtitle:
                                'Gemini AI ranks your buyer leads',
                            badge: 'AI',
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const LeadScoringScreen()))),
                      ],

                      _menuItem(context,
                          icon: Icons.favorite_outline,
                          title: 'Saved Properties',
                          subtitle:
                              '${user?.savedProperties.length ?? 0} saved',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const FavoritesScreen()))),

                      _menuItem(context,
                          icon: Icons.receipt_long,
                          title: 'Transaction History',
                          subtitle: 'View your payment history',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => TransactionHistoryScreen(
                                      userId: user!.id)))),

                      // ── AI Chat — all users ──────────────────────────────
                      _menuItem(context,
                          icon: Icons.chat_bubble_outline,
                          title: 'Maximus AI Chat',
                          subtitle: 'Ask anything about real estate',
                          badge: 'AI',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AiChatScreen()))),

                      // ── PDF Analyser — all users ─────────────────────────
                      _menuItem(context,
                          icon: Icons.description_outlined,
                          title: 'Document Analyser',
                          subtitle: 'Analyse C of O, Survey Plan & more',
                          badge: 'AI',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const PdfSummariserScreen()))),

                      _menuItem(context,
                          icon: Icons.lock_outline,
                          title: 'Change Password',
                          onTap: () => _showChangePasswordDialog(
                              context, authProvider)),

                      _menuItem(context,
                          icon: Icons.notifications_outlined,
                          title: 'Notifications',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const NotificationsScreen()))),
                    ],

                    _menuItem(context,
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        onTap: () => _showSettingsDialog(context)),

                    _menuItem(context,
                        icon: Icons.headset_mic_outlined,
                        title: 'Contact Support',
                        subtitle: 'Chat, call or email us',
                        onTap: () => _showContactSupportSheet(context)),

                    _menuItem(context,
                        icon: Icons.help_outline,
                        title: 'Help & FAQ',
                        onTap: () => _showHelpDialog(context)),

                    _menuItem(context,
                        icon: Icons.info_outline,
                        title: 'About',
                        onTap: () => _showAboutDialog(context)),

                    const SizedBox(height: 20),

                    _menuItem(context,
                        icon: Icons.logout,
                        title: 'Logout',
                        isDestructive: true,
                        onTap: () => _showLogoutDialog(
                            context, authProvider, adminProvider, isAdmin)),
                  ]),
                ),

                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Maximus Real Estate v1.0.0',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              ]),
            ),
    );
  }

  // ── Contact Support Sheet ─────────────────────────────────────────────────
  void _showContactSupportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.headset_mic,
                  color: Color(0xFF1565C0), size: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Contact Support',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('We\'re here to help!',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ]),
            ),
          ]),
          const SizedBox(height: 24),
          _supportTile(
            ctx: ctx,
            icon: Icons.chat,
            color: const Color(0xFF25D366),
            title: 'WhatsApp Us',
            subtitle: AppConfig.appOwnerWhatsapp,
            badge: 'FASTEST',
            badgeColor: const Color(0xFF25D366),
            onTap: () {
              Navigator.pop(ctx);
              _launchWhatsApp(AppConfig.appOwnerWhatsapp,
                  'Hello! I need help with Maximus Real Estate app.\n\nMy issue: ');
            },
          ),
          _supportTile(
            ctx: ctx,
            icon: Icons.phone,
            color: Colors.blue,
            title: 'Call Us',
            subtitle: AppConfig.appOwnerPhone,
            onTap: () {
              Navigator.pop(ctx);
              _launchPhone(AppConfig.appOwnerPhone);
            },
          ),
          _supportTile(
            ctx: ctx,
            icon: Icons.email_outlined,
            color: Colors.orange,
            title: 'Email Us',
            subtitle: FlutterwaveService.appOwnerEmail,
            onTap: () {
              Navigator.pop(ctx);
              _launchEmail(
                FlutterwaveService.appOwnerEmail,
                'Support Request — Maximus Real Estate',
                'Hello,\n\nI need help with:\n\n[Describe your issue here]\n\nThank you.',
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('Available: Mon – Sat, 8am – 8pm WAT',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                ]),
          ),
        ]),
      ),
    );
  }

  static Widget _supportTile({
    required BuildContext ctx,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
    Color? badgeColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Row(children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (badgeColor ?? color).withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(badge,
                  style: TextStyle(
                      color: badgeColor ?? color,
                      fontSize: 9,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
        subtitle: Text(subtitle,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.arrow_forward_ios, size: 14, color: color),
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _launchWhatsApp(String phone, String message) async {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final withCountry =
        cleaned.startsWith('0') ? '+234${cleaned.substring(1)}' : cleaned;
    final uri = Uri.parse(
        'https://wa.me/$withCountry?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchEmail(
      String to, String subject, String body) async {
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      query:
          'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _showEditProfileDialog(
      BuildContext context, AuthProvider authProvider) {
    final user = authProvider.currentUser;
    final nameController =
        TextEditingController(text: user?.name ?? '');
    final phoneController =
        TextEditingController(text: user?.phone ?? '');
    final whatsappController =
        TextEditingController(text: user?.whatsappNumber ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Profile'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Name required'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: whatsappController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'WhatsApp Number',
                  hintText: 'Leave blank if same as phone',
                  prefixIcon: const Icon(Icons.chat_outlined,
                      color: Color(0xFF25D366)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context);
              final success = await authProvider.updateUserProfile(
                name: nameController.text.trim(),
                phone: phoneController.text.trim().isEmpty
                    ? null
                    : phoneController.text.trim(),
                whatsappNumber: whatsappController.text.trim().isEmpty
                    ? null
                    : whatsappController.text.trim(),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success
                      ? '✅ Profile updated!'
                      : authProvider.errorMessage ?? 'Update failed'),
                  backgroundColor: success ? Colors.green : Colors.red,
                ));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(
      BuildContext context, AuthProvider authProvider) {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureOld = true;
    bool obscureNew = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('Change Password'),
          content: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: oldCtrl,
                obscureText: obscureOld,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscureOld
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => obscureOld = !obscureOld),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newCtrl,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscureNew
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => obscureNew = !obscureNew),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 6) return 'Min 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) =>
                    v != newCtrl.text ? 'Passwords do not match' : null,
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(context);
                final success = await authProvider.changePassword(
                    oldCtrl.text, newCtrl.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(success
                        ? '✅ Password changed!'
                        : authProvider.errorMessage ??
                            'Incorrect current password'),
                    backgroundColor:
                        success ? Colors.green : Colors.red,
                  ));
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.settings_outlined, color: Color(0xFF1565C0)),
          SizedBox(width: 12),
          Text('Settings'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _settingsTile(
              icon: Icons.notifications_outlined,
              title: 'Push Notifications',
              trailing: Switch(
                  value: true,
                  onChanged: (_) {},
                  activeThumbColor: const Color(0xFF1565C0))),
          _settingsTile(
              icon: Icons.language,
              title: 'Language',
              trailing: const Text('English',
                  style: TextStyle(color: Colors.grey))),
          _settingsTile(
              icon: Icons.currency_exchange,
              title: 'Currency',
              trailing: const Text('NGN ₦',
                  style: TextStyle(color: Colors.grey))),
          _settingsTile(
              icon: Icons.dark_mode_outlined,
              title: 'Dark Mode',
              trailing: Switch(
                  value: false,
                  onChanged: (_) {},
                  activeThumbColor: const Color(0xFF1565C0))),
        ]),
        actions: [
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done')),
        ],
      ),
    );
  }

  static Widget _settingsTile(
      {required IconData icon,
      required String title,
      required Widget trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF1565C0), size: 22),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
        trailing,
      ]),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.help_outline, color: Color(0xFF1565C0)),
          SizedBox(width: 12),
          Text('Help & FAQ'),
        ]),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Frequently Asked Questions',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              SizedBox(height: 12),
              _FaqItem(
                  q: 'How do I use the AI features?',
                  a: 'Go to Profile → Maximus AI Chat to ask questions. '
                      'Document Analyser lets you upload a PDF. '
                      'AI Lead Scoring is available for sellers/agents.'),
              _FaqItem(
                  q: 'How do I list a property?',
                  a: 'Sellers/agents tap "Add Property" (floating button). '
                      'First listing is free; subscribe from the 2nd property onwards.'),
              _FaqItem(
                  q: 'How does contact unlocking work?',
                  a: 'Buyers pay ₦3,000 once to see seller contact details for a property.'),
              _FaqItem(
                  q: 'Payment done but app didn\'t respond?',
                  a: 'On the payment screen, tap "I\'ve completed payment — verify now" to manually verify.'),
              _FaqItem(
                  q: 'How is payment split?',
                  a: 'Inspection: 10% platform, 90% seller. '
                      'Purchase: 5% platform, 95% seller. '
                      'Contact unlock: 100% to platform.'),
              SizedBox(height: 12),
              Text('Still need help? Use "Contact Support" above.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.home_rounded,
                color: Color(0xFF1565C0), size: 32),
          ),
          const SizedBox(width: 12),
          const Text('About'),
        ]),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Maximus Real Estate',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Version 1.0.0'),
            SizedBox(height: 16),
            Text(
                'Your trusted platform for buying, selling, and renting '
                'properties across Nigeria. Powered by Gemini AI.',
                style: TextStyle(fontSize: 14)),
            SizedBox(height: 16),
            Text('© 2026 Maximus Real Estate. All rights reserved.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      ),
    );
  }

  void _showLogoutDialog(
      BuildContext context,
      AuthProvider authProvider,
      AdminAuthProvider adminProvider,
      bool isAdmin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (isAdmin) {
                await adminProvider.logoutAdmin();
              } else {
                await authProvider.signOut();
              }
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
    String? badge,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors.red.shade50
                : const Color(0xFF1565C0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              color:
                  isDestructive ? Colors.red : const Color(0xFF1565C0),
              size: 24),
        ),
        title: Row(children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color:
                      isDestructive ? Colors.red : Colors.black87)),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(badge,
                  style: const TextStyle(
                      color: Colors.purple,
                      fontSize: 9,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
        subtitle: subtitle != null
            ? Text(subtitle, style: const TextStyle(fontSize: 12))
            : null,
        trailing: Icon(Icons.chevron_right,
            color: isDestructive ? Colors.red : Colors.grey),
      ),
    );
  }
}

// ── FAQ Item ──────────────────────────────────────────────────────────────────
class _FaqItem extends StatelessWidget {
  final String q;
  final String a;
  const _FaqItem({required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Q: $q',
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 4),
        Text('A: $a',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
    );
  }
}

// ── My Properties Screen ──────────────────────────────────────────────────────
class MyPropertiesScreen extends StatefulWidget {
  final String userId;
  const MyPropertiesScreen({super.key, required this.userId});

  @override
  State<MyPropertiesScreen> createState() => _MyPropertiesScreenState();
}

class _MyPropertiesScreenState extends State<MyPropertiesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<PropertyModel> _properties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyProperties();
  }

  Future<void> _fetchMyProperties() async {
    try {
      setState(() => _isLoading = true);
      final data = await _supabase
          .from('properties')
          .select()
          .eq('owner_id', widget.userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _properties = (data as List)
              .map((row) => PropertyModel.fromSupabaseJson(
                  row as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Properties'),
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchMyProperties),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _properties.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.home_work_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("You haven't listed any properties yet",
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchMyProperties,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _properties.length,
                    itemBuilder: (context, index) {
                      final p = _properties[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      PropertyDetailsScreen(property: p))),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: p.images.isNotEmpty
                                ? Image.network(p.images.first,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                        width: 56,
                                        height: 56,
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.home)))
                                : Container(
                                    width: 56,
                                    height: 56,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.home)),
                          ),
                          title: Text(p.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '₦${NumberFormat.compact().format(p.price)}',
                                  style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                  '${p.location.city} • ${p.bedrooms} bed • ${p.bathrooms} bath',
                                  style:
                                      const TextStyle(fontSize: 12)),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: p.status == 'active'
                                  ? Colors.green.shade100
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(p.status.toUpperCase(),
                                style: TextStyle(
                                    color: p.status == 'active'
                                        ? Colors.green
                                        : Colors.grey,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ── Transaction History Screen ────────────────────────────────────────────────
class TransactionHistoryScreen extends StatefulWidget {
  final String userId;
  const TransactionHistoryScreen({super.key, required this.userId});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends State<TransactionHistoryScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _inspections = [];
  List<Map<String, dynamic>> _unlocks = [];
  bool _isLoading = true;

  final _fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
  final _dateFmt = DateFormat('MMM dd, yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _supabase
          .from('inspections')
          .select()
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false),
      _supabase
          .from('contact_unlocks')
          .select()
          .eq('buyer_id', widget.userId)
          .order('created_at', ascending: false),
    ]);
    if (mounted) {
      setState(() {
        _inspections =
            List<Map<String, dynamic>>.from(results[0] as List);
        _unlocks =
            List<Map<String, dynamic>>.from(results[1] as List);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transaction History'),
          elevation: 0,
          bottom: const TabBar(tabs: [
            Tab(text: 'Inspections'),
            Tab(text: 'Contact Unlocks'),
          ]),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [
                _buildList(_inspections, isInspection: true),
                _buildList(_unlocks, isInspection: false),
              ]),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items,
      {required bool isInspection}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isInspection ? Icons.event_busy : Icons.lock_open,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                  isInspection
                      ? 'No inspection bookings yet'
                      : 'No contact unlocks yet',
                  style:
                      const TextStyle(fontSize: 16, color: Colors.grey)),
            ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final data = items[index];
          final dateStr = isInspection
              ? data['inspection_date'] as String?
              : data['created_at'] as String?;
          final createdStr = data['created_at'] as String?;
          final date =
              dateStr != null ? DateTime.tryParse(dateStr) : null;
          final created =
              createdStr != null ? DateTime.tryParse(createdStr) : null;

          final status = isInspection
              ? (data['payment_status'] ?? 'pending') as String
              : (data['status'] ?? 'pending') as String;

          final amount = isInspection
              ? _fmt.format((data['inspection_fee'] ?? 0).toDouble())
              : _fmt.format((data['unlock_fee'] ?? 0).toDouble());

          Color statusColor;
          switch (status) {
            case 'paid':
            case 'completed':
            case 'free':
              statusColor = Colors.green;
              break;
            case 'pending':
              statusColor = Colors.orange;
              break;
            default:
              statusColor = Colors.red;
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color:
                        (isInspection ? Colors.blue : Colors.orange)
                            .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(
                    isInspection
                        ? Icons.event_available
                        : Icons.phone,
                    color:
                        isInspection ? Colors.blue : Colors.orange,
                    size: 24),
              ),
              title: Text(data['property_title'] ?? 'Property',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isInspection
                        ? (date != null
                            ? '${date.day}/${date.month}/${date.year} • ${data['time_slot'] ?? ''}'
                            : 'Date not set')
                        : 'Contact unlock',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (created != null)
                    Text(_dateFmt.format(created),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(amount,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(status.toUpperCase(),
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}

// ── Notifications Screen ──────────────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      setState(() => _isLoading = true);
      final userId = _supabase.auth.currentUser?.id ?? '';
      if (userId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }
      final data = await _supabase
          .from('inspections')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);

      if (mounted) {
        setState(() {
          _notifications =
              List<Map<String, dynamic>>.from(data as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchNotifications),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No notifications yet',
                          style:
                              TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final data = _notifications[index];
                      final bookStatus =
                          data['booking_status'] ?? 'pending';
                      final payStatus =
                          data['payment_status'] ?? 'pending';
                      final createdStr =
                          data['created_at'] as String?;
                      final createdAt = createdStr != null
                          ? DateTime.tryParse(createdStr)
                          : null;

                      IconData icon;
                      Color iconColor;
                      String message;

                      if (payStatus == 'paid' &&
                          bookStatus == 'confirmed') {
                        icon = Icons.check_circle;
                        iconColor = Colors.green;
                        message =
                            'Your inspection for "${data['property_title']}" is confirmed!';
                      } else if (bookStatus == 'cancelled') {
                        icon = Icons.cancel;
                        iconColor = Colors.red;
                        message =
                            'Your inspection for "${data['property_title']}" was cancelled.';
                      } else if (payStatus == 'free') {
                        icon = Icons.check_circle;
                        iconColor = Colors.green;
                        message =
                            'Free inspection booked for "${data['property_title']}"!';
                      } else {
                        icon = Icons.pending;
                        iconColor = Colors.orange;
                        message =
                            'Inspection booking pending for "${data['property_title']}".';
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              iconColor.withOpacity(0.1),
                          child:
                              Icon(icon, color: iconColor, size: 22),
                        ),
                        title: Text(message,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: createdAt != null
                            ? Text(
                                DateFormat('MMM dd, yyyy')
                                    .format(createdAt),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey))
                            : null,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                      );
                    },
                  ),
                ),
    );
  }
}