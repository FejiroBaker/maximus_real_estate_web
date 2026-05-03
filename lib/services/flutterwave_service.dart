// lib/services/flutterwave_service.dart
//
// 🔐 Security Architecture
// ─────────────────────────────────────────────────────────────────────────────
// The Flutterwave SECRET key NEVER lives in this file or in the Flutter binary.
// All calls requiring the secret key (verify payment, create subaccount, etc.)
// are proxied through a Supabase Edge Function.
//
// FIXES APPLIED:
// ─────────────────────────────────────────────────────────────────────────────
// [FIX 1]  processSubscriptionPayment() computed expiry as
//          DateTime(now.year, now.month + 1, now.day).  When now.month == 12
//          this produces month=13, which Dart rolls over to Jan of the NEXT year
//          — correct, but fragile and undocumented.  Replaced with an explicit
//          Duration-based calculation that is clear and handles DST correctly.
// [FIX 2]  getSellerPropertyCount() fetched all columns ('*') just to count
//          rows — wasteful.  Replaced with a count-only query using `.count()`.
// [FIX 3]  _edgeGet() passed query params inside the JSON body, but the edge
//          function expects them as query-string params on a GET request.
//          Supabase functions.invoke() does not forward body params as query
//          strings, so the edge function always received empty params.
//          Fixed: encode query params in the custom `x-edge-path` header so
//          the edge function can parse them from that header, and also include
//          them in the body as a fallback (the edge fn already supports
//          body._path).  For verify specifically, moved tx_ref into the body
//          POST since the edge fn reads body.tx_ref.
// [FIX 4]  verifyPayment() called _edgeGet which used HTTP GET; the edge
//          function for "verify" reads body.tx_ref, so a GET with no body
//          always got an empty tx_ref.  Switched verify to _edgePost.
// [FIX 5]  canAddProperty() caught all errors and returned `allowed: true` as
//          a fallback — silently letting sellers bypass the subscription gate
//          on any Supabase error.  Changed fallback to `allowed: false` with a
//          user-facing message so the gate holds on errors.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import '../config/app_config.dart';
import '../models/transaction_model.dart';
import '../models/property_model.dart';
import '../models/user_model.dart';

class FlutterwaveService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── Commission / fee rates ─────────────────────────────────────────────────
  static const double contactUnlockFee = 3000.0;
  static const double inspectionCommissionRate = 10.0;
  static const double purchaseCommissionRate = 5.0;
  static const double basicPlanFee = 20000.0;
  static const double premiumPlanFee = 70000.0;

  static String get appOwnerEmail => AppConfig.adminEmail;

  // ── Reference generator ───────────────────────────────────────────────────
  String generateReference() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(99999);
    return 'MAXIMUS-$timestamp-$random';
  }

  // ── Private: invoke Supabase Edge Function (POST) ─────────────────────────
  Future<Map<String, dynamic>?> _edgePost(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _supabase.functions.invoke(
        'flutterwave',
        method: HttpMethod.post,
        headers: {'x-edge-path': path},
        body: {...body, '_path': path},
      );
      if (response.data == null) return null;
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Edge function POST error ($path): $e');
      return null;
    }
  }

  // FIX 3: _edgeGet now encodes query params into the path header so the
  // edge function can read them.  For GET calls the edge fn reads from
  // url.searchParams, which it constructs from the full path including ?query.
  Future<Map<String, dynamic>?> _edgeGet(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    try {
      String fullPath = path;
      if (queryParams != null && queryParams.isNotEmpty) {
        final qs = queryParams.entries
            .map((e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
        fullPath = '$path?$qs';
      }

      final response = await _supabase.functions.invoke(
        'flutterwave',
        method: HttpMethod.get,
        headers: {'x-edge-path': fullPath},
        body: {'_path': fullPath, ...?queryParams},
      );
      if (response.data == null) return null;
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Edge function GET error ($path): $e');
      return null;
    }
  }

  // FIX 4: verify uses POST so body.tx_ref is readable by the edge function.
  Future<Map<String, dynamic>?> verifyPayment(String txRef) async {
    final result = await _edgePost('/verify', {'tx_ref': txRef});
    if (result == null) {
      return {'status': 'error', 'message': 'Verification failed'};
    }
    return result;
  }

  // ── Build Flutterwave payment URL ─────────────────────────────────────────
  String buildPaymentUrl({
    required String txRef,
    required double amount,
    required String email,
    required String name,
    required String phone,
    required String description,
    String currency = 'NGN',
  }) {
    final publicKey = AppConfig.flutterwavePublicKey;
    final callbackUrl =
        Uri.encodeComponent(AppConfig.flutterwaveCallbackUrl);
    final encodedDesc = Uri.encodeComponent(description);
    final encodedName = Uri.encodeComponent(name);
    final encodedEmail = Uri.encodeComponent(email);
    final encodedPhone = Uri.encodeComponent(phone);

    return 'https://checkout.flutterwave.com/v3/hosted/pay'
        '?public_key=$publicKey'
        '&tx_ref=$txRef'
        '&amount=${amount.toInt()}'
        '&currency=$currency'
        '&payment_options=card,banktransfer,ussd'
        '&redirect_url=$callbackUrl'
        '&customer[email]=$encodedEmail'
        '&customer[name]=$encodedName'
        '&customer[phonenumber]=$encodedPhone'
        '&customizations[title]=Maximus+Real+Estate'
        '&customizations[description]=$encodedDesc'
        '&customizations[logo]=https://maximusrealestate.ng/logo.png'
        '&meta[source]=flutter_app';
  }

  // ── Subaccount helpers ────────────────────────────────────────────────────
  Future<String?> _getSellerSubaccountId(String sellerId) async {
    try {
      final data = await _supabase
          .from('users')
          .select('flutterwave_subaccount_id')
          .eq('id', sellerId)
          .maybeSingle();
      if (data == null) return null;
      final code = data['flutterwave_subaccount_id']?.toString();
      return (code == null || code.isEmpty) ? null : code;
    } catch (e) {
      debugPrint('Error fetching subaccount id: $e');
      return null;
    }
  }

  Future<String?> createSubaccount({
    required String sellerId,
    required String accountBank,
    required String accountNumber,
    required String businessName,
    required String splitValue,
  }) async {
    final result = await _edgePost('/create-subaccount', {
      'account_bank': accountBank,
      'account_number': accountNumber,
      'business_name': businessName,
      'split_type': 'percentage',
      'split_value': splitValue,
    });

    if (result == null) return null;

    if (result['status'] == 'success') {
      final subId = result['data']?['subaccount_id']?.toString();
      if (subId != null) {
        await _supabase.from('users').update({
          'flutterwave_subaccount_id': subId,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', sellerId);
      }
      return subId;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getBankList() async {
    final result = await _edgeGet('/banks', queryParams: {'country': 'NG'});
    if (result == null) return [];
    return List<Map<String, dynamic>>.from(result['data'] ?? []);
  }

  Future<String?> resolveAccountNumber({
    required String accountNumber,
    required String bankCode,
  }) async {
    final result = await _edgeGet('/resolve-account', queryParams: {
      'account_number': accountNumber,
      'account_bank': bankCode,
    });
    if (result == null) return null;
    if (result['status'] == 'success') {
      return result['data']?['account_name']?.toString();
    }
    return null;
  }

  // ── 1. Contact Unlock ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> payToUnlockContact({
    required PropertyModel property,
    required UserModel buyer,
  }) async {
    try {
      final txRef = generateReference();

      await _supabase.from('contact_unlocks').insert({
        'property_id': property.id,
        'property_title': property.title,
        'buyer_id': buyer.id,
        'buyer_name': buyer.name,
        'buyer_email': buyer.email,
        'seller_id': property.ownerId,
        'unlock_fee': contactUnlockFee,
        'payment_reference': txRef,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      final url = buildPaymentUrl(
        txRef: txRef,
        amount: contactUnlockFee,
        email: buyer.email,
        name: buyer.name,
        phone: buyer.phone ?? '',
        description: 'Unlock contact for: ${property.title}',
      );

      return {
        'status': true,
        'payment_url': url,
        'tx_ref': txRef,
      };
    } catch (e) {
      debugPrint('Contact unlock init error: $e');
      return {'status': false, 'message': 'Payment failed: $e'};
    }
  }

  // ── 2. Process contact unlock ─────────────────────────────────────────────
  Future<bool> processContactUnlock(String txRef) async {
    try {
      final verifyResult = await verifyPayment(txRef);
      if (verifyResult == null) return false;
      if (verifyResult['status'] != 'success') return false;
      final payData = verifyResult['data'];
      if (payData == null) return false;
      if (payData['status'] != 'successful') return false;

      final unlocks = await _supabase
          .from('contact_unlocks')
          .select()
          .eq('payment_reference', txRef);
      if ((unlocks as List).isEmpty) return false;

      final unlock = unlocks.first as Map<String, dynamic>;
      final unlockId = unlock['id'];

      await _supabase.from('contact_unlocks').update({
        'status': 'paid',
        'flutterwave_reference': payData['flw_ref']?.toString() ?? txRef,
        'paid_at': DateTime.now().toIso8601String(),
      }).eq('id', unlockId);

      await _createCommissionTransaction(
        type: 'contact_unlock',
        propertyId: unlock['property_id']?.toString() ?? '',
        propertyTitle: unlock['property_title'] ?? '',
        buyerId: unlock['buyer_id']?.toString() ?? '',
        buyerName: unlock['buyer_name'] ?? '',
        buyerEmail: unlock['buyer_email'] ?? '',
        sellerId: unlock['seller_id']?.toString() ?? '',
        amount: contactUnlockFee,
        commissionAmount: contactUnlockFee,
        sellerPayoutAmount: 0.0,
        commissionPercentage: 100.0,
        txRef: txRef,
        flwRef: payData['flw_ref']?.toString() ?? txRef,
        splitUsed: false,
      );

      return true;
    } catch (e) {
      debugPrint('Process contact unlock error: $e');
      return false;
    }
  }

  // ── 3. Has buyer unlocked contact ─────────────────────────────────────────
  Future<bool> hasUnlockedContact(String buyerId, String propertyId) async {
    try {
      final result = await _supabase
          .from('contact_unlocks')
          .select()
          .eq('buyer_id', buyerId)
          .eq('property_id', propertyId)
          .eq('status', 'paid');
      return (result as List).isNotEmpty;
    } catch (e) {
      debugPrint('Error checking unlock status: $e');
      return false;
    }
  }

  // ── 4. Inspection payment ─────────────────────────────────────────────────
  Future<Map<String, dynamic>?> chargeForInspection({
    required PropertyModel property,
    required UserModel buyer,
    required String txRef,
  }) async {
    try {
      final amount = property.inspectionFee;
      final subaccountId = await _getSellerSubaccountId(property.ownerId);

      final url = buildPaymentUrl(
        txRef: txRef,
        amount: amount,
        email: buyer.email,
        name: buyer.name,
        phone: buyer.phone ?? '',
        description: 'Inspection fee for: ${property.title}',
      );

      return {
        'status': true,
        'payment_url': url,
        'tx_ref': txRef,
        'split_used': subaccountId != null,
        'subaccount_id': subaccountId,
      };
    } catch (e) {
      debugPrint('Inspection payment init error: $e');
      return {'status': false, 'message': 'Payment failed: $e'};
    }
  }

  // ── 5. Process inspection ─────────────────────────────────────────────────
  Future<bool> processInspectionPayment(
    String txRef,
    PropertyModel property,
    UserModel buyer,
  ) async {
    try {
      final verifyResult = await verifyPayment(txRef);
      if (verifyResult == null) return false;
      if (verifyResult['status'] != 'success') return false;
      final payData = verifyResult['data'];
      if (payData == null) return false;
      if (payData['status'] != 'successful') return false;

      final double amountPaid =
          ((payData['amount'] ?? 0) as num).toDouble();
      final double commission =
          amountPaid * inspectionCommissionRate / 100;
      final double sellerPayout = amountPaid - commission;
      final String flwRef = payData['flw_ref']?.toString() ?? txRef;
      final bool splitUsed = payData['meta']?['split_used'] == true;

      final inspections = await _supabase
          .from('inspections')
          .select()
          .eq('payment_reference', txRef);

      for (final doc in (inspections as List)) {
        await _supabase.from('inspections').update({
          'payment_status': 'paid',
          'booking_status': 'confirmed',
          'flutterwave_reference': flwRef,
          'paid_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', doc['id']);
      }

      await _createCommissionTransaction(
        type: 'inspection',
        propertyId: property.id,
        propertyTitle: property.title,
        buyerId: buyer.id,
        buyerName: buyer.name,
        buyerEmail: buyer.email,
        sellerId: property.ownerId,
        amount: amountPaid,
        commissionAmount: commission,
        sellerPayoutAmount: sellerPayout,
        commissionPercentage: inspectionCommissionRate,
        txRef: txRef,
        flwRef: flwRef,
        splitUsed: splitUsed,
      );

      return true;
    } catch (e) {
      debugPrint('Process inspection payment error: $e');
      return false;
    }
  }

  // ── 6. Property purchase ──────────────────────────────────────────────────
  Future<Map<String, dynamic>?> initiatePropertyPurchase({
    required PropertyModel property,
    required UserModel buyer,
  }) async {
    try {
      final amount =
          property.buyPrice > 0 ? property.buyPrice : property.price;
      final txRef = generateReference();
      final subaccountId = await _getSellerSubaccountId(property.ownerId);

      await _supabase.from('property_purchases').insert({
        'property_id': property.id,
        'property_title': property.title,
        'buyer_id': buyer.id,
        'buyer_name': buyer.name,
        'buyer_email': buyer.email,
        'seller_id': property.ownerId,
        'amount': amount,
        'payment_reference': txRef,
        'status': 'pending',
        'split_used': subaccountId != null,
        'created_at': DateTime.now().toIso8601String(),
      });

      final url = buildPaymentUrl(
        txRef: txRef,
        amount: amount,
        email: buyer.email,
        name: buyer.name,
        phone: buyer.phone ?? '',
        description: 'Purchase: ${property.title}',
      );

      return {
        'status': true,
        'payment_url': url,
        'tx_ref': txRef,
        'amount': amount,
        'split_used': subaccountId != null,
      };
    } catch (e) {
      debugPrint('Property purchase init error: $e');
      return {'status': false, 'message': 'Payment failed: $e'};
    }
  }

  // ── 7. Process property purchase ──────────────────────────────────────────
  Future<bool> processPropertyPurchase(
    String txRef,
    PropertyModel property,
    UserModel buyer,
  ) async {
    try {
      final verifyResult = await verifyPayment(txRef);
      if (verifyResult == null) return false;
      if (verifyResult['status'] != 'success') return false;
      final payData = verifyResult['data'];
      if (payData == null) return false;
      if (payData['status'] != 'successful') return false;

      final double amountPaid =
          ((payData['amount'] ?? 0) as num).toDouble();
      final double commission =
          amountPaid * purchaseCommissionRate / 100;
      final double sellerPayout = amountPaid - commission;
      final String flwRef = payData['flw_ref']?.toString() ?? txRef;
      final bool splitUsed = payData['meta']?['split_used'] == true;

      final purchases = await _supabase
          .from('property_purchases')
          .select()
          .eq('payment_reference', txRef);

      for (final doc in (purchases as List)) {
        await _supabase.from('property_purchases').update({
          'status': 'completed',
          'flutterwave_reference': flwRef,
          'paid_at': DateTime.now().toIso8601String(),
          'commission_amount': commission,
          'seller_payout_amount': sellerPayout,
          'split_used': splitUsed,
        }).eq('id', doc['id']);
      }

      await _createCommissionTransaction(
        type: 'property_purchase',
        propertyId: property.id,
        propertyTitle: property.title,
        buyerId: buyer.id,
        buyerName: buyer.name,
        buyerEmail: buyer.email,
        sellerId: property.ownerId,
        amount: amountPaid,
        commissionAmount: commission,
        sellerPayoutAmount: sellerPayout,
        commissionPercentage: purchaseCommissionRate,
        txRef: txRef,
        flwRef: flwRef,
        splitUsed: splitUsed,
      );

      return true;
    } catch (e) {
      debugPrint('Process property purchase error: $e');
      return false;
    }
  }

  // ── 8. Seller subscription ────────────────────────────────────────────────
  Future<Map<String, dynamic>?> paySellerSubscription({
    required UserModel seller,
    required String plan,
  }) async {
    try {
      final fee = plan == 'premium' ? premiumPlanFee : basicPlanFee;
      final txRef = generateReference();

      final url = buildPaymentUrl(
        txRef: txRef,
        amount: fee,
        email: seller.email,
        name: seller.name,
        phone: seller.phone ?? '',
        description: 'Seller subscription (${plan.toUpperCase()} plan)',
      );

      return {
        'status': true,
        'payment_url': url,
        'tx_ref': txRef,
        'plan': plan,
      };
    } catch (e) {
      debugPrint('Subscription payment init error: $e');
      return {'status': false, 'message': 'Payment failed: $e'};
    }
  }

  // ── 9. Process subscription ───────────────────────────────────────────────
  // FIX 1: subscription expiry uses Duration arithmetic instead of raw
  // month arithmetic which was ambiguous for December (month 13 bug).
  Future<bool> processSubscriptionPayment(
    String txRef,
    String sellerId,
    String plan,
  ) async {
    try {
      final verifyResult = await verifyPayment(txRef);
      if (verifyResult == null) return false;
      if (verifyResult['status'] != 'success') return false;
      final payData = verifyResult['data'];
      if (payData == null) return false;
      if (payData['status'] != 'successful') return false;

      final sellerData = await _supabase
          .from('users')
          .select()
          .eq('id', sellerId)
          .maybeSingle();
      if (sellerData == null) return false;

      final fee = plan == 'premium' ? premiumPlanFee : basicPlanFee;
      final now = DateTime.now();
      // FIX 1: 30-day subscription window — clear, correct, DST-safe.
      final expiry = now.add(const Duration(days: 30));
      final flwRef = payData['flw_ref']?.toString() ?? txRef;

      await _supabase.from('seller_subscriptions').upsert({
        'seller_id': sellerId,
        'seller_name': sellerData['name'] ?? '',
        'seller_email': sellerData['email'] ?? '',
        'plan': plan,
        'monthly_fee': fee,
        'start_date': now.toIso8601String(),
        'expiry_date': expiry.toIso8601String(),
        'is_active': true,
        'payment_reference': txRef,
        'flutterwave_reference': flwRef,
        'created_at': now.toIso8601String(),
        'last_payment_date': now.toIso8601String(),
      }, onConflict: 'seller_id');

      await _supabase.from('subscription_payments').insert({
        'seller_id': sellerId,
        'seller_name': sellerData['name'] ?? '',
        'seller_email': sellerData['email'] ?? '',
        'plan': plan,
        'amount': fee,
        'payment_reference': txRef,
        'flutterwave_reference': flwRef,
        'created_at': now.toIso8601String(),
      });

      return true;
    } catch (e) {
      debugPrint('Process subscription error: $e');
      return false;
    }
  }

  // ── 10. Get seller subscription ───────────────────────────────────────────
  Future<SellerSubscription?> getSellerSubscription(String sellerId) async {
    try {
      final data = await _supabase
          .from('seller_subscriptions')
          .select()
          .eq('seller_id', sellerId)
          .maybeSingle();

      if (data == null) return null;

      final sub =
          SellerSubscription.fromJson(data['id']?.toString() ?? '', data);

      if (sub.isExpired && sub.isActive) {
        await _supabase
            .from('seller_subscriptions')
            .update({'is_active': false}).eq('seller_id', sellerId);
      }

      return sub;
    } catch (e) {
      debugPrint('Error getting subscription: $e');
      return null;
    }
  }

  // FIX 2: count-only query instead of fetching all columns.
  Future<int> getSellerPropertyCount(String sellerId) async {
    try {
      final response = await _supabase
          .from('properties')
          .select('id')
          .eq('owner_id', sellerId)
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      debugPrint('Error counting seller properties: $e');
      return 0;
    }
  }

  // ── 12. Can seller add property? ──────────────────────────────────────────
  // FIX 5: error fallback is now `allowed: false` so the gate holds on errors.
  Future<Map<String, dynamic>> canAddProperty(String sellerId) async {
    try {
      final count = await getSellerPropertyCount(sellerId);
      if (count == 0) {
        return {'allowed': true, 'reason': 'free_first_listing'};
      }
      final sub = await getSellerSubscription(sellerId);
      if (sub == null || sub.isExpired || !sub.isActive) {
        return {
          'allowed': false,
          'reason': 'no_subscription',
          'message':
              'You have used your 1 free listing. Subscribe to add more.',
        };
      }
      if (sub.plan == 'basic' && count >= 20) {
        return {
          'allowed': false,
          'reason': 'basic_limit_reached',
          'message':
              'Basic plan allows up to 20 listings. Upgrade to Premium.',
        };
      }
      return {'allowed': true, 'reason': 'subscribed'};
    } catch (e) {
      debugPrint('Error checking canAddProperty: $e');
      // FIX 5: was `allowed: true` — changed to false so gate holds on errors.
      return {
        'allowed': false,
        'reason': 'error',
        'message':
            'Unable to verify your subscription. Please try again or contact support.',
      };
    }
  }

  // ── 13. Admin: get total commissions ──────────────────────────────────────
  Future<Map<String, dynamic>> getTotalCommissions() async {
    try {
      final transactions = await _supabase
          .from('commission_transactions')
          .select()
          .eq('status', 'completed');

      double totalCommissions = 0;
      double todayCommissions = 0;
      double thisMonthCommissions = 0;
      double pendingSellerPayouts = 0;
      double inspectionCommissions = 0;
      double salesCommissions = 0;
      int contactUnlocks = 0;
      int inspections = 0;
      int purchases = 0;
      int autoSplitCount = 0;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final monthStart = DateTime(now.year, now.month, 1);

      for (final row in (transactions as List)) {
        final trans = CommissionTransaction.fromJson(
          row['id']?.toString() ?? '',
          row as Map<String, dynamic>,
        );

        totalCommissions += trans.commissionAmount;
        if (trans.createdAt.isAfter(todayStart)) {
          todayCommissions += trans.commissionAmount;
        }
        if (trans.createdAt.isAfter(monthStart)) {
          thisMonthCommissions += trans.commissionAmount;
        }

        final payoutStatus =
            row['seller_payout_status']?.toString() ?? '';
        if (payoutStatus == 'pending_disbursement') {
          pendingSellerPayouts +=
              ((row['seller_payout_amount'] ?? 0) as num).toDouble();
        }
        if (row['split_used'] == true) autoSplitCount++;

        switch (trans.type) {
          case 'contact_unlock':
            contactUnlocks++;
            break;
          case 'inspection':
            inspections++;
            inspectionCommissions += trans.commissionAmount;
            break;
          case 'property_purchase':
            purchases++;
            salesCommissions += trans.commissionAmount;
            break;
        }
      }

      return {
        'totalCommissions': totalCommissions,
        'todayCommissions': todayCommissions,
        'thisMonthCommissions': thisMonthCommissions,
        'pendingSellerPayouts': pendingSellerPayouts,
        'contactUnlocks': contactUnlocks,
        'inspections': inspections,
        'inspectionCommissions': inspectionCommissions,
        'purchases': purchases,
        'salesCommissions': salesCommissions,
        'totalTransactions': (transactions).length,
        'autoSplitCount': autoSplitCount,
      };
    } catch (e) {
      debugPrint('Error getting commissions: $e');
      return {};
    }
  }

  Future<int> getActiveSubscriptionsCount() async {
    try {
      final response = await _supabase
          .from('seller_subscriptions')
          .select('id')
          .eq('is_active', true)
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      return 0;
    }
  }

  // ── Private: write commission transaction record ───────────────────────────
  Future<void> _createCommissionTransaction({
    required String type,
    required String propertyId,
    required String propertyTitle,
    required String buyerId,
    required String buyerName,
    required String buyerEmail,
    required String sellerId,
    required double amount,
    required double commissionAmount,
    required double sellerPayoutAmount,
    required double commissionPercentage,
    required String txRef,
    required String flwRef,
    required bool splitUsed,
  }) async {
    try {
      String sellerName = 'Property Owner';
      try {
        final sellerData = await _supabase
            .from('users')
            .select('name')
            .eq('id', sellerId)
            .maybeSingle();
        if (sellerData != null) {
          sellerName = sellerData['name'] ?? sellerName;
        }
      } catch (_) {}

      final now = DateTime.now().toIso8601String();

      await _supabase.from('commission_transactions').insert({
        'type': type,
        'property_id': propertyId.isNotEmpty ? propertyId : null,
        'property_title': propertyTitle,
        'buyer_id': buyerId.isNotEmpty ? buyerId : null,
        'buyer_name': buyerName,
        'buyer_email': buyerEmail,
        'seller_id': sellerId.isNotEmpty ? sellerId : null,
        'seller_name': sellerName,
        'amount': amount,
        'commission_amount': commissionAmount,
        'commission_percentage': commissionPercentage,
        'seller_payout_amount': sellerPayoutAmount,
        'seller_payout_status': splitUsed
            ? 'auto_split_by_flutterwave'
            : 'pending_disbursement',
        'split_used': splitUsed,
        'status': 'completed',
        'payment_reference': txRef,
        'flutterwave_reference': flwRef,
        'app_owner_email': appOwnerEmail,
        'created_at': now,
        'completed_at': now,
      });
    } catch (e) {
      debugPrint('Error creating commission transaction: $e');
    }
  }
}