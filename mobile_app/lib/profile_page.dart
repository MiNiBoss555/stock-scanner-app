import "dart:async";
import "package:file_picker/file_picker.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";

import "api_service.dart";
import "models.dart";
import "theme/app_theme.dart";

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.currentUser,
    required this.api,
    required this.onLogout,
    required this.onRefreshSession,
  });

  final AppUser currentUser;
  final StockApiService api;
  final Future<void> Function() onLogout;
  final Future<void> Function() onRefreshSession;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<List<AppUser>> _usersFuture;
  late AppUser _profileUser;
  int _profileImageNonce = 0;
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _currentPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final TextEditingController _profileImageUrlController =
      TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  String _role = "staff";
  bool _active = true;
  bool _isSaving = false;
  bool _isChangingPin = false;
  bool _isUploadingProfileImage = false;
  bool _isEditingDisplayName = false;
  bool _isUpdatingDisplayName = false;
  bool _obscureCurrentPin = true;
  bool _obscureNewPin = true;
  bool _obscureConfirmPin = true;
  String? _displayNameError;

  @override
  void initState() {
    super.initState();
    _profileUser = widget.currentUser;
    _displayNameController.text = _profileUser.userName;
    _usersFuture = widget.api.getUsers(activeOnly: false);
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser.userId != widget.currentUser.userId ||
        oldWidget.currentUser.userName != widget.currentUser.userName ||
        oldWidget.currentUser.profileImageUrl !=
            widget.currentUser.profileImageUrl ||
        oldWidget.currentUser.role != widget.currentUser.role ||
        oldWidget.currentUser.active != widget.currentUser.active) {
      _profileUser = widget.currentUser;
      if (!_isEditingDisplayName) {
        _displayNameController.text = _profileUser.userName;
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _userIdController.dispose();
    _userNameController.dispose();
    _positionController.dispose();
    _pinController.dispose();
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    _profileImageUrlController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _usersFuture = widget.api.getUsers(activeOnly: false);
    });
    await _usersFuture;
    final refreshedUser = await widget.api.getCurrentUser();
    if (mounted) {
      setState(() {
        _profileUser = refreshedUser;
      });
    }
    await widget.onRefreshSession();
  }

  void _startDisplayNameEditing() {
    setState(() {
      _isEditingDisplayName = true;
      _displayNameError = null;
      _displayNameController.text = _profileUser.userName;
      _displayNameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _displayNameController.text.length,
      );
    });
  }

  void _cancelDisplayNameEditing() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isEditingDisplayName = false;
      _displayNameError = null;
      _displayNameController.text = _profileUser.userName;
    });
  }

  Future<void> _saveDisplayName() async {
    FocusScope.of(context).unfocus();
    final userName = _displayNameController.text.trim();

    if (userName.isEmpty) {
      setState(() {
        _displayNameError = "กรุณากรอกชื่อที่แสดง";
      });
      return;
    }

    if (userName == _profileUser.userName) {
      _cancelDisplayNameEditing();
      return;
    }

    setState(() {
      _isUpdatingDisplayName = true;
      _displayNameError = null;
    });

    try {
      final updatedUser = await widget.api.updateMyProfile(userName: userName);
      if (!mounted) {
        return;
      }
      setState(() {
        _profileUser = updatedUser;
        _isEditingDisplayName = false;
        _displayNameController.text = updatedUser.userName;
      });
      await widget.onRefreshSession();
      if (mounted) {
        _showSnack("บันทึกชื่อเรียบร้อย");
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _displayNameError = normalizeFeedbackMessage(
            error.toString().replaceFirst("Exception: ", ""),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingDisplayName = false;
        });
      }
    }
  }

  Future<void> _changePin() async {
    final currentPin = _currentPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (currentPin.isEmpty || newPin.isEmpty || confirmPin.isEmpty) {
      _showSnack("กรุณากรอก PIN ให้ครบทุกช่อง");
      return;
    }
    if (newPin.length < 4) {
      _showSnack("PIN ใหม่ต้องมีอย่างน้อย 4 หลัก");
      return;
    }
    if (newPin != confirmPin) {
      _showSnack("PIN ใหม่และการยืนยัน PIN ไม่ตรงกัน");
      return;
    }

    setState(() {
      _isChangingPin = true;
    });

    try {
      final message = await widget.api.changePin(
        currentPin: currentPin,
        newPin: newPin,
      );
      _currentPinController.clear();
      _newPinController.clear();
      _confirmPinController.clear();
      _showSnack(message);
    } catch (error) {
      _showSnack(error.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() {
          _isChangingPin = false;
        });
      }
    }
  }

  Future<void> _saveUser() async {
    final userId = _userIdController.text.trim().toUpperCase();
    final userName = _userNameController.text.trim();
    final position = _positionController.text.trim();
    if (userId.isEmpty || userName.isEmpty) {
      _showSnack(
          "\u0e01\u0e23\u0e38\u0e13\u0e32\u0e01\u0e23\u0e2d\u0e01\u0e23\u0e2b\u0e31\u0e2a\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e41\u0e25\u0e30\u0e0a\u0e37\u0e48\u0e2d\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e43\u0e2b\u0e49\u0e04\u0e23\u0e1a");
      return;
    }
    if (_pinController.text.trim().length < 4) {
      _showSnack(
          "PIN \u0e15\u0e49\u0e2d\u0e07\u0e21\u0e35\u0e2d\u0e22\u0e48\u0e32\u0e07\u0e19\u0e49\u0e2d\u0e22 4 \u0e2b\u0e25\u0e31\u0e01");
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.api.upsertUser(
        requesterId: widget.currentUser.userId,
        userId: userId,
        userName: userName,
        role: _role,
        position: position.isEmpty ? null : position,
        active: _active,
        pin: _pinController.text.trim(),
        profileImageUrl: _profileImageUrlController.text.trim().isEmpty
            ? null
            : _profileImageUrlController.text.trim(),
      );
      _userIdController.clear();
      _userNameController.clear();
      _positionController.clear();
      _pinController.clear();
      _profileImageUrlController.clear();
      setState(() {
        _role = "staff";
        _active = true;
      });
      await _reload();
      _showSnack(
          "\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e40\u0e23\u0e35\u0e22\u0e1a\u0e23\u0e49\u0e2d\u0e22");
    } catch (error) {
      _showSnack(error.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _toggleUser(AppUser user) async {
    if (user.userId == widget.currentUser.userId) {
      _showSnack(
          "\u0e1a\u0e31\u0e0d\u0e0a\u0e35\u0e17\u0e35\u0e48\u0e01\u0e33\u0e25\u0e31\u0e07\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e2d\u0e22\u0e39\u0e48\u0e44\u0e21\u0e48\u0e2a\u0e32\u0e21\u0e32\u0e23\u0e16\u0e1b\u0e34\u0e14\u0e44\u0e14\u0e49");
      return;
    }
    try {
      await widget.api.upsertUser(
        requesterId: widget.currentUser.userId,
        userId: user.userId,
        userName: user.userName,
        role: user.role,
        active: !user.active,
      );
      await _reload();
    } catch (error) {
      _showSnack(error.toString().replaceFirst("Exception: ", ""));
    }
  }

  Future<void> _deleteUser(AppUser user) async {
    if (user.userId == widget.currentUser.userId) {
      _showSnack(
          "\u0e44\u0e21\u0e48\u0e2a\u0e32\u0e21\u0e32\u0e23\u0e16\u0e25\u0e1a\u0e1a\u0e31\u0e0d\u0e0a\u0e35\u0e17\u0e35\u0e48\u0e01\u0e33\u0e25\u0e31\u0e07\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e2d\u0e22\u0e39\u0e48\u0e44\u0e14\u0e49");
      return;
    }

    bool deleteMovements = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                  "\u0e25\u0e1a\u0e1e\u0e19\u0e31\u0e01\u0e07\u0e32\u0e19 ${user.userName}"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      "\u0e15\u0e49\u0e2d\u0e07\u0e01\u0e32\u0e23\u0e25\u0e1a\u0e02\u0e49\u0e2d\u0e21\u0e39\u0e25\u0e02\u0e2d\u0e07 ${user.userId} \u0e2d\u0e2d\u0e01\u0e08\u0e32\u0e01\u0e23\u0e30\u0e1a\u0e1a\u0e2b\u0e23\u0e37\u0e2d\u0e44\u0e21\u0e48"),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: deleteMovements,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                        "\u0e25\u0e1a\u0e1b\u0e23\u0e30\u0e27\u0e31\u0e15\u0e34\u0e01\u0e32\u0e23\u0e17\u0e33\u0e23\u0e32\u0e22\u0e01\u0e32\u0e23\u0e02\u0e2d\u0e07\u0e1e\u0e19\u0e31\u0e01\u0e07\u0e32\u0e19\u0e04\u0e19\u0e19\u0e35\u0e49\u0e14\u0e49\u0e27\u0e22"),
                    subtitle: const Text(
                        "\u0e40\u0e2b\u0e21\u0e32\u0e30\u0e2a\u0e33\u0e2b\u0e23\u0e31\u0e1a\u0e1e\u0e19\u0e31\u0e01\u0e07\u0e32\u0e19\u0e40\u0e01\u0e48\u0e32\u0e17\u0e35\u0e48\u0e44\u0e21\u0e48\u0e15\u0e49\u0e2d\u0e07\u0e40\u0e01\u0e47\u0e1a\u0e02\u0e49\u0e2d\u0e21\u0e39\u0e25\u0e22\u0e49\u0e2d\u0e19\u0e2b\u0e25\u0e31\u0e07"),
                    onChanged: (value) {
                      setDialogState(() {
                        deleteMovements = value ?? false;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text("\u0e22\u0e01\u0e40\u0e25\u0e34\u0e01"),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text(
                      "\u0e25\u0e1a\u0e02\u0e49\u0e2d\u0e21\u0e39\u0e25"),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final message = await widget.api.deleteUser(
        requesterId: widget.currentUser.userId,
        userId: user.userId,
        deleteMovements: deleteMovements,
      );
      await _reload();
      _showSnack(message);
    } catch (error) {
      _showSnack(error.toString().replaceFirst("Exception: ", ""));
    }
  }

  Future<void> _pickAndUploadProfileImage(AppUser targetUser) async {
    try {
      String? filePath;
      List<int>? bytes;
      String? filename;

      if (kIsWeb) {
        final picked = await FilePicker.pickFiles(
          type: FileType.image,
          withData: true,
        );
        final platformFile =
            picked?.files.isNotEmpty == true ? picked!.files.first : null;
        if (platformFile == null) {
          _showSnack("ยังไม่ได้เลือกไฟล์รูป");
          return;
        }
        if (platformFile.bytes == null || platformFile.bytes!.isEmpty) {
          _showSnack(
              "ไม่สามารถอ่านไฟล์รูปจากเบราว์เซอร์ได้ ลองเลือกใหม่อีกครั้ง");
          return;
        }
        bytes = platformFile.bytes!;
        filename = platformFile.name;
      } else {
        final file = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1600,
        );
        if (file == null) {
          _showSnack("ยังไม่ได้เลือกรูป");
          return;
        }
        filePath = file.path;
        filename = file.name;
      }

      setState(() {
        _isUploadingProfileImage = true;
      });

      await widget.api.uploadProfileImage(
        requesterId: widget.currentUser.userId,
        targetUserId: targetUser.userId,
        filePath: filePath,
        bytes: bytes,
        filename: filename,
      );
      await _reload();
      if (mounted) {
        setState(() {
          // Bust browser caches so the new image shows immediately on web.
          _profileImageNonce = DateTime.now().millisecondsSinceEpoch;
        });
      }
      _showSnack(
          "\u0e2d\u0e31\u0e1b\u0e42\u0e2b\u0e25\u0e14\u0e23\u0e39\u0e1b\u0e42\u0e1b\u0e23\u0e44\u0e1f\u0e25\u0e4c\u0e40\u0e23\u0e35\u0e22\u0e1a\u0e23\u0e49\u0e2d\u0e22");
    } catch (error) {
      _showSnack(error.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingProfileImage = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    showAppSnack(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ColoredBox(
        color: brandSurface,
        child: RefreshIndicator(
          onRefresh: _reload,
          child: FutureBuilder<List<AppUser>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _ErrorState(message: snapshot.error.toString());
              }

              final users = snapshot.data ?? [];
              final displayRole = roleLabel(_profileUser.role);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _PageHeader(
                    title: _profileUser.isAdmin
                        ? "\u0e42\u0e1b\u0e23\u0e44\u0e1f\u0e25\u0e4c\u0e41\u0e25\u0e30\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49"
                        : "\u0e42\u0e1b\u0e23\u0e44\u0e1f\u0e25\u0e4c",
                    subtitle: _profileUser.isAdmin
                        ? "\u0e14\u0e39\u0e02\u0e49\u0e2d\u0e21\u0e39\u0e25\u0e02\u0e2d\u0e07\u0e04\u0e38\u0e13\u0e41\u0e25\u0e30\u0e08\u0e31\u0e14\u0e01\u0e32\u0e23\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e44\u0e14\u0e49"
                        : "\u0e14\u0e39\u0e02\u0e49\u0e2d\u0e21\u0e39\u0e25\u0e02\u0e2d\u0e07\u0e04\u0e38\u0e13\u0e41\u0e25\u0e30\u0e2d\u0e2d\u0e01\u0e08\u0e32\u0e01\u0e23\u0e30\u0e1a\u0e1a",
                    showBackButton: true,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Color.lerp(brandSurface, profileAccent, 0.18)!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(radiusXl),
                      border: Border.all(color: profileTeal.withOpacity(0.10)),
                      boxShadow: [
                        BoxShadow(
                          color: profileTeal.withOpacity(0.12),
                          blurRadius: 30,
                          offset: const Offset(0, 16),
                        ),
                        BoxShadow(
                          color: profileAccent.withOpacity(0.10),
                          blurRadius: 26,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Container(
                              height: 170,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    profileTeal.withOpacity(0.92),
                                    brandPrimary.withOpacity(0.88),
                                    profileTeal.withOpacity(0.96),
                                  ],
                                ),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(radiusXl),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              left: 28,
                              right: 28,
                              child: Container(
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.34),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(999),
                                    bottomRight: Radius.circular(999),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 18,
                              right: 22,
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.10),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 38,
                              left: 26,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: brandPrimary.withOpacity(0.42),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 98,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 12,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            profileAccent.withOpacity(0.95),
                                            profileAccent.withOpacity(0.72),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 168),
                                  Expanded(
                                    child: Container(
                                      height: 12,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            profileAccent.withOpacity(0.72),
                                            profileAccent.withOpacity(0.95),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              bottom: -66,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      brandPrimary,
                                      profileAccent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: profileTeal.withOpacity(0.18),
                                      blurRadius: 22,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(
                                        color: profileTeal.withOpacity(0.08)),
                                  ),
                                  child: _UserAvatar(
                                    imageUrl: (() {
                                      final base = widget.api.resolveAssetUrl(
                                        _profileUser.profileImageUrl,
                                      );
                                      if (base.isEmpty) return base;
                                      final nonce = _profileImageNonce;
                                      if (nonce == 0) return base;
                                      final sep =
                                          base.contains("?") ? "&" : "?";
                                      return "$base${sep}v=$nonce";
                                    })(),
                                    name: _profileUser.userName,
                                    radius: 58,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 78, 20, 24),
                          child: Column(
                            children: [
                              Text(
                                _profileUser.userName,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: brandDeep,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      brandPrimary,
                                      profileAccent,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: brandPrimary.withOpacity(0.22),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  displayRole,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: brandDeep,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                height: 1,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                color: profileTeal.withOpacity(0.08),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: profileAccent.withOpacity(0.55),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: brandPrimary.withOpacity(0.28),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: profileAccent.withOpacity(0.55),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _isUpdatingDisplayName
                              ? null
                              : (_isEditingDisplayName
                                  ? _cancelDisplayNameEditing
                                  : _startDisplayNameEditing),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: brandDeep,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                                color: brandPrimary.withOpacity(0.44)),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(radiusMd),
                            ),
                            shadowColor: brandPrimary.withOpacity(0.10),
                          ),
                          icon: Icon(
                            _isEditingDisplayName
                                ? Icons.close_rounded
                                : Icons.edit_outlined,
                          ),
                          label: Text(
                            _isEditingDisplayName
                                ? "\u0e22\u0e01\u0e40\u0e25\u0e34\u0e01"
                                : "\u0e41\u0e01\u0e49\u0e44\u0e02\u0e0a\u0e37\u0e48\u0e2d",
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _isUploadingProfileImage
                              ? null
                              : () => _pickAndUploadProfileImage(_profileUser),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: brandDeep,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                                color: profileTeal.withOpacity(0.36)),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(radiusMd),
                            ),
                            shadowColor: profileTeal.withOpacity(0.10),
                          ),
                          icon: _isUploadingProfileImage
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.add_a_photo_outlined),
                          label: const Text(
                              "\u0e40\u0e1b\u0e25\u0e35\u0e48\u0e22\u0e19\u0e23\u0e39\u0e1b"),
                        ),
                      ),
                    ],
                  ),
                  if (_isEditingDisplayName) ...[
                    const SizedBox(height: 12),
                    Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(radiusLg),
                          border: Border.all(
                              color: brandPrimary.withOpacity(0.16)),
                          boxShadow: [
                            BoxShadow(
                              color: profileTeal.withOpacity(0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "\u0e41\u0e01\u0e49\u0e44\u0e02\u0e0a\u0e37\u0e48\u0e2d\u0e17\u0e35\u0e48\u0e41\u0e2a\u0e14\u0e07",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: brandDeep,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _displayNameController,
                              enabled: !_isUpdatingDisplayName,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _saveDisplayName(),
                              decoration: InputDecoration(
                                labelText:
                                    "\u0e0a\u0e37\u0e48\u0e2d\u0e17\u0e35\u0e48\u0e41\u0e2a\u0e14\u0e07",
                                errorText: _displayNameError,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _isUpdatingDisplayName
                                    ? null
                                    : _saveDisplayName,
                                child: _isUpdatingDisplayName
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Text(
                                        "\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e0a\u0e37\u0e48\u0e2d"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: widget.onLogout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: brandDeep,
                      backgroundColor: brandSurface,
                      side: BorderSide(color: brandPrimary.withOpacity(0.34)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(radiusMd),
                      ),
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text(
                        "\u0e2d\u0e2d\u0e01\u0e08\u0e32\u0e01\u0e23\u0e30\u0e1a\u0e1a"),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Color.lerp(brandSurface, profileAccent, 0.24)!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(radiusXl),
                      border: Border.all(color: profileTeal.withOpacity(0.12)),
                      boxShadow: [
                        BoxShadow(
                          color: profileTeal.withOpacity(0.08),
                          blurRadius: 22,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            inputDecorationTheme: InputDecorationTheme(
                              filled: true,
                              fillColor: Color.lerp(
                                  brandSurface, brandSurfaceStrong, 0.14)!,
                              labelStyle: TextStyle(
                                color: profileTeal.withOpacity(0.78),
                                fontWeight: FontWeight.w700,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(radiusMd),
                                borderSide: BorderSide(
                                    color: profileTeal.withOpacity(0.12)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(radiusMd),
                                borderSide: BorderSide(
                                    color: profileTeal.withOpacity(0.12)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(radiusMd),
                                borderSide: const BorderSide(
                                    color: profileTeal, width: 1.4),
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          brandPrimary,
                                          profileAccent,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.lock_outline_rounded,
                                      color: brandDeep,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "\u0e40\u0e1b\u0e25\u0e35\u0e48\u0e22\u0e19 PIN",
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: brandDeep,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "\u0e2d\u0e31\u0e1b\u0e40\u0e14\u0e15 PIN \u0e02\u0e2d\u0e07\u0e1a\u0e31\u0e0d\u0e0a\u0e35\u0e43\u0e2b\u0e49\u0e1b\u0e25\u0e2d\u0e14\u0e20\u0e31\u0e22\u0e02\u0e36\u0e49\u0e19",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color:
                                                    brandInk.withOpacity(0.72),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Container(
                                height: 1,
                                color: profileTeal.withOpacity(0.08),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                "\u0e43\u0e0a\u0e49 PIN \u0e1b\u0e31\u0e08\u0e08\u0e38\u0e1a\u0e31\u0e19\u0e40\u0e1e\u0e37\u0e48\u0e2d\u0e22\u0e37\u0e19\u0e22\u0e31\u0e19 \u0e41\u0e25\u0e49\u0e27\u0e15\u0e31\u0e49\u0e07 PIN \u0e43\u0e2b\u0e21\u0e48\u0e2d\u0e22\u0e48\u0e32\u0e07\u0e19\u0e49\u0e2d\u0e22 4 \u0e2b\u0e25\u0e31\u0e01",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: brandInk.withOpacity(0.70),
                                      height: 1.4,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _currentPinController,
                                keyboardType: TextInputType.number,
                                obscureText: _obscureCurrentPin,
                                decoration: InputDecoration(
                                  labelText:
                                      "PIN \u0e1b\u0e31\u0e08\u0e08\u0e38\u0e1a\u0e31\u0e19",
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscureCurrentPin =
                                            !_obscureCurrentPin;
                                      });
                                    },
                                    icon: Icon(
                                      _obscureCurrentPin
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _newPinController,
                                keyboardType: TextInputType.number,
                                obscureText: _obscureNewPin,
                                decoration: InputDecoration(
                                  labelText: "PIN \u0e43\u0e2b\u0e21\u0e48",
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscureNewPin = !_obscureNewPin;
                                      });
                                    },
                                    icon: Icon(
                                      _obscureNewPin
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _confirmPinController,
                                keyboardType: TextInputType.number,
                                obscureText: _obscureConfirmPin,
                                decoration: InputDecoration(
                                  labelText:
                                      "\u0e22\u0e37\u0e19\u0e22\u0e31\u0e19 PIN \u0e43\u0e2b\u0e21\u0e48",
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPin =
                                            !_obscureConfirmPin;
                                      });
                                    },
                                    icon: Icon(
                                      _obscureConfirmPin
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _isChangingPin ? null : _changePin,
                                style: FilledButton.styleFrom(
                                  backgroundColor: brandDeep,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(radiusMd),
                                  ),
                                  elevation: 0,
                                  shadowColor: profileTeal.withOpacity(0.18),
                                ),
                                icon: _isChangingPin
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.lock_reset_outlined),
                                label: Text(
                                  _isChangingPin
                                      ? "\u0e01\u0e33\u0e25\u0e31\u0e07\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01..."
                                      : "\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01 PIN \u0e43\u0e2b\u0e21\u0e48",
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!widget.currentUser.isAdmin) ...[
                    const SizedBox(height: 12),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                            "\u0e1a\u0e31\u0e0d\u0e0a\u0e35\u0e19\u0e35\u0e49\u0e44\u0e21\u0e48\u0e21\u0e35\u0e2a\u0e34\u0e17\u0e18\u0e34\u0e4c\u0e08\u0e31\u0e14\u0e01\u0e32\u0e23\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49"),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                "\u0e40\u0e1e\u0e34\u0e48\u0e21\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19",
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _userIdController,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r"[A-Za-z0-9_-]"),
                                ),
                                UpperCaseTextFormatter(),
                              ],
                              decoration: const InputDecoration(
                                labelText:
                                    "\u0e23\u0e2b\u0e31\u0e2a\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _userNameController,
                              decoration: const InputDecoration(
                                labelText:
                                    "\u0e0a\u0e37\u0e48\u0e2d\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _positionController,
                              decoration: const InputDecoration(
                                labelText: "ตำแหน่ง",
                                hintText: "เช่น ฝ่ายผลิต / QC / จัดส่ง",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _pinController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "PIN",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _profileImageUrlController,
                              decoration: const InputDecoration(
                                labelText: "Profile Image URL",
                                hintText: "https://example.com/avatar.png",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _role,
                              decoration: const InputDecoration(
                                labelText:
                                    "\u0e2a\u0e34\u0e17\u0e18\u0e34\u0e4c",
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: "staff",
                                    child: Text(
                                        "\u0e1e\u0e19\u0e31\u0e01\u0e07\u0e32\u0e19")),
                                DropdownMenuItem(
                                    value: "admin",
                                    child: Text(
                                        "\u0e1c\u0e39\u0e49\u0e14\u0e39\u0e41\u0e25")),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _role = value;
                                  });
                                }
                              },
                            ),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                  "\u0e40\u0e1b\u0e34\u0e14\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19"),
                              value: _active,
                              onChanged: (value) {
                                setState(() {
                                  _active = value;
                                });
                              },
                            ),
                            FilledButton.icon(
                              onPressed: _isSaving ? null : _saveUser,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.person_add_alt_1),
                              label: const Text(
                                  "\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19"),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                        "\u0e23\u0e32\u0e22\u0e0a\u0e37\u0e48\u0e2d\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19",
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(radiusMd),
                        border:
                            Border.all(color: brandPrimary.withOpacity(0.16)),
                        boxShadow: [
                          BoxShadow(
                            color: brandPrimary.withOpacity(0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: brandSurfaceStrong.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: brandPrimary.withOpacity(0.10)),
                            ),
                            child: const Icon(
                              Icons.info_outline_rounded,
                              color: brandPrimary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "\u0e2b\u0e21\u0e32\u0e22\u0e40\u0e2b\u0e15\u0e38",
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: brandDeep,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "\u0e1a\u0e31\u0e0d\u0e0a\u0e35\u0e17\u0e35\u0e48\u0e01\u0e33\u0e25\u0e31\u0e07\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e2d\u0e22\u0e39\u0e48\u0e08\u0e30\u0e44\u0e21\u0e48\u0e2a\u0e32\u0e21\u0e32\u0e23\u0e16\u0e1b\u0e34\u0e14\u0e2b\u0e23\u0e37\u0e2d\u0e25\u0e1a\u0e44\u0e14\u0e49",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: brandInk,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        height: 1.45,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (users.isEmpty)
                      const _EmptyTile(
                          message:
                              "\u0e22\u0e31\u0e07\u0e44\u0e21\u0e48\u0e21\u0e35\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e43\u0e19\u0e23\u0e30\u0e1a\u0e1a")
                    else
                      ...users.map(
                        (user) {
                          final isCurrentUser =
                              user.userId == widget.currentUser.userId;
                          final isAdmin =
                              user.role.trim().toLowerCase() == "admin";
                          final badgeColor = isAdmin ? brandDeep : brandInk;
                          final badgeBackground = isAdmin
                              ? brandPrimary.withOpacity(0.24)
                              : brandSurfaceStrong.withOpacity(0.26);
                          return Card(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 14, 12, 14),
                              child: Row(
                                children: [
                                  _UserAvatar(
                                    imageUrl: widget.api
                                        .resolveAssetUrl(user.profileImageUrl),
                                    name: user.userName,
                                    radius: 24,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                user.userName,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontSize: 17,
                                                    ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5),
                                              decoration: BoxDecoration(
                                                color: badgeBackground,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                isAdmin ? "ADMIN" : "STAFF",
                                                style: TextStyle(
                                                  color: badgeColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.6,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          user.userId,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color:
                                                    brandInk.withOpacity(0.72),
                                              ),
                                        ),
                                        if (isCurrentUser) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: brandSurfaceStrong
                                                  .withOpacity(0.26),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Text(
                                              "\u0e01\u0e33\u0e25\u0e31\u0e07\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19",
                                              style: TextStyle(
                                                color: brandPrimary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      PopupMenuButton<String>(
                                        tooltip:
                                            "\u0e15\u0e31\u0e27\u0e40\u0e25\u0e37\u0e2d\u0e01",
                                        onSelected: (value) {
                                          if (value == "upload") {
                                            _pickAndUploadProfileImage(user);
                                          } else if (value == "delete") {
                                            _deleteUser(user);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem<String>(
                                            value: "upload",
                                            child: ListTile(
                                              leading: Icon(Icons
                                                  .add_photo_alternate_outlined),
                                              title: Text(
                                                  "\u0e2d\u0e31\u0e1b\u0e42\u0e2b\u0e25\u0e14\u0e23\u0e39\u0e1b"),
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                          if (!isCurrentUser)
                                            const PopupMenuItem<String>(
                                              value: "delete",
                                              child: ListTile(
                                                leading:
                                                    Icon(Icons.delete_outline),
                                                title: Text(
                                                    "\u0e25\u0e1a\u0e1e\u0e19\u0e31\u0e01\u0e07\u0e32\u0e19"),
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                            ),
                                        ],
                                        child: Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.78),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                              Icons.more_horiz_rounded,
                                              color: brandInk),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isCurrentUser)
                                            const Padding(
                                              padding:
                                                  EdgeInsets.only(right: 6),
                                              child: Tooltip(
                                                message:
                                                    "\u0e1a\u0e31\u0e0d\u0e0a\u0e35\u0e17\u0e35\u0e48\u0e01\u0e33\u0e25\u0e31\u0e07\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e25\u0e1a\u0e2b\u0e23\u0e37\u0e2d\u0e1b\u0e34\u0e14\u0e44\u0e21\u0e48\u0e44\u0e14\u0e49",
                                                child: Icon(Icons.lock_outline,
                                                    size: 18, color: brandInk),
                                              ),
                                            ),
                                          Transform.scale(
                                            scale: 0.92,
                                            child: Switch.adaptive(
                                              value: user.active,
                                              onChanged: isCurrentUser
                                                  ? null
                                                  : (_) => _toggleUser(user),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}


// --- Local Helpers ---

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


ImageProvider<Object>? _networkImageProvider(String? imageUrl) {
  if (imageUrl == null || imageUrl.trim().isEmpty) {
    return null;
  }
  return NetworkImage(imageUrl);
}


class _UserAvatar extends StatelessWidget {
  const _UserAvatar({
    required this.imageUrl,
    required this.name,
    this.radius = 22,
  });

  final String? imageUrl;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final imageProvider = _networkImageProvider(imageUrl);
    return CircleAvatar(
      // Force a fresh image resolution when the URL changes (helps on web + in-app caches).
      key: ValueKey(imageUrl),
      radius: radius,
      backgroundColor: brandSurfaceStrong,
      backgroundImage: imageProvider,
      child: imageProvider == null ? Text(name.isEmpty ? "?" : name[0]) : null,
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
                  "\u0e22\u0e31\u0e07\u0e44\u0e21\u0e48\u0e21\u0e35\u0e23\u0e32\u0e22\u0e01\u0e32\u0e23",
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


class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: pagePadding,
      children: [
        const SizedBox(height: 80),
        Container(
          padding: cardPadding,
          decoration: softPanelDecoration(
            tone: profileAccent,
            surfaceStrength: 0.30,
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: profileAccent.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: brandTextOnLight,
                  size: 26,
                ),
              ),
              const SizedBox(height: spaceSm),
              Text(
                "\u0e40\u0e0a\u0e37\u0e48\u0e2d\u0e21\u0e15\u0e48\u0e2d API \u0e44\u0e21\u0e48\u0e2a\u0e33\u0e40\u0e23\u0e47\u0e08",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: spaceXs),
              Text(
                message.replaceFirst("Exception: ", ""),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: brandInk.withOpacity(0.72),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

