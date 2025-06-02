import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pegasflex_admin/screens/PaymenthistoryScreen.dart';
import 'package:pegasflex_admin/screens/shop_details.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  double upcomingAmount = 0.0;
  double stockAmount = 0.0;
  double remainingAmount = 0.0;
  double assignedAmount = 0.0;
  
  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }
   Future<void> _fetchTotalPaidAcrossAllRoutes() async {
    double totalPaid = 0;

    final routesSnapshot =
        await FirebaseFirestore.instance.collection('routes').get();

    for (var routeDoc in routesSnapshot.docs) {
      final shopsSnapshot = await routeDoc.reference.collection('shops').get();

      for (var shopDoc in shopsSnapshot.docs) {
        final shopData = shopDoc.data();
        final shopTotalPaid = shopData['totalPaid'];

        if (shopTotalPaid != null) {
          totalPaid += (shopTotalPaid as num).toDouble();
        }
      }
    }
    // ✅ Save totalPaid to Firestore (admin/summary)
    await FirebaseFirestore.instance.collection('admin').doc('summary').set({
      'latestTotalPaid': totalPaid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // ✅ Update local state
    setState(() {
      totalPaidAcrossRoutes = totalPaid;
    });
  }

  void openGoogleForm() async {
    final amountText = amountSentController.text.trim();

    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the amount sent")),
      );
      return;
    }

    final double? amountSent = double.tryParse(amountText);
    if (amountSent == null || amountSent <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid amount")),
      );
      return;
    }

    // ✅ Save the deduction entry for history
    await FirebaseFirestore.instance.collection('deductions').add({
      'amount': amountSent,
      'sentAt': FieldValue.serverTimestamp(),
    });

    // ✅ Save summary
    await FirebaseFirestore.instance.collection('admin').doc('summary').set({
      'lastSentAmount': amountSent,
      'sentAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // ✅ Reset all shops with status == 'Paid'
    final routesSnapshot =
        await FirebaseFirestore.instance.collection('routes').get();

    for (var routeDoc in routesSnapshot.docs) {
      final shopsSnapshot = await routeDoc.reference.collection('shops').get();

      for (var shopDoc in shopsSnapshot.docs) {
        final shopData = shopDoc.data();
        if (shopData['status'] == 'Paid') {
          await shopDoc.reference.update({
            'status': 'Unpaid',
            'totalPaid': 0,
          });
        }
      }
    }

    // ✅ Reset total paid locally
    setState(() {
      totalPaidAcrossRoutes = 0;
    });
  }


  Future<void> loadDashboardData() async {
    final shopsSnapshot =
        await FirebaseFirestore.instance.collectionGroup('shops').get();

    double totalUpcoming = 0;
    for (var doc in shopsSnapshot.docs) {
      totalUpcoming += (doc.data()['amount'] ?? 0).toDouble();
    }

    final statsRef =
        FirebaseFirestore.instance.collection('admin').doc('stats');
    final summaryRef =
        FirebaseFirestore.instance.collection('admin').doc('summary');
    final historyRef = summaryRef.collection('paidHistory');

    final statsDoc = await statsRef.get();
    final summaryDoc = await summaryRef.get();

    final double currentLatestPaid =
        (summaryDoc.data()?['latestTotalPaid'] ?? 0).toDouble();
    double savedAssigned =
        (statsDoc.data()?['assignedTotalPaid'] ?? 0).toDouble();
    double lastSavedPaid =
        (statsDoc.data()?['lastSavedLatestPaid'] ?? 0).toDouble();

    if (currentLatestPaid > lastSavedPaid) {
      double diff = currentLatestPaid - lastSavedPaid;

      // 1. Add the increase to assigned
      savedAssigned += diff;

      // 2. Save this increase to paidHistory
      await historyRef.add({
        'value': currentLatestPaid,
        'increment': diff,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 3. Update stats document
      await statsRef.set({
        'assignedTotalPaid': savedAssigned,
        'lastSavedLatestPaid': currentLatestPaid,
      }, SetOptions(merge: true));
    } else if (currentLatestPaid < lastSavedPaid) {
      // Only update tracker (do NOT update assigned or history)
      await statsRef.set({
        'lastSavedLatestPaid': currentLatestPaid,
      }, SetOptions(merge: true));
    }

    setState(() {
      upcomingAmount = totalUpcoming;
      stockAmount = (statsDoc.data()?['stockAmount'] ?? 0).toDouble();
      remainingAmount = currentLatestPaid;
      assignedAmount = savedAssigned;
    });
  }

  void saveStockAmount(String value) async {
    double parsedValue = double.tryParse(value) ?? 0;
    setState(() {
      stockAmount = parsedValue;
    });

    await FirebaseFirestore.instance.collection('admin').doc('stats').set(
      {'stockAmount': parsedValue},
      SetOptions(merge: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter =
        NumberFormat.currency(locale: 'en', symbol: 'LKR ', decimalDigits: 2);
    final today = DateFormat('dd:MM:yyyy').format(DateTime.now());

    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: "Dashboard"),
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline), label: "Chat"),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications_none), label: "Notifications"),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Dashboard",
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildInfoCard(
                      title: "Upcoming Amount\n(all balance)",
                      value: currencyFormatter.format(upcomingAmount),
                      gradient: const LinearGradient(
                          colors: [Colors.greenAccent, Colors.white]),
                    ),
                    const SizedBox(width: 12),
                    _buildInfoCard(
                      title: "Stocks Amount",
                      value: currencyFormatter.format(stockAmount),
                      gradient: const LinearGradient(
                          colors: [Colors.blueAccent, Colors.white]),
                      isEditable: true,
                      onEdit: (val) {
                        saveStockAmount(val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  "Total Asset : ${currencyFormatter.format(upcomingAmount + stockAmount)}",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: _containerBox(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Date", style: TextStyle(fontSize: 16)),
                      Text(today,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusCard(
                        title: "Remaining\n(Latest totalPaid)",
                        amount: currencyFormatter.format(remainingAmount),
                        icon: Icons.account_balance_wallet_outlined,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatusCard(
                        title: "Assigned\n(all totalPaid)",
                        amount: currencyFormatter.format(assignedAmount),
                        icon: Icons.assignment_turned_in_outlined,
                        color: Colors.blueGrey,
                        trailing: IconButton(
                          icon: const Icon(Icons.history,
                              size: 20, color: Colors.blueGrey),
                          tooltip: "View History",
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const PaymentHistoryScreen(),
                              ),
                            );
                          },
                        ),
                        helperText: "Click here to see history",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: const Center(
                    child: Text(
                      "LKR 20,000.00",
                      style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ShopDetailsScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _containerBox(),
                    child: Row(
                      children: const [
                        CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Icon(Icons.store, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Text(
                          "Shop Details",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue,
                          ),
                        ),
                        Spacer(),
                        Icon(Icons.arrow_forward_ios, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _containerBox() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.grey.shade200,
          blurRadius: 10,
          spreadRadius: 2,
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required Gradient gradient,
    bool isEditable = false,
    void Function(String)? onEdit,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 6,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54)),
            const SizedBox(height: 8),
            isEditable
                ? TextField(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    controller: TextEditingController(
                        text: value.replaceAll("LKR ", "")),
                    onSubmitted: onEdit,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  )
                : Text(value,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
          ],
        ),
      ),
    );
  }

  // ...existing code...
  Widget _buildStatusCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
    Widget? trailing,
    String? helperText, // <-- Add this line
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _containerBox(),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 6),
              Text(amount,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              if (helperText != null) ...[
                const SizedBox(height: 4),
                Text(
                  helperText,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.blueGrey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
          if (trailing != null)
            Positioned(
              top: 94,
              right: -15,
              child: trailing,
            ),
        ],
      ),
    );
  }
}
