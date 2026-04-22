// lib/screens/admin/admin_users_screen.dart
//
// 🔐 User role changes now go through the server-side set_user_type() RPC.
//    Direct UPDATE on user_type is blocked by RLS for all clients.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _filterType  = 'all';
  String _searchQuery = '';
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      setState(() => _isLoading = true);
      final data = await _supabase
          .from('users')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _users     = List<Map<String, dynamic>>.from(data as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _users.where((u) {
      final type  = u['user_type'] ?? 'buyer';
      final name  = (u['name']  ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final matchType   = _filterType == 'all' || type == _filterType;
      final matchSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery) ||
          email.contains(_searchQuery);
      return matchType && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchUsers),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search users by name or email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled:    true,
                fillColor: Colors.white,
              ),
              onChanged: (v) =>
                  setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['all', 'buyer', 'seller', 'agent', 'admin'].map((type) {
                final selected = _filterType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(type == 'all'
                        ? 'All'
                        : type[0].toUpperCase() + type.substring(1)),
                    selected: selected,
                    selectedColor:
                        Theme.of(context).primaryColor.withValues(alpha: 0.2),
                    onSelected: (_) => setState(() => _filterType = type),
                  ),
                );
              }).toList(),
            ),
          ),

          // Users list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No users found',
                                style: TextStyle(fontSize: 18, color: Colors.grey)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchUsers,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final data = _filtered[index];
                            return _buildUserCard(
                                data['id']?.toString() ?? '', data);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(String userId, Map<String, dynamic> data) {
    final name        = data['name']       ?? 'Unknown';
    final email       = data['email']      ?? '';
    final phone       = data['phone']      ?? 'N/A';
    final type        = data['user_type']  ?? 'buyer';
    final savedCount  = (data['saved_properties'] as List?)?.length ?? 0;
    final createdAtStr = data['created_at'] as String?;
    final createdAt   =
        createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;

    Color typeColor;
    switch (type) {
      case 'admin':  typeColor = Colors.red;    break;
      case 'seller': typeColor = Colors.green;  break;
      case 'agent':  typeColor = Colors.orange; break;
      default:       typeColor = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: typeColor.withValues(alpha: 0.15),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'U',
            style: TextStyle(color: typeColor, fontWeight: FontWeight.bold),
          ),
        ),
        title:    Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(email, style: const TextStyle(fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color:        typeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(type.toUpperCase(),
              style: TextStyle(
                  color: typeColor, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: [
              _infoRow(Icons.email,         'Email',             email),
              _infoRow(Icons.phone,         'Phone',             phone),
              _infoRow(Icons.favorite,      'Saved Properties',  '$savedCount'),
              _infoRow(Icons.calendar_today, 'Joined',
                  createdAt != null
                      ? DateFormat('MMM dd, yyyy').format(createdAt)
                      : 'N/A'),
              _infoRow(Icons.fingerprint, 'User ID', userId),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Change Role: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['buyer', 'seller', 'agent'].map((newType) {
                        final isCurrent = type == newType;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ElevatedButton(
                            onPressed: isCurrent
                                ? null
                                : () => _changeUserType(userId, newType),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isCurrent ? Colors.grey : typeColor,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                                newType[0].toUpperCase() + newType.substring(1),
                                style: const TextStyle(fontSize: 12)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );

  // 🔐 Uses the server-side RPC instead of a direct UPDATE.
  //    The Postgres function verifies the caller is an admin before changing
  //    user_type. A regular user calling this will get a permission error.
  Future<void> _changeUserType(String userId, String newType) async {
    try {
      await _supabase.rpc('set_user_type', params: {
        'target_user_id': userId,
        'new_type':        newType,
      });

      // Update local list without re-fetch
      final idx =
          _users.indexWhere((u) => u['id']?.toString() == userId);
      if (idx != -1) {
        setState(() =>
            _users[idx] = {..._users[idx], 'user_type': newType});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('User role updated to ${newType.toUpperCase()}'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:         Text('Error: $e'),
            backgroundColor: Colors.red));
      }
    }
  }
}