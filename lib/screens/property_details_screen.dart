// lib/screens/property_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/property_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/image_gallery_viewer.dart';
import '../services/production_paystack_service.dart';
import 'inspection_booking_screen.dart';
import 'paystack_webview_screen.dart';
import 'ai/neighbourhood_insights_screen.dart';
import 'ai/ai_chat_screen.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final PropertyModel property;
  const PropertyDetailsScreen({super.key, required this.property});

  @override
  State<PropertyDetailsScreen> createState() =>
      _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  int _currentImageIndex = 0;
  final ProductionPaystackService _paystackService =
      ProductionPaystackService();
  final SupabaseClient _supabase = Supabase.instance.client;
  final _currencyFmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  void _showVideoPlayer(String videoUrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => VideoPlayerSheet(videoUrl: videoUrl),
    );
  }

  // Fetch seller profile as fallback for contact details
  Future<Map<String, dynamic>?> _fetchSellerData() async {
    try {
      return await _supabase
          .from('users')
          .select()
          .eq('id', widget.property.ownerId)
          .maybeSingle();
    } catch (e) {
      debugPrint('Error fetching seller data: $e');
      return null;
    }
  }

  void _handleContactAgent(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please login to contact the agent'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final alreadyUnlocked = await _paystackService.hasUnlockedContact(
        user.id, widget.property.id);
    final sellerData = await _fetchSellerData();

    if (!mounted) return;
    Navigator.pop(context);

    if (alreadyUnlocked) {
      _showContactSheet(context, sellerData);
    } else {
      _showUnlockContactSheet(context, user, sellerData);
    }
  }

  void _showUnlockContactSheet(BuildContext context, dynamic user,
      Map<String, dynamic>? sellerData) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline, size: 48, color: Color(0xFF1565C0)),
          const SizedBox(height: 16),
          const Text('Contact Details Locked',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            'Pay ₦3,000 once to unlock the agent\'s phone number, WhatsApp, and email for this property.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This is a one-time fee. You will always have access to this seller\'s contact for this property.',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.lock_open),
              label: const Text('Pay ₦3,000 to Unlock Contact',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF1565C0),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _processContactUnlockPayment(context, user);
              },
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _processContactUnlockPayment(
      BuildContext context, dynamic user) async {
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await _paystackService.payToUnlockContact(
      context: context,
      property: widget.property,
      buyer: user,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (result == null || result['status'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result?['message'] ?? 'Failed to initialize payment'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final authorizationUrl = result['authorization_url'] as String?;
    final reference = result['reference'] as String;

    if (authorizationUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Payment URL not received'),
          backgroundColor: Colors.red));
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaystackWebViewScreen(
          authorizationUrl: authorizationUrl,
          reference: reference,
          onSuccess: (ref) async {
            final success =
                await _paystackService.processContactUnlock(ref);
            if (mounted) {
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('✅ Contact unlocked successfully!'),
                  backgroundColor: Colors.green,
                ));
                final sellerData = await _fetchSellerData();
                if (mounted) _showContactSheet(context, sellerData);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      'Payment verification failed. Contact support.'),
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

  void _showContactSheet(
      BuildContext context, Map<String, dynamic>? sellerData) {
    final propPhone = widget.property.sellerPhone.trim();
    final propWhatsapp = widget.property.sellerWhatsapp.trim();
    final propEmail = widget.property.sellerEmail.trim();

    final phone = propPhone.isNotEmpty
        ? propPhone
        : (sellerData?['phone'] as String?)?.trim() ?? '';
    final whatsapp = propWhatsapp.isNotEmpty
        ? propWhatsapp
        : ((sellerData?['whatsapp_number'] as String?)?.trim() ?? phone);
    final email = propEmail.isNotEmpty
        ? propEmail
        : (sellerData?['email'] as String?) ?? '';
    final name = (sellerData?['name'] as String?) ?? 'Agent';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              radius: 24,
              child: const Icon(Icons.person,
                  color: Color(0xFF1565C0), size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Agent / Property Owner',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13)),
                  ]),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12)),
              child: const Text('Verified',
                  style: TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          const Divider(height: 28),
          if (phone.isNotEmpty) ...[
            _contactTile(
              icon: Icons.phone,
              color: const Color(0xFF2196F3),
              title: 'Call Agent',
              subtitle: phone,
              onTap: () {
                Navigator.pop(ctx);
                _makePhoneCall(phone);
              },
            ),
            _contactTile(
              icon: Icons.chat,
              color: const Color(0xFF25D366),
              title: 'WhatsApp',
              subtitle: whatsapp.isNotEmpty ? whatsapp : phone,
              onTap: () {
                Navigator.pop(ctx);
                _launchWhatsApp(whatsapp.isNotEmpty ? whatsapp : phone);
              },
            ),
            _contactTile(
              icon: Icons.sms,
              color: Colors.purple,
              title: 'Send SMS',
              subtitle: phone,
              onTap: () {
                Navigator.pop(ctx);
                _sendSms(phone);
              },
            ),
          ],
          if (email.isNotEmpty)
            _contactTile(
              icon: Icons.email,
              color: Colors.orange,
              title: 'Send Email',
              subtitle: email,
              onTap: () {
                Navigator.pop(ctx);
                _sendEmail(
                  email,
                  'Enquiry: ${widget.property.title}',
                  'Hello $name,\n\nI am interested in the property: ${widget.property.title}\n'
                      'Price: ₦${_formatPrice(widget.property.price)}\n'
                      'Location: ${widget.property.location.fullAddress}\n\n'
                      'Please contact me.\n\nThank you.',
                );
              },
            ),
          if (phone.isEmpty && email.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No contact details available for this agent.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _contactTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 22),
      ),
      title:
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios,
          size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _handleBuyProperty(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please login to purchase this property'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    if (user.id == widget.property.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('You cannot buy your own property'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final double buyAmount = widget.property.buyPrice > 0
        ? widget.property.buyPrice
        : widget.property.price;
    final double sellerPayout = buyAmount -
        buyAmount * ProductionPaystackService.purchaseCommissionRate / 100;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Purchase Property'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('You are about to purchase:',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Text(widget.property.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          _summaryRow('Total Price',
              _currencyFmt.format(buyAmount), Colors.blue),
          const SizedBox(height: 8),
          const Text(
            'Payment is processed securely via Paystack.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Proceed to Payment')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await _paystackService.initiatePropertyPurchase(
      property: widget.property,
      buyer: user,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (result == null || result['status'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result?['message'] ?? 'Failed to initialize payment'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final authorizationUrl = result['authorization_url'] as String?;
    final reference = result['reference'] as String;

    if (authorizationUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Payment URL not received'),
          backgroundColor: Colors.red));
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaystackWebViewScreen(
          authorizationUrl: authorizationUrl,
          reference: reference,
          onSuccess: (ref) async {
            final success = await _paystackService.processPropertyPurchase(
              ref,
              widget.property,
              user,
            );
            if (mounted) {
              if (success) {
                _showPurchaseSuccessDialog(buyAmount, sellerPayout);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content:
                      Text('Payment verification failed. Contact support.'),
                  backgroundColor: Colors.red,
                ));
              }
            }
          },
          onCancel: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Purchase cancelled')));
            }
          },
        ),
      ),
    );
  }

  void _showPurchaseSuccessDialog(double amount, double sellerPayout) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Purchase Successful!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            'You have successfully paid ${_currencyFmt.format(amount)} for ${widget.property.title}.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'The agent will contact you shortly to complete the transaction.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ]),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
      ]),
    );
  }

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _sendSms(String phone) async {
    final uri = Uri(scheme: 'sms', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _sendEmail(
      String to, String subject, String body) async {
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      query:
          'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchWhatsApp(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final withCountry =
        cleaned.startsWith('0') ? '+234${cleaned.substring(1)}' : cleaned;
    final message = Uri.encodeComponent(
        'Hello, I am interested in: ${widget.property.title}\n'
        'Price: ₦${_formatPrice(widget.property.price)}\n'
        'Location: ${widget.property.location.fullAddress}');
    final uri =
        Uri.parse('https://wa.me/$withCountry?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M';
    }
    if (price >= 1000) return '${(price / 1000).toStringAsFixed(0)}K';
    return price.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isSaved = authProvider.isPropertySaved(widget.property.id);

    return Scaffold(
      body: Stack(children: [
        CustomScrollView(slivers: [
          // Image Gallery
          SliverToBoxAdapter(
            child: SizedBox(
              height: 350,
              child: Stack(children: [
                widget.property.images.isNotEmpty
                    ? PageView.builder(
                        itemCount: widget.property.images.length,
                        onPageChanged: (index) =>
                            setState(() => _currentImageIndex = index),
                        itemBuilder: (context, index) => GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ImageGalleryViewer(
                                  images: widget.property.images,
                                  initialIndex: index),
                            ),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: widget.property.images[index],
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                                color: Colors.grey[300],
                                child: const Center(
                                    child: CircularProgressIndicator())),
                            errorWidget: (_, __, ___) => Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.error)),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[300],
                        child: const Center(
                            child: Icon(Icons.home,
                                size: 64, color: Colors.grey))),

                if (widget.property.images.length > 1)
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        widget.property.images.length,
                        (index) => Container(
                          margin:
                              const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentImageIndex == index
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),

                if (widget.property.videos.isNotEmpty)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: GestureDetector(
                      onTap: () => _showVideoPlayer(
                          widget.property.videos.first),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(children: [
                          Icon(Icons.play_circle_outline,
                              color: Colors.white, size: 20),
                          SizedBox(width: 6),
                          Text('Video Tour',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
          ),

          // Property Details
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _badge(widget.property.propertyType, Colors.blue),
                      const SizedBox(width: 8),
                      _badge(
                          widget.property.listingType == 'sale'
                              ? 'For Sale'
                              : 'For Rent',
                          Colors.green),
                      if (widget.property.featured) ...[
                        const SizedBox(width: 8),
                        _badge('Featured', Colors.orange),
                      ],
                    ]),
                    const SizedBox(height: 16),
                    Text(widget.property.title,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text('₦${_formatPrice(widget.property.price)}',
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2196F3))),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.location_on,
                          color: Colors.grey, size: 20),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                            widget.property.location.fullAddress,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 14)),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statItem(Icons.bed,
                            '${widget.property.bedrooms}', 'Bedrooms'),
                        _statItem(Icons.bathtub,
                            '${widget.property.bathrooms}', 'Bathrooms'),
                        _statItem(Icons.square_foot,
                            '${widget.property.area.toInt()}', 'sq ft'),
                      ],
                    ),
                    const Divider(height: 40),

                    if (widget.property.inspectionFee > 0 ||
                        widget.property.buyPrice > 0 ||
                        widget.property.price > 0) ...[
                      const Text('Transaction Info',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(children: [
                          if (widget.property.inspectionFee > 0)
                            _feeRow(
                              Icons.event_available,
                              'Inspection Fee',
                              _currencyFmt.format(
                                  widget.property.inspectionFee),
                              Colors.teal,
                            ),
                          if (widget.property.inspectionFee > 0)
                            const Divider(height: 20),
                          _feeRow(
                            Icons.shopping_bag,
                            'Purchase Price',
                            _currencyFmt.format(
                              widget.property.buyPrice > 0
                                  ? widget.property.buyPrice
                                  : widget.property.price,
                            ),
                            Colors.green,
                          ),
                        ]),
                      ),
                      const SizedBox(height: 24),
                    ],

                    const Text('Description',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(widget.property.description,
                        style: const TextStyle(
                            color: Colors.grey, height: 1.6)),
                    const SizedBox(height: 24),

                    if (widget.property.amenities.isNotEmpty) ...[
                      const Text('Amenities',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.property.amenities
                            .map((a) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                  child: Text(a,
                                      style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14)),
                                ))
                            .toList(),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // AI Features section
                    const Text('AI Tools',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    _AiFeatureTile(
                      icon: Icons.location_city,
                      color: Colors.teal,
                      title: 'Neighbourhood Insights',
                      subtitle: 'Safety, infrastructure, amenities & price trends',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NeighbourhoodInsightsScreen(property: widget.property),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    _AiFeatureTile(
                      icon: Icons.chat_bubble_outline,
                      color: const Color(0xFF1565C0),
                      title: 'Ask Maximus AI',
                      subtitle: 'Get instant answers about this property',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AiChatScreen(property: widget.property),
                        ),
                      ),
                    ),

                    const SizedBox(height: 160),
                  ],
                ),
              ),
            ),
          ),
        ]),

        // Top bar
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Row(children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.share, color: Colors.black),
                    onPressed: () => Share.share(
                        '${widget.property.title} - ₦${_formatPrice(widget.property.price)}\n${widget.property.location.fullAddress}'),
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: Icon(
                      isSaved ? Icons.favorite : Icons.favorite_border,
                      color: isSaved ? Colors.red : Colors.black,
                    ),
                    onPressed: () => authProvider
                        .toggleSavedProperty(widget.property.id),
                  ),
                ),
              ]),
            ],
          ),
        ),

        // Bottom action buttons
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5))
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InspectionBookingScreen(
                          property: widget.property),
                    ),
                  ),
                  icon: const Icon(Icons.event_available),
                  label: Text(
                    widget.property.inspectionFee > 0
                        ? 'Book Inspection (${_currencyFmt.format(widget.property.inspectionFee)})'
                        : 'Book Free Inspection',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _handleBuyProperty(context),
                  icon: const Icon(Icons.shopping_bag),
                  label: Text(
                    'Buy Property (${_currencyFmt.format(widget.property.buyPrice > 0 ? widget.property.buyPrice : widget.property.price)})',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleContactAgent(context),
                    style: ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Contact Agent',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12)),
                  child: IconButton(
                    icon: const Icon(Icons.chat,
                        color: Color(0xFF25D366)),
                    tooltip: 'WhatsApp',
                    onPressed: () => _handleContactAgent(context),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _feeRow(IconData icon, String label, String value, Color color) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 14))),
      Text(value,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 16)),
    ]);
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Column(children: [
      Row(children: [
        Icon(icon, color: const Color(0xFF2196F3), size: 28),
        const SizedBox(width: 8),
        Text(value,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
    ]);
  }
}


// ── AI Feature Tile ──────────────────────────────────────────────────────────
class _AiFeatureTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AiFeatureTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('AI',
                        style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios,
              size: 14, color: Colors.grey.shade400),
        ]),
      ),
    );
  }
}

// ── Video Player Sheet ────────────────────────────────────────────────────────
class VideoPlayerSheet extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerSheet({super.key, required this.videoUrl});

  @override
  State<VideoPlayerSheet> createState() => _VideoPlayerSheetState();
}

class _VideoPlayerSheetState extends State<VideoPlayerSheet> {
  late VideoPlayerController _controller;
  ChewieController? _chewieController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    await _controller.initialize();
    if (mounted) {
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _controller,
          autoPlay: true,
          looping: false,
          aspectRatio: _controller.value.aspectRatio,
        );
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Property Tour',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: _isInitialized
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator(color: Colors.white),
          ),
        ),
      ]),
    );
  }
}