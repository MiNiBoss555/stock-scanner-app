import "package:flutter/material.dart";

import "../theme/app_theme.dart";

enum OrderStatusTab {
  all,
  pending,
  working,
  qc,
  shipping,
  delivered,
  cancelled,
}

extension OrderStatusTabInfo on OrderStatusTab {
  String get label {
    switch (this) {
      case OrderStatusTab.all:
        return "ทั้งหมด";
      case OrderStatusTab.pending:
        return "รอดำเนินการ";
      case OrderStatusTab.working:
        return "กำลังดำเนินการ";
      case OrderStatusTab.qc:
        return "รอ QC";
      case OrderStatusTab.shipping:
        return "รอจัดส่ง";
      case OrderStatusTab.delivered:
        return "จัดส่งแล้ว";
      case OrderStatusTab.cancelled:
        return "ยกเลิก";
    }
  }

  IconData get icon {
    switch (this) {
      case OrderStatusTab.all:
        return Icons.all_inbox_rounded;
      case OrderStatusTab.pending:
        return Icons.hourglass_empty_rounded;
      case OrderStatusTab.working:
        return Icons.build_circle_rounded;
      case OrderStatusTab.qc:
        return Icons.check_circle_outline_rounded;
      case OrderStatusTab.shipping:
        return Icons.local_shipping_rounded;
      case OrderStatusTab.delivered:
        return Icons.done_all_rounded;
      case OrderStatusTab.cancelled:
        return Icons.cancel_outlined;
    }
  }

  Color badgeColor(BuildContext context) {
    return semanticStatusTone(swatch);
  }

  SemanticStatus get swatch {
    switch (this) {
      case OrderStatusTab.all:
        return SemanticStatus.neutral;
      case OrderStatusTab.pending:
        return SemanticStatus.pending;
      case OrderStatusTab.working:
        return SemanticStatus.working;
      case OrderStatusTab.qc:
        return SemanticStatus.qc;
      case OrderStatusTab.shipping:
        return SemanticStatus.working;
      case OrderStatusTab.delivered:
        return SemanticStatus.delivered;
      case OrderStatusTab.cancelled:
        return SemanticStatus.rejected;
    }
  }

  bool matches(String? status) {
    final s = (status ?? "").toLowerCase().trim();
    switch (this) {
      case OrderStatusTab.all:
        return true;
      case OrderStatusTab.pending:
        return s == "" || s == "new" || s == "pending";
      case OrderStatusTab.working:
        return s == "assigned" ||
            s == "in_production" ||
            s == "rework_required" ||
            s == "qc_passed";
      case OrderStatusTab.qc:
        return s == "qc_pending";
      case OrderStatusTab.shipping:
        return s == "preparing" || s == "out_for_delivery";
      case OrderStatusTab.delivered:
        return s == "delivered";
      case OrderStatusTab.cancelled:
        return s == "cancelled";
    }
  }
}

const visibleOrderStatusTabs = [
  OrderStatusTab.all,
  OrderStatusTab.pending,
  OrderStatusTab.working,
  OrderStatusTab.qc,
  OrderStatusTab.shipping,
  OrderStatusTab.delivered,
  OrderStatusTab.cancelled,
];

class OrdersStatusTabs extends StatelessWidget {
  const OrdersStatusTabs({
    super.key,
    required this.selectedTab,
    required this.counts,
    required this.onChanged,
  });

  final OrderStatusTab selectedTab;
  final Map<OrderStatusTab, int> counts;
  final ValueChanged<OrderStatusTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Material(
      color: Colors.transparent,
      child: Container(
        key: const Key("orders_status_tabs"),
        height: 34,
        margin: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            key: const Key("orders_status_tabs_scroll"),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.hardEdge,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: visibleOrderStatusTabs.map((tab) {
                final isSelected = tab == selectedTab;
                final count = counts[tab] ?? 0;
                final labelText = tab.label;
                final color = tab.badgeColor(context);

                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: Key("tab_$labelText"),
                        onTap: () => onChanged(tab),
                        borderRadius: BorderRadius.circular(18),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryColor
                                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? primaryColor
                                  : theme.colorScheme.outline.withValues(alpha: 0.12),
                              width: 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: primaryColor.withValues(alpha: 0.25),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tab.icon,
                                size: 12,
                                color: isSelected
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                labelText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 3),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                constraints: const BoxConstraints(minWidth: 16),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.colorScheme.onPrimary.withValues(alpha: 0.22)
                                      : (count > 0
                                          ? color.withValues(alpha: 0.15)
                                          : theme.colorScheme.onSurface.withValues(alpha: 0.08)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "$count",
                                  key: Key("tab_count_$labelText"),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected
                                        ? theme.colorScheme.onPrimary
                                        : (count > 0
                                            ? color
                                            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
