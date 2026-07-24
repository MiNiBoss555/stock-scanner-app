import "dart:async" show TimeoutException;
import "package:flutter/material.dart";
import "package:flutter/services.dart" show FilteringTextInputFormatter;

import "api_service.dart";
import "config.dart";
import "models.dart";
import "theme/app_theme.dart";

DateTime? loginTapStart;
DateTime? authCompleteTime;

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.api,
    required this.onLogin,
  });

  final StockApiService api;
  final Future<void> Function(LoginSession session) onLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePin = true;
  String? _userIdError;
  String? _pinError;

  void _handleUserIdChanged(String value) {
    final normalized = value.toUpperCase().replaceAll(" ", "");
    if (normalized != value) {
      _userIdController.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }
    if (_userIdError != null) {
      setState(() {
        _userIdError = null;
      });
    }
  }

  void _handlePinChanged(String value) {
    if (_pinError != null) {
      setState(() {
        _pinError = null;
      });
    }
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    loginTapStart = DateTime.now();
    final userId = _userIdController.text.trim().toUpperCase();
    final pin = _pinController.text.trim();

    setState(() {
      _userIdError = null;
      _pinError = null;
    });

    if (userId.isEmpty) {
      setState(() {
        _userIdError = "กรุณากรอก User ID";
      });
      return;
    }
    if (pin.isEmpty) {
      setState(() {
        _pinError = "กรุณากรอก PIN";
      });
      return;
    }
    if (pin.length < 4) {
      setState(() {
        _pinError = "PIN ต้องมีอย่างน้อย 4 หลัก";
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });
    showAppSnack(context, "กำลังเข้าสู่ระบบ...");

    try {
      final session = await widget.api
          .login(userId: userId, pin: pin)
          .timeout(const Duration(seconds: 20));
      authCompleteTime = DateTime.now();
      debugPrint("DEBUG TIMER: login tap to auth complete = ${authCompleteTime!.difference(loginTapStart!).inMilliseconds} ms");
      await widget.onLogin(session);
    } catch (error) {
      final message = error.toString().replaceFirst("Exception: ", "");
      if (message.contains("Invalid user id or PIN")) {
        setState(() {
          _userIdError = "ไม่พบ User ID นี้ หรือ PIN ไม่ถูกต้อง";
          _pinError = "ตรวจสอบ PIN แล้วลองอีกครั้ง";
        });
      } else if (message.contains("inactive")) {
        setState(() {
          _userIdError = "บัญชีนี้ถูกปิดการใช้งาน";
        });
      } else if (error is TimeoutException ||
          message.contains("TimeoutException")) {
        _showSnack("เชื่อมต่อช้าเกินไป (timeout) ลองใหม่อีกครั้ง");
      } else {
        _showSnack(message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    showAppSnack(context, message, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + safeBottom),
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + safeBottom),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "เข้าสู่ระบบ",
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "เข้าสู่ระบบด้วยรหัสผู้ใช้และ PIN",
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _userIdController,
                            textCapitalization: TextCapitalization.characters,
                            onChanged: _handleUserIdChanged,
                            decoration: InputDecoration(
                              labelText: "User ID",
                              hintText: "รหัสพนักงาน",
                              helperText: _userIdError == null
                                  ? "ใช้อักษรและตัวเลขของรหัสพนักงาน"
                                  : null,
                              errorText: _userIdError,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _pinController,
                            obscureText: _obscurePin,
                            keyboardType: TextInputType.number,
                            onChanged: _handlePinChanged,
                            decoration: InputDecoration(
                              labelText: "PIN",
                              errorText: _pinError,
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePin = !_obscurePin;
                                  });
                                },
                                icon: Icon(_obscurePin
                                    ? Icons.visibility
                                    : Icons.visibility_off),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _isLoading ? null : _login,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(
                              _isLoading
                                  ? "กำลังเข้าสู่ระบบ..."
                                  : "เข้าสู่ระบบ",
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "ถ้าเซิร์ฟเวอร์เพิ่งตื่น ครั้งแรกอาจใช้เวลา 10-20 วินาที",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _showServerConfigDialog,
                            icon: const Icon(Icons.settings_ethernet_rounded, size: 18),
                            label: Text(
                              "เซิร์ฟเวอร์: ${AppConfig.baseUrl}",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showServerConfigDialog() {
    final controller = TextEditingController(text: AppConfig.baseUrl);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("ตั้งค่าเซิร์ฟเวอร์ (Server URL)"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "ระบุ IP Address ของเครื่องคอมพิวเตอร์ที่รันระบบอยู่ เช่น http://192.168.1.108:8000",
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: "Server URL",
                  hintText: "http://192.168.1.108:8000",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await AppConfig.setCustomServerUrl(null);
                if (mounted) {
                  Navigator.pop(dialogContext);
                  setState(() {});
                }
              },
              child: const Text("คืนค่าเดิม"),
            ),
            ElevatedButton(
              onPressed: () async {
                await AppConfig.setCustomServerUrl(controller.text);
                if (mounted) {
                  Navigator.pop(dialogContext);
                  setState(() {});
                }
              },
              child: const Text("บันทึก IP ใหม่"),
            ),
          ],
        );
      },
    );
  }
}
