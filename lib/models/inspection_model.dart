// lib/models/inspection_model.dart

class InspectionBooking {
  final String id;
  final String propertyId;
  final String propertyTitle;
  final String userId;
  final String userName;
  final String userEmail;
  final String userPhone;
  final DateTime inspectionDate;
  final String timeSlot;
  final double inspectionFee;
  final String paymentStatus; // 'pending', 'paid', 'failed', 'free'
  final String bookingStatus; // 'pending', 'confirmed', 'cancelled', 'completed'
  final String paymentReference;
  final String? flutterwaveReference;
  final DateTime createdAt;
  final DateTime? paidAt;

  InspectionBooking({
    required this.id,
    required this.propertyId,
    required this.propertyTitle,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.inspectionDate,
    required this.timeSlot,
    required this.inspectionFee,
    required this.paymentStatus,
    required this.bookingStatus,
    required this.paymentReference,
    this.flutterwaveReference,
    required this.createdAt,
    this.paidAt,
  });

  Map<String, dynamic> toJson() => {
        'property_id': propertyId,
        'property_title': propertyTitle,
        'user_id': userId,
        'user_name': userName,
        'user_email': userEmail,
        'user_phone': userPhone,
        'inspection_date': inspectionDate.toIso8601String(),
        'time_slot': timeSlot,
        'inspection_fee': inspectionFee,
        'payment_status': paymentStatus,
        'booking_status': bookingStatus,
        'payment_reference': paymentReference,
        'flutterwave_reference': flutterwaveReference,
        'created_at': createdAt.toIso8601String(),
        'paid_at': paidAt?.toIso8601String(),
      };

  factory InspectionBooking.fromJson(
          String id, Map<String, dynamic> json) =>
      InspectionBooking(
        id: id,
        propertyId: json['property_id']?.toString() ?? '',
        propertyTitle: json['property_title'] ?? '',
        userId: json['user_id']?.toString() ?? '',
        userName: json['user_name'] ?? '',
        userEmail: json['user_email'] ?? '',
        userPhone: json['user_phone'] ?? '',
        inspectionDate: json['inspection_date'] != null
            ? DateTime.parse(json['inspection_date'])
            : DateTime.now(),
        timeSlot: json['time_slot'] ?? '',
        inspectionFee: (json['inspection_fee'] ?? 0.0).toDouble(),
        paymentStatus: json['payment_status'] ?? 'pending',
        bookingStatus: json['booking_status'] ?? 'pending',
        paymentReference: json['payment_reference'] ?? '',
        // Support both old and new column names during DB migration
        flutterwaveReference: json['flutterwave_reference']?.toString() ??
            json['paystack_reference']?.toString(),
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        paidAt: json['paid_at'] != null
            ? DateTime.parse(json['paid_at'])
            : null,
      );
}