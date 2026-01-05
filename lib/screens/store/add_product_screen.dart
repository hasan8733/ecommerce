import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/glass_container.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final descriptionController = TextEditingController();

  XFile? selectedImage;
  bool isUploading = false;
  // Temporarily allow creating products without an image (useful for testing
  // when Firebase Storage is restricted or to isolate upload issues).
  final bool allowNoImageUpload = true;

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => selectedImage = image);
    }
  }

  Future<void> uploadProduct() async {
    if (nameController.text.trim().isEmpty ||
        priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isUploading = true);

    try {
      final storeId = FirebaseAuth.instance.currentUser!.uid;

      // Validate price
      final price = double.tryParse(priceController.text.trim());
      if (price == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Please enter a valid numeric price"),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // If an image is selected, upload it. Otherwise, either require an
      // image or continue with an empty images list (controlled by
      // `allowNoImageUpload`). This helps isolate image upload failures.
      List<String> images = [];

      if (selectedImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('products/${DateTime.now().millisecondsSinceEpoch}.jpg');

        UploadTask uploadTask;
        if (kIsWeb) {
          final bytes = await selectedImage!.readAsBytes();
          uploadTask = storageRef.putData(bytes);
        } else {
          uploadTask = storageRef.putFile(File(selectedImage!.path));
        }

        try {
          await uploadTask
              .whenComplete(() => null)
              .timeout(const Duration(seconds: 60));
        } on TimeoutException catch (te) {
          try {
            await uploadTask.cancel();
          } catch (_) {}
          rethrow;
        }

        final snapshot = uploadTask.snapshot;
        if (snapshot.state != TaskState.success) {
          throw Exception('Upload failed with state: ${snapshot.state}');
        }

        final imageUrl = await storageRef.getDownloadURL();
        images = [imageUrl];
      } else {
        if (!allowNoImageUpload) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Please pick an image"),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // Add product to Firestore
      await FirebaseFirestore.instance.collection('products').add({
        'productName': nameController.text.trim(),
        'price': price,
        'description': descriptionController.text.trim(),
        'images': images,
        'storeId': storeId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Product added successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/auth_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        "Add Product",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Form
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: GlassContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Image Picker
                          GestureDetector(
                            onTap: pickImage,
                            child: Container(
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: selectedImage == null
                                  ? const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate,
                                          size: 50,
                                          color: Colors.white70,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          "Tap to pick image",
                                          style:
                                              TextStyle(color: Colors.white70),
                                        ),
                                      ],
                                    )
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: kIsWeb
                                          ? Image.network(
                                              selectedImage!.path,
                                              fit: BoxFit.cover,
                                            )
                                          : Image.file(
                                              File(selectedImage!.path),
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Product Name
                          _inputField("Product Name", nameController),
                          const SizedBox(height: 12),

                          // Price
                          _inputField(
                            "Price",
                            priceController,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),

                          // Description
                          _inputField(
                            "Description (Optional)",
                            descriptionController,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 24),

                          // Submit Button
                          ElevatedButton(
                            onPressed: isUploading ? null : uploadProduct,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              minimumSize: const Size(double.infinity, 48),
                            ),
                            child: isUploading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text("Add Product"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField(
    String hint,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
