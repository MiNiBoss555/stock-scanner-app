import "dart:ui" show PointerDeviceKind;
import "package:google_fonts/google_fonts.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";

import "models.dart";
import "theme/app_theme.dart";
import "dashboard_components.dart" show WebDashboardHero, DashboardUpdateCard;

class DashboardData {
  DashboardData({
    required this.summary,
    required this.products,
    required this.activeOrders,
    required this.todayUpdatedOrders,
  });

  final StockSummary summary;
  final List<Product> products;
  final List<DeliveryOrder> activeOrders;
  final List<DeliveryOrder> todayUpdatedOrders;
}

class MobileDashboardHome extends StatelessWidget {
  const MobileDashboardHome({
    super.key,
    required this.data,
    required this.currentUser,
    required this.onOpenOrdersTab,
    required this.onOpenOrderPreview,
    required this.onOpenProductList,
  });

  final DashboardData data;
  final AppUser currentUser;
  final VoidCallback onOpenOrdersTab;
  final Future<void> Function(DeliveryOrder order) onOpenOrderPreview;
  final void Function(
    BuildContext context,
    List<Product> products,
    String title,
    IconData icon,
    Color color,
  ) onOpenProductList;

  @override
  Widget build(BuildContext context) {
    final outOfStock = data.products.where((p) => p.currentStock <= 0).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final lowStock = data.products
        .where((p) => p.currentStock > 0 && p.currentStock <= p.minimumStock)
        .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

    final latestOrders = data.activeOrders.take(6).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: isDark ? darkSurface : brandSurface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _DashboardSectionHeader(
            eyebrow: "Dashboard",
            title: "ภาพรวมสต็อก",
            subtitle: "ดูออเดอร์ งานค้าง และรายการอัปเดตล่าสุดจากมือถือ",
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StockHealthCard(
                  label: "สินค้าทั้งหมด",
                  count: data.products.length,
                  icon: Icons.inventory_2_outlined,
                  color: brandPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StockHealthCard(
                  label: "หมดสต็อก",
                  count: outOfStock.length,
                  icon: Icons.error_outline,
                  color: Colors.redAccent,
                  onTap: outOfStock.isEmpty
                      ? null
                      : () => onOpenProductList(
                            context,
                            outOfStock,
                            "สินค้าหมด",
                            Icons.inventory_2_outlined,
                            Colors.redAccent,
                          ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StockHealthCard(
                  label: "ใกล้หมด",
                  count: lowStock.length,
                  icon: Icons.warning_amber_rounded,
                  color: Colors.orangeAccent,
                  onTap: lowStock.isEmpty
                      ? null
                      : () => onOpenProductList(
                            context,
                            lowStock,
                            "สินค้าใกล้หมด",
                            Icons.warning_amber_rounded,
                            Colors.orangeAccent,
                          ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: adaptivePanelDecoration(
              context,
              tone: brandPrimary,
              radius: 24,
              surfaceStrength: 0.72,
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentUser.userName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: isDark ? darkTextPrimary : brandDeep,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "เช็กงานที่ต้องตามต่อวันนี้ได้ในหน้าเดียว",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? darkTextSecondary : brandInk.withOpacity(0.72),
                        ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _HeroInfoChip(
                        icon: Icons.badge_outlined,
                        label: roleLabel(currentUser.role),
                      ),
                      _HeroInfoChip(
                        icon: Icons.local_shipping_outlined,
                        label: "งานค้าง ${data.activeOrders.length} ออเดอร์",
                      ),
                      _HeroInfoChip(
                        icon: Icons.update_rounded,
                        label:
                            "อัปเดตใหม่วันนี้ ${data.todayUpdatedOrders.length}",
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          const _DashboardSectionHeader(
            eyebrow: "Order bills",
            title: "บิลออเดอร์ค้างส่ง",
            subtitle: "บิลรายการสินค้าสไตล์กระดาษใบเสร็จ (เลื่อนซ้าย-ขวาได้)",
          ),
          const SizedBox(height: 14),
          if (latestOrders.isEmpty)
            const _EmptyTile(message: "ยังไม่มีรายการออเดอร์")
          else
            _HorizontalReceiptBillList(
              orders: latestOrders,
              onOpenOrdersTab: onOpenOrdersTab,
              onOpenOrderPreview: onOpenOrderPreview,
            ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _HorizontalReceiptBillList extends StatefulWidget {
  const _HorizontalReceiptBillList({
    required this.orders,
    required this.onOpenOrdersTab,
    this.onOpenOrderPreview,
  });

  final List<DeliveryOrder> orders;
  final VoidCallback onOpenOrdersTab;
  final Future<void> Function(DeliveryOrder order)? onOpenOrderPreview;

  @override
  State<_HorizontalReceiptBillList> createState() => _HorizontalReceiptBillListState();
}

class _HorizontalReceiptBillListState extends State<_HorizontalReceiptBillList> {
  final ScrollController _scrollController = ScrollController();

  void _scroll(double delta) {
    if (!_scrollController.hasClients) return;
    final newOffset = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.orders.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton.filledTonal(
                  onPressed: () => _scroll(-320),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  tooltip: "เลื่อนทางซ้าย",
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => _scroll(320),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  tooltip: "เลื่อนทางขวา",
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.orders.map((order) {
                return _SharedReceiptBillCard(
                  order: order,
                  onOpenOrdersTab: widget.onOpenOrdersTab,
                  onOpenOrderPreview: widget.onOpenOrderPreview,
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _SharedReceiptBillCard extends StatelessWidget {
  const _SharedReceiptBillCard({
    required this.order,
    required this.onOpenOrdersTab,
    this.onOpenOrderPreview,
  });

  final DeliveryOrder order;
  final VoidCallback onOpenOrdersTab;
  final Future<void> Function(DeliveryOrder order)? onOpenOrderPreview;

  int? _daysUntilDue(DeliveryOrder order) {
    final dueAt = order.scheduledDeliveryAt;
    if (dueAt == null) {
      return null;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueAt.year, dueAt.month, dueAt.day);
    return dueDay.difference(today).inDays;
  }

  Color? _dueTone(DeliveryOrder order) {
    final days = _daysUntilDue(order);
    if (days == null) {
      return null;
    }
    if (days <= 1) {
      return const Color(0xFFD64545); // Red (Urgent)
    }
    if (days == 2) {
      return const Color(0xFFF28C28); // Orange (Near)
    }
    if (days == 3) {
      return const Color(0xFFE0B21B); // Yellow (Warning)
    }
    return const Color(0xFF2E9E6F); // Green (Safe)
  }

  String _statusLabel(String status) {
    switch (status) {
      case "pending_board":
        return "รอผลิตบอร์ด";
      case "pending_robot":
        return "รอผลิตหุ่นยนต์";
      case "waiting_board":
        return "รอประกอบบอร์ด";
      case "assembling":
        return "กำลังประกอบ";
      case "pending_qc":
        return "รอตรวจ QC";
      case "rejected_board":
        return "ตก QC บอร์ด";
      case "rejected_robot":
        return "ตก QC หุ่นยนต์";
      case "pending_delivery":
      case "out_for_delivery":
      case "delivery":
        return "กำลังส่ง";
      case "delivered":
        return "ส่งแล้ว";
      default:
        return status;
    }
  }

  int _getActiveStep(String status) {
    switch (status) {
      case "pending_robot":
      case "rejected_robot":
        return 1;
      case "pending_qc":
        return 2;
      case "pending_delivery":
      case "out_for_delivery":
      case "delivery":
      case "delivered":
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hash = order.id.hashCode.abs();
    final queueCode = "V${(hash % 90 + 10)}"; 
    final dueTone = _dueTone(order);
    
    final itemRows = <Widget>[];
    for (final item in order.items) {
      itemRows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${item.quantity} x ",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Expanded(
                child: Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final allPossibleSteps = [
      {"index": 0, "title": "ผลิตบอร์ด", "user": order.boardProductionUserName, "id": order.boardProductionUserId},
      {"index": 1, "title": "ผลิตหุ่นยนต์", "user": order.robotProductionUserName, "id": order.robotProductionUserId},
      {"index": 2, "title": "ตรวจสอบ QC", "user": order.qcUserName, "id": order.qcUserId},
      {"index": 3, "title": "จัดส่ง", "user": order.deliveryUserName, "id": order.deliveryUserId},
    ];

    final assignedSteps = allPossibleSteps.where((step) {
      final id = step["id"];
      return id != null && id.toString().trim().isNotEmpty;
    }).toList();

    final steps = assignedSteps.isEmpty ? allPossibleSteps : assignedSteps;
    final effectiveStatus = (order.status == "out_for_delivery" || order.status == "delivery" || order.status == "delivered")
        ? order.status
        : order.orderWorkflowStatus;
    final originalActiveIndex = _getActiveStep(effectiveStatus);
    
    int activeStep = 0;
    if (assignedSteps.isNotEmpty) {
      bool foundActive = false;
      for (int i = 0; i < steps.length; i++) {
        if (steps[i]["index"] == originalActiveIndex) {
          activeStep = i;
          foundActive = true;
          break;
        }
      }
      if (!foundActive) {
        for (int i = 0; i < steps.length; i++) {
          if ((steps[i]["index"] as int) > originalActiveIndex) {
            activeStep = i;
            foundActive = true;
            break;
          }
        }
        if (!foundActive) {
          activeStep = steps.length - 1;
        }
      }
    } else {
      activeStep = originalActiveIndex;
    }

    final stepWidgets = <Widget>[];
    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final isCompleted = i < activeStep;
      final isActive = i == activeStep;
      
      final indicatorColor = isActive 
          ? brandPrimary 
          : (isCompleted ? const Color(0xFF1F7A3D) : Colors.grey.shade300);
      
      final titleColor = isActive 
          ? brandDeep 
          : (isCompleted ? Colors.black87 : Colors.grey.shade500);
          
      final userName = step["user"] != null && step["user"]!.toString().isNotEmpty
          ? "${step["user"]} (${step["id"]})"
          : "ยังไม่มอบหมาย";

      stepWidgets.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    shape: BoxShape.circle,
                    border: isActive 
                        ? Border.all(color: brandPrimary.withOpacity(0.3), width: 2) 
                        : null,
                  ),
                ),
                if (i < steps.length - 1)
                  Container(
                    width: 2,
                    height: 20,
                    color: isCompleted ? const Color(0xFF1F7A3D) : Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step["title"] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.w500,
                      color: titleColor,
                    ),
                  ),
                  Text(
                    userName,
                    style: TextStyle(
                      fontSize: 9,
                      color: isActive ? brandPrimary : Colors.grey.shade600,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onOpenOrderPreview != null ? () => onOpenOrderPreview!(order) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
      width: 290,
      margin: const EdgeInsets.only(right: 14, bottom: 12, top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  const Text(
                    "STOCK SCANNER",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "-" * 38,
                    maxLines: 1,
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ลูกค้า: ${order.customerName}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "Tran ID : ${order.id.substring(0, order.id.length > 8 ? 8 : order.id.length)}",
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                  ),
                ),
                (() {
                  final hash = order.id.hashCode.abs();
                  final displayDue = order.scheduledDeliveryAt ?? order.updatedAt.add(Duration(days: (hash % 3) + 1));
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: Colors.black54),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "กำหนดส่ง: ${formatDateTime(displayDue)}",
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (dueTone != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: dueTone,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: dueTone.withOpacity(0.6),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                })(),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "-" * 38,
              maxLines: 1,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
            const SizedBox(height: 4),
            const Text(
              "รายการสินค้า",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            ...itemRows,
            const SizedBox(height: 6),
            Text(
              "-" * 38,
              maxLines: 1,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
            const SizedBox(height: 4),
            const Text(
              "สถานะขั้นตอนการทำงาน",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            ...stepWidgets,
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                (() {
                  String effectivePillStatus = _statusLabel(order.status == "out_for_delivery" || order.status == "delivery" || order.status == "delivered" ? order.status : order.orderWorkflowStatus);
                  if ((order.orderWorkflowStatus == "pending_board" || order.orderWorkflowStatus.isEmpty) &&
                      order.status != "out_for_delivery" &&
                      order.status != "delivery" &&
                      order.status != "delivered" &&
                      assignedSteps.isNotEmpty &&
                      activeStep >= 0 &&
                      activeStep < steps.length) {
                    final activeStepIndex = steps[activeStep]["index"] as int;
                    if (activeStepIndex == 1) effectivePillStatus = "รอผลิตหุ่นยนต์";
                    if (activeStepIndex == 2) effectivePillStatus = "รอตรวจ QC";
                    if (activeStepIndex == 3) effectivePillStatus = "กำลังส่ง";
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: brandPrimary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      effectivePillStatus,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: brandPrimary,
                      ),
                    ),
                  );
                })(),
                TextButton.icon(
                  onPressed: () => onOpenOrdersTab(),
                  icon: const Icon(Icons.arrow_forward, size: 12),
                  label: const Text("จัดการ", style: TextStyle(fontSize: 10)),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}
class WebDashboardHome extends StatelessWidget {
  const WebDashboardHome({
    super.key,
    required this.data,
    required this.onOpenOrdersTab,
    required this.productSearchController,
    required this.productSearch,
    required this.onProductSearchChanged,
    required this.onClearProductSearch,
    required this.matchedProducts,
    required this.onOpenAssistant,
    required this.onOpenOrders,
    required this.onOpenStock,
    required this.onOpenProductList,
    required this.onOpenProductDetails,
  });

  final DashboardData data;
  final VoidCallback onOpenOrdersTab;
  final TextEditingController productSearchController;
  final String productSearch;
  final ValueChanged<String> onProductSearchChanged;
  final VoidCallback onClearProductSearch;
  final List<Product> matchedProducts;
  final VoidCallback onOpenAssistant;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenStock;
  final void Function(
    BuildContext context,
    List<Product> products,
    String title,
    IconData icon,
    Color color,
  ) onOpenProductList;
  final void Function(BuildContext context, Product product)
      onOpenProductDetails;

  @override
  Widget build(BuildContext context) {
    final outOfStock = data.products.where((p) => p.currentStock <= 0).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _DashboardSectionHeader(
          eyebrow: "Overview",
          title: "ภาพรวมด่วน",
          subtitle: "สถานะและข้อมูลสำคัญของคลังสินค้าวันนี้",
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickStatCard(
              title: "สินค้าใกล้หมด",
              value: "${data.summary.lowStockCount}",
              subtitle: "รายการที่ควรเติมสต็อก",
              icon: Icons.warning_amber_rounded,
              tone: brandPrimary,
            ),
            _QuickStatCard(
              title: "ออเดอร์ค้างส่ง",
              value: "${data.activeOrders.length}",
              subtitle: "งานที่ยังต้องดำเนินการต่อ",
              icon: Icons.local_shipping_outlined,
              tone: profileTeal,
              onTap: onOpenOrdersTab,
            ),
            _QuickStatCard(
              title: "สินค้าทั้งหมด",
              value: "${data.summary.totalProducts}",
              subtitle: "พร้อมค้นหาและพิมพ์ป้าย",
              icon: Icons.inventory_2_rounded,
              tone: profileAccent,
            ),
          ],
        ),
        const SizedBox(height: 28),
        const _DashboardSectionHeader(
          eyebrow: "Order bills",
          title: "บิลออเดอร์ค้างส่ง",
          subtitle: "บิลรายการสินค้าสไตล์กระดาษใบเสร็จ (เลื่อนซ้าย-ขวาได้)",
        ),
        const SizedBox(height: 14),
        if (data.activeOrders.isEmpty)
          const _EmptyTile(message: "ยังไม่มีออเดอร์ค้างส่ง")
        else
          _HorizontalReceiptBillList(
            orders: data.activeOrders,
            onOpenOrdersTab: onOpenOrdersTab,
          ),
        const SizedBox(height: 28),
        const _DashboardSectionHeader(
          eyebrow: "Focus now",
          title: "ต้องดูต่อ",
          subtitle: "รายการสำคัญที่ควรเปิดเช็กจากหน้า dashboard",
        ),
        const SizedBox(height: 10),
        if (outOfStock.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: () => onOpenProductList(
                context,
                outOfStock,
                "สินค้าหมด",
                Icons.inventory_2_outlined,
                Colors.redAccent,
              ),
              icon: const Icon(Icons.inventory_2_outlined),
              label: Text("สินค้าหมด: ${outOfStock.length} รายการ"),
            ),
          ),
          const SizedBox(height: 10),
        ],
        ...data.summary.lowStockItems.take(3).map(
              (item) => _LowStockFocusCard(
                product: item,
                onTap: () => onOpenProductDetails(context, item),
              ),
            ),
        const SizedBox(height: 18),
      ],
    );
  }
}
class _StockHealthCard extends StatelessWidget {
  const _StockHealthCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _HoverLift(
      lift: onTap != null ? 4 : 0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withOpacity(onTap != null ? 0.24 : 0.12),
                width: onTap != null ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  "$count",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: brandDeep,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: brandInk.withOpacity(0.8),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverLift extends StatefulWidget {
  const _HoverLift({
    required this.child,
    this.lift = 8,
    this.scale = 1.01,
  });

  final Widget child;
  final double lift;
  final double scale;

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = kIsWeb && _hovered;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: active ? widget.scale : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, active ? -widget.lift : 0, 0),
          child: widget.child,
        ),
      ),
    );
  }
}

class _HeroReveal extends StatefulWidget {
  const _HeroReveal({
    required this.child,
    this.delayMs = 0,
  });

  final Widget child;
  final int delayMs;

  @override
  State<_HeroReveal> createState() => _HeroRevealState();
}

class _HeroRevealState extends State<_HeroReveal> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (!mounted) return;
      setState(() {
        _visible = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      offset: _visible ? Offset.zero : const Offset(0, 0.08),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 360),
        opacity: _visible ? 1 : 0,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _HeroInfoChip extends StatelessWidget {
  const _HeroInfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.70),
            Colors.white.withOpacity(0.50),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: brandPrimary.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: brandPrimary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: brandDeep,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSectionHeader extends StatelessWidget {
  const _DashboardSectionHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: brandPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: isDark ? darkTextPrimary : brandDeep,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? darkTextSecondary : brandInk.withOpacity(0.72),
              ),
        ),
      ],
    );
  }
}

class _ActionBanner extends StatelessWidget {
  const _ActionBanner({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.tone,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final accent = tone ?? brandPrimary;
    return _HoverLift(
      lift: 6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withOpacity(0.12),
                  Color.lerp(accent, profileTeal, 0.35)!.withOpacity(0.10),
                  brandSurfaceStrong.withOpacity(0.34),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: accent.withOpacity(0.14)),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.86),
                        Colors.white.withOpacity(0.68),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: brandDeep,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: brandInk.withOpacity(0.72),
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, color: brandDeep),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.tone,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _HoverLift(
      lift: 4,
      scale: 1.006,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            width: 250,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? darkCard : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? darkCardBorder.withOpacity(0.8) : tone.withOpacity(0.12)),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withOpacity(0.25) : tone.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tone.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: tone),
                ),
                const SizedBox(height: 14),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: isDark ? darkTextPrimary : brandDeep,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isDark ? darkTextPrimary : brandDeep,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? darkTextSecondary : brandInk.withOpacity(0.72),
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LowStockFocusCard extends StatelessWidget {
  const _LowStockFocusCard({
    required this.product,
    required this.onTap,
  });

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? darkCard : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: isDark ? darkCardBorder.withOpacity(0.8) : brandPrimary.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: brandPrimary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: brandPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: isDark ? darkTextPrimary : brandDeep,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${product.barcode} · คงเหลือ ${product.currentStock} ${product.unit}",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark ? darkTextSecondary : brandInk.withOpacity(0.74),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: brandPrimary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      "min ${product.minimumStock}",
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: brandPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "เปิดบาร์โค้ด",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: brandInk.withOpacity(0.62),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderStatusPill extends StatelessWidget {
  const _OrderStatusPill({
    required this.label,
    required this.tone,
  });

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: tone,
              fontWeight: FontWeight.w800,
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
      decoration: adaptivePanelDecoration(context, surfaceStrength: 0.45),
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
                        color: Theme.of(context).brightness == Brightness.dark ? darkTextPrimary : brandInk,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : brandInk.withOpacity(0.70),
                        height: 1.35,
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
