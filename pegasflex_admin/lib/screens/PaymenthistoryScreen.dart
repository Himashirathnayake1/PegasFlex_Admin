import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({Key? key}) : super(key: key);

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  List<Map<String, dynamic>> collected = [];
  List<Map<String, dynamic>> received = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchHistoryData();
  }

  Future<void> fetchHistoryData() async {
    try {
      setState(() {
        isLoading = true;
      });

      final paidHistorySnap = await FirebaseFirestore.instance
          .collection('admin')
          .doc('summary')
          .collection('paidHistory')
          .orderBy('timestamp', descending: true)
          .get();

      final deductionsSnap = await FirebaseFirestore.instance
          .collection('deductions')
          .orderBy('sentAt', descending: true)
          .get();

      setState(() {
        collected = paidHistorySnap.docs
            .map((doc) => {
                  'amount': doc['increment'],
                  'timestamp': doc['timestamp'],
                })
            .toList();

        received = deductionsSnap.docs
            .map((doc) => {
                  'amount': doc['amount'],
                  'timestamp': doc['sentAt'],
                })
            .toList();

        isLoading = false;
      });
    } catch (e) {
      print("Error fetching payment history: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  String formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('yyyy-MM-dd – kk:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchHistoryData,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchHistoryData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text("Collected",
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (collected.isEmpty)
                    const Text("No collected records."),
                  ...collected.map((item) => ListTile(
                        leading: const Icon(Icons.arrow_upward,
                            color: Colors.green),
                        title: Text("LKR ${item['amount']}"),
                        subtitle: Text(formatTimestamp(item['timestamp'])),
                      )),
                  const SizedBox(height: 24),
                  const Text("Received",
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (received.isEmpty)
                    const Text("No received records."),
                  ...received.map((item) => ListTile(
                        leading: const Icon(Icons.arrow_downward,
                            color: Colors.red),
                        title: Text("LKR ${item['amount']}"),
                        subtitle: Text(formatTimestamp(item['timestamp'])),
                      )),
                ],
              ),
            ),
    );
  }
}
