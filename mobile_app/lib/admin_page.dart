import "dart:async";
import "dart:io";
import "package:file_picker/file_picker.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:flutter/services.dart" show Clipboard, ClipboardData;
import "package:path_provider/path_provider.dart" show getTemporaryDirectory;
import "package:share_plus/share_plus.dart" show Share, XFile;
import "package:url_launcher/url_launcher.dart" show launchUrl, LaunchMode;

import "api_service.dart";
import "models.dart";
import "theme/app_theme.dart";

class AdminPage extends StatefulWidget {
  const AdminPage({
    super.key,
    required this.api,
    required this.currentUser,
  });

  final StockApiService api;
  final AppUser currentUser;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool _isRunning = false;
  String? _lastMessage;
  late Future<Map<String, ExportLink>> _exportLinksFuture;
  final TextEditingController _downloadSearchController =
      TextEditingController();
  String _downloadSearch = "";
  String _downloadTypeFilter = "all";

  Future<void> _exportOrdersBackorderCsv() async {
    final orders =
        await widget.api.getOrders(requesterId: widget.currentUser.userId);
    final buffer = StringBuffer()
      ..writeln(
          "order_id,customer_name,status,assigned_to,created_by,items,delivered_items,backorder");
    for (final order in orders) {
      final totalItems = order.items.length;
      final deliveredItems =
          order.items.where((i) => i.deliveredQuantity >= i.quantity).length;
      final backorder = order.items
          .where((i) => i.deliveredQuantity < i.quantity)
          .map((i) => "${i.productName}:${i.quantity - i.deliveredQuantity}")
          .join("|");
      final esc = (String v) => "\"${v.replaceAll("\"", "\"\"")}\"";
      buffer.writeln([
        esc(order.id),
        esc(order.customerName),
        esc(order.status),
        esc(order.assignedToName ?? ""),
        esc(order.createdByName),
        totalItems,
        deliveredItems,
        esc(backorder),
      ].join(","));
    }
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/orders_backorder_report.csv");
    await file.writeAsString(buffer.toString(), flush: true);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: "รายงานออเดอร์และค้างจ่าย",
    );
  }

  @override
  void initState() {
    super.initState();
    _exportLinksFuture = _loadExportLinks();
  }

  @override
  void dispose() {
    _downloadSearchController.dispose();
    super.dispose();
  }

  Future<Map<String, ExportLink>> _loadExportLinks() async {
    final requesterId = widget.currentUser.userId;
    final results = await Future.wait([
      widget.api.createExportLink(
          exportName: "products_csv", requesterId: requesterId),
      widget.api
          .createExportLink(exportName: "users_csv", requesterId: requesterId),
      widget.api.createExportLink(
        exportName: "movements_csv",
        requesterId: requesterId,
        movementLimit: 500,
      ),
      widget.api.createExportLink(
        exportName: "all_xlsx",
        requesterId: requesterId,
        movementLimit: 5000,
      ),
    ]);
    return {
      "products": results[0],
      "users": results[1],
      "movements": results[2],
      "excel": results[3],
    };
  }

  void _refreshExportLinks() {
    setState(() {
      _exportLinksFuture = _loadExportLinks();
    });
  }

  Future<void> _runAction(Future<String> Function() action) async {
    if (!widget.currentUser.isAdmin) {
      _showSnack("เฉพาะ admin เท่านั้นที่ใช้งานหน้านี้ได้");
      return;
    }

    setState(() {
      _isRunning = true;
    });
    try {
      final message = await action();
      setState(() {
        _lastMessage = message;
      });
      _showSnack(message);
    } catch (error) {
      _showSnack(error.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  Future<void> _downloadAndShareBackup() async {
    if (!widget.currentUser.isAdmin) return;

    _showSnack("กำลังสำรองข้อมูล...");

    setState(() {
      _isRunning = true;
    });
    try {
      debugPrint("Starting downloadBackup for user: ${widget.currentUser.userId}");
      final bytes = await widget.api.downloadBackup(widget.currentUser.userId);
      debugPrint("downloadBackup completed, received ${bytes.length} bytes");

      final dir = await getTemporaryDirectory();

      final now = DateTime.now();
      final timestamp = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_"
          "${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";

      final file = File("${dir.path}/backup_$timestamp.zip");
      await file.writeAsBytes(bytes, flush: true);

      debugPrint("Backup file written to: ${file.path}");

      await Share.shareXFiles(
        [XFile(file.path)],
        text: "Backup System Data",
      );

      _showSnack("ดาวน์โหลดไฟล์สำรองแล้ว");

      if (mounted) {
        setState(() {
          _lastMessage = "ดาวน์โหลดไฟล์สำรองแล้ว";
        });
      }
    } catch (error) {
      debugPrint("Backup failed: $error");
      _showSnack(error.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  Future<bool> _confirmRestoreBackup() async {
    final controller = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Restore System Data"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "WARNING: DESTRUCTIVE ACTION!",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "This will completely REPLACE the current database and all uploaded files. This cannot be undone.",
                ),
                const SizedBox(height: 12),
                const Text(
                  "Type RESTORE in the field below to confirm this action.",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  inputFormatters: [UpperCaseTextFormatter()],
                  decoration: const InputDecoration(
                    labelText: "Confirmation",
                    hintText: "RESTORE",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("CANCEL"),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  final isMatch = value.text.trim().toUpperCase() == "RESTORE";
                  return FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: isMatch ? Colors.red : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isMatch
                        ? () => Navigator.of(context).pop(true)
                        : null,
                    child: const Text("CONFIRM RESTORE"),
                  );
                },
              ),
            ],
          );
        },
      );
      return confirmed == true;
    } finally {
      controller.dispose();
    }
  }

  Future<void> _pickAndRestoreBackup() async {
    if (!widget.currentUser.isAdmin) return;

    final confirmed = await _confirmRestoreBackup();
    if (!confirmed) {
      _showSnack("Restore cancelled.");
      return;
    }

    try {
      String? filePath;
      List<int>? bytes;
      String? filename;

      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ["zip"],
        withData: kIsWeb,
      );
      final platformFile =
          picked?.files.isNotEmpty == true ? picked!.files.first : null;
      if (platformFile == null) {
        _showSnack("No backup ZIP selected.");
        return;
      }

      filename = platformFile.name;
      if (kIsWeb) {
        if (platformFile.bytes == null || platformFile.bytes!.isEmpty) {
          _showSnack("Unable to read the selected backup ZIP.");
          return;
        }
        bytes = platformFile.bytes!;
      } else {
        filePath = platformFile.path;
        if (filePath == null || filePath.isEmpty) {
          _showSnack("Unable to read the selected backup ZIP path.");
          return;
        }
      }

      _showSnack("กำลังกู้คืนข้อมูล...");
      setState(() {
        _isRunning = true;
      });

      debugPrint("Starting restoreBackup for user: ${widget.currentUser.userId}");
      final message = await widget.api.restoreBackup(
        requesterId: widget.currentUser.userId,
        filePath: filePath,
        bytes: bytes,
        filename: filename,
      );
      debugPrint("restoreBackup completed: $message");

      if (!mounted) return;

      _showSnack("กู้คืนข้อมูลสำเร็จ");

      setState(() {
        _lastMessage = message;
      });
    } catch (error) {
      debugPrint("Restore failed: $error");
      _showSnack(error.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  Future<void> _pickAndImportProductsExcel() async {
    if (!widget.currentUser.isAdmin) {
      _showSnack("เฉพาะ admin เท่านั้นที่ใช้งานหน้านี้ได้");
      return;
    }

    try {
      String? filePath;
      List<int>? bytes;
      String? filename;

      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ["xlsx", "xlsm"],
        withData: kIsWeb,
      );
      final platformFile =
          picked?.files.isNotEmpty == true ? picked!.files.first : null;
      if (platformFile == null) {
        _showSnack("ยังไม่ได้เลือกไฟล์ Excel");
        return;
      }

      filename = platformFile.name;
      if (kIsWeb) {
        if (platformFile.bytes == null || platformFile.bytes!.isEmpty) {
          _showSnack(
              "ไม่สามารถอ่านไฟล์ Excel จากเบราว์เซอร์ได้ ลองเลือกใหม่อีกครั้ง");
          return;
        }
        bytes = platformFile.bytes!;
      } else {
        filePath = platformFile.path;
        if (filePath == null || filePath.isEmpty) {
          _showSnack("ไม่พบ path ของไฟล์ Excel");
          return;
        }
      }

      setState(() {
        _isRunning = true;
      });
      final message = await widget.api.importProductsExcel(
        requesterId: widget.currentUser.userId,
        filePath: filePath,
        bytes: bytes,
        filename: filename,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _lastMessage = message;
      });
      _showSnack(message);
    } catch (error) {
      _showSnack(error.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    showAppSnack(context, message);
  }

  bool _matchesDownloadSearch(String label) {
    final query = _downloadSearch.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }
    return label.toLowerCase().contains(query);
  }

  bool _matchesDownloadType(String group) {
    return _downloadTypeFilter == "all" || _downloadTypeFilter == group;
  }

  List<({String label, String url, DateTime? expiresAt, String group})>
      _buildExportItems(
    Map<String, ExportLink>? links,
  ) {
    return <({String label, String url, DateTime? expiresAt, String group})>[
      (
        label: "สินค้า CSV",
        url: links?["products"]?.url ??
            widget.api.exportUrl(
              path: "/exports/products.csv",
              requesterId: widget.currentUser.userId,
            ),
        expiresAt: links?["products"]?.expiresAt,
        group: "csv",
      ),
      (
        label: "ผู้ใช้ CSV",
        url: links?["users"]?.url ??
            widget.api.exportUrl(
              path: "/exports/users.csv",
              requesterId: widget.currentUser.userId,
            ),
        expiresAt: links?["users"]?.expiresAt,
        group: "csv",
      ),
      (
        label: "ประวัติ CSV",
        url: links?["movements"]?.url ??
            widget.api.exportUrl(
              path: "/exports/movements.csv",
              requesterId: widget.currentUser.userId,
            ),
        expiresAt: links?["movements"]?.expiresAt,
        group: "csv",
      ),
      (
        label: "ไฟล์ Excel ทั้งหมด",
        url: links?["excel"]?.url ??
            widget.api.exportUrl(
              path: "/exports/all.xlsx",
              requesterId: widget.currentUser.userId,
            ),
        expiresAt: links?["excel"]?.expiresAt,
        group: "excel",
      ),
    ];
  }

  List<Widget> _buildGroupedExportWidgets(Map<String, ExportLink>? links) {
    final filtered = _buildExportItems(links)
        .where((item) => _matchesDownloadSearch(item.label))
        .where((item) => _matchesDownloadType(item.group))
        .toList();
    if (filtered.isEmpty) {
      return const [
        _EmptyTile(
          message:
              "ไม่พบไฟล์ที่ค้นหา ลองพิมพ์คำว่า Excel, CSV, สินค้า หรือ ประวัติ",
        ),
      ];
    }

    final csvItems = filtered.where((item) => item.group == "csv").toList();
    final excelItems = filtered.where((item) => item.group == "excel").toList();
    final widgets = <Widget>[];

    if (csvItems.isNotEmpty) {
      widgets.add(
        _ExportGroupCard(
          title: "ไฟล์ CSV",
          icon: Icons.table_view_outlined,
          children: csvItems
              .map(
                (item) => _SelectableUrl(
                  label: item.label,
                  url: item.url,
                  expiresAt: item.expiresAt,
                ),
              )
              .toList(),
        ),
      );
    }
    if (excelItems.isNotEmpty) {
      widgets.add(
        _ExportGroupCard(
          title: "ไฟล์ Excel",
          icon: Icons.grid_on_rounded,
          children: excelItems
              .map(
                (item) => _SelectableUrl(
                  label: item.label,
                  url: item.url,
                  expiresAt: item.expiresAt,
                ),
              )
              .toList(),
        ),
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom + 28;

    if (!widget.currentUser.isAdmin) {
      return SafeArea(
        child: ColoredBox(
          color: brandSurface,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
            children: const [
              _PageHeader(
                title: "ผู้ดูแลระบบ",
                subtitle: "หน้านี้สำหรับผู้ดูแลระบบเท่านั้น",
                showBackButton: true,
              ),
              SizedBox(height: 16),
              _EmptyTile(
                  message: "บัญชีนี้ไม่มีสิทธิ์ใช้งานฟังก์ชัน admin"),
            ],
          ),
        ),
      );
    }

    final requesterId = widget.currentUser.userId;

    return SafeArea(
      child: ColoredBox(
        color: brandSurface,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
          children: [
            const _PageHeader(
              title: "ผู้ดูแลระบบ",
              subtitle: "งาน sync ข้อมูลและลิงก์ export สำหรับผู้ดูแลระบบ",
              showBackButton: true,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("คำสั่ง Google Sheets",
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _isRunning
                          ? null
                          : () => _runAction(
                                () => widget.api
                                    .syncProducts(requesterId: requesterId),
                              ),
                      child: const Text("ซิงก์สินค้า"),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed:
                          _isRunning ? null : _pickAndImportProductsExcel,
                      child: const Text("นำเข้า Excel สินค้า"),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _isRunning
                          ? null
                          : () => _runAction(
                                () => widget.api
                                    .syncUsers(requesterId: requesterId),
                              ),
                      child: const Text("ซิงก์ผู้ใช้"),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _isRunning
                          ? null
                          : () => _runAction(
                                () => widget.api
                                    .syncStocks(requesterId: requesterId),
                              ),
                      child: const Text("อัปเดตยอดคงเหลือ"),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _isRunning
                          ? null
                          : () => _runAction(
                                () => widget.api
                                    .appendTest(requesterId: requesterId),
                              ),
                      child: const Text("ทดสอบเพิ่มแถว"),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: _isRunning
                          ? null
                          : () => _runAction(() async {
                                await _exportOrdersBackorderCsv();
                                return "ส่งออกรายงานออเดอร์/งานค้างส่งแล้ว";
                              }),
                      child: const Text("ส่งออกรายงานออเดอร์/งานค้างส่ง (CSV)"),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isRunning ? null : _downloadAndShareBackup,
                      child: const Text("Download Backup (ZIP)"),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isRunning ? null : _pickAndRestoreBackup,
                      child: const Text("Restore Backup (ZIP)"),
                    ),
                    if (_lastMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        "ล่าสุด: $_lastMessage",
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("ลิงก์ส่งออกข้อมูล",
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    const Text("เปิดลิงก์เหล่านี้ในเบราว์เซอร์ที่เข้าถึง backend ได้"),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _downloadSearchController,
                      onChanged: (value) {
                        setState(() {
                          _downloadSearch = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "ค้นหาไฟล์ เช่น Excel, CSV, สินค้า",
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _downloadSearch.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _downloadSearchController.clear();
                                  setState(() {
                                    _downloadSearch = "";
                                  });
                                },
                                icon: const Icon(Icons.close),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: "all",
                          label: Text("ทั้งหมด"),
                          icon: Icon(Icons.apps_rounded),
                        ),
                        ButtonSegment<String>(
                          value: "csv",
                          label: Text("CSV"),
                          icon: Icon(Icons.table_view_outlined),
                        ),
                        ButtonSegment<String>(
                          value: "excel",
                          label: Text("Excel"),
                          icon: Icon(Icons.grid_on_rounded),
                        ),
                      ],
                      selected: {_downloadTypeFilter},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _downloadTypeFilter = selection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    ..._buildGroupedExportWidgets(null),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("ลิงก์ชั่วคราวแบบปลอดภัย",
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    const Text("ลิงก์ชุดนี้ซ่อน requester_id และใช้ได้ช่วงสั้น ๆ"),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _refreshExportLinks,
                        icon: const Icon(Icons.refresh),
                        label: const Text("สร้างลิงก์ใหม่"),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<Map<String, ExportLink>>(
                      future: _exportLinksFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return _EmptyTile(
                            message: snapshot.error == null
                                ? "ไม่สามารถสร้างลิงก์ชั่วคราวได้"
                                : snapshot.error
                                    .toString()
                                    .replaceFirst("Exception: ", ""),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ..._buildGroupedExportWidgets(snapshot.data),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportGroupCard extends StatelessWidget {
  const _ExportGroupCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: softPanelDecoration(
        radius: radiusMd,
        surfaceStrength: 0.36,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: brandPrimary.withOpacity(0.10),
                child: Icon(icon, color: brandPrimary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SelectableUrl extends StatelessWidget {
  const _SelectableUrl({
    required this.label,
    required this.url,
    this.expiresAt,
  });

  final String label;
  final String url;
  final DateTime? expiresAt;

  Future<void> _openUrl(BuildContext context) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      showAppSnack(context, "ลิงก์ไม่ถูกต้อง");
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      showAppSnack(
        context,
        "ไม่สามารถเปิดลิงก์ดาวน์โหลดได้",
      );
    }
  }

  Future<void> _copyUrl(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      showAppSnack(context, "คัดลอกลิงก์แล้ว");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: spaceSm),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: softPanelDecoration(
          radius: radiusMd,
          surfaceStrength: 0.32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            if (expiresAt != null) ...[
              const SizedBox(height: 4),
              Text(
                "หมดอายุ ${formatDateTime(expiresAt!)}",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _openUrl(context),
              borderRadius: BorderRadius.circular(radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  url,
                  style: const TextStyle(
                    color: brandPrimary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openUrl(context),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text("ดาวน์โหลดเลย"),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: () => _copyUrl(context),
                  icon: const Icon(Icons.copy_all_outlined),
                  tooltip: "คัดลอกลิงก์",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    this.showBackButton = false,
  });

  final String title;
  final String subtitle;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final headerColor = Color.lerp(brandSurfaceStrong, brandPrimary, 0.34)!;
    return Container(
      padding:
          const EdgeInsets.fromLTRB(spaceLg, spaceLg, spaceLg, spaceMd),
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: BorderRadius.circular(radiusXl),
        border: Border.all(color: brandPrimary.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: brandPrimary.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBackButton) ...[
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
              color: brandDeep,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.82),
              ),
            ),
            const SizedBox(height: spaceXs),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: brandDeep,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: brandInk.withOpacity(0.82),
                ),
          ),
          const SizedBox(height: spaceSm),
          Container(
            width: 64,
            height: 4,
            decoration: BoxDecoration(
              color: brandPrimary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
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
