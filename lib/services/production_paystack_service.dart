// lib/services/production_paystack_service.dart
//
// 🔐 Security note
// ─────────────────────────────────────────────────────────────────────────────
// The Paystack SECRET key NEVER lives in this file or in the Flutter binary.
// All calls that require the secret key (initialize, verify, subaccounts, banks)
// are proxied through the Supabase Edge Function at:
//   supabase/functions/paystack/index.ts
//
// The Edge Function stores the secret as a Supabase secret environment variable
// (Project Settings → Edge Functions → Secrets → PAYSTACK_SECRET_KEY).
//
// The Flutter app only ever sees the PUBLIC key (used by the Paystack SDK / WebView).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:math';
import '../config/app_config.dart';
import '../models/transaction_model.dart';
import '../models/property_model.dart';
import '../models/user_model.dart';

class ProductionPaystackService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── Edge Function base URL ─────────────────────────────────────────────────
  // All Paystack API calls go through this server-side function.
  String get _edgeFunctionUrl =>
      '${AppConfig.supabaseUrl}/functions/v1/paystack';

  String get _callbackUrl => AppConfig.paystackCallbackUrl;

  // ── App owner info ─────────────────────────────────────────────────────────
  static const String appOwnerPhone    = '09038466714';
  static const String appOwnerWhatsapp = '09078238396';
  static String get appOwnerEmail => AppConfig.adminEmail;

  // ── Commission / fee rates ─────────────────────────────────────────────────
  static const double contactUnlockFee         = 3000.0;
  static const double inspectionCommissionRate = 10.0;
  static const double purchaseCommissionRate   = 5.0;
  static const double basicPlanFee             = 20000.0;
  static const double premiumPlanFee           = 70000.0;

  // ── Private: call the edge function ───────────────────────────────────────
  Future<Map<String, dynamic>?> _edgePost(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _supabase.functions.invoke(
        'paystack',
        method: HttpMethod.post,
        headers: {'x-edge-path': path},
        body: {...body, '_path': path},
      );
      if (response.data == null) return null;
      final data = response.data as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint('Edge function POST error ($path): $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _edgeGet(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'paystack',
        method: HttpMethod.get,
        headers: {'x-edge-path': path},
        body: {'_path': path, ...?queryParams},
      );
      if (response.data == null) return null;
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Edge function GET error ($path): $e');
      return null;
    }
  }

  // ── Subaccount helpers ─────────────────────────────────────────────────────
  Future<String?> _getSellerSubaccountCode(String sellerId) async {
    try {
      final data = await _supabase
          .from('users')
          .select('paystack_subaccount_code')
          .eq('id', sellerId)
          .maybeSingle();
      if (data == null) return null;
      final code = data['paystack_subaccount_code']?.toString();
      return (code == null || code.isEmpty) ? null : code;
    } catch (e) {
      debugPrint('Error fetching subaccount code: $e');
      return null;
    }
  }

  Future<String?> createSubaccount({
    required String sellerId,
    required String businessName,
    required String bankCode,
    required String accountNumber,
    required double percentageCharge,
  }) async {
    final result = await _edgePost('/subaccount', {
      'business_name':     businessName,
      'bank_code':         bankCode,
      'account_number':    accountNumber,
      'percentage_charge': percentageCharge,
    });

    if (result == null) return null;

    final code = result['data']?['subaccount_code'] as String?;
    if (code != null) {
      await _supabase.from('users').update({
        'paystack_subaccount_code': code,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', sellerId);
    }
    return code;
  }

  Future<List<Map<String, dynamic>>> getBankList() async {
    final result = await _edgeGet('/banks');
    if (result == null) return [];
    return List<Map<String, dynamic>>.from(result['data'] ?? []);
  }

  Future<String?> resolveAccountNumber({
    required String accountNumber,
    required String bankCode,
  }) async {
    final result = await _edgeGet('/resolve-account', queryParams: {
      'account_number': accountNumber,
      'bank_code':      bankCode,
    });
    return result?['data']?['account_name'] as String?;
  }

  // ── Core payment primitives ────────────────────────────────────────────────
  String generateReference() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random    = Random().nextInt(10000);
    return 'MAXIMUS-$timestamp-$random';
  }

  Future<Map<String, dynamic>?> initializePayment({
    required String email,
    required double amount,
    required String reference,
    Map<String, dynamic>? metadata,
    String? subaccountCode,
    double? transactionCharge,
    String bearer = 'account',
  }) async {
    final body = <String, dynamic>{
      'email':        email,
      'amount':       (amount * 100).toInt(),
      'reference':    reference,
      'currency':     'NGN',
      'callback_url': _callbackUrl,
      'metadata':     metadata ?? {},
    };

    if (subaccountCode != null && subaccountCode.isNotEmpty) {
      body['subaccount'] = subaccountCode;
      body['bearer']     = bearer;
      if (transactionCharge != null && transactionCharge > 0) {
        body['transaction_charge'] = (transactionCharge * 100).toInt();
      }
    }

    final result = await _edgePost('/initialize', body);
    if (result == null) {
      return {'status': false, 'message': 'Payment initialization failed'};
    }
    // Paystack wraps response in status/data
    if (result['status'] == true) {
      return {'status': true, 'data': result['data']};
    }
    return {
      'status':  false,
      'message': result['message'] ?? 'Payment initialization failed',
    };
  }

  Future<Map<String, dynamic>?> verifyPayment(String reference) async {
    final result = await _edgeGet('/verify/$reference');
    if (result == null) {
      return {'status': false, 'message': 'Verification failed'};
    }
    if (result['status'] == true) {
      return {'status': true, 'data': result['data']};
    }
    return {'status': false, 'message': result['message'] ?? 'Verification failed'};
  }

  // ── 1. Pay to unlock contact ───────────────────────────────────────────────
  Future<Map<String, dynamic>?> payToUnlockContact({
    required BuildContext context,
    required PropertyModel property,
    required UserModel buyer,
  }) async {
    try {
      final reference = generateReference();

      final initResult = await initializePayment(
        email:     buyer.email,
        amount:    contactUnlockFee,
        reference: reference,
        metadata: {
          'type':          'contact_unlock',
          'property_id':   property.id,
          'buyer_id':      buyer.id,
          'property_title': property.title,
        },
      );

      if (initResult == null || initResult['status'] != true) {
        return {
          'status':  false,
          'message': initResult?['message'] ?? 'Failed to initialize payment',
        };
      }

      await _supabase.from('contact_unlocks').insert({
        'property_id':    property.id,
        'property_title': property.title,
        'buyer_id':       buyer.id,
        'buyer_name':     buyer.name,
        'buyer_email':    buyer.email,
        'seller_id':      property.ownerId,
        'unlock_fee':     contactUnlockFee,
        'payment_reference': reference,
        'status':         'pending',
        'created_at':     DateTime.now().toIso8601String(),
      });

      return {
        'status':            true,
        'authorization_url': initResult['data']['authorization_url'],
        'reference':         reference,
      };
    } catch (e) {
      debugPrint('Contact unlock error: $e');
      return {'status': false, 'message': 'Payment failed: $e'};
    }
  }

  // ── 2. Process contact unlock ──────────────────────────────────────────────
  Future<bool> processContactUnlock(String reference) async {
    try {
      final verifyResult = await verifyPayment(reference);
      if (verifyResult == null || verifyResult['status'] != true) return false;

      final paymentData = verifyResult['data'];
      if (paymentData['status'] != 'success') return false;

      final unlocks = await _supabase
          .from('contact_unlocks')
          .select()
          .eq('payment_reference', reference);

      if ((unlocks as List).isEmpty) return false;

      final unlock   = unlocks.first as Map<String, dynamic>;
      final unlockId = unlock['id'];

      await _supabase.from('contact_unlocks').update({
        'status':             'paid',
        'paystack_reference': paymentData['reference'],
        'paid_at':            DateTime.now().toIso8601String(),
      }).eq('id', unlockId);

      await _createCommissionTransaction(
        type:                'contact_unlock',
        propertyId:          unlock['property_id']?.toString() ?? '',
        propertyTitle:       unlock['property_title'] ?? '',
        buyerId:             unlock['buyer_id']?.toString() ?? '',
        buyerName:           unlock['buyer_name'] ?? '',
        buyerEmail:          unlock['buyer_email'] ?? '',
        sellerId:            unlock['seller_id']?.toString() ?? '',
        amount:              contactUnlockFee,
        commissionAmount:    contactUnlockFee,
        sellerPayoutAmount:  0.0,
        commissionPercentage: 100.0,
        reference:           reference,
        splitUsed:           false,
      );

      return true;
    } catch (e) {
      debugPrint('Process unlock error: $e');
      return false;
    }
  }

  // ── 3. Check if buyer has unlocked contact ─────────────────────────────────
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

  // ── 4. Inspection payment ──────────────────────────────────────────────────
  Future<Map<String, dynamic>?> chargeCardForInspection({
    required String email,
    required double amount,
    required String reference,
    required PropertyModel property,
    required UserModel buyer,
  }) async {
    try {
      final subaccountCode  = await _getSellerSubaccountCode(property.ownerId);
      final platformCharge  = amount * inspectionCommissionRate / 100;

      final initResult = await initializePayment(
        email:           email,
        amount:          amount,
        reference:       reference,
        metadata: {
          'type':          'inspection',
          'property_id':   property.id,
          'buyer_id':      buyer.id,
          'property_title': property.title,
          'split_used':    subaccountCode != null,
        },
        subaccountCode:    subaccountCode,
        transactionCharge: platformCharge,
        bearer:            'account',
      );

      if (initResult == null || initResult['status'] != true) {
        return {
          'status':  false,
          'message': initResult?['message'] ?? 'Failed to initialize payment',
        };
      }

      return {
        'status':            true,
        'authorization_url': initResult['data']['authorization_url'],
        'reference':         reference,
        'split_used':        subaccountCode != null,
      };
    } catch (e) {
      debugPrint('Inspection payment error: $e');
      return {'status': false, 'message': 'Payment failed: $e'};
    }
  }

  // ── 5. Process inspection payment ─────────────────────────────────────────
  Future<bool> processInspectionPayment(
    String reference,
    PropertyModel property,
    UserModel buyer,
  ) async {
    try {
      final verifyResult = await verifyPayment(reference);
      if (verifyResult == null || verifyResult['status'] != true) return false;

      final paymentData = verifyResult['data'];
      if (paymentData['status'] != 'success') return false;

      final double amountPaid =
          ((paymentData['amount'] ?? 0) as num).toDouble() / 100;
      final double commission = amountPaid * inspectionCommissionRate / 100;
      final double sellerPayout = amountPaid - commission;
      final bool splitUsed = paymentData['subaccount'] != null;

      final inspections = await _supabase
          .from('inspections')
          .select()
          .eq('payment_reference', reference);

      for (final doc in (inspections as List)) {
        await _supabase.from('inspections').update({
          'payment_status':   'paid',
          'booking_status':   'confirmed',
          'paystack_reference': paymentData['reference'],
          'paid_at':          DateTime.now().toIso8601String(),
          'updated_at':       DateTime.now().toIso8601String(),
        }).eq('id', doc['id']);
      }

      await _createCommissionTransaction(
        type:                'inspection',
        propertyId:          property.id,
        propertyTitle:       property.title,
        buyerId:             buyer.id,
        buyerName:           buyer.name,
        buyerEmail:          buyer.email,
        sellerId:            property.ownerId,
        amount:              amountPaid,
        commissionAmount:    commission,
        sellerPayoutAmount:  sellerPayout,
        commissionPercentage: inspectionCommissionRate,
        reference:           reference,
        splitUsed:           splitUsed,
      );

      return true;
    } catch (e) {
      debugPrint('Process inspection error: $e');
      return false;
    }
  }

  // ── 6. Property purchase payment ───────────────────────────────────────────
  Future<Map<String, dynamic>?> initiatePropertyPurchase({
    required PropertyModel property,
    required UserModel buyer,
  }) async {
    try {
      final amount         = property.buyPrice > 0 ? property.buyPrice : property.price;
      final reference      = generateReference();
      final subaccountCode = await _getSellerSubaccountCode(property.ownerId);
      final platformCharge = amount * purchaseCommissionRate / 100;

      final initResult = await initializePayment(
        email:           buyer.email,
        amount:          amount,
        reference:       reference,
        metadata: {
          'type':          'property_purchase',
          'property_id':   property.id,
          'buyer_id':      buyer.id,
          'property_title': property.title,
          'split_used':    subaccountCode != null,
        },
        subaccountCode:    subaccountCode,
        transactionCharge: platformCharge,
        bearer:            'account',
      );

      if (initResult == null || initResult['status'] != true) {
        return {
          'status':  false,
          'message': initResult?['message'] ?? 'Failed to initialize payment',
        };
      }

      await _supabase.from('property_purchases').insert({
        'property_id':    property.id,
        'property_title': property.title,
        'buyer_id':       buyer.id,
        'buyer_name':     buyer.name,
        'buyer_email':    buyer.email,
        'seller_id':      property.ownerId,
        'amount':         amount,
        'payment_reference': reference,
        'status':         'pending',
        'split_used':     subaccountCode != null,
        'created_at':     DateTime.now().toIso8601String(),
      });

      return {
        'status':            true,
        'authorization_url': initResult['data']['authorization_url'],
        'reference':         reference,
        'amount':            amount,
        'split_used':        subaccountCode != null,
      };
    } catch (e) {
      debugPrint('Property purchase init error: $e');
      return {'status': false, 'message': 'Payment failed: $e'};
    }
  }

  // ── 7. Process property purchase ───────────────────────────────────────────
  Future<bool> processPropertyPurchase(
    String reference,
    PropertyModel property,
    UserModel buyer,
  ) async {
    try {
      final verifyResult = await verifyPayment(reference);
      if (verifyResult == null || verifyResult['status'] != true) return false;

      final paymentData    = verifyResult['data'];
      if (paymentData['status'] != 'success') return false;

      final double amountPaid =
          ((paymentData['amount'] ?? 0) as num).toDouble() / 100;
      final double commission   = amountPaid * purchaseCommissionRate / 100;
      final double sellerPayout = amountPaid - commission;
      final bool   splitUsed    = paymentData['subaccount'] != null;

      final purchases = await _supabase
          .from('property_purchases')
          .select()
          .eq('payment_reference', reference);

      for (final doc in (purchases as List)) {
        await _supabase.from('property_purchases').update({
          'status':             'completed',
          'paystack_reference': paymentData['reference'],
          'paid_at':            DateTime.now().toIso8601String(),
          'commission_amount':  commission,
          'seller_payout_amount': sellerPayout,
          'split_used':         splitUsed,
        }).eq('id', doc['id']);
      }

      await _createCommissionTransaction(
        type:                'property_purchase',
        propertyId:          property.id,
        propertyTitle:       property.title,
        buyerId:             buyer.id,
        buyerName:           buyer.name,
        buyerEmail:          buyer.email,
        sellerId:            property.ownerId,
        amount:              amountPaid,
        commissionAmount:    commission,
        sellerPayoutAmount:  sellerPayout,
        commissionPercentage: purchaseCommissionRate,
        reference:           reference,
        splitUsed:           splitUsed,
      );

      return true;
    } catch (e) {
      debugPrint('Process purchase error: $e');
      return false;
    }
  }

  // ── 8. Seller subscription payment ────────────────────────────────────────
  Future<Map<String, dynamic>?> paySellerSubscription({
    required UserModel seller,
    required String plan,
  }) async {
    try {
      final fee       = plan == 'premium' ? premiumPlanFee : basicPlanFee;
      final reference = generateReference();

      final initResult = await initializePayment(
        email:     seller.email,
        amount:    fee,
        reference: reference,
        metadata: {
          'type':      'subscription',
          'seller_id': seller.id,
          'plan':      plan,
        },
      );

      if (initResult == null || initResult['status'] != true) {
        return {
          'status':  false,
          'message': initResult?['message'] ?? 'Failed to initialize payment',
        };
      }

      return {
        'status':            true,
        'authorization_url': initResult['data']['authorization_url'],
        'reference':         reference,
        'plan':              plan,
      };
    } catch (e) {
      debugPrint('Subscription payment error: $e');
      return {'status': false, 'message': 'Payment failed: $e'};
    }
  }

  // ── 9. Process subscription payment ───────────────────────────────────────
  Future<bool> processSubscriptionPayment(
      String reference, String sellerId, String plan) async {
    try {
      final verifyResult = await verifyPayment(reference);
      if (verifyResult == null || verifyResult['status'] != true) return false;

      final paymentData = verifyResult['data'];
      if (paymentData['status'] != 'success') return false;

      final sellerData = await _supabase
          .from('users')
          .select()
          .eq('id', sellerId)
          .maybeSingle();
      if (sellerData == null) return false;

      final fee    = plan == 'premium' ? premiumPlanFee : basicPlanFee;
      final now    = DateTime.now();
      final expiry = DateTime(now.year, now.month + 1, now.day);

      await _supabase.from('seller_subscriptions').upsert({
        'seller_id':          sellerId,
        'seller_name':        sellerData['name'] ?? '',
        'seller_email':       sellerData['email'] ?? '',
        'plan':               plan,
        'monthly_fee':        fee,
        'start_date':         now.toIso8601String(),
        'expiry_date':        expiry.toIso8601String(),
        'is_active':          true,
        'payment_reference':  reference,
        'paystack_reference': paymentData['reference'],
        'created_at':         now.toIso8601String(),
        'last_payment_date':  now.toIso8601String(),
      }, onConflict: 'seller_id');

      await _supabase.from('subscription_payments').insert({
        'seller_id':          sellerId,
        'seller_name':        sellerData['name'] ?? '',
        'seller_email':       sellerData['email'] ?? '',
        'plan':               plan,
        'amount':             fee,
        'payment_reference':  reference,
        'paystack_reference': paymentData['reference'],
        'created_at':         now.toIso8601String(),
      });

      return true;
    } catch (e) {
      debugPrint('Process subscription error: $e');
      return false;
    }
  }

  // ── 10. Get seller subscription ────────────────────────────────────────────
  Future<SellerSubscription?> getSellerSubscription(String sellerId) async {
    try {
      final data = await _supabase
          .from('seller_subscriptions')
          .select()
          .eq('seller_id', sellerId)
          .maybeSingle();

      if (data == null) return null;

      final sub = SellerSubscription.fromJson(data['id']?.toString() ?? '', data);

      if (sub.isExpired && sub.isActive) {
        await _supabase
            .from('seller_subscriptions')
            .update({'is_active': false})
            .eq('seller_id', sellerId);
      }

      return sub;
    } catch (e) {
      debugPrint('Error getting subscription: $e');
      return null;
    }
  }

  // ── 11. Count seller's properties ─────────────────────────────────────────
  Future<int> getSellerPropertyCount(String sellerId) async {
    try {
      final data = await _supabase
          .from('properties')
          .select()
          .eq('owner_id', sellerId);
      return (data as List).length;
    } catch (e) {
      debugPrint('Error counting seller properties: $e');
      return 0;
    }
  }

  // ── 12. Can seller add property? ───────────────────────────────────────────
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
          'reason':  'no_subscription',
          'message': 'You have used your 1 free listing. Subscribe to add more.',
        };
      }

      if (sub.plan == 'basic' && count >= 20) {
        return {
          'allowed': false,
          'reason':  'basic_limit_reached',
          'message': 'Basic plan allows up to 20 listings. Upgrade to Premium.',
        };
      }

      return {'allowed': true, 'reason': 'subscribed'};
    } catch (e) {
      debugPrint('Error checking canAddProperty: $e');
      return {'allowed': true, 'reason': 'error_fallback'};
    }
  }

  // ── 13. Create commission transaction ──────────────────────────────────────
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
    required String reference,
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
        if (sellerData != null) sellerName = sellerData['name'] ?? sellerName;
      } catch (_) {}

      final now = DateTime.now().toIso8601String();

      await _supabase.from('commission_transactions').insert({
        'type':               type,
        'property_id':        propertyId.isNotEmpty ? propertyId : null,
        'property_title':     propertyTitle,
        'buyer_id':           buyerId.isNotEmpty ? buyerId : null,
        'buyer_name':         buyerName,
        'buyer_email':        buyerEmail,
        'seller_id':          sellerId.isNotEmpty ? sellerId : null,
        'seller_name':        sellerName,
        'amount':             amount,
        'commission_amount':  commissionAmount,
        'commission_percentage': commissionPercentage,
        'seller_payout_amount': sellerPayoutAmount,
        'seller_payout_status':
            splitUsed ? 'auto_split_by_paystack' : 'pending_disbursement',
        'split_used':         splitUsed,
        'status':             'completed',
        'payment_reference':  reference,
        'paystack_reference': reference,
        'app_owner_email':    appOwnerEmail,
        'created_at':         now,
        'completed_at':       now,
      });
    } catch (e) {
      debugPrint('Error creating commission transaction: $e');
    }
  }

  // ── 14. Get total commissions (admin) ──────────────────────────────────────
  Future<Map<String, dynamic>> getTotalCommissions() async {
    try {
      final transactions = await _supabase
          .from('commission_transactions')
          .select()
          .eq('status', 'completed');

      double totalCommissions      = 0;
      double todayCommissions      = 0;
      double thisMonthCommissions  = 0;
      double pendingSellerPayouts  = 0;
      double inspectionCommissions = 0;
      double salesCommissions      = 0;
      int    contactUnlocks        = 0;
      int    inspections           = 0;
      int    purchases             = 0;
      int    autoSplitCount        = 0;

      final now        = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final monthStart = DateTime(now.year, now.month, 1);

      for (final row in (transactions as List)) {
        final trans = CommissionTransaction.fromJson(
            row['id']?.toString() ?? '', row as Map<String, dynamic>);

        totalCommissions += trans.commissionAmount;
        if (trans.createdAt.isAfter(todayStart)) {
          todayCommissions += trans.commissionAmount;
        }
        if (trans.createdAt.isAfter(monthStart)) {
          thisMonthCommissions += trans.commissionAmount;
        }

        final payoutStatus = row['seller_payout_status']?.toString() ?? '';
        if (payoutStatus == 'pending_disbursement') {
          pendingSellerPayouts +=
              (row['seller_payout_amount'] ?? 0.0) as double;
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
        'totalCommissions':       totalCommissions,
        'todayCommissions':       todayCommissions,
        'thisMonthCommissions':   thisMonthCommissions,
        'pendingSellerPayouts':   pendingSellerPayouts,
        'contactUnlocks':         contactUnlocks,
        'inspections':            inspections,
        'inspectionCommissions':  inspectionCommissions,
        'purchases':              purchases,
        'salesCommissions':       salesCommissions,
        'sales':                  purchases,
        'totalTransactions':      (transactions).length,
        'autoSplitCount':         autoSplitCount,
        'manualDisbursementCount':
            (transactions).length - contactUnlocks - autoSplitCount,
      };
    } catch (e) {
      debugPrint('Error getting commissions: $e');
      return {};
    }
  }

  // ── 15. Get active subscriptions count (admin) ─────────────────────────────
  Future<int> getActiveSubscriptionsCount() async {
    try {
      final subs = await _supabase
          .from('seller_subscriptions')
          .select()
          .eq('is_active', true);
      return (subs as List).length;
    } catch (e) {
      debugPrint('Error getting subscriptions count: $e');
      return 0;
    }
  }
}