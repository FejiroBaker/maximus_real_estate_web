// lib/screens/paystack_webview_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/production_paystack_service.dart';

class PaystackWebViewScreen extends StatefulWidget {
  final String authorizationUrl;
  final String reference;
  final Function(String reference) onSuccess;
  final Function() onCancel;

  const PaystackWebViewScreen({
    Key? key,
    required this.authorizationUrl,
    required this.reference,
    required this.onSuccess,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<PaystackWebViewScreen> createState() => _PaystackWebViewScreenState();
}

class _PaystackWebViewScreenState extends State<PaystackWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _paymentHandled = false;

  // ── Domain where Paystack redirects after payment ─────────────────────────
  // For a mobile app, Paystack will redirect to your callback_url.
  // Since the site may not exist, we intercept the navigation request BEFORE
  // the WebView tries to load it. We detect both the callback domain and
  // Paystack's own standard close URL (used when callback_url is not reachable).
  static const String _callbackDomain = 'maximusrealestate.ng';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (progress == 100 && mounted) {
              setState(() => _isLoading = false);
            }
          },
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
            _checkPaymentStatus(url);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
            _checkPaymentStatus(url);
          },
          onWebResourceError: (WebResourceError error) {
            // When Paystack tries to redirect to our callback domain,
            // the WebView will throw an error (domain doesn't resolve).
            // We catch this and treat it as a success signal.
            final url = error.url ?? '';
            if (url.contains(_callbackDomain)) {
              debugPrint('PaystackWebView: callback domain error (expected) — treating as success. URL: $url');
              _checkPaymentStatus(url);
            } else {
              debugPrint('WebView error: ${error.description} — URL: $url');
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // ── PRIMARY SUCCESS DETECTION ─────────────────────────────────
            // Intercept BEFORE the WebView tries to navigate to the callback
            // URL. This fires reliably on mobile even without a live website.
            final url = request.url;
            if (url.contains(_callbackDomain)) {
              debugPrint('PaystackWebView: intercepted callback URL: $url');
              _checkPaymentStatus(url);
              return NavigationDecision.prevent; // block the actual load
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  // ── Core payment status logic ─────────────────────────────────────────────
  void _checkPaymentStatus(String url) {
    if (_paymentHandled || url.isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    debugPrint('PaystackWebView checking URL: $url');

    final hasReference = uri.queryParameters.containsKey('reference') ||
        uri.queryParameters.containsKey('trxref');

    // ── Success condition 1: redirected to our callback domain ───────────
    final isOurCallback = url.contains(_callbackDomain);

    // ── Success condition 2: Paystack's own close page WITH a reference ──
    // This fires when the callback_url can't be reached but the payment
    // went through (Paystack appends ?reference=xxx to its close URL).
    final isPaystackClose = url.contains('paystack.co/close') ||
        url.contains('standard.paystack.co/close') ||
        url.contains('paystack.com/close');

    // ── Cancel condition: close page WITHOUT reference means user quit ────
    final isCancelUrl =
        (isPaystackClose && !hasReference) ||
            url.contains('cancelled=true') ||
            (url.contains('/cancel') &&
                !url.contains('paystack.co/transaction'));

    if ((isOurCallback || isPaystackClose) && hasReference) {
      // ✅ Payment confirmed — extract reference and hand control back
      _paymentHandled = true;
      final ref = uri.queryParameters['reference'] ??
          uri.queryParameters['trxref'] ??
          widget.reference;
      debugPrint('✅ PaystackWebView: payment success. Reference: $ref');
      widget.onSuccess(ref);
      if (mounted) Navigator.pop(context);
    } else if (isOurCallback && !hasReference) {
      // ── Callback domain loaded but no reference query param ──────────
      // Paystack sometimes hits the callback URL without appending params
      // if it already verified internally. We use the original reference.
      _paymentHandled = true;
      debugPrint('✅ PaystackWebView: callback domain reached (no params). Using original ref: ${widget.reference}');
      widget.onSuccess(widget.reference);
      if (mounted) Navigator.pop(context);
    } else if (isCancelUrl) {
      // ❌ User cancelled
      _paymentHandled = true;
      debugPrint('❌ PaystackWebView: payment cancelled. URL: $url');
      widget.onCancel();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _showCancelDialog,
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text(
                      'Loading payment page...',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please do not close this screen',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    // ── Manual verify fallback ────────────────────────────
                    // If Paystack's page loads but user sees a success message
                    // yet the app hasn't detected it, they can tap this.
                    TextButton.icon(
                      onPressed: _manualVerify,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text(
                        'Payment done but app stuck? Tap here',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // ── Persistent manual-verify button (bottom of screen) ────────
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Visibility(
              visible: !_isLoading,
              child: ElevatedButton.icon(
                onPressed: _manualVerify,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('I\'ve completed payment — verify now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Manual verification fallback ─────────────────────────────────────────
  // If the automatic redirect detection fails (e.g. Paystack changes their
  // URL patterns), the user can tap this to trigger server-side verification
  // using the original reference. This is the safest mobile fallback.
  Future<void> _manualVerify() async {
    if (_paymentHandled) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Verifying payment...'),
        ]),
      ),
    );

    try {
      final paystack = ProductionPaystackService();
      final result = await paystack.verifyPayment(widget.reference);

      if (mounted) Navigator.pop(context); // close verifying dialog

      if (result != null &&
          result['status'] == true &&
          result['data']?['status'] == 'success') {
        if (!_paymentHandled) {
          _paymentHandled = true;
          debugPrint('✅ Manual verify success. Reference: ${widget.reference}');
          widget.onSuccess(widget.reference);
          if (mounted) Navigator.pop(context);
        }
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Payment Not Confirmed'),
              content: const Text(
                'Your payment has not been confirmed yet. If you completed the payment, please wait a moment and try again. '
                'If the problem persists, contact support.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Try Again'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showCancelDialog();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close verifying dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Payment'),
        content: const Text(
            'Are you sure you want to cancel this payment? Your booking will not be confirmed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Payment'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (!_paymentHandled) {
                _paymentHandled = true;
                widget.onCancel();
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}