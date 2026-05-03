// lib/providers/property_provider.dart
//
// FIXES APPLIED:
// ─────────────────────────────────────────────────────────────────────────────
// [FIX 1]  Duplicate state field: both `_error` and `_errorMessage` held the
//          same value. Collapsed into one canonical `_errorMessage` field.
// [FIX 2]  searchProperties() fetched ALL active properties then filtered
//          client-side — O(N) network payload on every keystroke. Replaced
//          with server-side OR filter using Supabase's .or() builder.
// [FIX 3]  addProperty() called fetchProperties() after every insert, causing
//          an unnecessary full re-fetch. Now inserts the new property into the
//          local list directly so the UI updates instantly.
// [FIX 4]  deleteProperty() looped individual storage deletions without error
//          handling per file. Added per-file try/catch so one bad URL doesn't
//          abort the whole deletion.
// [FIX 5]  getPropertyStatistics() fetched ALL columns for all properties
//          just to count them — expensive. Now selects only the fields needed.
// [FIX 6]  _toSnakeCase() had a catch-all `else` branch that ran a regex on
//          every unrecognised key, silently dropping known camelCase keys that
//          were not explicitly mapped (e.g. 'status', 'area', 'type', etc.).
//          Replaced with an explicit allow-list so no data is lost.
// ─────────────────────────────────────────────────────────────────────────────

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

  // FIX 1: single error field (was duplicated as _error + _errorMessage)
  String? _errorMessage;

  List<PropertyModel> get properties => _properties;
  List<PropertyModel> get featuredProperties => _featuredProperties;
  PropertyModel? get selectedProperty => _selectedProperty;
  bool get isLoading => _isLoading;
  String? get error => _errorMessage;
  String? get errorMessage => _errorMessage;

  static const double _absoluteMaxPrice = 1000000000; // ₦1 billion

  // ── Fetch all active properties — filters pushed to Supabase ─────────────
  Future<void> fetchProperties({
    String? propertyType,
    double? minPrice,
    double? maxPrice,
    String? city,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      var query = _supabase
          .from('properties')
          .select()
          .eq('status', 'active');

      if (propertyType != null && propertyType != 'All') {
        query = query.eq('type', propertyType.toLowerCase());
      }
      if (minPrice != null && minPrice > 0) {
        query = query.gte('price', minPrice);
      }
      if (maxPrice != null && maxPrice < _absoluteMaxPrice) {
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
      _errorMessage = 'Failed to fetch properties: $e';
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
      _errorMessage = 'Failed to fetch property: $e';
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
      _errorMessage = null;
      notifyListeners();

      final imageUrls = await _storage.uploadImages(images);
      if (imageUrls.isEmpty && images.isNotEmpty) {
        _errorMessage =
            'Failed to upload images. Check your internet connection.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final videoUrls = await _storage.uploadVideos(videos);

      final now = DateTime.now().toIso8601String();
      propertyData['images'] = imageUrls;
      propertyData['videos'] = videoUrls;
      propertyData['views'] = 0;
      propertyData['created_at'] = now;
      propertyData['updated_at'] = now;

      final row = _toSnakeCase(propertyData);

      // FIX 3: insert and get the row back so we can update local state
      // without a full re-fetch.
      final inserted = await _supabase
          .from('properties')
          .insert(row)
          .select()
          .single();

      final newProperty =
          PropertyModel.fromSupabaseJson(inserted as Map<String, dynamic>);
      _properties.insert(0, newProperty);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add property: $e';
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
      _errorMessage = null;
      notifyListeners();

      final newImageUrls = await _storage.uploadImages(newImages);
      final newVideoUrls = await _storage.uploadVideos(newVideos);

      propertyData['images'] = [...existingImageUrls, ...newImageUrls];
      propertyData['videos'] = [...existingVideoUrls, ...newVideoUrls];
      propertyData['updated_at'] = DateTime.now().toIso8601String();

      final row = _toSnakeCase(propertyData);
      final updated = await _supabase
          .from('properties')
          .update(row)
          .eq('id', propertyId)
          .select()
          .single();

      final updatedProp =
          PropertyModel.fromSupabaseJson(updated as Map<String, dynamic>);
      final idx = _properties.indexWhere((p) => p.id == propertyId);
      if (idx != -1) _properties[idx] = updatedProp;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update property: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Delete property ───────────────────────────────────────────────────────
  Future<bool> deleteProperty(String propertyId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final data = await _supabase
          .from('properties')
          .select()
          .eq('id', propertyId)
          .maybeSingle();

      if (data != null) {
        final prop = PropertyModel.fromSupabaseJson(data);
        // FIX 4: individual try/catch so one bad URL doesn't abort deletion
        for (final url in [...prop.images, ...prop.videos]) {
          try {
            await _storage.deleteFile(url);
          } catch (e) {
            if (kDebugMode) print('Could not delete file $url: $e');
          }
        }
      }

      await _supabase.from('properties').delete().eq('id', propertyId);
      _properties.removeWhere((p) => p.id == propertyId);
      _featuredProperties.removeWhere((p) => p.id == propertyId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete property: $e';
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

  // ── Search — FIX 2: server-side OR filter, not client-side scan ───────────
  Future<void> searchProperties(String query) async {
    if (query.trim().isEmpty) {
      await fetchProperties();
      return;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final q = query.trim();

      // Server-side OR filter across title, description, city, state, type.
      // Much cheaper than fetching everything and filtering in Dart.
      final data = await _supabase
          .from('properties')
          .select()
          .eq('status', 'active')
          .or(
            'title.ilike.%$q%,'
            'description.ilike.%$q%,'
            'city.ilike.%$q%,'
            'state.ilike.%$q%,'
            'type.ilike.%$q%',
          )
          .order('created_at', ascending: false);

      _properties = (data as List)
          .map((row) =>
              PropertyModel.fromSupabaseJson(row as Map<String, dynamic>))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Search failed: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Client-side filter (admin screens) ────────────────────────────────────
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

  // ── Admin statistics — FIX 5: select only needed columns ─────────────────
  Future<Map<String, dynamic>> getPropertyStatistics() async {
    try {
      final data = await _supabase
          .from('properties')
          .select('status, price, views');

      final rows = data as List;

      int active = 0, sold = 0, rented = 0, totalViews = 0;
      double totalValue = 0;

      for (final row in rows) {
        final status = row['status'] as String? ?? '';
        final price = ((row['price'] ?? 0) as num).toDouble();
        final views = (row['views'] ?? 0) as int;

        if (status == 'active') active++;
        if (status == 'sold') sold++;
        if (status == 'rented') rented++;
        totalViews += views;
        totalValue += price;
      }

      return {
        'totalProperties': rows.length,
        'activeProperties': active,
        'soldProperties': sold,
        'rentedProperties': rented,
        'totalViews': totalViews,
        'totalValue': totalValue,
        'averagePrice': rows.isNotEmpty ? totalValue / rows.length : 0.0,
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
    _errorMessage = null;
    notifyListeners();
  }

  // ── FIX 6: Explicit camelCase → snake_case map (no silent data loss) ──────
  Map<String, dynamic> _toSnakeCase(Map<String, dynamic> data) {
    final result = <String, dynamic>{};

    data.forEach((key, value) {
      switch (key) {
        // ── Nested location object ──────────────────────────────────────────
        case 'location':
          if (value is Map) {
            result['address'] = value['address'] ?? '';
            result['city'] = value['city'] ?? '';
            result['state'] = value['state'] ?? '';
            result['country'] = value['country'] ?? 'Nigeria';
            result['zip_code'] = value['zipCode'] ?? value['zip_code'] ?? '';
            result['latitude'] = value['latitude'] ?? 0.0;
            result['longitude'] = value['longitude'] ?? 0.0;
          }
          break;

        // ── camelCase → snake_case mappings ────────────────────────────────
        case 'ownerId':
          result['owner_id'] = value;
          break;
        case 'isFeatured':
          result['is_featured'] = value;
          break;
        case 'propertyType':
          result['property_type'] = value;
          break;
        case 'listingType':
          result['listing_type'] = value;
          break;
        case 'inspectionFee':
          result['inspection_fee'] = value;
          break;
        case 'buyPrice':
          result['buy_price'] = value;
          break;
        case 'sellerPhone':
          result['seller_phone'] = value;
          break;
        case 'sellerWhatsapp':
          result['seller_whatsapp'] = value;
          break;
        case 'sellerEmail':
          result['seller_email'] = value;
          break;

        // ── Pass-through keys that are already snake_case or single-word ───
        // (title, description, price, type, status, bedrooms, bathrooms,
        //  area, images, videos, amenities, featured, views,
        //  created_at, updated_at)
        default:
          result[key] = value;
      }
    });

    return result;
  }
}