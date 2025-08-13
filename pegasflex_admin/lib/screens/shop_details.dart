import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pegasflex_admin/screens/shopdetal%5Bage2.dart';

class ShopDetailsScreen extends StatefulWidget {
  const ShopDetailsScreen({super.key});

  @override
  State<ShopDetailsScreen> createState() => _ShopDetailsScreenState();
}
// ... keep your previous imports and class declarations ...

class _ShopDetailsScreenState extends State<ShopDetailsScreen> {
  final _db = FirebaseFirestore.instance;
  final currencyFormatter =
      NumberFormat.currency(locale: 'en', symbol: 'LKR ', decimalDigits: 2);

  String selectedRoute = 'All';
  String selectedAddStatus = 'All'; // Added / Not Added / All
  String selectedPayStatus = 'All'; // Paid / Unpaid / All

  List<String> availableRoutes = [];
  List<Map<String, dynamic>> allShops = [];

  @override
  void initState() {
    super.initState();
    _loadAllShops();
  }

  Future<void> _loadAllShops() async {
    final routeSnapshots = await _db.collection('routes').get();
    List<Map<String, dynamic>> loadedShops = [];

    for (var routeDoc in routeSnapshots.docs) {
      final shopsSnapshot = await routeDoc.reference.collection('shops').get();
      for (var shopDoc in shopsSnapshot.docs) {
        final shopData = shopDoc.data();
        shopData['shopId'] = shopDoc.id;
        shopData['routeId'] = routeDoc.id;
        loadedShops.add(shopData);
      }
    }

    setState(() {
      allShops = loadedShops;
      availableRoutes = [
        'All',
        ...{...loadedShops.map((s) => s['routeId'] as String)}
      ];
    });
  }

  List<Map<String, dynamic>> _applyFilters() {
    return allShops.where((shop) {
      final matchesRoute =
          selectedRoute == 'All' || shop['routeId'] == selectedRoute;
      final addStatus = (shop['addStatus'] ?? 'Not Added');
      final payStatus = (shop['status'] ?? 'Unpaid');
      final matchesAddStatus =
          selectedAddStatus == 'All' || addStatus == selectedAddStatus;
      final matchesPayStatus =
          selectedPayStatus == 'All' || payStatus == selectedPayStatus;
      return matchesRoute && matchesAddStatus && matchesPayStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredShops = _applyFilters();

    return Scaffold(
      appBar: AppBar(title: const Text("Shop Details"),backgroundColor: Colors.greenAccent
      ,),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: filteredShops.isEmpty
                ? const Center(child: Text("Loading...."))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredShops.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final shop = filteredShops[index];
                      final lastCredit =
                          (shop['lastCreditAt'] as Timestamp?)?.toDate();
                      final timeAgo =
                          lastCredit != null ? timeSince(lastCredit) : 'Never';

                      return GestureDetector(
                        onTap: () {
                          final shopRef = _db
                              .collection('routes')
                              .doc(shop['routeId'])
                              .collection('shops')
                              .doc(shop['shopId']);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ShopDetailPage(shopRef: shopRef),
                            ),
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade200,
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shop['name'] ?? 'Unnamed Shop',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    "Route: ${shop['routeId']}",
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  Chip(
                                    label: Text(shop['addStatus'] ?? 'Unknown'),
                                    backgroundColor:
                                        (shop['addStatus'] == 'Added')
                                            ? Colors.green.shade100
                                            : Colors.red.shade100,
                                  ),
                                  Chip(
                                    label: Text(shop['status'] ?? 'Unknown'),
                                    backgroundColor: (shop['status'] == 'Paid')
                                        ? Colors.blue.shade100
                                        : Colors.orange.shade100,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Total Added: ${currencyFormatter.format(shop['totalAdded'] ?? 0)}",
                                style: const TextStyle(fontSize: 14),
                              ),
                              Text(
                                "Last Credit: $timeAgo",
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text("Route:"),
              DropdownButton<String>(
                value: selectedRoute,
                items: availableRoutes
                    .map((route) =>
                        DropdownMenuItem(value: route, child: Text(route)))
                    .toList(),
                onChanged: (val) => setState(() => selectedRoute = val!),
              ),
              const Text("Add Status:"),
              DropdownButton<String>(
                value: selectedAddStatus,
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All')),
                  DropdownMenuItem(value: 'Added', child: Text('Added')),
                  DropdownMenuItem(
                      value: 'Not Added', child: Text('Not Added')),
                ],
                onChanged: (val) => setState(() => selectedAddStatus = val!),
              ),
              const Text("Pay Status:"),
              DropdownButton<String>(
                value: selectedPayStatus,
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All')),
                  DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'Unpaid', child: Text('Unpaid')),
                ],
                onChanged: (val) => setState(() => selectedPayStatus = val!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String timeSince(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays >= 1) return "${diff.inDays} day(s) ago";
    if (diff.inHours >= 1) return "${diff.inHours} hour(s) ago";
    if (diff.inMinutes >= 1) return "${diff.inMinutes} min ago";
    return "Just now";
  }
}
