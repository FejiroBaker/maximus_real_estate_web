// lib/screens/favorites_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import '../models/property_model.dart';
import '../widgets/property_card.dart';
import 'property_details_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  Future<List<PropertyModel>> _fetchFavorites(
      List<String> savedIds) async {
    if (savedIds.isEmpty) return [];
    final data = await Supabase.instance.client
        .from('properties')
        .select()
        .inFilter('id', savedIds);
    return (data as List)
        .map((row) =>
            PropertyModel.fromSupabaseJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final savedPropertyIds =
        authProvider.currentUser?.savedProperties ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        elevation: 0,
      ),
      body: savedPropertyIds.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_outline,
                      size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('No favorites yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('Start adding properties to your favorites',
                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            )
          : FutureBuilder<List<PropertyModel>>(
              future: _fetchFavorites(savedPropertyIds),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text('No saved properties found'));
                }
                final properties = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: properties.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: PropertyCard(
                      property: properties[index],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PropertyDetailsScreen(
                              property: properties[index]),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
