import "dart:async";

import "package:flutter/material.dart";

import "api_service.dart";
import "models.dart";
import "theme/app_theme.dart";

class OrderChatPage extends StatefulWidget {
  const OrderChatPage({
    super.key,
    required this.api,
    required this.currentUser,
    required this.order,
  });

  final StockApiService api;
  final AppUser currentUser;
  final DeliveryOrder order;

  @override
  State<OrderChatPage> createState() => _OrderChatPageState();
}

class _OrderChatPageState extends State<OrderChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollTimer;
  bool _isLoading = false;
  bool _isSending = false;
  List<OrderMessageModel> _messages = const [];

  @override
  void initState() {
    super.initState();
    widget.api.markOrderMessagesRead(
      requesterId: widget.currentUser.userId,
      orderId: widget.order.id,
    );
    _load(initial: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _isSending) return;
      _load();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final items = await widget.api.getOrderMessages(
        requesterId: widget.currentUser.userId,
        orderId: widget.order.id,
      );
      await widget.api.markOrderMessagesRead(
        requesterId: widget.currentUser.userId,
        orderId: widget.order.id,
      );
      if (!mounted) return;
      setState(() {
        _messages = items;
      });
      if (initial) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    } catch (_) {
      // Silent background refresh.
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _isSending = true;
    });
    _controller.clear();
    try {
      await widget.api.postOrderMessage(
        requesterId: widget.currentUser.userId,
        orderId: widget.order.id,
        message: text,
      );
      await _load();
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          error.toString().replaceFirst("Exception: ", ""),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderTitle = widget.order.customerName;
    return Scaffold(
      appBar: AppBar(
        title: Text("แชทออเดอร์: $orderTitle"),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final item = _messages[index];
                final isMe = item.userId == widget.currentUser.userId;
                final bubbleColor = isMe ? brandPrimary : Colors.white;
                final textColor = isMe ? Colors.white : brandInk;
                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 340),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(16),
                      border: isMe
                          ? null
                          : Border.all(color: brandPrimary.withOpacity(0.22)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.userName,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: textColor.withOpacity(0.85),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.message,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: textColor,
                                  ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: "พิมพ์ข้อความติดตามงาน...",
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending ? null : _send,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    tooltip: "ส่ง",
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
