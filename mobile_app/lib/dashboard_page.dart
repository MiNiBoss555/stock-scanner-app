import "dart:async" show Future;
import "package:flutter/foundation.dart" show ValueListenable, kIsWeb;
import "package:flutter/material.dart";

import "api_service.dart";
import "models.dart";
import "theme/app_theme.dart";
import "dashboard_home.dart";
import "chat_assistant_page.dart";
import "orders_page.dart";
import "login_page.dart";

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.api,
    required this.refreshSignal,
    required this.currentUser,
    required this.routeObserver,
    required this.onOpenOrdersTab,
    required this.onOpenProductList,
    required this.onOpenProductDetails,
    required this.onOpenCustomLabel,
    required this.onOpenOrderChat,
  });

  final StockApiService api;
  final ValueListenable<int> refreshSignal;
  final AppUser currentUser;
  final RouteObserver<ModalRoute<void>> routeObserver;
  final VoidCallback onOpenOrdersTab;
  final void Function(BuildContext context, List<Product> products, String title, IconData icon, Color color) onOpenProductList;
  final void Function(BuildContext context, Product product) onOpenProductDetails;
  final void Function(BuildContext context, String label) onOpenCustomLabel;
  final void Function(BuildContext context, DeliveryOrder order) onOpenOrderChat;

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> with RouteAware {
  late Future<DashboardData> _future;
  final TextEditingController _productSearchController =
      TextEditingController();
  String _productSearch = "";

  @override
  void initState() {
    super.initState();
    _future = _load();
    widget.refreshSignal.addListener(_handleRealtimeRefresh);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      widget.routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _productSearchController.dispose();
    widget.refreshSignal.removeListener(_handleRealtimeRefresh);
    widget.routeObserver.unsubscribe(this);
    super.dispose();
  }

  void refreshNow() {
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  @override
  void didPopNext() {
    // Returned to Dashboard from another page -> refresh.
    refreshNow();
  }

  List<Product> _filterProducts(List<Product> products) {
    final query = _productSearch.trim().toLowerCase();
    if (query.isEmpty) {
      return const <Product>[];
    }
    return products
        .where((product) {
          return product.name.toLowerCase().contains(query) ||
              product.barcode.toLowerCase().contains(query) ||
              (product.sku?.toLowerCase().contains(query) ?? false);
        })
        .take(12)
        .toList();
  }

  void _handleRealtimeRefresh() {
    if (!mounted) {
      return;
    }
    setState(() {
      _future = _load();
    });
  }

  Future<void> _showOrderPreview(DeliveryOrder order) async {
    final statusLabel = order.status == "new"
        ? "ใหม่"
        : order.status == "assigned"
            ? "มอบหมายแล้ว"
            : order.status == "preparing"
                ? "กำลังจัดสินค้า"
                : order.status == "out_for_delivery"
                    ? "กำลังส่ง"
                    : order.status == "delivered"
                        ? "ส่งแล้ว"
                        : order.status == "cancelled"
                            ? "ยกเลิก"
                            : order.status;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.5,
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "ใบสรุปออเดอร์",
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.customerName,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        widget.onOpenOrderChat(this.context, order);
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text("แชทติดตามงาน"),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _ReceiptDivider(),
                  const SizedBox(height: 8),
                  _receiptRow("สถานะ", statusLabel),
                  _receiptRow("ผู้รับออเดอร์", order.createdByName),
                  _receiptRow(
                      "ผู้ส่ง", order.assignedToName ?? "ยังไม่มอบหมาย"),
                  if (order.customerPhone != null &&
                      order.customerPhone!.isNotEmpty)
                    _receiptRow("โทร", order.customerPhone!),
                  if (order.customerAddress != null &&
                      order.customerAddress!.isNotEmpty)
                    _receiptRow("ที่อยู่", order.customerAddress!),
                  if (order.note != null && order.note!.isNotEmpty)
                    _receiptRow("หมายเหตุ", order.note!),
                  const SizedBox(height: 10),
                  const _ReceiptDivider(),
                  const SizedBox(height: 8),
                  Text("รายการสินค้า",
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  ...order.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.productName,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "x${item.quantity} ${item.unit}",
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _ReceiptDivider(),
                  const SizedBox(height: 8),
                  _receiptRow("รวมรายการ", "${order.items.length} รายการ",
                      bold: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                color: brandInk.withOpacity(0.85),
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const Text(": "),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: brandDeep,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<DashboardData> _load() async {
    final start = DateTime.now();
    final results = await Future.wait([
      widget.api.getSummary(),
      widget.api.getProducts(),
      widget.api.getOrders(requesterId: widget.currentUser.userId, limit: 300),
    ]);
    debugPrint("DEBUG TIMER: load initial dashboard duration = ${DateTime.now().difference(start).inMilliseconds} ms");
    if (loginTapStart != null) {
      debugPrint("DEBUG TIMER: total time from login tap to first screen = ${DateTime.now().difference(loginTapStart!).inMilliseconds} ms");
      loginTapStart = null;
    }
    final allOrders = results[2] as List<DeliveryOrder>;
    int duePriority(DeliveryOrder order) {
      final dueAt = order.scheduledDeliveryAt;
      if (dueAt == null) {
        return 9999;
      }
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(dueAt.year, dueAt.month, dueAt.day);
      return dueDay.difference(today).inDays;
    }

    final activeOrders = allOrders
        .where((order) =>
            order.status != "delivered" && order.status != "cancelled")
        .toList()
      ..sort((a, b) {
        final dueCompare = duePriority(a).compareTo(duePriority(b));
        if (dueCompare != 0) {
          return dueCompare;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final todayUpdatedOrders = activeOrders
        .where((order) =>
            order.updatedAt.isAfter(startOfToday) ||
            order.updatedAt.isAtSameMomentAs(startOfToday))
        .take(4)
        .toList();
    return DashboardData(
      summary: results[0] as StockSummary,
      products: results[1] as List<Product>,
      activeOrders: activeOrders.take(6).toList(),
      todayUpdatedOrders: todayUpdatedOrders,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _future = _load();
        });
        await _future;
      },
      child: FutureBuilder<DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final data = snapshot.data!;
          final matchedProducts = _filterProducts(data.products);
          if (kIsWeb) {
            return ColoredBox(
              color: brandSurface,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: WebDashboardHome(
                      data: data,
                      onOpenOrdersTab: widget.onOpenOrdersTab,
                      productSearchController: _productSearchController,
                      productSearch: _productSearch,
                      onProductSearchChanged: (value) {
                        setState(() {
                          _productSearch = value;
                        });
                      },
                      onClearProductSearch: () {
                        _productSearchController.clear();
                        setState(() {
                          _productSearch = "";
                        });
                      },
                      matchedProducts: matchedProducts,
                      onOpenAssistant: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatAssistantPage(
                              api: widget.api,
                              refreshSignal: widget.refreshSignal,
                              onOpenProductDetails: widget.onOpenProductDetails,
                            ),
                          ),
                        );
                      },
                      onOpenOrders: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OrdersPage(
                              api: widget.api,
                              currentUser: widget.currentUser,
                              refreshSignal: widget.refreshSignal,
                            ),
                          ),
                        );
                      },
                      onOpenStock: () {
                        widget.onOpenCustomLabel(context, "");
                      },
                      onOpenProductList: widget.onOpenProductList,
                      onOpenProductDetails: widget.onOpenProductDetails,
                    ),
                  ),
                ),
              ),
            );
          }

          return MobileDashboardHome(
            data: data,
            currentUser: widget.currentUser,
            onOpenOrdersTab: widget.onOpenOrdersTab,
            onOpenOrderPreview: _showOrderPreview,
            onOpenProductList: widget.onOpenProductList,
          );
        },
      ),
    );
  }
}

class _ReceiptDivider extends StatelessWidget {
  const _ReceiptDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dashCount = (constraints.maxWidth / 10).floor().clamp(12, 60);
        return Row(
          children: List.generate(
            dashCount,
            (_) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                height: 1.4,
                color: brandPrimary.withOpacity(0.35),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.tone = brandPrimary,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final iconChipColor = Color.lerp(brandSurface, tone, 0.16)!;
    final iconColor = Color.lerp(brandDeep, tone, 0.55)!;
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, spaceSm),
      decoration: softPanelDecoration(
        tone: tone,
        radius: 20,
        surfaceStrength: 0.80,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconChipColor,
              borderRadius: BorderRadius.circular(spaceSm),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: spaceXs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: brandDeep,
                    fontWeight: FontWeight.w800,
                    fontSize: 30,
                  ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: brandInk.withOpacity(0.9),
                  fontSize: 12,
                  height: 1.1,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    this.onOpenCode,
    this.onPrintLabel,
  });

  final Product product;
  final VoidCallback? onOpenCode;
  final VoidCallback? onPrintLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
        minLeadingWidth: 34,
        onTap: onOpenCode,
        title: Text(
          product.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          "${product.barcode} · ${product.location ?? "ไม่ระบุตำแหน่ง"}",
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5),
        ),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: (product.isLowStock ? brandPrimary : brandDeep)
              .withOpacity(0.10),
          child: Icon(
            product.isLowStock
                ? Icons.warning_amber_rounded
                : Icons.inventory_2_rounded,
            size: 18,
            color: product.isLowStock ? brandPrimary : brandDeep,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${product.currentStock} ${product.unit}",
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                Text(
                  "min ${product.minimumStock}",
                  style: TextStyle(
                    fontSize: 11.5,
                    color:
                        product.isLowStock ? brandPrimary : brandTextOnLight,
                  ),
                ),
              ],
            ),
            if (onPrintLabel != null) ...[
              const SizedBox(width: 4),
              IconButton(
                onPressed: onPrintLabel,
                icon: const Icon(Icons.print_outlined, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                tooltip: "พิมพ์ป้ายสินค้า",
              ),
            ],
            if (onOpenCode != null) ...[
              const SizedBox(width: 2),
              IconButton(
                onPressed: onOpenCode,
                icon: const Icon(Icons.qr_code_2_outlined, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                tooltip: "ดู barcode",
              ),
            ],
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: brandInk.withOpacity(0.62),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
