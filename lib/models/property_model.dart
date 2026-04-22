// lib/models/property_model.dart

class PropertyLocation {
  final String address;
  final String city;
  final String state;
  final String country;
  final String zipCode;
  final double latitude;
  final double longitude;

  PropertyLocation({
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    required this.zipCode,
    required this.latitude,
    required this.longitude,
  });

  // For local use / Cloudinary metadata
  Map<String, dynamic> toJson() => {
        'address': address,
        'city': city,
        'state': state,
        'country': country,
        'zipCode': zipCode,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory PropertyLocation.fromJson(Map<String, dynamic> json) =>
      PropertyLocation(
        address: json['address'] ?? '',
        city: json['city'] ?? '',
        state: json['state'] ?? '',
        country: json['country'] ?? 'Nigeria',
        zipCode: json['zipCode'] ?? json['zip_code'] ?? '',
        latitude: (json['latitude'] ?? 0.0).toDouble(),
        longitude: (json['longitude'] ?? 0.0).toDouble(),
      );

  String get fullAddress => '$address, $city, $state $zipCode';
}

class PropertyModel {
  final String id;
  final String title;
  final String description;
  final double price;
  final String propertyType;
  final String status;
  final int bedrooms;
  final int bathrooms;
  final double area;
  final List<String> images;
  final List<String> videos;
  final PropertyLocation location;
  final List<String> amenities;
  final String ownerId;
  final bool featured;
  final int views;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String type;
  final String listingType;
  final bool isFeatured;
  final double inspectionFee;
  final double buyPrice;
  final String sellerPhone;
  final String sellerWhatsapp;
  final String sellerEmail;

  PropertyModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.propertyType,
    required this.status,
    required this.bedrooms,
    required this.bathrooms,
    required this.area,
    required this.images,
    required this.videos,
    required this.location,
    required this.amenities,
    required this.ownerId,
    this.featured = false,
    this.views = 0,
    required this.createdAt,
    required this.updatedAt,
    String? type,
    String? listingType,
    bool? isFeatured,
    this.inspectionFee = 0.0,
    this.buyPrice = 0.0,
    this.sellerPhone = '',
    this.sellerWhatsapp = '',
    this.sellerEmail = '',
  })  : type = type ?? propertyType.toLowerCase(),
        listingType = listingType ?? 'sale',
        isFeatured = isFeatured ?? featured;

  /// Convert to Supabase flat row format.
  Map<String, dynamic> toSupabaseJson() => {
        'title': title,
        'description': description,
        'price': price,
        'property_type': propertyType,
        'type': type,
        'listing_type': listingType,
        'status': status,
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'area': area,
        'images': images,
        'videos': videos,
        'address': location.address,
        'city': location.city,
        'state': location.state,
        'country': location.country,
        'zip_code': location.zipCode,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'amenities': amenities,
        'owner_id': ownerId,
        'featured': featured,
        'is_featured': isFeatured,
        'views': views,
        'inspection_fee': inspectionFee,
        'buy_price': buyPrice,
        'seller_phone': sellerPhone,
        'seller_whatsapp': sellerWhatsapp,
        'seller_email': sellerEmail,
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory PropertyModel.fromSupabaseJson(Map<String, dynamic> json) =>
      PropertyModel(
        id: json['id']?.toString() ?? '',
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        price: (json['price'] ?? 0.0).toDouble(),
        propertyType: json['property_type'] ?? 'House',
        type: json['type'] ?? 'house',
        listingType: json['listing_type'] ?? 'sale',
        status: json['status'] ?? 'active',
        bedrooms: json['bedrooms'] ?? 0,
        bathrooms: json['bathrooms'] ?? 0,
        area: (json['area'] ?? 0.0).toDouble(),
        images: List<String>.from(json['images'] ?? []),
        videos: List<String>.from(json['videos'] ?? []),
        location: PropertyLocation(
          address: json['address'] ?? '',
          city: json['city'] ?? '',
          state: json['state'] ?? '',
          country: json['country'] ?? 'Nigeria',
          zipCode: json['zip_code'] ?? '',
          latitude: (json['latitude'] ?? 0.0).toDouble(),
          longitude: (json['longitude'] ?? 0.0).toDouble(),
        ),
        amenities: List<String>.from(json['amenities'] ?? []),
        ownerId: json['owner_id']?.toString() ?? '',
        featured: json['featured'] ?? false,
        isFeatured: json['is_featured'] ?? json['featured'] ?? false,
        views: json['views'] ?? 0,
        inspectionFee: (json['inspection_fee'] ?? 0.0).toDouble(),
        buyPrice: (json['buy_price'] ?? 0.0).toDouble(),
        sellerPhone: json['seller_phone']?.toString() ?? '',
        sellerWhatsapp: json['seller_whatsapp']?.toString() ?? '',
        sellerEmail: json['seller_email']?.toString() ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : DateTime.now(),
      );

  PropertyModel copyWith({
    String? title,
    String? description,
    double? price,
    String? propertyType,
    String? type,
    String? listingType,
    String? status,
    int? bedrooms,
    int? bathrooms,
    double? area,
    List<String>? images,
    List<String>? videos,
    PropertyLocation? location,
    List<String>? amenities,
    bool? featured,
    bool? isFeatured,
    int? views,
    double? inspectionFee,
    double? buyPrice,
    String? sellerPhone,
    String? sellerWhatsapp,
    String? sellerEmail,
    DateTime? updatedAt,
  }) =>
      PropertyModel(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        price: price ?? this.price,
        propertyType: propertyType ?? this.propertyType,
        type: type ?? this.type,
        listingType: listingType ?? this.listingType,
        status: status ?? this.status,
        bedrooms: bedrooms ?? this.bedrooms,
        bathrooms: bathrooms ?? this.bathrooms,
        area: area ?? this.area,
        images: images ?? this.images,
        videos: videos ?? this.videos,
        location: location ?? this.location,
        amenities: amenities ?? this.amenities,
        ownerId: ownerId,
        featured: featured ?? this.featured,
        isFeatured: isFeatured ?? this.isFeatured,
        views: views ?? this.views,
        inspectionFee: inspectionFee ?? this.inspectionFee,
        buyPrice: buyPrice ?? this.buyPrice,
        sellerPhone: sellerPhone ?? this.sellerPhone,
        sellerWhatsapp: sellerWhatsapp ?? this.sellerWhatsapp,
        sellerEmail: sellerEmail ?? this.sellerEmail,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );
}
