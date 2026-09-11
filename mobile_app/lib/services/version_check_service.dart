import "dart:convert";
import "dart:io";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:http/http.dart" as http;
import "package:package_info_plus/package_info_plus.dart";
import "package:url_launcher/url_launcher.dart";

import "../config.dart";

class AppVersionCheckService {
  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final uri = Uri.parse("${AppConfig.baseUrl}/app/version-check");
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final latestVersion = data["latest_version"] as String? ?? currentVersion;
        final releaseNotes = data["release_notes"] as String? ?? "";
        final downloadUrlExe = data["download_url_exe"] as String? ?? "";
        final downloadUrlApk = data["download_url_apk"] as String? ?? "";

        if (_isNewerVersion(latestVersion, currentVersion)) {
          if (context.mounted) {
            _showUpdateDialog(
              context,
              latestVersion: latestVersion,
              releaseNotes: releaseNotes,
              downloadUrlExe: downloadUrlExe,
              downloadUrlApk: downloadUrlApk,
              currentVersion: currentVersion,
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Version check skipped or failed: $e");
    }
  }

  static bool _isNewerVersion(String latest, String current) {
    try {
      final vLatest = latest.split(".").map(int.parse).toList();
      final vCurrent = current.split(".").map(int.parse).toList();
      for (int i = 0; i < vLatest.length && i < vCurrent.length; i++) {
        if (vLatest[i] > vCurrent[i]) return true;
        if (vLatest[i] < vCurrent[i]) return false;
      }
      return vLatest.length > vCurrent.length;
    } catch (_) {
      return false;
    }
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required String latestVersion,
    required String releaseNotes,
    required String downloadUrlExe,
    required String downloadUrlApk,
    required String currentVersion,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.system_update_rounded, color: Color(0xFF005AA7), size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "พบเวอร์ชันใหม่ (v$latestVersion)",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "เวอร์ชันปัจจุบันของคุณคือ v$currentVersion",
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "รายการอัปเดตใหม่:",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF003B73)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      releaseNotes.isNotEmpty ? releaseNotes : "ปรับปรุงประสิทธิภาพและเพิ่มฟีเจอร์ใหม่",
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "💡 คุณสามารถกดดาวน์โหลดและติดตั้งทับเวอร์ชันเดิมได้ทันทีโดยไม่ต้องถอนติดตั้งก่อน",
                style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("ไว้ทีหลัง"),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF005AA7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text("อัปเดต / ติดตั้งทับ"),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                String targetPath = downloadUrlApk;
                if (!kIsWeb && Platform.isWindows) {
                  targetPath = downloadUrlExe;
                }
                final fullUrl = "${AppConfig.baseUrl}$targetPath";
                final uri = Uri.parse(fullUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
            );
      },
    );
  }
}

class AppVersionText extends StatelessWidget {
  const AppVersionText({super.key, this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final label = info == null ? "" : "v${info.version} (${info.buildNumber})";
        return Text(label, style: style);
      },
    );
  }
}
