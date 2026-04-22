// lib/screens/search_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/property_provider.dart';
import '../widgets/property_card.dart';
import 'property_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  String? _selectedPropertyType;
  // ── FIX: Raised max price from ₦10M to ₦1B to cover Nigerian luxury market
  static const double _absoluteMax = 1000000000; // ₦1 billion
  double _minPrice = 0;
  double _maxPrice = _absoluteMax;
  final _cityController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final propertyProvider =
        Provider.of<PropertyProvider>(context, listen: false);
    propertyProvider.fetchProperties(
      propertyType: _selectedPropertyType,
      minPrice: _minPrice,
      maxPrice: _maxPrice,
      city: _cityController.text.trim(),
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedPropertyType = null;
      _minPrice = 0;
      _maxPrice = _absoluteMax;
      _cityController.clear();
      _searchController.clear();
    });
    final propertyProvider =
        Provider.of<PropertyProvider>(context, listen: false);
    propertyProvider.fetchProperties();
  }

  String _formatPrice(double price) {
    if (price >= 1000000000) return '₦1B+';
    if (price >= 1000000) return '₦${(price / 1000000).toStringAsFixed(0)}M';
    if (price >= 1000) return '₦${(price / 1000).toStringAsFixed(0)}K';
    return '₦${price.toInt()}';
  }

  @override
  Widget build(BuildContext context) {
    final propertyProvider = Provider.of<PropertyProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Properties'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: const Color(0xFF1565C0),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by title, location...',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.tune, color: Colors.white),
                  onPressed: _showFilterSheet,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  propertyProvider.searchProperties(value);
                }
              },
            ),
          ),

          // Active Filters
          if (_selectedPropertyType != null ||
              _minPrice > 0 ||
              _maxPrice < _absoluteMax ||
              _cityController.text.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Filters: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (_selectedPropertyType != null)
                            _buildFilterChip(_selectedPropertyType!, () {
                              setState(() => _selectedPropertyType = null);
                              _applyFilters();
                            }),
                          if (_cityController.text.isNotEmpty)
                            _buildFilterChip(_cityController.text, () {
                              setState(() => _cityController.clear());
                              _applyFilters();
                            }),
                          if (_minPrice > 0 || _maxPrice < _absoluteMax)
                            _buildFilterChip(
                              '${_formatPrice(_minPrice)} – ${_formatPrice(_maxPrice)}',
                              () {
                                setState(() {
                                  _minPrice = 0;
                                  _maxPrice = _absoluteMax;
                                });
                                _applyFilters();
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear All'),
                  ),
                ],
              ),
            ),

          // Results
          Expanded(
            child: propertyProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : propertyProvider.properties.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off,
                                size: 80, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text(
                              'No properties found',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Try adjusting your filters',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: propertyProvider.properties.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: PropertyCard(
                              property: propertyProvider.properties[index],
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PropertyDetailsScreen(
                                      property:
                                          propertyProvider.properties[index],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDelete) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label),
        onDeleted: onDelete,
        backgroundColor: Colors.blue.shade50,
        deleteIconColor: Colors.blue,
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Property Type
                const Text('Property Type',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ['House', 'Apartment', 'Villa', 'Commercial']
                      .map((type) {
                    return ChoiceChip(
                      label: Text(type),
                      selected: _selectedPropertyType == type,
                      onSelected: (selected) {
                        setModalState(() => _selectedPropertyType =
                            selected ? type : null);
                        setState(() => _selectedPropertyType =
                            selected ? type : null);
                      },
                      selectedColor: Colors.blue.shade100,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // City
                const Text('City',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Lagos, Abuja, Port Harcourt',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Price Range — now up to ₦1 billion
                const Text('Price Range',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatPrice(_minPrice),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _maxPrice >= _absoluteMax
                          ? '₦1B+'
                          : _formatPrice(_maxPrice),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                RangeSlider(
                  values: RangeValues(_minPrice, _maxPrice),
                  min: 0,
                  max: _absoluteMax,
                  // 20 divisions = ₦50M steps — fits Nigerian market well
                  divisions: 20,
                  labels: RangeLabels(
                    _formatPrice(_minPrice),
                    _maxPrice >= _absoluteMax
                        ? '₦1B+'
                        : _formatPrice(_maxPrice),
                  ),
                  onChanged: (values) {
                    setModalState(() {
                      _minPrice = values.start;
                      _maxPrice = values.end;
                    });
                    setState(() {
                      _minPrice = values.start;
                      _maxPrice = values.end;
                    });
                  },
                ),
                const SizedBox(height: 24),

                // Apply / Clear buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _clearFilters();
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Clear'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          _applyFilters();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Apply Filters'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}