// lib/screens/admin/admin_add_property_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/property_model.dart';
import '../../providers/admin_auth_provider.dart';
import '../../providers/property_provider.dart';

class AdminAddPropertyScreen extends StatefulWidget {
  final PropertyModel? property;
  const AdminAddPropertyScreen({super.key, this.property});

  @override
  State<AdminAddPropertyScreen> createState() =>
      _AdminAddPropertyScreenState();
}

class _AdminAddPropertyScreenState extends State<AdminAddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _areaController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();

  String _propertyType = 'house';
  String _listingType = 'sale';
  int _bedrooms = 2;
  int _bathrooms = 2;
  final List<File> _selectedImages = [];
  List<String> _existingImageUrls = [];
  final List<File> _selectedVideos = [];
  List<String> _existingVideoUrls = [];
  final List<String> _selectedAmenities = [];
  bool _isLoading = false;
  bool _isFeatured = false;

  final List<String> _availableAmenities = [
    'Parking', 'Garden', 'Swimming Pool', 'Gym', 'Security',
    'Elevator', 'Balcony', 'Air Conditioning', 'Heating', 'WiFi',
    'Pet Friendly', 'Furnished',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.property != null) _loadPropertyData();
  }

  void _loadPropertyData() {
    final p = widget.property!;
    _titleController.text = p.title;
    _descriptionController.text = p.description;
    _priceController.text = p.price.toString();
    _areaController.text = p.area.toString();
    _addressController.text = p.location.address;
    _cityController.text = p.location.city;
    _stateController.text = p.location.state;
    _zipController.text = p.location.zipCode;
    _propertyType = p.type;
    _listingType = p.listingType;
    _bedrooms = p.bedrooms;
    _bathrooms = p.bathrooms;
    _existingImageUrls = List.from(p.images);
    _existingVideoUrls = List.from(p.videos);
    _selectedAmenities.addAll(p.amenities);
    _isFeatured = p.isFeatured;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await ImagePicker().pickMultiImage();
    if (images.isNotEmpty) {
      setState(
          () => _selectedImages.addAll(images.map((i) => File(i.path))));
    }
  }

  Future<void> _pickVideos() async {
    try {
      final XFile? video = await ImagePicker().pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 5));
      if (video != null) {
        final file = File(video.path);
        final size = await file.length();
        if (size > 100 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Video must be under 100MB'),
                backgroundColor: Colors.orange));
          }
          return;
        }
        setState(() => _selectedVideos.add(file));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _submitProperty() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty && _existingImageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one image')));
      return;
    }

    setState(() => _isLoading = true);

    final propertyProvider =
        Provider.of<PropertyProvider>(context, listen: false);

    // FIX: Use AdminAuthProvider.ADMIN_ID (set after admin login)
    // Falls back to 'admin' string if called before login (shouldn't happen).
    final ownerId = AdminAuthProvider.ADMIN_ID.isNotEmpty
        ? AdminAuthProvider.ADMIN_ID
        : 'admin';

    final propertyData = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'price': double.parse(_priceController.text),
      'type': _propertyType.toLowerCase(),
      'propertyType':
          _propertyType[0].toUpperCase() + _propertyType.substring(1),
      'listingType': _listingType,
      'bedrooms': _bedrooms,
      'bathrooms': _bathrooms,
      'area': double.parse(_areaController.text),
      'location': {
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'country': 'Nigeria',
        'zipCode': _zipController.text.trim(),
        'latitude': 0.0,
        'longitude': 0.0,
      },
      'amenities': _selectedAmenities,
      'status': 'active',
      'ownerId': ownerId,
      'featured': _isFeatured,
      'isFeatured': _isFeatured,
    };

    bool success;
    if (widget.property != null) {
      success = await propertyProvider.updateProperty(
        widget.property!.id,
        propertyData,
        _selectedImages,
        _existingImageUrls,
        _selectedVideos,
        _existingVideoUrls,
      );
    } else {
      success = await propertyProvider.addProperty(
          propertyData, _selectedImages, _selectedVideos);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? widget.property != null
                ? 'Property updated!'
                : 'Property added!'
            : propertyProvider.errorMessage ?? 'Operation failed'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
      if (success) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.property != null ? 'Edit Property' : 'Add Property'),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_selectedVideos.isNotEmpty
                      ? 'Uploading media...'
                      : 'Uploading images...'),
                ]))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section('Property Images'),
                  const SizedBox(height: 12),
                  _buildImagePicker(),
                  const SizedBox(height: 24),

                  _section('Property Videos'),
                  const SizedBox(height: 12),
                  _buildVideoPicker(),
                  const SizedBox(height: 24),

                  _section('Basic Information'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.home)),
                    validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder()),
                    maxLines: 4,
                    validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                        labelText: 'Price (₦)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money)),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),

                  _section('Property Details'),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _propertyType,
                        decoration: const InputDecoration(
                            labelText: 'Type',
                            border: OutlineInputBorder()),
                        items: ['house', 'apartment', 'condo', 'villa', 'land']
                            .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(
                                    t[0].toUpperCase() + t.substring(1))))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _propertyType = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _listingType,
                        decoration: const InputDecoration(
                            labelText: 'Listing',
                            border: OutlineInputBorder()),
                        items: ['sale', 'rent']
                            .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(
                                    t == 'sale' ? 'For Sale' : 'For Rent')))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _listingType = v!),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                        child: _numberSelector('Bedrooms', _bedrooms,
                            (v) => setState(() => _bedrooms = v))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _numberSelector('Bathrooms', _bathrooms,
                            (v) => setState(() => _bathrooms = v))),
                  ]),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _areaController,
                    decoration: const InputDecoration(
                        labelText: 'Area (sq ft)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.square_foot)),
                    keyboardType: TextInputType.number,
                    validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Mark as Featured'),
                    subtitle:
                        const Text('Featured properties appear at the top'),
                    value: _isFeatured,
                    onChanged: (v) => setState(() => _isFeatured = v),
                    activeThumbColor: Colors.amber,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),

                  _section('Location'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on)),
                    validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                            labelText: 'City',
                            border: OutlineInputBorder()),
                        validator: (v) =>
                            (v?.isEmpty ?? true) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _stateController,
                        decoration: const InputDecoration(
                            labelText: 'State',
                            border: OutlineInputBorder()),
                        validator: (v) =>
                            (v?.isEmpty ?? true) ? 'Required' : null,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _zipController,
                    decoration: const InputDecoration(
                        labelText: 'ZIP / Area Code',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),

                  _section('Amenities'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableAmenities.map((a) {
                      final selected = _selectedAmenities.contains(a);
                      return FilterChip(
                        label: Text(a),
                        selected: selected,
                        onSelected: (sel) => setState(() => sel
                            ? _selectedAmenities.add(a)
                            : _selectedAmenities.remove(a)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: _submitProperty,
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: Text(
                      widget.property != null
                          ? 'Update Property'
                          : 'Add Property',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _section(String title) =>
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));

  Widget _numberSelector(String label, int value, Function(int) onChanged) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(
              onPressed: value > 1 ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_circle_outline)),
          Text(value.toString(),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(
              onPressed: value < 20 ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add_circle_outline)),
        ]),
      ]),
    );
  }

  Widget _buildImagePicker() {
    return Column(children: [
      if (_existingImageUrls.isNotEmpty)
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _existingImageUrls.length,
            itemBuilder: (_, i) => Stack(children: [
              Container(
                width: 120,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                      image: NetworkImage(_existingImageUrls[i]),
                      fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 4,
                right: 12,
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _existingImageUrls.removeAt(i)),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
            ]),
          ),
        ),
      if (_selectedImages.isNotEmpty) ...[
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedImages.length,
            itemBuilder: (_, i) => Stack(children: [
              Container(
                width: 120,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                      image: FileImage(_selectedImages[i]),
                      fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 4,
                right: 12,
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _selectedImages.removeAt(i)),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _pickImages,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('Add Images'),
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12)),
      ),
    ]);
  }

  Widget _buildVideoPicker() {
    return Column(children: [
      if (_existingVideoUrls.isNotEmpty || _selectedVideos.isNotEmpty)
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._existingVideoUrls.asMap().entries.map((e) => Stack(children: [
                    Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8)),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_circle_outline,
                                color: Colors.white, size: 36),
                            const SizedBox(height: 4),
                            Text('Video ${e.key + 1}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ]),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => setState(
                            () => _existingVideoUrls.removeAt(e.key)),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ])),
              ..._selectedVideos.asMap().entries.map((e) => Stack(children: [
                    Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade900,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue, width: 2),
                      ),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.videocam,
                                color: Colors.white, size: 36),
                            const SizedBox(height: 4),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(e.value.path.split('/').last,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 10),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ]),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedVideos.removeAt(e.key)),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ])),
            ],
          ),
        ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _pickVideos,
        icon: const Icon(Icons.video_library),
        label: const Text('Add Video'),
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            foregroundColor: Colors.blue),
      ),
    ]);
  }
}
