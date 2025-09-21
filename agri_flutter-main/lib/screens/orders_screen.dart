import 'package:flutter/material.dart';
import '../services/api_service.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<Map<int, String>> _productMapFuture;

  @override
  void initState() {
    super.initState();
    _productMapFuture = _buildProductMap();
  }

  /// Build a map { productId : productName }
  Future<Map<int, String>> _buildProductMap() async {
    final products = await ApiService.fetchProducts();
    return {for (var p in products) p.id: p.name};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("📦 My COMMUNITY"),
        backgroundColor: Colors.green.shade700,
        elevation: 4,
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- NEW TEXT CONTENT ADDED HERE ---
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Orders Hub',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome! This screen shows all the collective orders placed by your community members. Track group purchases and stay updated on all transactions.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // --- END OF NEW TEXT CONTENT ---
          Expanded(
            child: FutureBuilder(
              future: Future.wait([
                ApiService.fetchOrders(),
                _productMapFuture,
              ]),
              builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "⚠️ Error: ${snapshot.error}",
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final orders = snapshot.data![0]; // List<Order>
                final productMap = snapshot.data![1] as Map<int, String>;

                if (orders.isEmpty) {
                  return const Center(
                    child: Text(
                      "No orders yet.",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];

                    // Convert productIds → names
                    final productNames = order.productIds
                        .map((id) => productMap[id] ?? "Unknown")
                        .join(", ");

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.green.shade100,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          child: const Icon(
                            Icons.receipt_long,
                            color: Colors.green,
                          ),
                        ),
                        title: Text(
                          "Order #${order.id}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            "🛒 $productNames\n💰 Total: ₹${order.totalPrice.toStringAsFixed(2)}",
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
