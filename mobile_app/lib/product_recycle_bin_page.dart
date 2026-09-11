import "dart:async";
import "package:flutter/material.dart";
import "api_service.dart";
import "models.dart";
import "empty_state.dart";
import "loading_state.dart";
import "theme/app_theme.dart";

class ProductRecycleBinPage extends StatefulWidget {
  const ProductRecycleBinPage({
    super.key,
    required this.api,
    required this.currentUser,
  });

  final StockApiService api;
  final AppUser currentUser;

  @override
  State<ProductRecycleBinPage> createState() => _ProductRecycleBinPageState();
}

class _ProductRecycleBinPageState extends State<ProductRecycleBinPage> {
  List<Product> _inactiveProducts = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    if (widget.currentUser.isAdmin) {
      _loadInactiveProducts();
    } else {
      _isLoading = false;
    }
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  Future<void> _loadInactiveProducts() async {
    if (!widget.currentUser.isAdmin) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final products = await widget.api.getProducts(includeInactive: true);
      if (mounted) {
        setState(() {
          _inactiveProducts = products.where((p) => p.active == false).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmAndRestoreProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text("ยืนยันการกู้คืน"),
        content: const Text("ต้องการกู้คืนสินค้านี้ใช่หรือไม่?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text("ยกเลิก"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: brandPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text("กู้คืน"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isLoading = true;
      });

      try {
        final message = await widget.api.restoreProduct(
          requesterId: widget.currentUser.userId,
          barcode: product.barcode,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
        await _loadInactiveProducts();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst("Exception: ", "")),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  List<Product> _getFilteredProducts() {
    if (_searchQuery.trim().isEmpty) {
      return _inactiveProducts;
    }
    final q = _searchQuery.trim().toLowerCase();
    return _inactiveProducts.where((p) {
      final nameMatch = p.name.toLowerCase().contains(q);
      final barcodeMatch = p.barcode.toLowerCase().contains(q);
      final skuMatch = p.sku?.toLowerCase().contains(q) ?? false;
      final catMatch = p.category?.toLowerCase().contains(q) ?? false;
      return nameMatch || barcodeMatch || skuMatch || catMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.currentUser.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("สิทธิ์การเข้าถึง"),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "ปฏิเสธการเข้าถึง: เฉพาะผู้ดูแลระบบเท่านั้น",
              style: TextStyle(
                fontSize: 16,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final filtered = _getFilteredProducts();

    return Scaffold(
      appBar: AppBar(
        title: const Text("ถังขยะสินค้า"),
        backgroundColor: brandPrimary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "ค้นหาด้วยชื่อ, บาร์โค้ด, SKU หรือหมวดหมู่",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const LoadingState(message: "กำลังโหลดถังขยะ...")
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadInactiveProducts,
                              child: const Text("ลองใหม่"),
                            ),
                          ],
                        ),
                      )
                    : _inactiveProducts.isEmpty
                        ? const EmptyState(
                            icon: Icons.restore_from_trash_outlined,
                            title: "ยังไม่มีสินค้าในถังขยะ",
                            message: "สินค้าที่ถูกซ่อนหรือปิดใช้งานจะแสดงที่นี่",
                          )
                        : filtered.isEmpty
                            ? const EmptyState(
                                icon: Icons.search_off_outlined,
                                title: "ไม่พบสินค้าที่ตรงกับคำค้นหา",
                                message: "ลองค้นหาด้วยชื่อ บาร์โค้ด SKU หรือหมวดหมู่อื่น",
                              )
                            : RefreshIndicator(
                                onRefresh: _loadInactiveProducts,
                                child: ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final product = filtered[index];
                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ListTile(
                                        title: Text(
                                          product.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text("บาร์โค้ด: ${product.barcode}"),
                                            if (product.sku != null &&
                                                product.sku!.isNotEmpty)
                                              Text("SKU: ${product.sku}"),
                                            Text("สต็อก: ${product.currentStock} ${product.unit}"),
                                          ],
                                        ),
                                        trailing: ElevatedButton(
                                          onPressed: () =>
                                              _confirmAndRestoreProduct(product),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: brandPrimary,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text("กู้คืน"),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
          ),
        ],
      ),
    );
  }
}
