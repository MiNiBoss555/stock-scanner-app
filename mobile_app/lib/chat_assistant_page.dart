import "dart:async";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:url_launcher/url_launcher.dart";

import "api_service.dart";
import "models.dart";
import "theme/app_theme.dart";

class ChatAssistantPage extends StatefulWidget {
  const ChatAssistantPage({
    super.key,
    required this.api,
    required this.refreshSignal,
    this.onBack,
    this.onOpenProductDetails,
  });

  final StockApiService api;
  final ValueListenable<int> refreshSignal;
  final VoidCallback? onBack;
  final void Function(BuildContext context, Product product)? onOpenProductDetails;

  @override
  State<ChatAssistantPage> createState() => _ChatAssistantPageState();
}

class _ChatAssistantPageState extends State<ChatAssistantPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<_ChatMessage> _messages;
  bool _isSending = false;
  bool? _assistantAvailable;
  bool _isOpeningWithdraw = false;

  @override
  void initState() {
    super.initState();
    _messages = [
      _ChatMessage.bot(
        "ถามสต็อกหรือสั่งงานได้เลย เช่น \"อะไรใกล้หมดบ้าง\" หรือ \"เบิก 2 8851234567890\"",
      ),
    ];
    widget.refreshSignal.addListener(_handleRealtimeRefresh);
    _checkAssistantAvailability();
  }

  @override
  void dispose() {
    widget.refreshSignal.removeListener(_handleRealtimeRefresh);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleRealtimeRefresh() {
    if (!mounted) {
      return;
    }
    setState(() {
      _messages = [
        ..._messages,
        _ChatMessage.bot("สต็อกมีการอัปเดตแล้ว ถามใหม่ได้เลย"),
      ];
    });
    _scrollToBottom();
  }

  Future<void> _checkAssistantAvailability() async {
    final available = await widget.api.isAssistantAvailable();
    if (!mounted) {
      return;
    }
    setState(() {
      _assistantAvailable = available;
      if (!available) {
        _messages = [
          _messages.first,
          _ChatMessage.bot(
            "เซิร์ฟเวอร์ที่เชื่อมต่ออยู่ยังไม่รองรับฟีเจอร์แชท กรุณาอัปเดต backend แล้วลองใหม่",
          ),
        ];
      }
    });
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _messageController.text).trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    final pendingAction = _detectPendingChatAction(text);
    if (pendingAction != null) {
      final confirmed = await _confirmChatAction(pendingAction);
      if (confirmed != true) {
        return;
      }
    }

    FocusScope.of(context).unfocus();
    _messageController.clear();
    setState(() {
      _isSending = true;
      _messages = [
        ..._messages,
        _ChatMessage.user(text),
      ];
    });
    _scrollToBottom();

    try {
      final reply = await widget.api.askAssistant(message: text);
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = [
          ..._messages,
          _ChatMessage.bot(
            reply.message,
            products: reply.matchedProducts,
            usedAi: reply.usedAi,
            action: reply.action,
            downloadLink: reply.downloadLink,
          ),
        ];
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = [
          ..._messages,
          _ChatMessage.bot(
            "ยังดึงข้อมูลสต็อกไม่ได้: ${normalizeFeedbackMessage(error.toString())}",
          ),
        ];
      });
      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<bool?> _confirmChatAction(_PendingChatAction action) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("ยืนยันคำสั่งสต็อก"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(action.summary),
              const SizedBox(height: 8),
              Text(
                "คำสั่งนี้จะบันทึกลงสต็อกจริงทันที",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("ยกเลิก"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text("ยืนยัน"),
            ),
          ],
        );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _openWithdrawFlow() async {
    if (_isOpeningWithdraw || _assistantAvailable == false) {
      return;
    }
    setState(() {
      _isOpeningWithdraw = true;
    });
    try {
      final products = await widget.api.getProducts();
      if (!mounted) return;

      final qtyController = TextEditingController(text: "1");
      String? selectedBarcode;

      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.remove_circle_outline,
                          color: brandPrimary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "เบิกสินค้า",
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: "ปิด",
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Material(
                    type: MaterialType.transparency,
                    // DropdownMenu inside a modal bottom sheet has caused framework assertions
                    // on some devices/emulators. DropdownButtonFormField is more stable here.
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: (selectedBarcode != null &&
                              products.any((p) => p.barcode == selectedBarcode))
                          ? selectedBarcode
                          : null,
                      decoration: const InputDecoration(
                        labelText: "เลือกสินค้า",
                        hintText: "เลือกจากรายการ",
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text("— เลือกสินค้า —"),
                        ),
                        ...products.map(
                          (p) => DropdownMenuItem<String>(
                            value: p.barcode,
                            child: Text(
                              "${p.name} • ${p.barcode} • คงเหลือ ${p.currentStock} ${p.unit}",
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setSheetState(() {
                          selectedBarcode = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "จำนวนที่ต้องการเบิก",
                      prefixIcon: Icon(Icons.numbers_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          child: const Text("ยกเลิก"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            if (selectedBarcode == null ||
                                selectedBarcode!.trim().isEmpty) {
                              _showAppSnack(context, "กรุณาเลือกสินค้า",
                                  isError: true);
                              return;
                            }
                            final qty = int.tryParse(qtyController.text.trim());
                            if (qty == null || qty <= 0) {
                              _showAppSnack(context, "จำนวนไม่ถูกต้อง",
                                  isError: true);
                              return;
                            }
                            Navigator.of(sheetContext).pop(true);
                          },
                          child: const Text("เบิก"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (confirmed == true && mounted) {
        final qty = int.tryParse(qtyController.text.trim()) ?? 1;
        final barcode = (selectedBarcode ?? "").trim();
        if (barcode.isNotEmpty) {
          await _sendMessage("เบิก $qty $barcode");
        }
      }

      qtyController.dispose();
    } catch (error) {
      if (mounted) {
        _showAppSnack(
          context,
          "โหลดรายการสินค้าไม่สำเร็จ: ${normalizeFeedbackMessage(error.toString())}",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningWithdraw = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const suggestions = [
      "อะไรใกล้หมดบ้าง",
      "ขอไฟล์ Excel",
      "เบิกสินค้า",
    ];

    return Material(
      color: brandSurface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: IconButton(
                      tooltip: "ย้อนกลับ",
                      onPressed: _handleBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6, left: 6),
                      child: const _PageHeader(
                        title:
                            "\u0e41\u0e0a\u0e17\u0e1c\u0e39\u0e49\u0e0a\u0e48\u0e27\u0e22\u0e2a\u0e15\u0e4a\u0e2d\u0e01",
                        subtitle:
                            "\u0e16\u0e32\u0e21\u0e08\u0e33\u0e19\u0e27\u0e19\u0e04\u0e07\u0e40\u0e2b\u0e25\u0e37\u0e2d \u0e14\u0e39\u0e02\u0e2d\u0e07\u0e43\u0e01\u0e25\u0e49\u0e2b\u0e21\u0e14 \u0e2b\u0e23\u0e37\u0e2d\u0e2a\u0e31\u0e48\u0e07\u0e40\u0e1e\u0e34\u0e48\u0e21-\u0e15\u0e31\u0e14\u0e2a\u0e15\u0e4a\u0e2d\u0e01\u0e08\u0e32\u0e01\u0e41\u0e0a\u0e17\u0e44\u0e14\u0e49\u0e40\u0e25\u0e22",
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    return ActionChip(
                      label: Text(suggestion),
                      onPressed: _isSending
                          ? null
                          : () {
                              if (suggestion == "เบิกสินค้า") {
                                _openWithdrawFlow();
                                return;
                              }
                              _sendMessage(suggestion);
                            },
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _ChatBubble(
                    message: message,
                    onOpenProduct: (product) {
                      if (widget.onOpenProductDetails != null) {
                        widget.onOpenProductDetails!(context, product);
                      }
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      minLines: 1,
                      maxLines: 3,
                      enabled: _assistantAvailable != false,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText:
                            "\u0e1e\u0e34\u0e21\u0e1e\u0e4c\u0e04\u0e33\u0e16\u0e32\u0e21\u0e40\u0e01\u0e35\u0e48\u0e22\u0e27\u0e01\u0e31\u0e1a\u0e2a\u0e15\u0e4a\u0e2d\u0e01...",
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: _isSending || _assistantAvailable == false
                        ? null
                        : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
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


class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.products = const [],
    this.usedAi = false,
    this.action,
    this.downloadLink,
  });

  factory _ChatMessage.user(String text) =>
      _ChatMessage(text: text, isUser: true);

  factory _ChatMessage.bot(
    String text, {
    List<Product> products = const [],
    bool usedAi = false,
    ChatAssistantAction? action,
    ExportLink? downloadLink,
  }) {
    return _ChatMessage(
      text: repairThaiMojibake(text),
      isUser: false,
      products: products,
      usedAi: usedAi,
      action: action,
      downloadLink: downloadLink,
    );
  }

  final String text;
  final bool isUser;
  final List<Product> products;
  final bool usedAi;
  final ChatAssistantAction? action;
  final ExportLink? downloadLink;
}


class _PendingChatAction {
  const _PendingChatAction({
    required this.type,
    required this.quantity,
    required this.productHint,
  });

  final String type;
  final int quantity;
  final String productHint;

  String get summary {
    final verb = switch (type) {
      "in" => "เพิ่มสต็อก",
      "issue" => "เบิกออก",
      _ => "ปรับ/แก้ไขสต็อก",
    };
    return "$verb จำนวน $quantity สำหรับ \"$productHint\"";
  }
}


_PendingChatAction? _detectPendingChatAction(String message) {
  final lowered = message.trim().toLowerCase();
  final intents = <String, List<String>>{
    "in": [
      "เพิ่ม",
      "รับเข้า",
      "เติม",
      "นำเข้า",
      "เอาเข้า",
      "เพิ่มสต็อก",
      "เพิ่มสต็อก"
    ],
    "out": [
      "เบิก",
      "ตัด",
      "ลด",
      "จ่ายออก",
      "เอาออก",
      "ลดสต็อก",
      "ลดสต็อก",
      "ตัดสต็อก",
      "ตัดสต็อก"
    ],
    "issue": ["issue", "ใช้ไป", "นำออกใช้", "หยิบใช้", "เบิกใช้"],
  };

  String? detectedType;
  List<String> matchedKeywords = const [];
  for (final entry in intents.entries) {
    final hit =
        entry.value.where((keyword) => lowered.contains(keyword)).toList();
    if (hit.isNotEmpty) {
      detectedType = entry.key;
      matchedKeywords = hit;
      break;
    }
  }
  if (detectedType == null) {
    return null;
  }

  int? quantity;
  for (final token in message.replaceAll(",", " ").split(RegExp(r"\s+"))) {
    if (token.isEmpty) {
      continue;
    }
    final parsed = int.tryParse(token);
    if (parsed != null && parsed > 0) {
      quantity = parsed;
      break;
    }
  }
  if (quantity == null) {
    return null;
  }

  var productHint = message;
  for (final keyword in matchedKeywords) {
    productHint = productHint.replaceAll(keyword, " ");
    productHint = productHint.replaceAll(keyword.toUpperCase(), " ");
  }
  productHint = productHint.replaceAll(RegExp(r"\b\d+\b"), " ");
  productHint = productHint.replaceAll(RegExp(r"\s+"), " ").trim();
  if (productHint.isEmpty) {
    productHint = "สินค้าที่ระบุ";
  }

  return _PendingChatAction(
    type: detectedType,
    quantity: quantity,
    productHint: productHint,
  );
}


class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.onOpenProduct,
  });

  final _ChatMessage message;
  final ValueChanged<Product> onOpenProduct;

  @override
  Widget build(BuildContext context) {
    final alignment =
        message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = message.isUser ? brandDeep : brandCard;
    final textColor = message.isUser ? Colors.white : brandInk;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(18),
                border: message.isUser
                    ? null
                    : Border.all(color: brandPrimary.withOpacity(0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!message.isUser &&
                      (message.usedAi || message.action != null)) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (message.usedAi)
                          _ChatMetaChip(
                            label: "AI",
                            tone: profileTeal,
                          ),
                        if (message.action != null)
                          _ChatMetaChip(
                            label: "สั่งงานแล้ว",
                            tone: message.action!.lowStock
                                ? brandPrimary
                                : brandDeep,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    message.text,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: textColor),
                  ),
                ],
              ),
            ),
          ),
          if (message.products.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...message.products.map(
              (product) => SizedBox(
                width: 320,
                child: _ProductTile(
                  product: product,
                  onOpenCode: () => onOpenProduct(product),
                  onPrintLabel: () => onOpenProduct(product),
                ),
              ),
            ),
          ],
          if (message.downloadLink != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 320,
              child: _SelectableUrl(
                label: "ดาวน์โหลดไฟล์",
                url: message.downloadLink!.url,
                expiresAt: message.downloadLink!.expiresAt,
              ),
            ),
          ],
        ],
      ),
    );
  }
}


class _ChatMetaChip extends StatelessWidget {
  const _ChatMetaChip({
    required this.label,
    required this.tone,
  });

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tone,
              fontWeight: FontWeight.w700,
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

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    this.onOpenCode,
    this.onPrintLabel,
  });

  final Product product;
  final VoidCallback? onOpenCode;
  final VoidCallback? onPrintLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
        minLeadingWidth: 34,
        onTap: onOpenCode,
        title: Text(
          product.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          "${product.barcode} · ${product.location ?? "ไม่ระบุตำแหน่ง"}",
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5),
        ),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: (product.isLowStock ? brandPrimary : brandDeep)
              .withOpacity(0.10),
          child: Icon(
            product.isLowStock
                ? Icons.warning_amber_rounded
                : Icons.inventory_2_rounded,
            size: 18,
            color: product.isLowStock ? brandPrimary : brandDeep,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${product.currentStock} ${product.unit}",
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                Text(
                  "min ${product.minimumStock}",
                  style: TextStyle(
                    fontSize: 11.5,
                    color:
                        product.isLowStock ? brandPrimary : brandTextOnLight,
                  ),
                ),
              ],
            ),
            if (onPrintLabel != null) ...[
              const SizedBox(width: 4),
              IconButton(
                onPressed: onPrintLabel,
                icon: const Icon(Icons.print_outlined, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                tooltip: "พิมพ์ป้ายสินค้า",
              ),
            ],
            if (onOpenCode != null) ...[
              const SizedBox(width: 2),
              IconButton(
                onPressed: onOpenCode,
                icon: const Icon(Icons.qr_code_2_outlined, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                tooltip: "\u0e14\u0e39 barcode",
              ),
            ],
          ],
        ),
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
      _showAppSnack(context,
          "\u0e25\u0e34\u0e07\u0e01\u0e4c\u0e44\u0e21\u0e48\u0e16\u0e39\u0e01\u0e15\u0e49\u0e2d\u0e07");
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      _showAppSnack(
        context,
        "\u0e44\u0e21\u0e48\u0e2a\u0e32\u0e21\u0e32\u0e23\u0e16\u0e40\u0e1b\u0e34\u0e14\u0e25\u0e34\u0e07\u0e01\u0e4c\u0e14\u0e32\u0e27\u0e19\u0e4c\u0e42\u0e2b\u0e25\u0e14\u0e44\u0e14\u0e49",
      );
    }
  }

  Future<void> _copyUrl(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      _showAppSnack(context,
          "\u0e04\u0e31\u0e14\u0e25\u0e2d\u0e01\u0e25\u0e34\u0e07\u0e01\u0e4c\u0e41\u0e25\u0e49\u0e27");
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
                "\u0e2b\u0e21\u0e14\u0e2d\u0e32\u0e22\u0e38 ${_formatDateTime(expiresAt!)}",
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
                    label: const Text(
                        "\u0e14\u0e32\u0e27\u0e19\u0e4c\u0e42\u0e2b\u0e25\u0e14\u0e40\u0e25\u0e22"),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: () => _copyUrl(context),
                  icon: const Icon(Icons.copy_all_outlined),
                  tooltip:
                      "\u0e04\u0e31\u0e14\u0e25\u0e2d\u0e01\u0e25\u0e34\u0e07\u0e01\u0e4c",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _showAppSnack(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final displayMessage = normalizeFeedbackMessage(message);
  final messenger = ScaffoldMessenger.of(context);
  final backgroundColor = isError ? brandInk : brandDeep;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(spaceMd, 0, spaceMd, spaceMd),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 4),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.info_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                displayMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

String _formatDateTime(DateTime value) {
  final date = "${value.day.toString().padLeft(2, "0")}/"
      "${value.month.toString().padLeft(2, "0")}/"
      "${value.year}";
  final time = "${value.hour.toString().padLeft(2, "0")}:"
      "${value.minute.toString().padLeft(2, "0")}";
  return "$date $time";
}
