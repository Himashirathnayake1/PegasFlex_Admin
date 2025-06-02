import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ShopDetailPage extends StatefulWidget {
  final DocumentReference shopRef;
  const ShopDetailPage({required this.shopRef, super.key});

  @override
  State<ShopDetailPage> createState() => _ShopDetailPageState();
}

class _ShopDetailPageState extends State<ShopDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final currencyFormatter =
      NumberFormat.currency(locale: 'en', symbol: 'LKR ', decimalDigits: 2);

  late TextEditingController _nameController;
  late TextEditingController _balanceController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;

  String addStatus = 'Not Added';
  String payStatus = 'Unpaid';

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _balanceController = TextEditingController();
    _loadShopData();
  }

  Future<void> _loadShopData() async {
    final doc = await widget.shopRef.get();
    final data = doc.data() as Map<String, dynamic>?;

    if (data != null) {
      setState(() {
        _nameController.text = data['name'] ?? '';
        _balanceController.text = (data['totalAdded'] ?? 0).toString();
        addStatus = data['addStatus'] ?? 'Not Added';
        payStatus = data['status'] ?? 'Unpaid';
        _latitudeController =
            TextEditingController(text: data['latitude']?.toString() ?? '');
        _longitudeController =  
            TextEditingController(text: data['longitude']?.toString() ?? '');
        _addressController =
            TextEditingController(text: data['address'] ?? '');
        _phoneController =
            TextEditingController(text: data['phone'] ?? '');
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop data not found!')),
      );
    }
  }

  Future<void> _saveShopData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final balance = double.tryParse(_balanceController.text) ?? 0;

      await widget.shopRef.update({
        'name': _nameController.text,
        'totalAdded': balance,
        'addStatus': addStatus,
        'status': payStatus,
        'latitude': double.tryParse(_latitudeController.text),
        'longitude': double.tryParse(_longitudeController.text),
        'address': _addressController.text,
        'phone': _phoneController.text,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop info updated')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _updateBalance(double change) async {
    setState(() => _saving = true);
    try {
      final doc = await widget.shopRef.get();
      final data = doc.data() as Map<String, dynamic>?;

      double currentBalance = data?['totalAdded']?.toDouble() ?? 0;
      double newBalance = currentBalance + change;

      // Update balance and status accordingly
      await widget.shopRef.update({
        'totalAdded': newBalance,
        // Optionally update addStatus based on balance
        'addStatus': newBalance > 0 ? 'Added' : 'Not Added',
        // Keep payStatus unchanged or add logic here if needed
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Balance updated by ${currencyFormatter.format(change)}')),
      );
      _loadShopData(); // Reload data after update
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update balance: $e')),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shop Detail')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration:
                                const InputDecoration(labelText: 'Shop Name'),
                            validator: (val) => val == null || val.isEmpty
                                ? 'Name required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _balanceController,
                            decoration:
                                const InputDecoration(labelText: 'Total Added'),
                            keyboardType: TextInputType.number,
                            validator: (val) {
                              if (val == null || val.isEmpty)
                                return 'Enter a number';
                              if (double.tryParse(val) == null)
                                return 'Invalid number';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Dropdown for Add Status
                          DropdownButtonFormField<String>(
                            value: addStatus,
                            decoration:
                                const InputDecoration(labelText: 'Add Status'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'Added', child: Text('Added')),
                              DropdownMenuItem(
                                  value: 'Not Added', child: Text('Not Added')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => addStatus = val);
                            },
                          ),

                          const SizedBox(height: 12),

                          // Dropdown for Pay Status
                          DropdownButtonFormField<String>(
                            value: payStatus,
                            decoration: const InputDecoration(
                                labelText: 'Payment Status'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'Paid', child: Text('Paid')),
                              DropdownMenuItem(
                                  value: 'Unpaid', child: Text('Unpaid')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => payStatus = val);
                            },
                          ),

                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _latitudeController,
                            decoration:
                                const InputDecoration(labelText: 'Latitude'),
                            keyboardType: TextInputType.number,
                            validator: (val) {
                              if (val == null || val.isEmpty)
                                return 'Enter a number';
                              if (double.tryParse(val) == null)
                                return 'Invalid number';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _longitudeController,
                            decoration:
                                const InputDecoration(labelText: 'Longitude'),
                            keyboardType: TextInputType.number,
                            validator: (val) {
                              if (val == null || val.isEmpty)
                                return 'Enter a number';
                              if (double.tryParse(val) == null)
                                return 'Invalid number';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _addressController,
                            decoration:
                                const InputDecoration(labelText: 'Address'),
                            validator: (val) => val == null || val.isEmpty
                                ? 'Address required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            decoration:
                                const InputDecoration(labelText: 'Phone'),
                            keyboardType: TextInputType.phone,
                            validator: (val) => val == null || val.isEmpty
                                ? 'Phone number required'
                                : null,
                          ),
                          const SizedBox(height: 20),

                          _saving
                              ? const CircularProgressIndicator()
                              : ElevatedButton(
                                  onPressed: _saveShopData,
                                  child: const Text('Save Changes'),
                                ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Balance quick adjust buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ElevatedButton(
                          onPressed: _saving ? null : () => _updateBalance(100),
                          child: const Text('+100'),
                        ),
                        ElevatedButton(
                          onPressed:
                              _saving ? null : () => _updateBalance(-100),
                          child: const Text('-100'),
                        ),
                        ElevatedButton(
                          onPressed: _saving ? null : () => _updateBalance(500),
                          child: const Text('+500'),
                        ),
                      ],
                    ),
// After your existing UI parts (like the form and balance adjust buttons),
// add these two sections:

// 1. Cash Additions List
                    const SizedBox(height: 40),
                    const Text('Cash Additions History',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot>(
                      stream: widget.shopRef
                          .collection('cashAdditions')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Text('No cash additions found.');
                        }

                        final docs = snapshot.data!.docs;

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data()! as Map<String, dynamic>;
                            final amount = data['amount'] ?? 0;
                            final createdAt =
                                (data['timestamp'] as Timestamp?)?.toDate();

                            return ListTile(
                              leading: const Icon(Icons.add_circle,
                                  color: Colors.green),
                              title: Text(currencyFormatter.format(amount)),
                              subtitle: Text(createdAt != null
                                  ? DateFormat.yMd().add_jm().format(createdAt)
                                  : ''),
                            );
                          },
                        );
                      },
                    ),

// 2. Transactions List
                    const SizedBox(height: 40),
                    const Text('Transactions History',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot>(
                      stream: widget.shopRef
                          .collection('transactions')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Text('No transactions found.');
                        }
                        print('ShopRef path: ${widget.shopRef.path}');

                        final docs = snapshot.data!.docs;

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data()! as Map<String, dynamic>;
                            final amount = data['amount'] ?? 0;
                            final type = data['type'] ??
                                'debit'; // or your field to distinguish type
                            final createdAt =
                                (data['timestampt'] as Timestamp?)?.toDate();

                            return ListTile(
                              leading: Icon(
                                  type == 'debit'
                                      ? Icons.remove_circle
                                      : Icons.add_circle,
                                  color: type == 'debit'
                                      ? Colors.red
                                      : Colors.green),
                              title: Text(currencyFormatter.format(amount)),
                              subtitle: Text(createdAt != null
                                  ? DateFormat.yMd().add_jm().format(createdAt)
                                  : ''),
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }
}
