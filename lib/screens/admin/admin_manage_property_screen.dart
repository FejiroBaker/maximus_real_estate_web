// lib/screens/admin/admin_manage_property_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../models/property_model.dart';
import '../../providers/property_provider.dart';
import '../../utils/pdf_generator.dart';
import 'admin_add_property_screen.dart';

class AdminManagePropertiesScreen extends StatefulWidget {
  const AdminManagePropertiesScreen({super.key});

  @override
  State<AdminManagePropertiesScreen> createState() =>
      _AdminManagePropertiesScreenState();
}

class _AdminManagePropertiesScreenState
    extends State<AdminManagePropertiesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _statusFilter = 'all';
  String _searchQuery = '';
  String _typeFilter = 'all';
  String _listingTypeFilter = 'all';
  List<PropertyModel> _allProperties = [];
  bool _isLoading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _fetchProperties();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchProperties() async {
    try {
      setState(() => _isLoading = true);
      final data = await _supabase
          .from('properties')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _allProperties = (data as List)
              .map((row) => PropertyModel.fromSupabaseJson(
                  row as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeRealtime() {
    _channel = _supabase
        .channel('admin_properties')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'properties',
          callback: (_) => _fetchProperties(),
        )
        .subscribe();
  }

  List<PropertyModel> get _filtered {
    return _allProperties.where((p) {
      final matchStatus =
          _statusFilter == 'all' || p.status == _statusFilter;
      final matchType = _typeFilter == 'all' || p.type == _typeFilter;
      final matchListing = _listingTypeFilter == 'all' ||
          p.listingType == _listingTypeFilter;
      final matchSearch = _searchQuery.isEmpty ||
          p.title.toLowerCase().contains(_searchQuery) ||
          p.location.city.toLowerCase().contains(_searchQuery) ||
          p.type.toLowerCase().contains(_searchQuery);
      return matchStatus && matchType && matchListing && matchSearch;
    }).toList();
  }

  Future<void> _exportToPDF() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generating PDF...')));
      final file = await PDFGenerator.generatePropertyReport(_filtered);
      await Printing.sharePdf(
          bytes: await file.readAsBytes(),
          filename: 'maximus_properties.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error generating PDF: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Properties'),
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Export to PDF',
              onPressed: _exportToPDF),
          IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterDialog),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'refresh') {
                _fetchProperties();
              } else if (value == 'clear_filters') {
                setState(() {
                  _statusFilter = 'all';
                  _typeFilter = 'all';
                  _listingTypeFilter = 'all';
                  _searchQuery = '';
                });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'refresh',
                  child: Row(children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Refresh')
                  ])),
              const PopupMenuItem(
                  value: 'clear_filters',
                  child: Row(children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Clear Filters')
                  ])),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const AdminAddPropertyScreen()),
        ).then((_) => _fetchProperties()),
        icon: const Icon(Icons.add),
        label: const Text('Add Property'),
      ),
      body: Column(children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search properties...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          setState(() => _searchQuery = ''))
                  : null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) =>
                setState(() => _searchQuery = value.toLowerCase()),
          ),
        ),

        // Active filter chips
        if (_statusFilter != 'all' ||
            _typeFilter != 'all' ||
            _listingTypeFilter != 'all')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                if (_statusFilter != 'all')
                  _buildFilterChip(
                    label: 'Status: ${_statusFilter.toUpperCase()}',
                    onDeleted: () =>
                        setState(() => _statusFilter = 'all'),
                  ),
                if (_typeFilter != 'all')
                  _buildFilterChip(
                    label:
                        'Type: ${_typeFilter[0].toUpperCase()}${_typeFilter.substring(1)}',
                    onDeleted: () =>
                        setState(() => _typeFilter = 'all'),
                  ),
                if (_listingTypeFilter != 'all')
                  _buildFilterChip(
                    label:
                        'Listing: ${_listingTypeFilter == 'sale' ? 'For Sale' : 'For Rent'}',
                    onDeleted: () =>
                        setState(() => _listingTypeFilter = 'all'),
                  ),
              ]),
            ),
          ),

        // Properties list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? const Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          Icon(Icons.home_work_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No properties found',
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey)),
                        ]))
                  : RefreshIndicator(
                      onRefresh: _fetchProperties,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) =>
                            _buildPropertyCard(
                                _filtered[index], fmt),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _buildPropertyCard(PropertyModel p, NumberFormat fmt) {
    Color statusColor;
    switch (p.status) {
      case 'sold':
        statusColor = Colors.orange;
        break;
      case 'rented':
        statusColor = Colors.purple;
        break;
      default:
        statusColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        // Property header
        ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: p.images.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: p.images.first,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.home)))
                : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.home)),
          ),
          title: Text(p.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fmt.format(p.price),
                  style: const TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold)),
              Text('${p.location.city}, ${p.location.state}',
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(p.status.toUpperCase(),
                style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            AdminAddPropertyScreen(property: p)),
                  ).then((_) => _fetchProperties()),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showDeleteConfirmation(p),
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  label: const Text('Delete',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: Colors.red)),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _statusButton(
                  label: 'Active',
                  isActive: p.status == 'active',
                  color: Colors.green,
                  onTap: () => _updateStatus(p.id, 'active'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _statusButton(
                  label: 'Sold',
                  isActive: p.status == 'sold',
                  color: Colors.orange,
                  onTap: () => _updateStatus(p.id, 'sold'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _statusButton(
                  label: 'Rented',
                  isActive: p.status == 'rented',
                  color: Colors.purple,
                  onTap: () => _updateStatus(p.id, 'rented'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            // Featured toggle
            Row(children: [
              Icon(
                p.isFeatured ? Icons.star : Icons.star_outline,
                color: p.isFeatured ? Colors.amber : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(p.isFeatured ? 'Featured' : 'Not Featured',
                  style: TextStyle(
                      color: p.isFeatured ? Colors.amber : Colors.grey,
                      fontSize: 13)),
              const Spacer(),
              Switch(
                value: p.isFeatured,
                activeThumbColor: Colors.amber,
                onChanged: (val) => _toggleFeatured(p.id, val),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _statusButton({
    required String label,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isActive ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: isActive ? Colors.white : color,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFilterChip(
      {required String label, required VoidCallback onDeleted}) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onDeleted: onDeleted,
      deleteIconColor: Colors.blue,
      backgroundColor: Colors.blue.shade50,
    );
  }

  Future<void> _updateStatus(String propertyId, String status) async {
    final pp = Provider.of<PropertyProvider>(context, listen: false);
    final success = await pp.updatePropertyStatus(propertyId, status);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? 'Status updated to ${status.toUpperCase()}'
            : 'Failed to update status'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
      if (success) await _fetchProperties();
    }
  }

  Future<void> _toggleFeatured(String propertyId, bool isFeatured) async {
    final pp = Provider.of<PropertyProvider>(context, listen: false);
    await pp.toggleFeaturedStatus(propertyId, isFeatured);
    await _fetchProperties();
  }

  void _showDeleteConfirmation(PropertyModel property) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Property'),
        content: Text(
            'Are you sure you want to delete "${property.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final pp =
                  Provider.of<PropertyProvider>(context, listen: false);
              final success = await pp.deleteProperty(property.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success
                      ? 'Property deleted successfully'
                      : pp.errorMessage ?? 'Failed to delete property'),
                  backgroundColor: success ? Colors.green : Colors.red,
                ));
                if (success) await _fetchProperties();
              }
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Filter Properties',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Status',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['all', 'active', 'sold', 'rented'].map((s) {
                final selected = _statusFilter == s;
                return ChoiceChip(
                  label: Text(s == 'all'
                      ? 'All'
                      : s[0].toUpperCase() + s.substring(1)),
                  selected: selected,
                  onSelected: (_) {
                    setModalState(() => _statusFilter = s);
                    setState(() => _statusFilter = s);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Property Type',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['all', 'house', 'apartment', 'villa', 'condo', 'land']
                  .map((t) {
                final selected = _typeFilter == t;
                return ChoiceChip(
                  label: Text(t == 'all'
                      ? 'All'
                      : t[0].toUpperCase() + t.substring(1)),
                  selected: selected,
                  onSelected: (_) {
                    setModalState(() => _typeFilter = t);
                    setState(() => _typeFilter = t);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Listing Type',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              'all', 'sale', 'rent'
            ].map((l) {
              final selected = _listingTypeFilter == l;
              return ChoiceChip(
                label: Text(l == 'all'
                    ? 'All'
                    : l == 'sale'
                        ? 'For Sale'
                        : 'For Rent'),
                selected: selected,
                onSelected: (_) {
                  setModalState(() => _listingTypeFilter = l);
                  setState(() => _listingTypeFilter = l);
                },
              );
            }).toList()),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Apply Filters'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
