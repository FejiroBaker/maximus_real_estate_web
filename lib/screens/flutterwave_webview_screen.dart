// lib/screens/flutterwave_webview_screen.dart
//
// Hosts the Flutterwave standard checkout in a WebView.
// We intercept the redirect_url (callback) to detect success/failure
// BEFORE the WebView tries to load it (which may 404).
// A manual-verify fallback button lets users recover if redirect fails.

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/flutterwave_service.dart';

class FlutterwaveWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String txRef;
  final Function(String txRef) onSuccess;
  final Function() onCancel;

  const FlutterwaveWebViewScreen({
    Key? key,
    required this.paymentUrl,
    required this.txRef,
    required this.onSuccess,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<FlutterwaveWebViewScreen> createState() =>
      _FlutterwaveWebViewScreenState();
}

class _FlutterwaveWebViewScreenState extends State<FlutterwaveWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading   = true;
  bool _handled     = false;

  // The redirect_url domain we intercept
  static const String _callbackDomain = 'maximusrealestate.ng';
  // Flutterwave's own close page after a completed/cancelled payment
  static const String _flwCloseDomain  = 'checkout.flutterwave.com/v3/hosted/pay';

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (progress == 100 && mounted) {
              setState(() => _isLoading = false);
            }
          },
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
            _checkUrl(url);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _isLoading = false);
            _checkUrl(url);
          },
          onWebResourceError: (error) {
            // When we intercept the callback URL, the WebView fires a resource
            // error because the page may not exist. That's expected — treat it
            // as a success signal.
            final url = error.url ?? '';
            if (url.contains(_callbackDomain)) {
              debugPrint('[FLW] Callback domain resource error (expected): $url');
              _checkUrl(url);
            }
          },
          onNavigationRequest: (request) {
            // PRIMARY interception — fires before the WebView loads the URL.
            final url = request.url;
            if (url.contains(_callbackDomain)) {
              debugPrint('[FLW] Intercepted callback URL: $url');
              _checkUrl(url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _checkUrl(String url) {
    if (_handled || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    debugPrint('[FLW] Checking URL: $url');

    final params       = uri.queryParameters;
    final status       = params['status']?.toLowerCase() ?? '';
    final txRef        = params['tx_ref'] ?? '';
    final isCallback   = url.contains(_callbackDomain);
    // Flutterwave appends ?status=successful&tx_ref=...&transaction_id=...
    final isSuccess    = status == 'successful' || status == 'completed';
    final isCancelled  = status == 'cancelled' || status == 'failed';

    if (isCallback && isSuccess && txRef.isNotEmpty) {
      _handleSuccess(txRef);
    } else if (isCallback && isSuccess && txRef.isEmpty) {
      // Callback domain reached but no params — use the original ref
      _handleSuccess(widget.txRef);
    } else if (isCallback && isCancelled) {
      _handleCancel();
    } else if (isCallback) {
      // Callback domain but status unknown — verify server-side to be safe
      _handleSuccess(txRef.isNotEmpty ? txRef : widget.txRef);
    }
  }

  void _handleSuccess(String txRef) {
    if (_handled) return;
    _handled = true;
    debugPrint('[FLW] ✅ Payment success. tx_ref: $txRef');
    widget.onSuccess(txRef);
    if (mounted) Navigator.pop(context);
  }

  void _handleCancel() {
    if (_handled) return;
    _handled = true;
    debugPrint('[FLW] ❌ Payment cancelled.');
    widget.onCancel();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _manualVerify() async {
    if (_handled) return;

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
      final service = FlutterwaveService();
      final result  = await service.verifyPayment(widget.txRef);

      if (mounted) Navigator.pop(context); // close dialog

      final confirmed = result != null &&
          result['status'] == 'success' &&
          result['data']?['status'] == 'successful';

      if (confirmed) {
        _handleSuccess(widget.txRef);
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Payment Not Confirmed'),
              content: const Text(
                'Your payment has not been confirmed yet.\n\n'
                'If you completed the payment, please wait a moment '
                'and tap "Try Again". If the problem persists, contact support.',
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
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
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
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Payment'),
        content: const Text(
            'Are you sure you want to cancel? Your booking will not be confirmed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Payment'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleCancel();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
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
                    const Text('Loading payment page...',
                        style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text('Please do not close this screen',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: _manualVerify,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text(
                        'Payment done but stuck? Tap to verify',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Always-visible verify button at the bottom
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Visibility(
              visible: !_isLoading,
              child: ElevatedButton.icon(
                onPressed: _manualVerify,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text("I've completed payment — verify now"),
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
}