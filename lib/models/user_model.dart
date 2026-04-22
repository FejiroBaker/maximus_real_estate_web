// lib/models/user_model.dart
class UserModel {
  final String id;
  final String name;
  final String email;
  final String userType; // 'buyer', 'seller', 'agent', 'admin'
  final String? phone;
  final String? whatsappNumber;
  final String? photoUrl;
  final List<String> savedProperties;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Bank account details (sellers / agents only)
  final String? bankAccountNumber;
  final String? bankName;
  final String? bankAccountName;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.userType,
    this.phone,
    this.whatsappNumber,
    this.photoUrl,
    this.savedProperties = const [],
    required this.createdAt,
    required this.updatedAt,
    this.bankAccountNumber,
    this.bankName,
    this.bankAccountName,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'user_type': userType,
        'phone': phone,
        'whatsapp_number': whatsappNumber,
        'photo_url': photoUrl,
        'saved_properties': savedProperties,
        'bank_account_number': bankAccountNumber,
        'bank_name': bankName,
        'bank_account_name': bankAccountName,
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory UserModel.fromJson(String id, Map<String, dynamic> json) {
    List<String> savedProps = [];
    if (json['saved_properties'] != null) {
      savedProps = List<String>.from(json['saved_properties']);
    }
    return UserModel(
      id: id,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      userType: json['user_type']?.toString() ?? 'buyer',
      phone: json['phone']?.toString(),
      whatsappNumber: json['whatsapp_number']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      savedProperties: savedProps,
      bankAccountNumber: json['bank_account_number']?.toString(),
      bankName: json['bank_name']?.toString(),
      bankAccountName: json['bank_account_name']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? userType,
    String? phone,
    String? whatsappNumber,
    String? photoUrl,
    List<String>? savedProperties,
    DateTime? updatedAt,
    String? bankAccountNumber,
    String? bankName,
    String? bankAccountName,
  }) =>
      UserModel(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        userType: userType ?? this.userType,
        phone: phone ?? this.phone,
        whatsappNumber: whatsappNumber ?? this.whatsappNumber,
        photoUrl: photoUrl ?? this.photoUrl,
        savedProperties: savedProperties ?? this.savedProperties,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
        bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
        bankName: bankName ?? this.bankName,
        bankAccountName: bankAccountName ?? this.bankAccountName,
      );

  @override
  String toString() =>
      'UserModel(id: $id, name: $name, email: $email, userType: $userType)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserModel &&
          other.id == id &&
          other.name == name &&
          other.email == email &&
          other.userType == userType);

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ email.hashCode ^ userType.hashCode;
}
