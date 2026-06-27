import "package:flutter/material.dart";
import "api_service.dart";
import "models.dart";
import "product_search_page.dart";
import "orders_page.dart";
import "product_recycle_bin_page.dart";

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({
    super.key,
    required this.api,
    required this.currentUser,
  });

  final StockApiService api;
  final AppUser currentUser;

  void _onTryAction(BuildContext context, String title) {
    switch (title) {
      case "เพิ่มสินค้า":
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductSearchPage(
              api: api,
              currentUser: currentUser,
            ),
          ),
        );
        break;
      case "รับสินค้าเข้า":
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductSearchPage(
              api: api,
              currentUser: currentUser,
              guidanceMode: ProductSearchGuidanceMode.stockIn,
            ),
          ),
        );
        break;
      case "เบิกสินค้าออก":
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductSearchPage(
              api: api,
              currentUser: currentUser,
              guidanceMode: ProductSearchGuidanceMode.stockOut,
            ),
          ),
        );
        break;
      case "ออเดอร์":
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrdersPage(
              api: api,
              currentUser: currentUser,
            ),
          ),
        );
        break;
      case "สแกนใบปะหน้า":
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrdersPage(
              api: api,
              currentUser: currentUser,
            ),
          ),
        );
        // Show guidance snackbar immediately
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("ใช้ปุ่มสแกนข้อมูลลูกค้าเพื่ออ่านใบปะหน้า"),
            duration: Duration(seconds: 4),
          ),
        );
        break;
      case "ถังขยะสินค้า":
        if (currentUser.isAdmin) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductRecycleBinPage(
                api: api,
                currentUser: currentUser,
              ),
            ),
          );
        } else {
          showDialog<void>(
            context: context,
            builder: (dialogCtx) => AlertDialog(
              title: const Text("สิทธิ์การเข้าถึง"),
              content: const Text("เมนูนี้ใช้ได้เฉพาะผู้ดูแลระบบ"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text("ตกลง"),
                ),
              ],
            ),
          );
        }
        break;
      case "ไทม์ไลน์สินค้า":
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductSearchPage(
              api: api,
              currentUser: currentUser,
              guidanceMode: ProductSearchGuidanceMode.timeline,
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final sections = [
      _HelpSection(
        title: "เริ่มต้นใช้งาน",
        description: "เริ่มต้นตรวจสอบข้อมูลสินค้าและสต็อกต่าง ๆ ได้ทันทีผ่านระบบเมนูและฟังก์ชันค้นหาสินค้าอย่างรวดเร็ว",
        icon: Icons.play_arrow_outlined,
        hasAction: false,
      ),
      _HelpSection(
        title: "เพิ่มสินค้า",
        description: "ไปที่เมนูสินค้า แล้วกดเพิ่มสินค้า หรือใช้การนำเข้า Excel เพื่อระบุรหัสบาร์โค้ด ชื่อสินค้า และหน่วยสินค้า",
        icon: Icons.add_to_photos_outlined,
        hasAction: true,
      ),
      _HelpSection(
        title: "รับสินค้าเข้า",
        description: "ค้นหาสินค้า แล้วกด + รับเข้า จากนั้นใส่จำนวนและบันทึกเพื่อเพิ่มจำนวนสต็อกปัจจุบัน",
        icon: Icons.add_circle_outline,
        hasAction: true,
      ),
      _HelpSection(
        title: "เบิกสินค้าออก",
        description: "ค้นหาสินค้า แล้วกด - เบิกออก จากนั้นใส่จำนวนและบันทึกเพื่อลดสต็อกเมื่อมีการจำหน่ายสินค้า",
        icon: Icons.remove_circle_outline,
        hasAction: true,
      ),
      _HelpSection(
        title: "ออเดอร์",
        description: "ระบบติดตามและจัดการใบสั่งซื้อ เพื่อมอบหมายงานให้กับฝ่ายจัดส่งในการติดตามสถานะปลายทาง",
        icon: Icons.local_shipping_outlined,
        hasAction: true,
      ),
      _HelpSection(
        title: "สแกนใบปะหน้า",
        description: "ใช้กล้องสแกนใบปะหน้าของบริษัทขนส่งเพื่ออ่านชื่อและที่อยู่ออเดอร์แบบอัตโนมัติด้วยระบบ OCR",
        icon: Icons.qr_code_scanner,
        hasAction: true,
      ),
      _HelpSection(
        title: "ถังขยะสินค้า",
        description: "สินค้าที่ซ่อนอยู่ (Archive) สามารถตรวจสอบ กู้คืน หรือลบออกแบบถาวรได้ในส่วนนี้โดยผู้ดูแลระบบ",
        icon: Icons.restore_from_trash_outlined,
        hasAction: true,
      ),
      _HelpSection(
        title: "ไทม์ไลน์สินค้า",
        description: "ใช้ดูประวัติของสินค้านี้ เช่น รับเข้า เบิกออก ซ่อน และกู้คืน เพื่อตรวจสอบกิจกรรมย้อนหลังทั้งหมด",
        icon: Icons.history_outlined,
        hasAction: true,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("วิธีใช้งาน"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: sections.map((section) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          section.icon,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              section.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade700,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (section.hasAction) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: Key("try_${section.title}"),
                        onPressed: () => _onTryAction(context, section.title),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: const Text("ลองทำเลย"),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HelpSection {
  _HelpSection({
    required this.title,
    required this.description,
    required this.icon,
    required this.hasAction,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool hasAction;
}
