// lib/screens/add_property_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../providers/property_provider.dart';
import '../models/property_model.dart';
import '../services/flutterwave_service.dart';
import 'seller_subscription_screen.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final FlutterwaveService _flwService =
      FlutterwaveService();

  // Basic info
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _bedroomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _areaController = TextEditingController();

  // Location
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipCodeController = TextEditingController();

  // Fees
  final _inspectionFeeController = TextEditingController();
  final _buyPriceController = TextEditingController();

  // ── Seller contact details for this listing ──────────────────────────────
  final _sellerPhoneController = TextEditingController();
  final _sellerWhatsappController = TextEditingController();
  final _sellerEmailController = TextEditingController();

  // ── Bank account details (for receiving payment payouts) ─────────────────
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();

  String _selectedPropertyType = 'house';
  String _selectedListingType = 'sale';
  final List<File> _selectedImages = [];
  final List<File> _selectedVideos = [];
  final List<String> _selectedAmenities = [];

  bool _checkingSubscription = true;
  bool _canAdd = false;
  String _subscriptionMessage = '';

  final List<String> _propertyTypes = [
    'house',
    'apartment',
    'villa',
    'condo',
    'land'
  ];
  final List<String> _listingTypes = ['sale', 'rent'];
  final List<String> _availableAmenities = [
    'Swimming Pool',
    'Gym',
    'Garden',
    'Parking',
    'Security',
    'Elevator',
    'Balcony',
    'Garage',
    'Air Conditioning',
    'Heating',
    'WiFi',
    'Furnished',
    'Pet Friendly',
  ];

  @override
  void initState() {
    super.initState();
    _checkSubscription();
    // Pre-fill seller contact & bank info from saved profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user =
          Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user != null) {
        _sellerPhoneController.text = user.phone ?? '';
        _sellerWhatsappController.text =
            user.whatsappNumber ?? user.phone ?? '';
        _sellerEmailController.text = user.email;
        // Pre-fill bank details if user already saved them before
        _bankNameController.text = user.bankName ?? '';
        _accountNumberController.text = user.bankAccountNumber ?? '';
        _accountNameController.text = user.bankAccountName ?? '';
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _inspectionFeeController.dispose();
    _buyPriceController.dispose();
    _sellerPhoneController.dispose();
    _sellerWhatsappController.dispose();
    _sellerEmailController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  // ── Subscription gate ─────────────────────────────────────────────────────
  Future<void> _checkSubscription() async {
    setState(() => _checkingSubscription = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) {
      setState(() {
        _checkingSubscription = false;
        _canAdd = false;
        _subscriptionMessage = 'Please log in first.';
      });
      return;
    }
    final result = await _flwService.canAddProperty(user.id);
    if (!mounted) return;
    setState(() {
      _checkingSubscription = false;
      _canAdd = result['allowed'] == true;
      _subscriptionMessage = result['message'] ?? '';
    });
  }

  // ── Media pickers ─────────────────────────────────────────────────────────
  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() =>
            _selectedImages.addAll(images.map((img) => File(img.path))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error picking images: $e')));
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Video added!'), backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error picking video: $e')));
      }
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submitProperty() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one image')));
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final propertyProvider =
        Provider.of<PropertyProvider>(context, listen: false);

    if (authProvider.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to add property')));
      return;
    }

    final gateResult =
        await _flwService.canAddProperty(authProvider.currentUser!.id);
    if (gateResult['allowed'] != true) {
      if (mounted) _showSubscriptionRequired(gateResult['message'] ?? '');
      return;
    }

    // ── Save bank details to user profile silently ────────────────────────
    // So they're pre-filled next time the seller adds a property.
    final bankName = _bankNameController.text.trim();
    final accountNumber = _accountNumberController.text.trim();
    final accountName = _accountNameController.text.trim();
    if (bankName.isNotEmpty &&
        accountNumber.isNotEmpty &&
        accountName.isNotEmpty) {
      await authProvider.updateUserProfile(
        bankAccountNumber: accountNumber,
        bankName: bankName,
        bankAccountName: accountName,
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                  'Uploading ${_selectedVideos.isNotEmpty ? "media" : "images"}...'),
              const SizedBox(height: 8),
              const Text('This may take a few moments',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ),
        ),
      ),
    );

    final inspectionFee =
        double.tryParse(_inspectionFeeController.text.trim()) ?? 0.0;
    final buyPrice =
        double.tryParse(_buyPriceController.text.trim()) ?? 0.0;

    final propertyData = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'price': double.parse(_priceController.text),
      'propertyType': _selectedPropertyType[0].toUpperCase() +
          _selectedPropertyType.substring(1),
      'type': _selectedPropertyType.toLowerCase(),
      'listingType': _selectedListingType,
      'status': 'active',
      'bedrooms': int.parse(_bedroomsController.text),
      'bathrooms': int.parse(_bathroomsController.text),
      'area': double.parse(_areaController.text),
      'location': PropertyLocation(
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        country: 'Nigeria',
        zipCode: _zipCodeController.text.trim(),
        latitude: 0.0,
        longitude: 0.0,
      ).toJson(),
      'amenities': _selectedAmenities,
      'ownerId': authProvider.currentUser!.id,
      'featured': false,
      'isFeatured': false,
      'inspectionFee': inspectionFee,
      'buyPrice': buyPrice,
      // ✅ Seller contact details stored on the listing (revealed after unlock)
      'sellerPhone': _sellerPhoneController.text.trim(),
      'sellerWhatsapp': _sellerWhatsappController.text.trim(),
      'sellerEmail': _sellerEmailController.text.trim(),
    };

    final success = await propertyProvider.addProperty(
        propertyData, _selectedImages, _selectedVideos);

    if (mounted) Navigator.pop(context); // close loading

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Property listed successfully!'),
            backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                propertyProvider.errorMessage ?? 'Failed to add property'),
            backgroundColor: Colors.red));
      }
    }
  }

  void _showSubscriptionRequired(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.lock_outline, color: Colors.orange),
          SizedBox(width: 8),
          Text('Subscription Required'),
        ]),
        content: Text(message.isNotEmpty
            ? message
            : 'You need an active subscription to add more properties.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SellerSubscriptionScreen()),
              ).then((_) => _checkSubscription());
            },
            child: const Text('Subscribe Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSubscription) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    if (!_canAdd) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Property'), elevation: 0),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.workspace_premium,
                  size: 80, color: Colors.orange),
              const SizedBox(height: 24),
              const Text('Subscription Required',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(
                _subscriptionMessage.isNotEmpty
                    ? _subscriptionMessage
                    : 'Subscribe to list more properties on Maximus Real Estate.',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 15),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const SellerSubscriptionScreen()),
                    ).then((_) => _checkSubscription());
                  },
                  icon: const Icon(Icons.star),
                  label: const Text('View Subscription Plans',
                      style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Add Property'), elevation: 0),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildFreeBanner(),
            const SizedBox(height: 16),

            // ── IMAGES ───────────────────────────────────────────────────
            _sectionTitle('Property Images *'),
            const SizedBox(height: 12),
            _buildImageSection(),
            const SizedBox(height: 24),

            // ── VIDEOS ───────────────────────────────────────────────────
            _sectionTitle('Property Videos (Optional)'),
            const SizedBox(height: 4),
            Text('Add video tours (max 100MB each)',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            _buildVideoSection(),
            const SizedBox(height: 24),

            // ── LISTING TYPE ─────────────────────────────────────────────
            _sectionTitle('Listing Type'),
            const SizedBox(height: 12),
            Row(
              children: _listingTypes.map((type) {
                final isSelected = _selectedListingType == type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedListingType = type),
                    child: Container(
                      margin: EdgeInsets.only(
                          right: type == _listingTypes.last ? 0 : 12),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1565C0)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isSelected
                                ? const Color(0xFF1565C0)
                                : Colors.grey.shade300),
                      ),
                      child: Text(
                        type == 'sale' ? 'For Sale' : 'For Rent',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── PROPERTY TYPE ────────────────────────────────────────────
            _sectionTitle('Property Type'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _propertyTypes.map((type) {
                final isSelected = _selectedPropertyType == type;
                return ChoiceChip(
                  label: Text(
                      type[0].toUpperCase() + type.substring(1)),
                  selected: isSelected,
                  onSelected: (_) =>
                      setState(() => _selectedPropertyType = type),
                  selectedColor: Colors.blue.shade100,
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── BASIC INFO ───────────────────────────────────────────────
            _sectionTitle('Basic Information'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Property Title *',
                hintText: '3 Bedroom Duplex in Lekki',
              ),
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Please enter property title'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'Describe your property...',
              ),
              maxLines: 4,
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Please enter description'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Listing Price (₦) *',
                hintText: '15000000',
                prefixText: '₦ ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please enter price';
                if (double.tryParse(v) == null)
                  return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── INSPECTION & PURCHASE SETTINGS ───────────────────────────
            _sectionTitle('Inspection & Purchase Settings'),
            const SizedBox(height: 8),
            // ✅ Commission breakdown visible to seller
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Text('Platform Commission Structure',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontSize: 13)),
                  ]),
                  const SizedBox(height: 8),
                  _commissionRow('Inspection Fee',
                      '10% platform + 90% goes to you'),
                  _commissionRow('Property Purchase',
                      '5% platform + 95% goes to you'),
                  _commissionRow('Contact Unlock',
                      '₦3,000 goes entirely to platform'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _inspectionFeeController,
              decoration: const InputDecoration(
                labelText: 'Inspection Fee (₦)',
                hintText: 'e.g. 50000',
                prefixText: '₦ ',
                helperText: 'Leave blank or 0 if inspection is free',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v != null &&
                    v.isNotEmpty &&
                    double.tryParse(v) == null) {
                  return 'Enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _buyPriceController,
              decoration: const InputDecoration(
                labelText: 'Purchase Price (₦)',
                hintText: 'e.g. 15000000',
                prefixText: '₦ ',
                helperText:
                    'Price a buyer pays to purchase this property. Leave blank to use Listing Price.',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v != null &&
                    v.isNotEmpty &&
                    double.tryParse(v) == null) {
                  return 'Enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── SELLER CONTACT DETAILS ────────────────────────────────────
            _sectionTitle('Your Contact Details for This Listing'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Row(children: [
                Icon(Icons.lock_open, color: Colors.green, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Buyers pay ₦3,000 to unlock these details. '
                    'They are hidden until payment is confirmed.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sellerPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number *',
                hintText: 'e.g. 08012345678',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Phone number is required'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sellerWhatsappController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'WhatsApp Number',
                hintText: 'Leave blank if same as phone number',
                prefixIcon: const Icon(Icons.chat_outlined,
                    color: Color(0xFF25D366)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sellerEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address *',
                hintText: 'your@email.com',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── BANK ACCOUNT DETAILS ──────────────────────────────────────
            // Sellers fill this so the admin can disburse their share of
            // inspection fees and property purchase payments.
            _sectionTitle('Bank Account Details'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.account_balance,
                      color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your bank details are used by the admin to send your share of payments. '
                      'Inspection fees: 90% to you. Property sales: 95% to you.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bankNameController,
              decoration: InputDecoration(
                labelText: 'Bank Name *',
                hintText: 'e.g. Access Bank, GTBank, Zenith Bank',
                prefixIcon:
                    const Icon(Icons.account_balance_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Bank name is required'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _accountNumberController,
              keyboardType: TextInputType.number,
              maxLength: 10,
              decoration: InputDecoration(
                labelText: 'Account Number *',
                hintText: '0123456789',
                prefixIcon: const Icon(Icons.numbers_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return 'Account number is required';
                if (v.trim().length < 10)
                  return 'Enter a valid 10-digit account number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _accountNameController,
              decoration: InputDecoration(
                labelText: 'Account Name *',
                hintText: 'Name exactly as on your bank account',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Account name is required'
                  : null,
            ),
            const SizedBox(height: 24),

            // ── PROPERTY DETAILS ─────────────────────────────────────────
            _sectionTitle('Property Details'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _bedroomsController,
                  decoration: const InputDecoration(
                      labelText: 'Bedrooms *', hintText: '3'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _bathroomsController,
                  decoration: const InputDecoration(
                      labelText: 'Bathrooms *', hintText: '2'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _areaController,
                  decoration: const InputDecoration(
                      labelText: 'Area (sqft) *', hintText: '2500'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ),
            ]),
            const SizedBox(height: 24),

            // ── LOCATION ─────────────────────────────────────────────────
            _sectionTitle('Location'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                  labelText: 'Address *',
                  hintText: '12 Bourdillon Road'),
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Please enter address'
                  : null,
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _cityController,
                  decoration:
                      const InputDecoration(labelText: 'City *'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _stateController,
                  decoration:
                      const InputDecoration(labelText: 'State *'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _zipCodeController,
                  decoration: const InputDecoration(
                      labelText: 'ZIP / Area Code'),
                ),
              ),
            ]),
            const SizedBox(height: 24),

            // ── AMENITIES ────────────────────────────────────────────────
            _sectionTitle('Amenities'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableAmenities.map((a) {
                final isSelected = _selectedAmenities.contains(a);
                return FilterChip(
                  label: Text(a),
                  selected: isSelected,
                  selectedColor: Colors.blue.shade100,
                  checkmarkColor: Colors.blue,
                  onSelected: (sel) {
                    setState(() => sel
                        ? _selectedAmenities.add(a)
                        : _selectedAmenities.remove(a));
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _submitProperty,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Add Property',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _commissionRow(String label, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        const Icon(Icons.circle, size: 6, color: Colors.blue),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style:
                  const TextStyle(fontSize: 12, color: Colors.black87),
              children: [
                TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600)),
                TextSpan(text: detail),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildFreeBanner() {
    return FutureBuilder<int>(
      future: _flwService.getSellerPropertyCount(
        Provider.of<AuthProvider>(context, listen: false)
                .currentUser
                ?.id ??
            '',
      ),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count > 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: const Row(children: [
            Icon(Icons.card_giftcard, color: Colors.green),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '🎉 You are listing your first property for FREE! '
                'After this, a subscription will be required.',
                style: TextStyle(color: Colors.green, fontSize: 13),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));

  Widget _buildImageSection() {
    return Column(children: [
      if (_selectedImages.isNotEmpty)
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedImages.length,
            itemBuilder: (_, i) => Stack(children: [
              Container(
                width: 120,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                      image: FileImage(_selectedImages[i]),
                      fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 4,
                right: 16,
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
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _pickImages,
        icon: const Icon(Icons.add_photo_alternate),
        label: Text(_selectedImages.isEmpty
            ? 'Add Images'
            : 'Add More Images'),
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16)),
      ),
    ]);
  }

  Widget _buildVideoSection() {
    return Column(children: [
      if (_selectedVideos.isNotEmpty)
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedVideos.length,
            itemBuilder: (_, i) {
              final name = _selectedVideos[i].path.split('/').last;
              return Stack(children: [
                Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade900,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.videocam,
                            color: Colors.white, size: 40),
                        const SizedBox(height: 8),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                ),
                Positioned(
                  top: 4,
                  right: 16,
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedVideos.removeAt(i)),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ]);
            },
          ),
        ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _pickVideo,
        icon: const Icon(Icons.videocam),
        label: Text(_selectedVideos.isEmpty
            ? 'Add Video Tour'
            : 'Add More Videos'),
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            foregroundColor: Colors.blue),
      ),
    ]);
  }
}