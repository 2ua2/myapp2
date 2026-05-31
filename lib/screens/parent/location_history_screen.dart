import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/location_model.dart';

class LocationHistoryScreen extends StatefulWidget {
  final String childName;

  const LocationHistoryScreen({
    super.key,
    this.childName = 'name',
  });

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen> {
  bool _isLoading = true;
  String? _childId;
  List<LocationModel> _locationHistory = [];
  // Parallel list of Firestore doc IDs for each entry in _locationHistory.
  // Used for deletes instead of item.locationId, which may be '' if the
  // doc was written without a locationId field.
  List<String> _locationDocIds = [];

  @override
  void initState() {
    super.initState();
    _loadLocationHistory();
  }

  Future<void> _loadLocationHistory() async {
    try {
      final familyId =
          context.read<AuthProvider>().currentUser?.familyId;
      if (familyId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // TODO: move to ChildService later
      final childSnapshot = await FirebaseFirestore.instance
          .collection('families')
          .doc(familyId)
          .collection('children')
          .where('status', isEqualTo: 'linked')
          .limit(1)
          .get();

      if (childSnapshot.docs.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      _childId = childSnapshot.docs.first.id;

      final historySnapshot = await FirebaseFirestore.instance
          .collection('locations')
          .doc(_childId)
          .collection('history')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      final docIds = historySnapshot.docs.map((doc) => doc.id).toList();
      final results = historySnapshot.docs
          .map((doc) => LocationModel.fromMap(doc.data()))
          .toList();
      print('[LOC-HISTORY] loaded ${results.length} entries for childId=$_childId');

      if (!mounted) return;
      setState(() {
        _locationHistory = results;
        _locationDocIds = docIds;
        _isLoading = false;
      });
    } catch (e) {
      print('[LOC-HISTORY] error loading history: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _clearHistory() {
    if (_locationHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No history to clear'),
          backgroundColor: Color(0xFF757575),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      // Use 'dialogContext' so the outer 'context' (screen) is not shadowed and
      // remains accessible for ScaffoldMessenger after the dialog is dismissed.
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
            'Are you sure you want to clear all location history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                // TODO: move to LocationService later
                // Use _locationDocIds (Firestore doc IDs) rather than
                // item.locationId, which may be '' for docs written
                // without an explicit locationId field.
                for (int i = 0; i < _locationDocIds.length; i++) {
                  await FirebaseFirestore.instance
                      .collection('locations')
                      .doc(_childId)
                      .collection('history')
                      .doc(_locationDocIds[i])
                      .delete();
                  if (!mounted) return;
                }
                print('[LOC-HISTORY] deleted ${_locationDocIds.length} docs for childId=$_childId');
              } catch (e) {
                print('[LOC-HISTORY] error deleting history: $e');
              }
              if (!mounted) return;
              setState(() {
                _locationHistory = [];
                _locationDocIds = [];
              });
              // 'context' here is the screen's context, not the dismissed dialog's context.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Location history cleared'),
                  backgroundColor: Color(0xFF4CAF50),
                ),
              );
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Color(0xFFF44336)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF212121)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Location History',
          style: TextStyle(
            color: Color(0xFF212121),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Color(0xFFF44336),
              size: 24,
            ),
            onPressed: _clearHistory,
            tooltip: 'Clear history',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _locationHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No recent location',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _locationHistory.length,
                  itemBuilder: (context, index) {
                    final item = _locationHistory[index];
                    final coords =
                        '${item.latitude}, ${item.longitude}';
                    final label = 'Location ${index + 1}';
                    final time = DateFormat('MMM d, y  h:mm a')
                        .format(item.timestamp);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xFF2196F3),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF212121),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  coords,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF757575),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
