import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FeedbackListPage extends StatefulWidget {
  const FeedbackListPage({super.key});

  @override
  State<FeedbackListPage> createState() => _FeedbackListPageState();
}

class _FeedbackListPageState extends State<FeedbackListPage> {
  DateTime? selectedDate;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('feedbacks');

    if (selectedDate != null) {
      DateTime start = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);
      DateTime end = start.add(const Duration(days: 1));
      query = query
          .where('submittedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('submittedAt', isLessThan: Timestamp.fromDate(end));
    }

    query = query.orderBy('submittedAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Feedback List"),
         backgroundColor: Colors.greenAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No feedback found"));
          }

          final feedbacks = snapshot.data!.docs;

          return ListView.builder(
            itemCount: feedbacks.length,
            itemBuilder: (context, index) {
              var fb = feedbacks[index];
              var data = fb.data() as Map<String, dynamic>;
              var submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: Icon(Icons.feedback, color: Colors.green.shade800),
                  title: Text("${data['shopName']} (${data['routeName']})"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Reason: ${data['reason']}"),
                      if (data['note'] != null && data['note'].toString().isNotEmpty)
                        Text("Note: ${data['note']}"),
                      if (submittedAt != null)
                        Text("Submitted: ${DateFormat('yyyy-MM-dd hh:mm a').format(submittedAt)}"),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
