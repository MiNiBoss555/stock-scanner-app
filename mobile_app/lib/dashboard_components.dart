import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

import "models.dart";
import "theme/app_theme.dart";

class DashboardUpdateCard extends StatelessWidget {
  const DashboardUpdateCard({
    super.key,
    required this.order,
    required this.onTap,
  });

  final DeliveryOrder order;
  final VoidCallback onTap;

  String _displayStatusLabel() {
    switch (order.status) {
      case "new":
        return "ออเดอร์ใหม่";
      case "assigned":
        return "มอบหมายแล้ว";
      case "in_production":
        return "เริ่มผลิต";
      case "qc_pending":
        return "รอ QC";
      case "rework_required":
        return "ต้องแก้งาน";
      case "qc_passed":
        return "ผ่าน QC";
      case "preparing":
        return "กำลังจัดเตรียม";
      case "out_for_delivery":
        return "กำลังจัดส่ง";
      case "delivered":
        return "ส่งแล้ว";
      case "cancelled":
        return "ยกเลิก";
      default:
        return order.status;
    }
  }

  String _displayStageLabel() {
    switch (order.status) {
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
        return "ขั้นตอนตอนนี้: ${order.status}";
    }
  }

  int? _daysUntilDue() {
    final dueAt = order.scheduledDeliveryAt;
    if (dueAt == null) {
      return null;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueAt.year, dueAt.month, dueAt.day);
    return dueDay.difference(today).inDays;
  }

  String _fmtDueAt(DateTime value) {
    final dd = value.day.toString().padLeft(2, "0");
    final mm = value.month.toString().padLeft(2, "0");
    final yy = value.year;
    final hh = value.hour.toString().padLeft(2, "0");
    final min = value.minute.toString().padLeft(2, "0");
    return "$dd/$mm/$yy $hh:$min";
  }

  bool _isDueSoon() {
    final days = _daysUntilDue();
    if (days == null) {
      return false;
    }
    return days >= 0 && days <= 3;
  }

  String? _dueWarningLabel() {
    final days = _daysUntilDue();
    if (days == null) {
      return null;
    }
    if (days < 0) {
      return "เลยกำหนดส่งแล้ว";
    }
    if (days == 0) {
      return "ครบกำหนดส่งวันนี้";
    }
    if (days == 1) {
      return "ใกล้ถึงกำหนดส่งใน 1 วัน";
    }
    if (days <= 3) {
      return "ใกล้ถึงกำหนดส่งใน $days วัน";
    }
    return null;
  }

  bool _isUrgentDue() {
    final days = _daysUntilDue();
    return days != null && days <= 1;
  }

  Color _displayStatusTone() {
    final days = _daysUntilDue();
    if (days != null && days <= 1) {
      return const Color(0xFFD64545);
    }
    if (days == 2) {
      return const Color(0xFFF28C28);
    }
    if (days == 3) {
      return const Color(0xFFE0B21B);
    }
    switch (order.status) {
      case "out_for_delivery":
        return brandPrimary;
      case "in_production":
      case "qc_pending":
      case "qc_passed":
      case "preparing":
        return profileTeal;
      case "rework_required":
        return Colors.orange;
      default:
        return brandDeep;
    }
  }

  String _statusLabel() {
    switch (order.status) {
      case "assigned":
        return "กำลังจัดคิว";
      case "in_production":
        return "กำลังผลิต";
      case "qc_pending":
        return "รอ QC";
      case "rework_required":
        return "ตีกลับแก้";
      case "qc_passed":
        return "QC ผ่าน";
      case "preparing":
        return "กำลังจัดสินค้า";
      case "out_for_delivery":
        return "กำลังส่ง";
      case "delivered":
        return "ส่งแล้ว";
      case "cancelled":
        return "ยกเลิก";
      default:
        return "รอดำเนินการ";
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = _displayStatusTone();
    final dueWarning = _dueWarningLabel();
    final dueDays = _daysUntilDue();
    return _HoverLift(
      lift: 6,
      scale: 1.008,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              tone.withOpacity(0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: tone.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: tone.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: tone.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(Icons.receipt_rounded, color: tone),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: tone,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Order update",
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: tone,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                            ),
                            if (_isUrgentDue()) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: tone.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(999),
                                  border:
                                      Border.all(color: tone.withOpacity(0.32)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.priority_high_rounded,
                                      size: 14,
                                      color: tone,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "ด่วน",
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: tone,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: brandDeep,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _OrderStatusPill(
                              label: _displayStatusLabel(),
                              tone: tone,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "${order.items.length} รายการ · ผู้ส่ง: ${order.assignedToName ?? "ยังไม่มอบหมาย"}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: brandInk.withOpacity(0.74),
                                    fontSize: 13.4,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          order.scheduledDeliveryAt != null
                              ? "อัปเดต: ${_fmtDueAt(order.updatedAt)} · กำหนดส่ง: ${_fmtDueAt(order.scheduledDeliveryAt!)}"
                              : "อัปเดต: ${_fmtDueAt(order.updatedAt)}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: brandInk.withOpacity(0.68),
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _displayStageLabel(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: tone.withOpacity(0.92),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        if (dueWarning != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: tone.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: tone.withOpacity(0.28)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.notification_important_outlined,
                                  size: 16,
                                  color: tone,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        dueWarning,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: tone,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      if (order.scheduledDeliveryAt != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            "กำหนดส่ง: ${_fmtDueAt(order.scheduledDeliveryAt!)}",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: tone.withOpacity(0.92),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      if (dueDays != null && dueDays < 0)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Text(
                                            "เลยกำหนดส่งมา ${-dueDays} วัน",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: tone.withOpacity(0.92),
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.78),
                                borderRadius: BorderRadius.circular(999),
                                border:
                                    Border.all(color: tone.withOpacity(0.10)),
                              ),
                              child: Text(
                                "แตะเพื่อเปิดออเดอร์",
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: brandDeep,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: brandInk.withOpacity(0.38),
                  ),
                ],
              ),
            ),
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

class WebDashboardHero extends StatelessWidget {
  const WebDashboardHero({
    super.key,
    required this.onOpenAssistant,
    required this.onOpenOrders,
    required this.onOpenStock,
  });

  final VoidCallback onOpenAssistant;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenStock;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 900 ? 38.0 : (width < 1200 ? 46.0 : 52.0);
    final subtitleSize = width < 900 ? 14.0 : (width < 1200 ? 15.5 : 17.0);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(brandSurface, brandSurfaceStrong, 0.42)!,
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: brandPrimary.withOpacity(0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1FB56A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Dashboard workspace",
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: brandDeep,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "STOCK SCANNER",
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: brandDeep,
                    fontWeight: FontWeight.w900,
                    fontSize: titleSize,
                    height: 0.98,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              "หน้าแรกสำหรับใช้งานบน Chrome\nคัดลอกข้อมูลลูกค้าแล้ววางสร้างออเดอร์ได้ทันที",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: brandInk.withOpacity(0.84),
                    fontSize: subtitleSize,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _HeroInfoChip(
                  icon: Icons.content_paste_go_rounded,
                  label: "คัดลอกลูกค้าแล้วสร้างออเดอร์ต่อได้ทันที",
                ),
                _HeroInfoChip(
                  icon: Icons.bolt_rounded,
                  label: "เข้าถึงงานสต็อกและผู้ช่วยได้เร็ว",
                ),
                _HeroInfoChip(
                  icon: Icons.auto_awesome_rounded,
                  label: "พร้อมสำหรับ workflow บน Chrome",
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _HeroQuickTile(
                  label: "Orders",
                  icon: Icons.receipt_rounded,
                  hint: "เปิดออเดอร์และจัดส่ง",
                  onTap: onOpenOrders,
                  accentColor: brandPrimary,
                ),
                _HeroQuickTile(
                  label: "Stock",
                  icon: Icons.inventory_2_rounded,
                  hint: "ค้นหาสินค้าและพิมพ์ป้าย",
                  onTap: onOpenStock,
                  accentColor: profileTeal,
                ),
                _HeroQuickTile(
                  label: "Assistant",
                  icon: Icons.smart_toy_rounded,
                  hint: "ถามสต็อกและขอไฟล์",
                  onTap: onOpenAssistant,
                  accentColor: profileAccent,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.70),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: brandPrimary.withOpacity(0.10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: brandPrimary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.show_chart_rounded,
                            color: Colors.white),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1FB56A),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              "Live",
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: brandDeep,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.rocket_launch_rounded,
                            color: brandPrimary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "โหมดใช้งานเร็วสำหรับเปิดออเดอร์และสต็อกต่อเนื่อง",
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: brandInk.withOpacity(0.76),
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "พร้อมสำหรับงานวันนี้",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: brandDeep,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "เปิดออเดอร์ เช็กสต็อก หรือเข้า assistant ได้จากทางลัดด้านบนโดยไม่ต้องไล่หาหลายหน้า",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: brandInk.withOpacity(0.76),
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1FB56A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Workspace online",
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: brandDeep,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        Text(
                          "2026-05-08-dashboard-v1",
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: brandInk.withOpacity(0.55),
                                  ),
                        ),
                      ],
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

class DashboardIdentityCard extends StatelessWidget {
  const DashboardIdentityCard({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.roleLabel,
    this.positionLabel,
  });

  final String? imageUrl;
  final String name;
  final String roleLabel;
  final String? positionLabel;

  @override
  Widget build(BuildContext context) {
    final woodTone = Color.lerp(brandPrimary, brandSurfaceStrong, 0.34)!;
    final woodDeep = Color.lerp(brandDeep, brandPrimary, 0.20)!;

    return Container(
      decoration: BoxDecoration(
        color: brandCard,
        borderRadius: BorderRadius.circular(radiusXl),
        border: Border.all(color: brandPrimary.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: brandPrimary.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radiusXl),
        child: Stack(
          children: [
            Positioned(
              right: -24,
              top: -24,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: brandPrimary.withOpacity(0.04),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: woodTone, width: 2.2),
                      boxShadow: [
                        BoxShadow(
                          color: brandPrimary.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: imageUrl != null && imageUrl!.isNotEmpty
                          ? Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _fallbackAvatar(name, woodTone),
                            )
                          : _fallbackAvatar(name, woodTone),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: woodDeep,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 19,
                                    letterSpacing: 0.2,
                                  ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: woodTone.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                roleLabel,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: woodTone,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            if (positionLabel != null &&
                                positionLabel!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                positionLabel!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: brandInk.withOpacity(0.65),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ],
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

  Widget _fallbackAvatar(String userName, Color color) {
    final initial = userName.trim().isNotEmpty ? userName.trim()[0] : "?";
    return Container(
      color: color.withOpacity(0.08),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
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
                  color: brandInk.withOpacity(0.80),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _HeroQuickTile extends StatelessWidget {
  const _HeroQuickTile({
    required this.label,
    required this.icon,
    required this.hint,
    required this.onTap,
    required this.accentColor,
  });

  final String label;
  final IconData icon;
  final String hint;
  final VoidCallback onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 1100;
    return _HoverLift(
      lift: 10,
      scale: 1.012,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: compact ? 222 : 248,
          padding: EdgeInsets.all(compact ? 16 : 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.94),
                Color.lerp(Colors.white, accentColor, 0.08)!.withOpacity(0.92),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accentColor.withOpacity(0.16)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.12),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 46 : 50,
                height: compact ? 46 : 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withOpacity(0.18),
                      Color.lerp(brandSurfaceStrong, accentColor, 0.24)!
                          .withOpacity(0.34),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: brandDeep,
                            fontWeight: FontWeight.w800,
                            fontSize: compact ? 16 : 17,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hint,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: brandInk.withOpacity(0.72),
                            fontSize: compact ? 12.4 : 13.2,
                            height: 1.32,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        "Open now",
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: accentColor,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                color: accentColor.withOpacity(0.82),
                size: 20,
              ),
            ],
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
