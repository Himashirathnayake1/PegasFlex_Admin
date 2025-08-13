import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class ReceiptsPage extends StatefulWidget {
  const ReceiptsPage({Key? key}) : super(key: key);

  @override
  State<ReceiptsPage> createState() => _ReceiptsPageState();
}

class _ReceiptsPageState extends State<ReceiptsPage> {
  List<Map<String, dynamic>> receiptData = [];
  bool isLoading = true;

  final String apiUrl = "https://api.sheetbest.com/sheets/24fafa2a-274f-4235-9e58-fd27f66e79ce"; // Replace with your API URL

  @override
  void initState() {
    super.initState();
    _fetchReceipts();
  }

  Future<void> _fetchReceipts() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          receiptData = data.map((e) => Map<String, dynamic>.from(e)).toList();
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load receipts");
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching receipts: $e")),
      );
    }
  }

  Future<void> _openReceipt(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open receipt link")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Submitted Receipts"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReceipts,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : receiptData.isEmpty
              ? const Center(child: Text("No receipts found"))
              : ListView.builder(
                  itemCount: receiptData.length,
                  itemBuilder: (context, index) {
                    final item = receiptData[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long, color: Colors.green, size: 30),
                        title: Text(
                          "Amount Sent: Rs. ${item['Amount Sent'] ?? 'N/A'}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("Time: ${item['Time'] ?? 'N/A'}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.open_in_new, color: Colors.blue),
                          onPressed: () => _openReceipt(item['Upload Receipt']),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
