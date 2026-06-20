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

  Color _statusTone(String status) {
    switch (status) {
      case "new":
        return const Color(0xFF7DB8E8);
      case "assigned":
        return profileTeal;
      case "in_production":
        return const Color(0xFF5B8CFF);
      case "qc_pending":
        return const Color(0xFFF5A623);
      case "qc_passed":
        return const Color(0xFF2E9E6F);
      case "preparing":
        return const Color(0xFF8A6DFF);
      case "out_for_delivery":
        return brandPrimary;
      case "delivered":
        return brandDeep;
      case "cancelled":
        return const Color(0xFFD64545);
      default:
        return brandInk;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case "new":
        return "ใหม่";
      case "assigned":
        return "มอบหมายแล้ว";
      case "in_production":
        return "กำลังผลิต";
      case "qc_pending":
        return "รอ QC";
      case "rework_required":
        return "ต้องแก้ไข";
      case "qc_passed":
        return "ผ่าน QC";
      case "preparing":
        return "กำลังจัดสินค้า";
      case "out_for_delivery":
        return "กำลังส่ง";
      case "delivered":
        return "ส่งแล้ว";
      case "cancelled":
        return "ยกเลิก";
      default:
        return status;
    }
  }

  String _stageLabel(String status) {
    switch (status) {
      case "new":
        return "ขั้นตอนตอนนี้: รอเริ่มงาน";
      case "assigned":
        return "ขั้นตอนตอนนี้: มอบหมายผู้รับผิดชอบแล้ว";
      case "in_production":
        return "ขั้นตอนตอนนี้: อยู่ระหว่างผลิต";
      case "qc_pending":
        return "ขั้นตอนตอนนี้: รอตรวจคุณภาพ";
      case "rework_required":
        return "ขั้นตอนตอนนี้: ต้องแก้ไขก่อนส่งต่อ";
      case "qc_passed":
        return "ขั้นตอนตอนนี้: ผ่าน QC แล้ว";
      case "preparing":
        return "ขั้นตอนตอนนี้: กำลังจัดของ";
      case "out_for_delivery":
        return "ขั้นตอนตอนนี้: ออกจัดส่งแล้ว";
      case "delivered":
        return "ขั้นตอนตอนนี้: ส่งสำเร็จ";
      case "cancelled":
        return "ขั้นตอนตอนนี้: ยกเลิกออเดอร์";
      default:
        return "ขั้นตอนตอนนี้: $status";
    }
  }

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
      return const Color(0xFFD64545);
    }
    if (days == 2) {
      return const Color(0xFFF28C28);
    }
    if (days == 3) {
      return const Color(0xFFE0B21B);
    }
    return null;
  }

  BoxDecoration _mobileOrderDecoration(Color tone, {bool emphasize = false}) {
    final base = emphasize ? tone.withOpacity(0.16) : tone.withOpacity(0.10);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.96),
          base,
          tone.withOpacity(emphasize ? 0.12 : 0.08),
        ],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: tone.withOpacity(0.16)),
      boxShadow: [
        BoxShadow(
          color: tone.withOpacity(0.10),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  Widget _buildMobileOrderCard(
    BuildContext context,
    DeliveryOrder order, {
    required bool emphasizeDue,
    String? eyebrow,
    String? supporting,
  }) {
    final tone = _statusTone(order.status);
    final dueTone = _dueTone(order);
    final accent = dueTone ?? tone;
    final dueText = order.scheduledDeliveryAt != null
        ? "กำหนดส่ง: ${formatDateTime(order.scheduledDeliveryAt!)}"
        : "อัปเดต: ${formatDateTime(order.updatedAt)}";
    final supportingText = supporting ??
        "${order.items.length} รายการ · ผู้ส่ง: ${order.createdByName}";

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _HoverLift(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onOpenOrderPreview(order),
            borderRadius: BorderRadius.circular(24),
            child: Ink(
              decoration: _mobileOrderDecoration(
                accent,
                emphasize: emphasizeDue || dueTone != null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null) ...[
                      Text(
                        eyebrow.toUpperCase(),
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.88),
                                accent.withOpacity(0.18),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            emphasizeDue
                                ? Icons.notification_important_outlined
                                : Icons.receipt_rounded,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: brandDeep,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                supportingText,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: brandInk.withOpacity(0.70),
                                      height: 1.35,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _OrderStatusPill(
                          label: _statusLabel(order.status),
                          tone: accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _stageLabel(order.status),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: brandDeep,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 16, color: accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dueText,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: accent,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        ),
                      ],
                    ),
                    if (dueTone != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: dueTone.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: dueTone.withOpacity(0.16)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.priority_high_rounded,
                              size: 18,
                              color: dueTone,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "ออเดอร์นี้ใกล้ถึงกำหนดส่งแล้ว",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: dueTone,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latestOrders = data.activeOrders.take(4).toList();
    final todayOrders = data.todayUpdatedOrders.take(4).toList();
    final unreadOrders = data.activeOrders
        .where((order) => order.unreadCount > 0)
        .toList()
      ..sort((a, b) => b.unreadCount.compareTo(a.unreadCount));
    final outOfStock = data.products.where((p) => p.currentStock <= 0).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final lowStock = data.products
        .where((p) => p.currentStock > 0 && p.currentStock <= p.minimumStock)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return ColoredBox(
      color: brandSurface,
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
            decoration: softPanelDecoration(
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
                          color: brandDeep,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "เช็กงานที่ต้องตามต่อวันนี้ได้ในหน้าเดียว",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: brandInk.withOpacity(0.72),
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
          const SizedBox(height: 18),
          if (data.activeOrders.isNotEmpty)
            _ActionBanner(
              title: "งานค้างส่ง ${data.activeOrders.length} ออเดอร์",
              subtitle: "แตะเพื่อเปิดหน้าออเดอร์และจัดการงานค้างต่อ",
              icon: Icons.local_shipping_outlined,
              onTap: onOpenOrdersTab,
            ),
          if (outOfStock.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ActionBanner(
              title: "สินค้าหมด: ${outOfStock.length} รายการ",
              subtitle: outOfStock.take(3).map((p) => p.name).join(" · "),
              icon: Icons.inventory_2_outlined,
              tone: Colors.redAccent,
              onTap: () => onOpenProductList(
                context,
                outOfStock,
                "สินค้าหมด",
                Icons.inventory_2_outlined,
                Colors.redAccent,
              ),
            ),
          ],
          if (unreadOrders.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ActionBanner(
              title: "แชทค้างอ่าน ${unreadOrders.length} ออเดอร์",
              subtitle: unreadOrders
                  .take(3)
                  .map((o) => "${o.customerName} (+${o.unreadCount})")
                  .join(" • "),
              icon: Icons.mark_chat_unread_rounded,
              tone: Colors.redAccent,
              onTap: onOpenOrdersTab,
            ),
          ],
          const SizedBox(height: 22),
          const _DashboardSectionHeader(
            eyebrow: "Focus now",
            title: "ออเดอร์ล่าสุด",
            subtitle: "ดูสถานะ ขั้นตอนปัจจุบัน และกำหนดส่งได้ทันที",
          ),
          const SizedBox(height: 12),
          if (latestOrders.isEmpty)
            const _EmptyTile(message: "ยังไม่มีรายการออเดอร์")
          else
            ...latestOrders.map(
              (order) => _buildMobileOrderCard(
                context,
                order,
                emphasizeDue: _dueTone(order) != null,
              ),
            ),
          const SizedBox(height: 8),
          const _DashboardSectionHeader(
            eyebrow: "Realtime feed",
            title: "อัปเดตใหม่วันนี้",
            subtitle: "รายการที่มีการเปลี่ยนแปลงล่าสุดในวันนี้",
          ),
          const SizedBox(height: 12),
          if (todayOrders.isEmpty)
            const _EmptyTile(message: "ยังไม่มีออเดอร์ที่อัปเดตใหม่วันนี้")
          else
            ...todayOrders.map(
              (order) => _buildMobileOrderCard(
                context,
                order,
                emphasizeDue: false,
                eyebrow: "Order update",
                supporting: "อัปเดต ${formatDateTime(order.updatedAt)}",
              ),
            ),
        ],
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
    final unreadOrders = data.activeOrders
        .where((order) => order.unreadCount > 0)
        .toList()
      ..sort((a, b) => b.unreadCount.compareTo(a.unreadCount));
    final outOfStock = data.products.where((p) => p.currentStock <= 0).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        WebDashboardHero(
          onOpenAssistant: onOpenAssistant,
          onOpenOrders: onOpenOrders,
          onOpenStock: onOpenStock,
        ),
        const SizedBox(height: 22),
        const _DashboardSectionHeader(
          eyebrow: "Order focus",
          title: "งานค้างส่ง",
          subtitle: "ดูออเดอร์ล่าสุดและเช็กขั้นตอนงานได้ทันทีจากด้านบน",
        ),
        const SizedBox(height: 10),
        if (data.activeOrders.isEmpty)
          const _EmptyTile(message: "ยังไม่มีออเดอร์ค้างส่ง")
        else ...[
          if (unreadOrders.isNotEmpty) ...[
            _HeroReveal(
              delayMs: 40,
              child: _ActionBanner(
                title: "แชทค้างอ่าน ${unreadOrders.length} ออเดอร์",
                subtitle: unreadOrders
                    .take(3)
                    .map((o) => "${o.customerName} (+${o.unreadCount})")
                    .join(" · "),
                icon: Icons.chat_bubble_outline,
                tone: Colors.redAccent,
                onTap: onOpenOrdersTab,
              ),
            ),
            const SizedBox(height: 12),
          ],
          _HeroReveal(
            delayMs: 80,
            child: _ActionBanner(
              title: "งานค้างส่ง ${data.activeOrders.length} ออเดอร์",
              subtitle:
                  "แตะเพื่อเปิดหน้าออเดอร์ หรือดูขั้นตอนปัจจุบันจากรายการด้านล่าง",
              icon: Icons.local_shipping_outlined,
              onTap: onOpenOrdersTab,
            ),
          ),
          const SizedBox(height: 12),
          ...data.activeOrders.toList().asMap().entries.map(
                (entry) => _HeroReveal(
                  delayMs: 120 + (entry.key * 40),
                  child: DashboardUpdateCard(
                    order: entry.value,
                    onTap: onOpenOrdersTab,
                  ),
                ),
              ),
          const SizedBox(height: 18),
        ],
        // Keep the homepage short: move product search to the Stock tab.
        const SizedBox(height: 18),
        const _DashboardSectionHeader(
          eyebrow: "Overview",
          title: "ภาพรวมด่วน",
          subtitle: "แตะการ์ดเพื่อไปยังงานที่ควรทำต่อทันที",
        ),
        const SizedBox(height: 10),
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
              subtitle: "งานที่ยังต้องติดตาม",
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
        const SizedBox(height: 18),
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
                color: brandDeep,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: brandInk.withOpacity(0.72),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: tone.withOpacity(0.12)),
              boxShadow: [
                BoxShadow(
                  color: tone.withOpacity(0.08),
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
                        color: brandDeep,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: brandPrimary.withOpacity(0.12)),
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
                            color: brandDeep,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${product.barcode} · คงเหลือ ${product.currentStock} ${product.unit}",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: brandInk.withOpacity(0.74),
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: brandInk.withOpacity(0.70),
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
