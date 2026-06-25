import "dart:async";
import "package:flutter/material.dart";
import "api_service.dart";
import "models.dart";
import "empty_state.dart";
import "loading_state.dart";

class ProductTimelinePage extends StatefulWidget {
  const ProductTimelinePage({
    super.key,
    required this.api,
    required this.currentUser,
    required this.barcode,
    this.productName,
  });

  final StockApiService api;
  final AppUser currentUser;
  final String barcode;
  final String? productName;

  @override
  State<ProductTimelinePage> createState() => _ProductTimelinePageState();
}

class _ProductTimelinePageState extends State<ProductTimelinePage> {
  List<ProductTimelineItem> _timelineItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await widget.api.getProductTimeline(
        barcode: widget.barcode,
        requesterId: widget.currentUser.userId,
      );

      if (mounted) {
        setState(() {
          _timelineItems = items;
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

  String _formatDateTime(DateTime dt) {
    final year = dt.year;
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return "$year-$month-$day $hour:$minute";
  }

  Color _getItemColor(ProductTimelineItem item) {
    if (item.type == "movement") {
      switch (item.action) {
        case "in":
          return Colors.green;
        case "out":
          return Colors.blue;
        case "issue":
          return Colors.red;
        default:
          return Colors.grey;
      }
    } else {
      switch (item.action) {
        case "restore":
          return Colors.teal;
        case "archive":
          return Colors.orange;
        case "hard_delete":
          return Colors.red.shade900;
        default:
          return Colors.purple;
      }
    }
  }

  IconData _getItemIcon(ProductTimelineItem item) {
    if (item.type == "movement") {
      switch (item.action) {
        case "in":
          return Icons.add_circle_outline;
        case "out":
          return Icons.remove_circle_outline;
        case "issue":
          return Icons.report_problem_outlined;
        default:
          return Icons.swap_horiz_outlined;
      }
    } else {
      switch (item.action) {
        case "restore":
          return Icons.settings_backup_restore_outlined;
        case "archive":
          return Icons.archive_outlined;
        case "hard_delete":
          return Icons.delete_forever_outlined;
        default:
          return Icons.info_outline;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayedName = widget.productName ??
        (_timelineItems.isNotEmpty ? _timelineItems.first.productName : "");

    return Scaffold(
      appBar: AppBar(
        title: const Text("ไทม์ไลน์สินค้า"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTimeline,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTimeline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayedName.isNotEmpty ? displayedName : "กำลังโหลดข้อมูล...",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.qr_code,
                        size: 16,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.barcode,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: "monospace",
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const LoadingState(message: "กำลังโหลดข้อมูลไทม์ไลน์...");
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadTimeline,
                child: const Text("ลองใหม่"),
              ),
            ],
          ),
        ),
      );
    }

    if (_timelineItems.isEmpty) {
      return const EmptyState(
        icon: Icons.timeline_outlined,
        title: "ยังไม่มีประวัติสำหรับสินค้านี้",
        message: "เมื่อมีการรับเข้า เบิกออก ซ่อน หรือกู้คืน Timeline จะแสดงที่นี่",
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _timelineItems.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemBuilder: (context, index) {
        final item = _timelineItems[index];
        final isLast = index == _timelineItems.length - 1;
        final color = _getItemColor(item);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timeline Node Line & Circle Icon
              Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                    child: Icon(
                      _getItemIcon(item),
                      size: 16,
                      color: color,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: Colors.grey.shade300,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // Content Card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Card(
                    margin: EdgeInsets.zero,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _formatDateTime(item.createdAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (item.type == "movement" &&
                              item.beforeStock != null &&
                              item.afterStock != null) ...[
                            Row(
                              children: [
                                Text(
                                  "จำนวน: ",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  "${item.action == 'in' ? '+' : '-'}${item.quantity}",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "คงเหลือ: ${item.beforeStock} → ${item.afterStock}",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "ผู้บันทึก: ${item.actorName} (${item.actorId})",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          if (item.description != null &&
                              item.description!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                              child: Text(
                                item.description!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
