import "dart:async";
import "dart:io";

import "package:excel/excel.dart" hide Border;
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:mobile_scanner/mobile_scanner.dart" hide Barcode;
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";
import "package:shared_preferences/shared_preferences.dart";

import "api_service.dart";
import "models.dart";
import "theme/app_theme.dart";

class ProductSearchPage extends StatefulWidget {
  const ProductSearchPage({
    super.key,
    required this.api,
    this.onOpenProductDetails,
  });

  final StockApiService api;
  final void Function(BuildContext context, Product product)? onOpenProductDetails;

  @override
  State<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends State<ProductSearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _query = "";
  List<Product> _allProducts = [];
  bool _isLoading = true;
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history = prefs.getStringList("recent_search_history") ?? [];
    });
  }

  Future<void> _addToHistory(String term) async {
    final t = term.trim();
    if (t.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList("recent_search_history") ?? [];
    
    current.removeWhere((e) => e.toLowerCase() == t.toLowerCase());
    current.insert(0, t);
    
    final updated = current.take(10).toList();
    await prefs.setStringList("recent_search_history", updated);
    
    if (mounted) {
      setState(() {
        _history = updated;
      });
    }
  }

  Future<void> _scanBarcode() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_scanner, color: brandPrimary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "สแกนบาร์โค้ดสินค้า",
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 300,
                  child: MobileScanner(
                    controller: MobileScannerController(
                      detectionSpeed: DetectionSpeed.noDuplicates,
                      returnImage: false,
                    ),
                    onDetect: (capture) {
                      final value = capture.barcodes.first.rawValue;
                      if (value != null && value.isNotEmpty) {
                        unawaited(HapticFeedback.lightImpact());
                        Navigator.of(sheetContext).pop(value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );

    if (result != null && mounted) {
      _controller.text = result;
      setState(() {
        _query = result;
      });
      _addToHistory(result);

      // Exact Match Auto-Select for barcode scan
      final trimmedResult = result.trim().toLowerCase();
      final exactMatches = _allProducts.where((p) {
        return p.barcode.toLowerCase() == trimmedResult ||
            (p.sku?.toLowerCase() == trimmedResult);
      }).toList();

      if (exactMatches.length == 1) {
        if (widget.onOpenProductDetails != null) {
          widget.onOpenProductDetails!(context, exactMatches.first);
        }
      }
    }
  }

  Future<void> _load() async {
    try {
      final products = await widget.api.getProducts();
      if (mounted) {
        setState(() {
          _allProducts = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(context, e.toString(), isError: true);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Product> _filteredProducts() {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _allProducts;
    return _allProducts.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.barcode.toLowerCase().contains(q) ||
          (p.sku?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _exportProductsExcel() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final products = await widget.api.getProducts();
      final excel = Excel.createExcel();
      final sheetName = "Products";
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      // Headers
      final headers = [
        "Barcode",
        "SKU",
        "Name",
        "Category",
        "Unit",
        "Current Stock",
        "Minimum Stock"
      ];
      for (var i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = TextCellValue(headers[i]);
      }

      // Data
      for (var i = 0; i < products.length; i++) {
        final p = products[i];
        final row = i + 1;
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = TextCellValue(p.barcode);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = TextCellValue(p.sku ?? "");
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
            .value = TextCellValue(p.name);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
            .value = TextCellValue(p.category ?? "");
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
            .value = TextCellValue(p.unit);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
            .value = IntCellValue(p.currentStock);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
            .value = IntCellValue(p.minimumStock);
      }

      final fileBytes = excel.save();
      if (fileBytes == null) throw Exception("สร้างไฟล์ Excel ไม่สำเร็จ");

      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/products.xlsx";
      final file = File(path);
      await file.writeAsBytes(fileBytes, flush: true);

      await Share.shareXFiles(
        [XFile(path)],
        text: "รายการสินค้าทั้งหมด (${products.length} รายการ)",
      );
    } catch (e) {
      if (mounted) {
        showAppSnack(context, "ส่งออกไม่สำเร็จ: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _filteredProducts();

    return Scaffold(
      backgroundColor: brandSurface,
      appBar: AppBar(
        titleSpacing: 0,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.table_view_outlined),
              onPressed: _exportProductsExcel,
              tooltip: "ส่งออก Excel",
            ),
        ],
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: "ค้นหาชื่อสินค้า บาร์โค้ด หรือ SKU...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_query.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = "");
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _scanBarcode,
                  ),
                ],
              ),
              border: InputBorder.none,
              filled: false,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_query.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Text(
                          "พบ ${results.length} รายการ",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _query.isEmpty
                      ? (_history.isNotEmpty
                          ? ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                Text(
                                  "ประวัติการค้นหาล่าสุด",
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: brandDeep,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                ..._history.map((term) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.history, size: 20),
                                      title: Text(term),
                                      trailing: const Icon(Icons.north_west, size: 16, color: Colors.grey),
                                      onTap: () {
                                        _controller.text = term;
                                        setState(() {
                                          _query = term;
                                        });
                                      },
                                    )),
                              ],
                            )
                          : const _EmptyTile(message: "ไม่มีรายการสินค้า"))
                      : results.isEmpty
                          ? const _EmptyTile(message: "ไม่พบสินค้าที่ตรงกับคำค้นหา")
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: results.length,
                              itemBuilder: (context, index) {
                                final product = results[index];
                                return _ProductSearchTile(
                                  product: product,
                                  query: _query,
                                  onTap: () {
                                    _addToHistory(_query);
                                    if (widget.onOpenProductDetails != null) {
                                      widget.onOpenProductDetails!(context, product);
                                    }
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

class _ProductSearchTile extends StatelessWidget {
  const _ProductSearchTile({
    required this.product,
    required this.query,
    required this.onTap,
  });

  final Product product;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String statusText;

    if (product.currentStock <= 0) {
      badgeColor = Colors.red;
      statusText = "หมด";
    } else if (product.currentStock <= product.minimumStock) {
      badgeColor = Colors.orange;
      statusText = "ใกล้หมด";
    } else {
      badgeColor = Colors.green;
      statusText = "ปกติ";
    }

    final bool isLongUnit = product.unit.length > 4;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("${product.barcode} | ${product.category ?? 'ทั่วไป'}"),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isLongUnit
                    ? "${product.currentStock}"
                    : "${product.currentStock} ${product.unit}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isLongUnit ? "$statusText (${product.unit})" : statusText,
              style: TextStyle(
                color: badgeColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTile extends StatelessWidget {
  const _EmptyTile({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: spaceLg, vertical: 22),
      decoration: softPanelDecoration(surfaceStrength: 0.45),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: brandPrimary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: brandPrimary.withOpacity(0.82),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "ยังไม่มีรายการ",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: brandInk,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: brandInk.withOpacity(0.60),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
