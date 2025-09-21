// File: lib/screens/marketplace.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen>
    with SingleTickerProviderStateMixin {
  final List<int> _selectedProductIds = [];
  late TabController _tabController;
  final List<String> _productCategories = [
    "All",
    "Seeds",
    "Fertilizers",
    "Equipment",
    "Soil Test",
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _productCategories.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleSelection(int productId) {
    setState(() {
      if (_selectedProductIds.contains(productId)) {
        _selectedProductIds.remove(productId);
      } else {
        _selectedProductIds.add(productId);
      }
    });
  }

  Future<void> _checkout() async {
    if (_selectedProductIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one product.")),
      );
      return;
    }

    try {
      final order = await ApiService.createOrder(_selectedProductIds);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "✅ Order #${order.id} created successfully!",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _selectedProductIds.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error creating order: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToSellCropsScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SellCropScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "🌾 Agri Marketplace",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green.shade800,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: _productCategories.map((name) => Tab(text: name)).toList(),
        ),
      ),
      body: FutureBuilder<List<Product>>(
        future: ApiService.fetchProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "⚠️ Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "No products available.",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            );
          }

          final products = snapshot.data!;

          return TabBarView(
            controller: _tabController,
            children: _productCategories.map((category) {
              final filteredProducts = category == "All"
                  ? products
                  : products.where((p) => p.category == category).toList();

              if (filteredProducts.isEmpty) {
                return const Center(
                  child: Text("No products in this category."),
                );
              }

              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.75,
                ),
                padding: const EdgeInsets.all(12),
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  final isSelected = _selectedProductIds.contains(product.id);
                  return ProductCard(
                    product: product,
                    isSelected: isSelected,
                    onTap: () => _toggleSelection(product.id),
                  );
                },
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: _navigateToSellCropsScreen,
            label: const Text("Sell Your Crops"),
            icon: const Icon(Icons.add),
            backgroundColor: Colors.blue.shade700,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            onPressed: _selectedProductIds.isEmpty ? null : _checkout,
            label: Text(
              "Checkout (${_selectedProductIds.length})",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.shopping_cart),
            backgroundColor: _selectedProductIds.isEmpty
                ? Colors.grey
                : Colors.green.shade700,
          ),
        ],
      ),
    );
  }
}

// Separate widget for the Product Card to improve code readability
class ProductCard extends StatelessWidget {
  final Product product;
  final bool isSelected;
  final VoidCallback onTap;

  const ProductCard({
    required this.product,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.green.shade700 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Image.network(
                  product.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 50,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "₹${product.price.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.center,
                    child: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.add_circle_outline,
                      color: isSelected ? Colors.green.shade700 : Colors.grey,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// New screen for users to list their crops for sale
class SellCropScreen extends StatelessWidget {
  const SellCropScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sell Your Crops"),
        backgroundColor: Colors.green.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "List your produce for sale.",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              decoration: const InputDecoration(
                labelText: "Crop Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: "Quantity (e.g., in kg)",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: "Price per unit (₹)",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Logic to submit crop details to API
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Crop submitted for review!")),
                );
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text(
                "Submit",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
