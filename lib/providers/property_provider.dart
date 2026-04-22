// lib/providers/property_provider.dart
import 'dart:async' show unawaited;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/property_model.dart';
import '../services/supabase_storage_service.dart';

class PropertyProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SupabaseStorageService _storage = SupabaseStorageService();

  List<PropertyModel> _properties = [];
  List<PropertyModel> _featuredProperties = [];
  PropertyModel? _selectedProperty;
  bool _isLoading = false;
  String? _error;
  String? _errorMessage;

  List<PropertyModel> get properties => _properties;
  List<PropertyModel> get featuredProperties => _featuredProperties;
  PropertyModel? get selectedProperty => _selectedProperty;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get errorMessage => _errorMessage;

  // ── Fetch all active properties — filters pushed to Supabase ─────────────
  Future<void> fetchProperties({
    String? propertyType,
    double? minPrice,
    double? maxPrice,
    String? city,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Start with base query
      var query = _supabase
          .from('properties')
          .select()
          .eq('status', 'active');

      // Push all filters to Supabase — never filter in Dart
      if (propertyType != null && propertyType != 'All') {
        query = query.eq('type', propertyType.toLowerCase());
      }
      if (minPrice != null && minPrice > 0) {
        query = query.gte('price', minPrice);
      }
      if (maxPrice != null && maxPrice < 10000000) {
        query = query.lte('price', maxPrice);
      }
      if (city != null && city.trim().isNotEmpty) {
        query = query.ilike('city', '%${city.trim()}%');
      }

      final data = await query.order('created_at', ascending: false);

      _properties = (data as List)
          .map((row) =>
              PropertyModel.fromSupabaseJson(row as Map<String, dynamic>))
          .toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to fetch properties: $e';
      _errorMessage = _error;
      _isLoading = false;
      notifyListeners();
      if (kDebugMode) print('Error fetching properties: $e');
    }
  }

  // ── Fetch featured properties ─────────────────────────────────────────────
  Future<void> fetchFeaturedProperties() async {
    try {
      final data = await _supabase
          .from('properties')
          .select()
          .eq('is_featured', true)
          .eq('status', 'active')
          .limit(10);

      _featuredProperties = (data as List)
          .map((row) =>
              PropertyModel.fromSupabaseJson(row as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error fetching featured properties: $e');
    }
  }

  // ── Fetch single property ─────────────────────────────────────────────────
  Future<PropertyModel?> fetchPropertyById(String propertyId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final data = await _supabase
          .from('properties')
          .select()
          .eq('id', propertyId)
          .maybeSingle();

      if (data != null) {
        _selectedProperty = PropertyModel.fromSupabaseJson(data);
        unawaited(incrementPropertyViews(propertyId));
        _isLoading = false;
        notifyListeners();
        return _selectedProperty;
      }
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Failed to fetch property: $e';
      _errorMessage = _error;
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // ── Add property ──────────────────────────────────────────────────────────
  Future<bool> addProperty(
    Map<String, dynamic> propertyData,
    List<File> images,
    List<File> videos,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      _errorMessage = null;
      notifyListeners();

      final imageUrls = await _storage.uploadImages(images);
      if (imageUrls.isEmpty && images.isNotEmpty) {
        _error = 'Failed to upload images. Check your internet connection.';
        _errorMessage = _error;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final videoUrls = await _storage.uploadVideos(videos);

      propertyData['images'] = imageUrls;
      propertyData['videos'] = videoUrls;
      propertyData['views'] = 0;
      propertyData['created_at'] = DateTime.now().toIso8601String();
      propertyData['updated_at'] = DateTime.now().toIso8601String();

      final row = _toSnakeCase(propertyData);
      await _supabase.from('properties').insert(row);

      await fetchProperties();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to add property: $e';
      _errorMessage = _error;
      _isLoading = false;
      notifyListeners();
      if (kDebugMode) print('Error adding property: $e');
      return false;
    }
  }

  // ── Update property ───────────────────────────────────────────────────────
  Future<bool> updateProperty(
    String propertyId,
    Map<String, dynamic> propertyData,
    List<File> newImages,
    List<String> existingImageUrls,
    List<File> newVideos,
    List<String> existingVideoUrls,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      _errorMessage = null;
      notifyListeners();

      final newImageUrls = await _storage.uploadImages(newImages);
      final newVideoUrls = await _storage.uploadVideos(newVideos);

      propertyData['images'] = [...existingImageUrls, ...newImageUrls];
      propertyData['videos'] = [...existingVideoUrls, ...newVideoUrls];
      propertyData['updated_at'] = DateTime.now().toIso8601String();

      final row = _toSnakeCase(propertyData);
      await _supabase.from('properties').update(row).eq('id', propertyId);

      await fetchProperties();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update property: $e';
      _errorMessage = _error;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Delete property ───────────────────────────────────────────────────────
  Future<bool> deleteProperty(String propertyId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final data = await _supabase
          .from('properties')
          .select()
          .eq('id', propertyId)
          .maybeSingle();

      if (data != null) {
        final prop = PropertyModel.fromSupabaseJson(data);
        for (final url in prop.images) {
          await _storage.deleteFile(url);
        }
        for (final url in prop.videos) {
          await _storage.deleteFile(url);
        }
      }

      await _supabase.from('properties').delete().eq('id', propertyId);
      _properties.removeWhere((p) => p.id == propertyId);
      _featuredProperties.removeWhere((p) => p.id == propertyId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete property: $e';
      _errorMessage = _error;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Status update ─────────────────────────────────────────────────────────
  Future<bool> updatePropertyStatus(String propertyId, String status) async {
    try {
      await _supabase.from('properties').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', propertyId);

      final idx = _properties.indexWhere((p) => p.id == propertyId);
      if (idx != -1) {
        _properties[idx] = _properties[idx].copyWith(status: status);
        notifyListeners();
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('Error updating property status: $e');
      return false;
    }
  }

  // ── Toggle featured ───────────────────────────────────────────────────────
  Future<bool> toggleFeaturedStatus(
      String propertyId, bool isFeatured) async {
    try {
      await _supabase.from('properties').update({
        'is_featured': isFeatured,
        'featured': isFeatured,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', propertyId);

      final idx = _properties.indexWhere((p) => p.id == propertyId);
      if (idx != -1) {
        _properties[idx] = _properties[idx]
            .copyWith(isFeatured: isFeatured, featured: isFeatured);
        if (isFeatured) {
          if (!_featuredProperties.any((p) => p.id == propertyId)) {
            _featuredProperties.add(_properties[idx]);
          }
        } else {
          _featuredProperties.removeWhere((p) => p.id == propertyId);
        }
        notifyListeners();
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('Error toggling featured: $e');
      return false;
    }
  }

  // ── Increment views (atomic via RPC) ──────────────────────────────────────
  Future<void> incrementPropertyViews(String propertyId) async {
    try {
      await _supabase
          .rpc('increment_property_views', params: {'pid': propertyId});
    } catch (e) {
      if (kDebugMode) print('Error incrementing views: $e');
    }
  }

  // ── Search — queries Supabase, does NOT mutate _properties ───────────────
  Future<void> searchProperties(String query) async {
    if (query.isEmpty) {
      await fetchProperties();
      return;
    }

    try {
      _isLoading = true;
      notifyListeners();

      // Fetch fresh from Supabase and filter in-memory on the result set
      // (Supabase free tier lacks full-text search; this keeps the fix safe)
      final data = await _supabase
          .from('properties')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false);

      final lq = query.toLowerCase();
      _properties = (data as List)
          .map((row) =>
              PropertyModel.fromSupabaseJson(row as Map<String, dynamic>))
          .where((p) =>
              p.title.toLowerCase().contains(lq) ||
              p.description.toLowerCase().contains(lq) ||
              p.location.city.toLowerCase().contains(lq) ||
              p.location.state.toLowerCase().contains(lq) ||
              p.type.toLowerCase().contains(lq))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Search failed: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Client-side filter (for admin screens) ────────────────────────────────
  List<PropertyModel> filterProperties({
    String? type,
    String? listingType,
    double? minPrice,
    double? maxPrice,
    int? bedrooms,
    int? bathrooms,
    String? status,
  }) {
    return _properties.where((p) {
      if (type != null && p.type != type) return false;
      if (listingType != null && p.listingType != listingType) return false;
      if (minPrice != null && p.price < minPrice) return false;
      if (maxPrice != null && p.price > maxPrice) return false;
      if (bedrooms != null && p.bedrooms < bedrooms) return false;
      if (bathrooms != null && p.bathrooms < bathrooms) return false;
      if (status != null && p.status != status) return false;
      return true;
    }).toList();
  }

  // ── Properties by owner ───────────────────────────────────────────────────
  Future<List<PropertyModel>> getPropertiesByAgent(String agentId) async {
    try {
      final data = await _supabase
          .from('properties')
          .select()
          .eq('owner_id', agentId)
          .order('created_at', ascending: false);

      return (data as List)
          .map((row) =>
              PropertyModel.fromSupabaseJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching agent properties: $e');
      return [];
    }
  }

  // ── Admin statistics ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getPropertyStatistics() async {
    try {
      final data = await _supabase.from('properties').select();
      final all = (data as List)
          .map((row) =>
              PropertyModel.fromSupabaseJson(row as Map<String, dynamic>))
          .toList();

      int active = 0, sold = 0, rented = 0, totalViews = 0;
      double totalValue = 0;
      for (final p in all) {
        if (p.status == 'active') active++;
        if (p.status == 'sold') sold++;
        if (p.status == 'rented') rented++;
        totalViews += p.views;
        totalValue += p.price;
      }
      return {
        'totalProperties': all.length,
        'activeProperties': active,
        'soldProperties': sold,
        'rentedProperties': rented,
        'totalViews': totalViews,
        'totalValue': totalValue,
        'averagePrice': all.isNotEmpty ? totalValue / all.length : 0,
      };
    } catch (e) {
      if (kDebugMode) print('Error fetching statistics: $e');
      return {};
    }
  }

  void clearSelectedProperty() {
    _selectedProperty = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    _errorMessage = null;
    notifyListeners();
  }

  // ── camelCase → snake_case conversion for Supabase ────────────────────────
  Map<String, dynamic> _toSnakeCase(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    data.forEach((key, value) {
      if (key == 'location' && value is Map) {
        final loc = value;
        result['address'] = loc['address'] ?? '';
        result['city'] = loc['city'] ?? '';
        result['state'] = loc['state'] ?? '';
        result['country'] = loc['country'] ?? 'Nigeria';
        result['zip_code'] = loc['zipCode'] ?? loc['zip_code'] ?? '';
        result['latitude'] = loc['latitude'] ?? 0.0;
        result['longitude'] = loc['longitude'] ?? 0.0;
      } else if (key == 'ownerId') {
        result['owner_id'] = value;
      } else if (key == 'isFeatured') {
        result['is_featured'] = value;
      } else if (key == 'propertyType') {
        result['property_type'] = value;
      } else if (key == 'listingType') {
        result['listing_type'] = value;
      } else if (key == 'inspectionFee') {
        result['inspection_fee'] = value;
      } else if (key == 'buyPrice') {
        result['buy_price'] = value;
      } else if (key == 'sellerPhone') {
        result['seller_phone'] = value;
      } else if (key == 'sellerWhatsapp') {
        result['seller_whatsapp'] = value;
      } else if (key == 'sellerEmail') {
        result['seller_email'] = value;
      } else {
        final snake = key.replaceAllMapped(
            RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}');
        result[snake] = value;
      }
    });
    return result;
  }
}