// lib/models/transaction_model.dart

class CommissionTransaction {
  final String id;
  final String type;
  final String propertyId;
  final String propertyTitle;
  final String buyerId;
  final String buyerName;
  final String buyerEmail;
  final String sellerId;
  final String sellerName;
  final double amount;
  final double commissionAmount;
  final double commissionPercentage;
  final String status;
  final String paymentReference;
  final String? paystackReference;
  final DateTime createdAt;
  final DateTime? completedAt;

  CommissionTransaction({
    required this.id,
    required this.type,
    required this.propertyId,
    required this.propertyTitle,
    required this.buyerId,
    required this.buyerName,
    required this.buyerEmail,
    required this.sellerId,
    required this.sellerName,
    required this.amount,
    required this.commissionAmount,
    required this.commissionPercentage,
    required this.status,
    required this.paymentReference,
    this.paystackReference,
    required this.createdAt,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'property_id': propertyId,
        'property_title': propertyTitle,
        'buyer_id': buyerId,
        'buyer_name': buyerName,
        'buyer_email': buyerEmail,
        'seller_id': sellerId,
        'seller_name': sellerName,
        'amount': amount,
        'commission_amount': commissionAmount,
        'commission_percentage': commissionPercentage,
        'status': status,
        'payment_reference': paymentReference,
        'paystack_reference': paystackReference,
        'created_at': createdAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
      };

  factory CommissionTransaction.fromJson(String id, Map<String, dynamic> json) =>
      CommissionTransaction(
        id: id,
        type: json['type'] ?? '',
        propertyId: json['property_id']?.toString() ?? '',
        propertyTitle: json['property_title'] ?? '',
        buyerId: json['buyer_id']?.toString() ?? '',
        buyerName: json['buyer_name'] ?? '',
        buyerEmail: json['buyer_email'] ?? '',
        sellerId: json['seller_id']?.toString() ?? '',
        sellerName: json['seller_name'] ?? '',
        amount: (json['amount'] ?? 0.0).toDouble(),
        commissionAmount: (json['commission_amount'] ?? 0.0).toDouble(),
        commissionPercentage: (json['commission_percentage'] ?? 0.0).toDouble(),
        status: json['status'] ?? 'pending',
        paymentReference: json['payment_reference'] ?? '',
        paystackReference: json['paystack_reference'],
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'])
            : null,
      );
}

class ContactUnlock {
  final String id;
  final String propertyId;
  final String propertyTitle;
  final String buyerId;
  final String buyerName;
  final String buyerEmail;
  final String sellerId;
  final double unlockFee;
  final String paymentReference;
  final String? paystackReference;
  final String status;
  final DateTime createdAt;
  final DateTime? paidAt;

  ContactUnlock({
    required this.id,
    required this.propertyId,
    required this.propertyTitle,
    required this.buyerId,
    required this.buyerName,
    required this.buyerEmail,
    required this.sellerId,
    required this.unlockFee,
    required this.paymentReference,
    this.paystackReference,
    required this.status,
    required this.createdAt,
    this.paidAt,
  });

  Map<String, dynamic> toJson() => {
        'property_id': propertyId,
        'property_title': propertyTitle,
        'buyer_id': buyerId,
        'buyer_name': buyerName,
        'buyer_email': buyerEmail,
        'seller_id': sellerId,
        'unlock_fee': unlockFee,
        'payment_reference': paymentReference,
        'paystack_reference': paystackReference,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'paid_at': paidAt?.toIso8601String(),
      };

  factory ContactUnlock.fromJson(String id, Map<String, dynamic> json) =>
      ContactUnlock(
        id: id,
        propertyId: json['property_id']?.toString() ?? '',
        propertyTitle: json['property_title'] ?? '',
        buyerId: json['buyer_id']?.toString() ?? '',
        buyerName: json['buyer_name'] ?? '',
        buyerEmail: json['buyer_email'] ?? '',
        sellerId: json['seller_id']?.toString() ?? '',
        unlockFee: (json['unlock_fee'] ?? 0.0).toDouble(),
        paymentReference: json['payment_reference'] ?? '',
        paystackReference: json['paystack_reference'],
        status: json['status'] ?? 'pending',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
      );
}

class SellerSubscription {
  final String id;
  final String sellerId;
  final String sellerName;
  final String sellerEmail;
  final String plan;
  final double monthlyFee;
  final DateTime startDate;
  final DateTime expiryDate;
  final bool isActive;
  final String paymentReference;
  final String? paystackReference;
  final DateTime createdAt;
  final DateTime? lastPaymentDate;

  SellerSubscription({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.sellerEmail,
    required this.plan,
    required this.monthlyFee,
    required this.startDate,
    required this.expiryDate,
    required this.isActive,
    required this.paymentReference,
    this.paystackReference,
    required this.createdAt,
    this.lastPaymentDate,
  });

  bool get isExpired => DateTime.now().isAfter(expiryDate);

  Map<String, dynamic> toJson() => {
        'seller_id': sellerId,
        'seller_name': sellerName,
        'seller_email': sellerEmail,
        'plan': plan,
        'monthly_fee': monthlyFee,
        'start_date': startDate.toIso8601String(),
        'expiry_date': expiryDate.toIso8601String(),
        'is_active': isActive,
        'payment_reference': paymentReference,
        'paystack_reference': paystackReference,
        'created_at': createdAt.toIso8601String(),
        'last_payment_date': lastPaymentDate?.toIso8601String(),
      };

  factory SellerSubscription.fromJson(String id, Map<String, dynamic> json) =>
      SellerSubscription(
        id: id,
        sellerId: json['seller_id']?.toString() ?? '',
        sellerName: json['seller_name'] ?? '',
        sellerEmail: json['seller_email'] ?? '',
        plan: json['plan'] ?? 'basic',
        monthlyFee: (json['monthly_fee'] ?? 0.0).toDouble(),
        startDate: json['start_date'] != null
            ? DateTime.parse(json['start_date'])
            : DateTime.now(),
        expiryDate: json['expiry_date'] != null
            ? DateTime.parse(json['expiry_date'])
            : DateTime.now(),
        isActive: json['is_active'] ?? false,
        paymentReference: json['payment_reference'] ?? '',
        paystackReference: json['paystack_reference'],
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        lastPaymentDate: json['last_payment_date'] != null
            ? DateTime.parse(json['last_payment_date'])
            : null,
      );
}
