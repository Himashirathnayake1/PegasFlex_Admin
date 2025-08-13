import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pegasflex_admin/screens/PaymenthistoryScreen.dart';
import 'package:pegasflex_admin/screens/collector_status_page.dart';
import 'package:pegasflex_admin/screens/feedback_list_screen.dart';
import 'package:pegasflex_admin/screens/form_submissions.dart';
import 'package:pegasflex_admin/screens/shop_details.dart';
import 'package:pegasflex_admin/screens/stock_list.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  double upcomingAmount = 0.0;
  double stockAmount = 0.0;
  double assignedAmount = 0.0;
  double totalPaidAcrossRoutes = 0;
  TextEditingController amountSentController = TextEditingController();
  final TextEditingController codeController = TextEditingController();
  double weekCollected = 0.0;
  double targetCollectAmount = 0;
  final currencyFormatter =
      NumberFormat.currency(locale: 'en_IN', symbol: 'LKR ');
  bool isTargetLoading = true;
  bool isWeekCollectLoading = false;
  DateTime selectedDate = DateTime.now();
  double totalPaidForSelectedDate = 0;
  bool isLoading = false;
  bool isSubmitting = false;

  void _changeDate(int offset) {
    setState(() {
      selectedDate = selectedDate.add(Duration(days: offset));
    });
    _fetchTotalPaidForDate();
  }

  @override
  void initState() {
    super.initState();
    _fetchTotalPaidAcrossAllRoutes();
    _fetchWeekCollected();
    _fetchTotalPaidForDate();
    _loadTargetCollectAmount();
    loadDashboardData();
  }

  void _showEditTargetDialog(
      BuildContext context, String current, Function(String) onSave) {
    final controller =
        TextEditingController(text: current.replaceAll(RegExp(r'[^\d.]'), ''));

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Target Amount"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Target Amount (LKR)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _loadTargetCollectAmount() async {
    final doc =
        await FirebaseFirestore.instance.collection('admin').doc('stats').get();
    if (doc.exists && doc.data()!.containsKey('targetWeek')) {
      setState(() {
        targetCollectAmount = (doc.data()!['targetWeek'] ?? 0).toDouble();
        isTargetLoading = false;
      });
    } else {
      setState(() {
        targetCollectAmount = 0;
        isTargetLoading = false;
      });
    }
  }

  Future<void> _saveTargetCollectAmount(double value) async {
    await FirebaseFirestore.instance
        .collection('admin')
        .doc('stats')
        .set({'targetWeek': value}, SetOptions(merge: true));
  }

  Future<void> _fetchTotalPaidForDate() async {
    setState(() {
      isLoading = true;
    });

    final Timestamp startOfDay = Timestamp.fromDate(DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      0,
      0,
      0,
    ));

    final Timestamp endOfDay = Timestamp.fromDate(DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      23,
      59,
      59,
    ));

    double total = 0;

    final routesSnapshot =
        await FirebaseFirestore.instance.collection('routes').get();

    for (var routeDoc in routesSnapshot.docs) {
      final shopsSnapshot = await routeDoc.reference.collection('shops').get();

      for (var shopDoc in shopsSnapshot.docs) {
        final transactionsSnapshot = await shopDoc.reference
            .collection('transactions')
            .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
            .where('timestamp', isLessThanOrEqualTo: endOfDay)
            .get();

        for (var txnDoc in transactionsSnapshot.docs) {
          final data = txnDoc.data();
          final type = data['type'];
          final amount = (data['amount'] ?? 0).toDouble();

          // Include if type is not 'credit' or type is missing
          if (type == null || type == 'paid' || type != 'Credit') {
            total += amount;
          }
        }
      }
    }

    setState(() {
      totalPaidForSelectedDate = total;
      isLoading = false;
    });
  }

  Future<void> _fetchWeekCollected() async {
    setState(() => isWeekCollectLoading = true);
    final now = DateTime.now();

    // Get Monday and Sunday of the current week
    final int currentWeekday = now.weekday; // Monday = 1, Sunday = 7
    final DateTime mondayThisWeek =
        now.subtract(Duration(days: currentWeekday - 1));
    final DateTime sundayThisWeek = mondayThisWeek.add(const Duration(days: 6));

    final Timestamp startOfWeek = Timestamp.fromDate(DateTime(
      mondayThisWeek.year,
      mondayThisWeek.month,
      mondayThisWeek.day,
      0,
      0,
      0,
    ));

    final Timestamp endOfWeek = Timestamp.fromDate(DateTime(
      sundayThisWeek.year,
      sundayThisWeek.month,
      sundayThisWeek.day,
      23,
      59,
      59,
    ));

    double total = 0;

    // Get all routes
    final routesSnapshot =
        await FirebaseFirestore.instance.collection('routes').get();

    for (var routeDoc in routesSnapshot.docs) {
      final shopsSnapshot = await routeDoc.reference.collection('shops').get();

      for (var shopDoc in shopsSnapshot.docs) {
        final transactionsSnapshot = await shopDoc.reference
            .collection('transactions')
            .where('timestamp', isGreaterThanOrEqualTo: startOfWeek)
            .where('timestamp', isLessThanOrEqualTo: endOfWeek)
            .get();

        for (var txnDoc in transactionsSnapshot.docs) {
          final data = txnDoc.data();
          final type = data['type'];
          final amount = (data['amount'] ?? 0).toDouble();

          // Include if type is not 'credit' or type is missing
          if (type == null || type == 'paid' || type != 'Credit') {
            total += amount;
          }
        }
      }
    }

    setState(() {
      weekCollected = total;
      isWeekCollectLoading = false;
    });
  }

  Future<void> _fetchTotalPaidAcrossAllRoutes() async {
    final summaryDoc = await FirebaseFirestore.instance
        .collection('admin')
        .doc('summary')
        .get();

    final totalPaid = (summaryDoc.data()?['latestTotalPaid'] ?? 0).toDouble();

    setState(() {
      totalPaidAcrossRoutes = totalPaid;
    });
  }

  Future<void> loadDashboardData() async {
    setState(() {
      isLoading = true;
    });

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
      assignedAmount =
          (savedAssigned - currentLatestPaid).clamp(0, double.infinity);
      isLoading = false;
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
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });

          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FeedbackListPage()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CollectorStatusPage()),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ReceiptsPage ()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.reviews),
            label: "Feedback",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.stay_current_landscape_outlined),
            label: "Status",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dynamic_form),
            label: "Submissions",
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text("Dashboard",
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: loadDashboardData,
                    ),
                  ],
                ),
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
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 135, 236, 187),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(255, 182, 204, 129)
                            .withOpacity(0.2),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_left, size: 28),
                            onPressed: () => _changeDate(-1),
                          ),
                          SizedBox(width: 8),
                          Text(
                            DateFormat('EEE, MMM d, yyyy').format(selectedDate),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.arrow_right, size: 28),
                            onPressed: () => _changeDate(1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      isLoading
                          ? AnimatedDots()
                          : Text(
                              'Total Paid: Rs.${totalPaidForSelectedDate.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildCombinedStatusCard(
                    isWeekCollectLoading: isWeekCollectLoading,
                    weekCollected: weekCollected,
                    targetAmount: targetCollectAmount,
                    isTargetLoading: isTargetLoading,
                    onTargetEdit: (val) {
                      final parsed = double.tryParse(val);
                      if (parsed != null) {
                        setState(() {
                          targetCollectAmount = parsed;
                        });
                        _saveTargetCollectAmount(parsed);
                      }
                    },
                    gradient: const LinearGradient(
                      colors: [
                        Color.fromARGB(255, 247, 204, 124),
                        Color.fromARGB(255, 235, 226, 145)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Row(
                  children: [
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatusCard(
                        title: "Assigned\n(recieved credit)",
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Collected Total Paid: Rs.${totalPaidAcrossRoutes.toStringAsFixed(2)}\n (still not recieved credit)",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountSentController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Amount Sent to Owner",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setState(() =>
                                    isSubmitting = true); // 2. Start loading

                                final amountText =
                                    amountSentController.text.trim();

                                if (amountText.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text("Please enter an amount.")),
                                  );
                                  setState(() => isSubmitting = false);
                                  return;
                                }

                                final amount = double.tryParse(amountText);
                                if (amount == null || amount <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            "Please enter a valid amount.")),
                                  );
                                  setState(() => isSubmitting = false);
                                  return;
                                }

                                try {
                                  await FirebaseFirestore.instance
                                      .collection('deductions')
                                      .add({
                                    'amount': amount,
                                    'sentAt': FieldValue.serverTimestamp(),
                                  });

                                  await FirebaseFirestore.instance
                                      .collection('admin')
                                      .doc('summary')
                                      .set({
                                    'lastSentAmount': amount,
                                    'sentAt': FieldValue.serverTimestamp(),
                                  }, SetOptions(merge: true));

                                  final routesSnapshot = await FirebaseFirestore
                                      .instance
                                      .collection('routes')
                                      .get();
                                  double remainingToDeduct = amount;
                                  const double epsilon = 0.01;

                                  for (var routeDoc in routesSnapshot.docs) {
                                    final shopsSnapshot = await routeDoc
                                        .reference
                                        .collection('shops')
                                        .get();

                                    for (var shopDoc in shopsSnapshot.docs) {
                                      final shopData = shopDoc.data();
                                      double shopPaid =
                                          (shopData['totalPaid'] ?? 0)
                                              .toDouble();

                                      if (shopPaid <= epsilon ||
                                          remainingToDeduct <= epsilon)
                                        continue;

                                      double deduction;
                                      if (remainingToDeduct >=
                                          shopPaid - epsilon) {
                                        deduction = shopPaid;
                                        remainingToDeduct -= deduction;

                                        await shopDoc.reference
                                            .collection('transactions')
                                            .add({
                                          'type': 'paid',
                                          'amount': deduction,
                                          'resetAt':
                                              FieldValue.serverTimestamp(),
                                        });

                                        await shopDoc.reference.update({
                                          'status': 'Unpaid',
                                          'totalPaid': 0,
                                        });
                                      } else {
                                        deduction = remainingToDeduct;
                                        remainingToDeduct = 0;

                                        await shopDoc.reference
                                            .collection('transactions')
                                            .add({
                                          'type': 'partialPaid',
                                          'amount': deduction,
                                          'resetAt':
                                              FieldValue.serverTimestamp(),
                                        });

                                        double updatedPaid =
                                            shopPaid - deduction;
                                        if (updatedPaid <= epsilon)
                                          updatedPaid = 0;

                                        await shopDoc.reference.update({
                                          'totalPaid': updatedPaid,
                                        });

                                        break;
                                      }
                                    }

                                    if (remainingToDeduct <= epsilon) break;
                                  }

                                  if (remainingToDeduct > epsilon) {
                                    print(
                                        "⚠️ Still remaining to deduct: $remainingToDeduct");
                                  }

                                  double updatedTotalPaid = 0;
                                  final updatedRoutesSnapshot =
                                      await FirebaseFirestore.instance
                                          .collection('routes')
                                          .get();

                                  for (var routeDoc
                                      in updatedRoutesSnapshot.docs) {
                                    final shopsSnapshot = await routeDoc
                                        .reference
                                        .collection('shops')
                                        .get();
                                    for (var shopDoc in shopsSnapshot.docs) {
                                      final shopData = shopDoc.data();
                                      updatedTotalPaid +=
                                          (shopData['totalPaid'] ?? 0)
                                              .toDouble();
                                    }
                                  }

                                  await FirebaseFirestore.instance
                                      .collection('admin')
                                      .doc('summary')
                                      .set({
                                    'latestTotalPaid': updatedTotalPaid,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  }, SetOptions(merge: true));

                                  await _fetchTotalPaidAcrossAllRoutes();
                                  amountSentController.clear();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            "Amount submitted and deducted successfully.")),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text("Error: ${e.toString()}")),
                                  );
                                } finally {
                                  setState(() =>
                                      isSubmitting = false); // 3. Stop loading
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 113, 182, 116),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Center(
                                child: const Text(
                                  "Submit Amount",
                                  style: TextStyle(color: Colors.black),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                AccessCodeSetter(),
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
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
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
                : Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),

            /// 👇 Show TextButton only for "Stocks Amount"
            if (title == "Stocks Amount") ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StockListScreen(),
                    ),
                  );
                },
                child: const Text("More Details"),
              ),
            ],
          ],
        ),
      ),
    );
  }

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

  Widget _buildCombinedStatusCard({
    required bool isWeekCollectLoading,
    required double weekCollected,
    required double targetAmount,
    required Function(String) onTargetEdit,
    required bool isTargetLoading,
    required LinearGradient gradient,
  }) {
    final TextEditingController _controller =
        TextEditingController(text: targetAmount.toStringAsFixed(0));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.date_range, size: 28, color: Colors.deepOrange),
              const SizedBox(width: 10),
              const Text('This Week Summary',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 161, 95, 41))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Week Collected
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Week Collected',
                      style: TextStyle(
                          fontSize: 13,
                          color: Color.fromARGB(255, 116, 66, 24))),
                  const SizedBox(height: 4),
                  isWeekCollectLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'LKR ${weekCollected.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ],
              ),

              // Target Collect
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Target Collect',
                    style: TextStyle(
                        fontSize: 13, color: Color.fromARGB(255, 116, 66, 24)),
                  ),
                  const SizedBox(height: 4),
                  isTargetLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          children: [
                            Text(
                              'LKR ${targetAmount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("Edit Target"),
                                    content: TextField(
                                      controller: _controller,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: const InputDecoration(
                                          labelText: "Enter target amount"),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text("Cancel"),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          onTargetEdit(_controller.text);
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text("Save"),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }
}

class AnimatedDots extends StatefulWidget {
  @override
  _AnimatedDotsState createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<AnimatedDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _dotCount;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: Duration(milliseconds: 900))
          ..repeat();
    _dotCount = StepTween(begin: 1, end: 3).animate(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dotCount,
      builder: (context, child) {
        String dots = '.' * _dotCount.value;
        return Text(
          'Loading$dots',
          style: TextStyle(
            fontSize: 18,
            color: Colors.blueGrey,
            fontWeight: FontWeight.w500,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class AccessCodeSetter extends StatefulWidget {
  @override
  _AccessCodeSetterState createState() => _AccessCodeSetterState();
}

class _AccessCodeSetterState extends State<AccessCodeSetter> {
  final TextEditingController _codeController = TextEditingController();
  bool _isSaving = false;
  String? _message;

  Future<void> _saveCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() => _message = "Please enter a code.");
      return;
    }

    setState(() {
      _isSaving = true;
      _message = null;
    });

    await FirebaseFirestore.instance.collection('admin').doc('config').set(
      {'accessCode': code},
      SetOptions(merge: true),
    );

    setState(() {
      _isSaving = false;
      _message = "Access code updated successfully.";
    });

    _codeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Set Access Code",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: "Access Code",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveCode,
              child: Text(_isSaving ? "Saving..." : "Save Code"),
            ),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(_message!, style: TextStyle(color: Colors.green)),
            ]
          ],
        ),
      ),
    );
  }
}
