import "dart:async";
import "package:flutter/material.dart";
import "api_service.dart";
import "models.dart";
import "empty_state.dart";
import "loading_state.dart";
import "theme/app_theme.dart";

class ProductActivityLogPage extends StatefulWidget {
  const ProductActivityLogPage({
    super.key,
    required this.api,
    required this.currentUser,
  });

  final StockApiService api;
  final AppUser currentUser;

  @override
  State<ProductActivityLogPage> createState() => _ProductActivityLogPageState();
}

class _ProductActivityLogPageState extends State<ProductActivityLogPage> {
  List<ProductActivityLog> _logs = [];
  bool _isLoading = true;
  String? _errorMessage;

  final TextEditingController _barcodeController = TextEditingController();
  String _selectedAction = "ทั้งหมด";
  int _limit = 50;

  final List<String> _actions = ["ทั้งหมด", "archive", "restore", "hard_delete"];

  @override
  void initState() {
    super.initState();
    if (widget.currentUser.isAdmin) {
      _loadLogs();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    if (!widget.currentUser.isAdmin) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final barcode = _barcodeController.text.trim();
      final action = _selectedAction == "ทั้งหมด" ? null : _selectedAction;

      final logs = await widget.api.getProductActivityLogs(
        barcode: barcode.isNotEmpty ? barcode : null,
        action: action,
        limit: _limit,
        requesterId: widget.currentUser.userId,
      );

      if (mounted) {
        setState(() {
          _logs = logs;
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

  Color _getActionColor(String action) {
    switch (action) {
      case "archive":
        return Colors.orange.shade700;
      case "restore":
        return Colors.green.shade700;
      case "hard_delete":
        return Colors.red.shade700;
      default:
        return Colors.blue.shade700;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case "archive":
        return Icons.archive_outlined;
      case "restore":
        return Icons.settings_backup_restore_outlined;
      case "hard_delete":
        return Icons.delete_forever_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _getActionTextThai(String action) {
    switch (action) {
      case "archive":
        return "ปิดใช้งานสินค้า (Archive)";
      case "restore":
        return "กู้คืนสินค้า (Restore)";
      case "hard_delete":
        return "ลบสินค้าถาวร (Hard Delete)";
      default:
        return action;
    }
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("ประวัติกิจกรรมสินค้า"),
        backgroundColor: brandPrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: "รีเฟรชข้อมูล",
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter section
          Card(
            margin: const EdgeInsets.all(12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _barcodeController,
                          decoration: InputDecoration(
                            labelText: "ค้นหาบาร์โค้ด",
                            hintText: "กรอกบาร์โค้ดเพื่อค้นหา",
                            prefixIcon: const Icon(Icons.qr_code_scanner),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onSubmitted: (_) => _loadLogs(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _loadLogs,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Icon(Icons.search),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Action chip filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _actions.map((action) {
                        final isSelected = _selectedAction == action;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            label: Text(
                              action == "ทั้งหมด" ? "ทั้งหมด" : _getActionTextThai(action).split(" ")[0],
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: brandPrimary,
                            backgroundColor: Colors.grey.shade200,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            onSelected: (bool selected) {
                              if (selected) {
                                setState(() {
                                  _selectedAction = action;
                                });
                                _loadLogs();
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "แสดงผลสูงสุด:",
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      DropdownButton<int>(
                        value: _limit,
                        items: [20, 50, 100, 200].map((int val) {
                          return DropdownMenuItem<int>(
                            value: val,
                            child: Text("$val รายการ", style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (int? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _limit = newValue;
                            });
                            _loadLogs();
                          }
                        },
                        underline: Container(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // List section
          Expanded(
            child: _isLoading
                ? const LoadingState(message: "กำลังโหลดประวัติกิจกรรม...")
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
                              onPressed: _loadLogs,
                              child: const Text("ลองใหม่"),
                            ),
                          ],
                        ),
                      )
                    : _logs.isEmpty
                        ? const EmptyState(
                            icon: Icons.history_outlined,
                            title: "ยังไม่มีกิจกรรมสินค้า",
                            message: "เมื่อมีการซ่อน กู้คืน หรือลบถาวร ระบบจะแสดงประวัติที่นี่",
                          )
                        : RefreshIndicator(
                            onRefresh: _loadLogs,
                            child: ListView.builder(
                              itemCount: _logs.length,
                              itemBuilder: (context, index) {
                                final log = _logs[index];
                                final actionColor = _getActionColor(log.action);
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: actionColor.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: actionColor.withValues(alpha: 0.1),
                                              foregroundColor: actionColor,
                                              child: Icon(_getActionIcon(log.action)),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _getActionTextThai(log.action),
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: actionColor,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    log.productName,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  Text(
                                                    "บาร์โค้ด: ${log.barcode}",
                                                    style: TextStyle(
                                                      color: Colors.grey.shade600,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              _formatDateTime(log.createdAt),
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (log.note != null && log.note!.isNotEmpty) ...[
                                          const Divider(height: 16),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.note_alt_outlined,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  log.note!,
                                                  style: const TextStyle(
                                                    color: Colors.black87,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        const Divider(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.person_outline,
                                                  size: 16,
                                                  color: Colors.grey,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  "ผู้ดำเนินการ: ${log.actorName}",
                                                  style: const TextStyle(
                                                    color: Colors.black54,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              "ID: ${log.actorId}",
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
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
