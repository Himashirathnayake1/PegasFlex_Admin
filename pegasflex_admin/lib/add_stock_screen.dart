// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:pegasflex_admin/screens/stock_list.dart';
// import 'package:uuid/uuid.dart';

// class AddStockPage extends StatefulWidget {
//   const AddStockPage({Key? key}) : super(key: key);

//   @override
//   State<AddStockPage> createState() => _AddStockPageState();
// }

// class _AddStockPageState extends State<AddStockPage> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController nameController = TextEditingController();
//   final TextEditingController originalPriceController = TextEditingController();
//   final TextEditingController discountedPriceController = TextEditingController();
//   final TextEditingController lastLowerPriceController = TextEditingController();
//   bool isAvailable = true;
//   File? _image;
//   bool isUploading = false;

//   Future<void> pickImage() async {
//     final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
//     if (picked != null) {
//       setState(() {
//         _image = File(picked.path);
//       });
//     }
//   }

//   Future<void> saveStock() async {
//     if (!_formKey.currentState!.validate()) return;

//     setState(() {
//       isUploading = true;
//     });

//     final id = const Uuid().v4();
//     String? imageUrl;

//     if (_image != null) {
//       final ref = FirebaseStorage.instance.ref().child('stocks/$id.jpg');
//       await ref.putFile(_image!);
//       imageUrl = await ref.getDownloadURL();
//     }

//     await FirebaseFirestore.instance.collection('stocks').doc(id).set({
//       'id': id,
//       'name': nameController.text.trim(),
//       'originalPrice': double.tryParse(originalPriceController.text) ?? 0.0,
//       'discountedPrice': double.tryParse(discountedPriceController.text) ?? 0.0,
//       'lastLowerPrice': double.tryParse(lastLowerPriceController.text) ?? 0.0,
//       'isAvailable': isAvailable,
//       'imageUrl': imageUrl,
//       'createdAt': Timestamp.now(),
//     });

//     setState(() {
//       isUploading = false;
//     });

//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Stock added successfully!')),
//     );

//     Navigator.pop(context);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Add Stock')),
//       body: isUploading
//           ? const Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//               padding: const EdgeInsets.all(16),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   children: [
//                     GestureDetector(
//                       onTap: pickImage,
//                       child: _image == null
//                           ? Container(
//                               height: 150,
//                               width: double.infinity,
//                               color: Colors.grey[300],
//                               child: const Icon(Icons.add_a_photo, size: 50),
//                             )
//                           : Image.file(_image!, height: 150, fit: BoxFit.cover),
//                     ),
//                     const SizedBox(height: 16),
//                     TextFormField(
//                       controller: nameController,
//                       decoration: const InputDecoration(labelText: 'Item Name'),
//                       validator: (val) =>
//                           val == null || val.trim().isEmpty ? 'Enter item name' : null,
//                     ),
//                     const SizedBox(height: 12),
//                     TextFormField(
//                       controller: originalPriceController,
//                       keyboardType: TextInputType.number,
//                       decoration: const InputDecoration(labelText: 'Original Price'),
//                     ),
//                     const SizedBox(height: 12),
//                     TextFormField(
//                       controller: discountedPriceController,
//                       keyboardType: TextInputType.number,
//                       decoration: const InputDecoration(labelText: 'Discounted Price'),
//                     ),
//                     const SizedBox(height: 12),
//                     TextFormField(
//                       controller: lastLowerPriceController,
//                       keyboardType: TextInputType.number,
//                       decoration: const InputDecoration(labelText: 'Last Lower Price'),
//                     ),
//                     const SizedBox(height: 12),
//                     Row(
//                       children: [
//                         const Text("Available:"),
//                         Switch(
//                           value: isAvailable,
//                           onChanged: (val) {
//                             setState(() {
//                               isAvailable = val;
//                             });
//                           },
//                         )
//                       ],
//                     ),
//                     const SizedBox(height: 20),
//                     ElevatedButton.icon(
//                       onPressed: saveStock,
//                       icon: const Icon(Icons.save),
//                       label: const Text("Save Stock"),
//                     ),
//                       const SizedBox(height: 20),
//                     ElevatedButton.icon(
//                       onPressed: () {
//                         Navigator.pushReplacement(
//                           context,
//                           MaterialPageRoute(builder: (context) => const StockListScreen()),
//                         );
//                       },
//                       icon: const Icon(Icons.list),
//                       label: const Text("View Stock List"),
//                       style: ElevatedButton.styleFrom(
//                         minimumSize: const Size.fromHeight(50),
//                       ),
//                     ),
                  
//                   ],
//                 ),
//               ),
//             ),
//     );
//   }
// }
