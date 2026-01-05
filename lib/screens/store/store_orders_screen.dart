import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

class StoreOrdersScreen extends StatelessWidget {
  const StoreOrdersScreen({super.key});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'shipped':
        return Colors.lightBlueAccent;
      case 'processing':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeId = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('orderDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Text(
              "No orders",
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        // Filter orders that contain this store's products
        final allOrders = snapshot.data!.docs;
        final storeOrders = allOrders.where((order) {
          final data = order.data() as Map<String, dynamic>? ?? {};
          final items = (data['items'] is List)
              ? data['items'] as List<dynamic>
              : <dynamic>[];
          return items.any((item) {
            try {
              return (item is Map && item['storeId'] == storeId);
            } catch (_) {
              return false;
            }
          });
        }).toList();

        if (storeOrders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long,
                    size: 80, color: Colors.white.withOpacity(0.7)),
                const SizedBox(height: 16),
                const Text(
                  "No orders yet",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: storeOrders.length,
          itemBuilder: (context, index) {
            final order = storeOrders[index];
            final data = order.data() as Map<String, dynamic>? ?? {};
            final allItems = (data['items'] is List)
                ? data['items'] as List<dynamic>
                : <dynamic>[];

            // Filter only this store's items
            final storeItems = allItems.where((item) {
              try {
                return (item is Map && item['storeId'] == storeId);
              } catch (_) {
                return false;
              }
            }).toList();

            // Calculate store's portion of total
            double storeTotal = 0;
            for (var item in storeItems) {
              storeTotal += (item['price'] * item['quantity']);
            }

            // Format date
            String dateStr = 'N/A';
            if (data['orderDate'] != null) {
              final timestamp = data['orderDate'] as Timestamp;
              final date = timestamp.toDate();
              dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(date);
            }

            return ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Order #${order.id.substring(0, 8)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Customer: ${data['userName']}",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    (data['status'] ?? 'pending').toString(),
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  (data['status'] ?? 'pending')
                                      .toString()
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Status change menu for store owners
                              PopupMenuButton<String>(
                                color: Colors.black87,
                                onSelected: (value) async {
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('orders')
                                        .doc(order.id)
                                        .update({'status': value});
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('Order status updated'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(
                                      value: 'pending',
                                      child: Text('Pending',
                                          style:
                                              TextStyle(color: Colors.white))),
                                  PopupMenuItem(
                                      value: 'shipped',
                                      child: Text('Shipped',
                                          style:
                                              TextStyle(color: Colors.white))),
                                  PopupMenuItem(
                                      value: 'delivered',
                                      child: Text('Delivered',
                                          style:
                                              TextStyle(color: Colors.white))),
                                  PopupMenuItem(
                                      value: 'cancelled',
                                      child: Text('Cancelled',
                                          style:
                                              TextStyle(color: Colors.white))),
                                ],
                                icon: const Icon(Icons.more_vert,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      const Divider(color: Colors.white30, height: 20),
                      const Text(
                        "Your Products:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...storeItems.map((item) {
                        final it = item as Map<String, dynamic>? ?? {};
                        final image = (it['image'] is String &&
                                (it['image'] as String).isNotEmpty)
                            ? it['image'] as String
                            : null;
                        final productName =
                            it['productName']?.toString() ?? 'Product';
                        final quantity = (it['quantity'] is int)
                            ? it['quantity'] as int
                            : int.tryParse('${it['quantity']}') ?? 1;
                        final price = (it['price'] is num)
                            ? it['price'] as num
                            : double.tryParse('${it['price']}') ?? 0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: image != null
                                    ? Image.network(
                                        image,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 50,
                                        height: 50,
                                        color: Colors.white.withOpacity(0.08),
                                        child: Icon(Icons.image,
                                            color:
                                                Colors.white.withOpacity(0.7)),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      "Qty: $quantity",
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                "₹ ${(price * quantity).toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const Divider(color: Colors.white30, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Your Earnings:",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            "₹ ${storeTotal.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                      if (data['deliveryAddress'] != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.location_on,
                                      size: 16,
                                      color: Colors.white.withOpacity(0.7)),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Delivery Address:",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data['deliveryAddress'],
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                              if (data['phoneNumber'] != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.phone,
                                        size: 16,
                                        color: Colors.white.withOpacity(0.7)),
                                    const SizedBox(width: 4),
                                    Text(
                                      data['phoneNumber'],
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
