import "package:flutter/material.dart";

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final sections = [
      _HelpSection(
        title: "เริ่มต้นใช้งาน",
        description: "เริ่มต้นตรวจสอบข้อมูลสินค้าและสต็อกต่าง ๆ ได้ทันทีผ่านระบบเมนูและฟังก์ชันค้นหาสินค้าอย่างรวดเร็ว",
        icon: Icons.play_arrow_outlined,
      ),
      _HelpSection(
        title: "เพิ่มสินค้า",
        description: "ไปที่เมนูสินค้า แล้วกดเพิ่มสินค้า หรือใช้การนำเข้า Excel เพื่อระบุรหัสบาร์โค้ด ชื่อสินค้า และหน่วยสินค้า",
        icon: Icons.add_to_photos_outlined,
      ),
      _HelpSection(
        title: "รับสินค้าเข้า",
        description: "ค้นหาสินค้า แล้วกด + รับเข้า จากนั้นใส่จำนวนและบันทึกเพื่อเพิ่มจำนวนสต็อกปัจจุบัน",
        icon: Icons.add_circle_outline,
      ),
      _HelpSection(
        title: "เบิกสินค้าออก",
        description: "ค้นหาสินค้า แล้วกด - เบิกออก จากนั้นใส่จำนวนและบันทึกเพื่อลดสต็อกเมื่อมีการจำหน่ายสินค้า",
        icon: Icons.remove_circle_outline,
      ),
      _HelpSection(
        title: "ออเดอร์",
        description: "ระบบติดตามและจัดการใบสั่งซื้อ เพื่อมอบหมายงานให้กับฝ่ายจัดส่งในการติดตามสถานะปลายทาง",
        icon: Icons.local_shipping_outlined,
      ),
      _HelpSection(
        title: "สแกนใบปะหน้า",
        description: "ใช้กล้องสแกนใบปะหน้าของบริษัทขนส่งเพื่ออ่านชื่อและที่อยู่ออเดอร์แบบอัตโนมัติด้วยระบบ OCR",
        icon: Icons.qr_code_scanner,
      ),
      _HelpSection(
        title: "ถังขยะสินค้า",
        description: "สินค้าที่ซ่อนอยู่ (Archive) สามารถตรวจสอบ กู้คืน หรือลบออกแบบถาวรได้ในส่วนนี้โดยผู้ดูแลระบบ",
        icon: Icons.restore_from_trash_outlined,
      ),
      _HelpSection(
        title: "ไทม์ไลน์สินค้า",
        description: "ใช้ดูประวัติของสินค้านี้ เช่น รับเข้า เบิกออก ซ่อน และกู้คืน เพื่อตรวจสอบกิจกรรมย้อนหลังทั้งหมด",
        icon: Icons.history_outlined,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("วิธีใช้งาน"),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final section = sections[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
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
            ),
          );
        },
      ),
    );
  }
}

class _HelpSection {
  _HelpSection({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}
