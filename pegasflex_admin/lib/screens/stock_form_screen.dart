import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class StockFormScreen extends StatefulWidget {
  final String? stockId;
  final Map<String, dynamic>? existingData;

  const StockFormScreen({Key? key, this.stockId, this.existingData, required Map initialData})
      : super(key: key);

  @override
  State<StockFormScreen> createState() => _StockFormScreenState();
}

class _StockFormScreenState extends State<StockFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _discountedPriceController = TextEditingController();
  final _lastLowerPriceController = TextEditingController();
  bool _isAvailable = true;
  File? _imageFile;
  String? _imageUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      _nameController.text = widget.existingData!['name'] ?? '';
      _originalPriceController.text =
          widget.existingData!['originalPrice']?.toString() ?? '';
      _discountedPriceController.text =
          widget.existingData!['discountedPrice']?.toString() ?? '';
      _lastLowerPriceController.text =
          widget.existingData!['lastLowerPrice']?.toString() ?? '';
      _isAvailable = widget.existingData!['isAvailable'] ?? true;
      _imageUrl = widget.existingData!['imageUrl'];
    }
  }

Future<String?> uploadToImgur(File imageFile) async {
  const clientId = 'e985f439dbcdd42'; // Replace this with your Imgur Client ID
  final bytes = await imageFile.readAsBytes();
  final base64Image = base64Encode(bytes);

  final response = await http.post(
    Uri.parse('https://api.imgur.com/3/image'),
    headers: {
      'Authorization': 'Client-ID $clientId',
    },
    body: {
      'image': base64Image,
    },
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['data']['link'];
  } else {
    debugPrint('Imgur upload failed: ${response.body}');
    return null;
  }
}

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _imageUrl;
    final fileName = 'stocks/${DateTime.now().millisecondsSinceEpoch}.jpg';
    return await uploadToImgur(_imageFile!);

  }

  Future<void> _saveStock() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUploading = true;
    });

    final imageUrl = await _uploadImage();

    final stockData = {
      'name': _nameController.text.trim(),
      'originalPrice': double.tryParse(_originalPriceController.text.trim()) ?? 0,
      'discountedPrice': double.tryParse(_discountedPriceController.text.trim()) ?? 0,
      'lastLowerPrice': double.tryParse(_lastLowerPriceController.text.trim()) ?? 0,
      'isAvailable': _isAvailable,
      'imageUrl': imageUrl,
    };

    final docRef = FirebaseFirestore.instance.collection('stocks');
    if (widget.stockId != null) {
      await docRef.doc(widget.stockId).update(stockData);
    } else {
      await docRef.add(stockData);
    }

    setState(() {
      _isUploading = false;
    });

    if (context.mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _originalPriceController.dispose();
    _discountedPriceController.dispose();
    _lastLowerPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.stockId != null ? "Edit Stock" : "Add New Stock"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isUploading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Item Name'),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _originalPriceController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Original Price'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _discountedPriceController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Discounted Price'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _lastLowerPriceController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Last Lower Price'),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Available'),
                      value: _isAvailable,
                      onChanged: (val) => setState(() {
                        _isAvailable = val;
                      }),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image),
                      label: const Text("Pick Image (optional)"),
                    ),
                    if (_imageFile != null || _imageUrl != null) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: Image.file(
                          _imageFile ?? File(''),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            if (_imageUrl != null) {
                              return Image.network(
                                _imageUrl!,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveStock,
                      child: Text(widget.stockId != null ? 'Update Stock' : 'Add Stock'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
