// lib/presentation/screens/shared/chat_screen.dart
//
// ChatScreen — booking-scoped 1:1 realtime chat UI.
// MVC ROLE: VIEW
//   • Receives data and callbacks from the Controller (main.dart).
//   • Owns only local UI state (composer text, scroll).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';

typedef ChatSubscribeFn = Object Function(
  void Function(ChatMessageEntity msg) onInsert,
  void Function(String messageId) onDelete,
);
typedef ChatUnsubscribeFn = void Function(Object channel);
typedef ChatTypingSubscribeFn = Object Function(
  void Function(String userId) onTyping,
  void Function(String userId) onStoppedTyping,
);
typedef ChatBroadcastTypingFn = Future<void> Function({required bool isTyping});
typedef ChatMarkReadFn = Future<void> Function();
typedef ChatSubscribeReadFn = Object Function(
  void Function(String messageId, DateTime readAt) onRead,
);

class ChatScreen extends StatefulWidget {
  final String bookingId;
  final String currentUserId;
  final String title;
  final VoidCallback? onBack;

  final Future<List<ChatMessageEntity>> Function(String bookingId)
      loadInitialMessages;
  final Future<ChatMessageEntity> Function({
    required String bookingId,
    required String body,
  }) sendMessage;

  /// Returns a channel-like object (RealtimeChannel) that must be passed back
  /// into [unsubscribe] on dispose.
  final ChatSubscribeFn subscribe;
  final ChatUnsubscribeFn unsubscribe;

  /// Optional — only own messages can be deleted.
  final Future<void> Function({required String messageId})? deleteMessage;

  /// Typing presence — subscribe/broadcast.
  final ChatTypingSubscribeFn subscribeTyping;
  final ChatBroadcastTypingFn broadcastTyping;

  /// Marks all incoming messages as read (DB write).
  final ChatMarkReadFn markRead;

  /// Listens for read_at UPDATE events so seen ticks update in realtime.
  final ChatSubscribeReadFn subscribeReadReceipts;

  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.currentUserId,
    required this.title,
    this.onBack,
    required this.loadInitialMessages,
    required this.sendMessage,
    required this.subscribe,
    required this.unsubscribe,
    this.deleteMessage,
    required this.subscribeTyping,
    required this.broadcastTyping,
    required this.markRead,
    required this.subscribeReadReceipts,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  bool _loading = true;
  bool _sending = false;
  final List<ChatMessageEntity> _messages = [];

  Object? _channel;
  Object? _typingChannel;
  Object? _readChannel;

  // Typing indicator state
  final Set<String> _typingUsers = {};
  Timer? _stopTypingTimer;
  bool _isBroadcastingTyping = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final initial = await widget.loadInitialMessages(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(initial);
        _loading = false;
      });

      // Mark messages read on open
      widget.markRead();

      _channel = widget.subscribe(
        (msg) {
          if (!mounted) return;
          final already = _messages.any((m) => m.id == msg.id);
          if (already) return;
          setState(() => _messages.add(msg));
          _scrollToBottom();
          widget.markRead();
        },
        (messageId) {
          // Realtime delete — remove from both sides' list instantly
          if (!mounted) return;
          setState(() => _messages.removeWhere((m) => m.id == messageId));
        },
      );

      _typingChannel = widget.subscribeTyping(
        (userId) {
          if (!mounted || userId == widget.currentUserId) return;
          setState(() => _typingUsers.add(userId));
          _scrollToBottom();
        },
        (userId) {
          if (!mounted) return;
          setState(() => _typingUsers.remove(userId));
        },
      );

      // Realtime seen ticks — update existing message in-memory when
      // the other side's markRead() call flips read_at in Postgres.
      _readChannel = widget.subscribeReadReceipts((messageId, readAt) {
        if (!mounted) return;
        final idx = _messages.indexWhere((m) => m.id == messageId);
        if (idx == -1) return;
        final old = _messages[idx];
        if (old.readAt != null) return; // already marked, skip rebuild
        setState(() {
          _messages[idx] = ChatMessageEntity(
            id: old.id,
            threadId: old.threadId,
            bookingId: old.bookingId,
            senderId: old.senderId,
            body: old.body,
            createdAt: old.createdAt,
            readAt: readAt,
          );
        });
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;

    if (hasText && !_isBroadcastingTyping) {
      _isBroadcastingTyping = true;
      widget.broadcastTyping(isTyping: true);
    }

    // Debounce: stop typing broadcast 2s after last keystroke
    _stopTypingTimer?.cancel();
    if (hasText) {
      _stopTypingTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        _isBroadcastingTyping = false;
        widget.broadcastTyping(isTyping: false);
      });
    } else {
      _isBroadcastingTyping = false;
      widget.broadcastTyping(isTyping: false);
    }
  }

  @override
  void dispose() {
    _stopTypingTimer?.cancel();
    // Broadcast stopped typing before leaving
    widget.broadcastTyping(isTyping: false);
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    if (_channel != null) widget.unsubscribe(_channel!);
    if (_typingChannel != null) widget.unsubscribe(_typingChannel!);
    if (_readChannel != null) widget.unsubscribe(_readChannel!);
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    _scroll.animateTo(max, duration: 220.ms, curve: Curves.easeOut);
  }

  Future<void> _onDelete(ChatMessageEntity msg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete message?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        content: const Text(
          'This will remove it for everyone.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await widget.deleteMessage!(messageId: msg.id);
    if (!mounted) return;
    setState(() => _messages.removeWhere((m) => m.id == msg.id));
  }

  Future<void> _onSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    // Stop typing broadcast immediately on send
    _stopTypingTimer?.cancel();
    _isBroadcastingTyping = false;
    widget.broadcastTyping(isTyping: false);

    setState(() => _sending = true);
    try {
      final sent = await widget.sendMessage(
          bookingId: widget.bookingId, body: text);
      if (!mounted) return;
      _controller.clear();
      final already = _messages.any((m) => m.id == sent.id);
      if (!already) setState(() => _messages.add(sent));
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack?.call();
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: SafeArea(
          child: Column(
            children: [
              _Header(title: widget.title, onBack: widget.onBack),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      )
                    : _MessageList(
                        scroll: _scroll,
                        messages: _messages,
                        currentUserId: widget.currentUserId,
                        onDelete: widget.deleteMessage != null
                            ? _onDelete
                            : null,
                        isOtherTyping: _typingUsers.isNotEmpty,
                      ),
              ),
              _Composer(
                controller: _controller,
                sending: _sending,
                onSend: _onSend,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const _Header({required this.title, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 14, color: AppColors.primary),
                SizedBox(width: 6),
                Text('Booking chat',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  final ScrollController scroll;
  final List<ChatMessageEntity> messages;
  final String currentUserId;
  final void Function(ChatMessageEntity)? onDelete;
  final bool isOtherTyping;

  const _MessageList({
    required this.scroll,
    required this.messages,
    required this.currentUserId,
    this.onDelete,
    required this.isOtherTyping,
  });

  /// Returns "Today", "Yesterday", or "April 28" style label.
  static String _dateLabel(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(local.year, local.month, local.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final label = '${months[local.month - 1]} ${local.day}';
    return local.year != now.year ? '$label, ${local.year}' : label;
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty && !isOtherTyping) {
      return Center(
        child: Text(
          'Say hi to get started.',
          style: TextStyle(
              color: AppColors.textMedium.withOpacity(0.9), fontSize: 13),
        ).animate().fadeIn(duration: 200.ms),
      );
    }

    // Build a flat list of items: date separators interleaved with messages.
    // Each item is either a DateTime (separator) or a ChatMessageEntity.
    final List<Object> items = [];
    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final isFirst = i == 0;
      final prevMsg = isFirst ? null : messages[i - 1];
      if (isFirst || !_sameDay(prevMsg!.createdAt, msg.createdAt)) {
        items.add(msg.createdAt); // separator
      }
      items.add(msg);
    }
    if (isOtherTyping) items.add('typing'); // sentinel

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item == 'typing') return const _TypingBubble();
        if (item is DateTime) {
          return _DateSeparator(label: _dateLabel(item));
        }
        final m = item as ChatMessageEntity;
        final mine = m.senderId == currentUserId;
        return _Bubble(
          message: m,
          mine: mine,
          onDelete: mine ? onDelete : null,
        );
      },
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final String label;
  const _DateSeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: AppColors.textMedium.withOpacity(0.18),
              thickness: 1,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary.withOpacity(0.75),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              color: AppColors.textMedium.withOpacity(0.18),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessageEntity message;
  final bool mine;
  final void Function(ChatMessageEntity)? onDelete;

  const _Bubble({
    required this.message,
    required this.mine,
    this.onDelete,
  });

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final bg = mine ? AppColors.primary : Colors.white;
    final fg = mine ? Colors.white : AppColors.textDark;
    final align = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: align,
      children: [
        GestureDetector(
          onLongPress: onDelete != null ? () => onDelete!(message) : null,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mine ? 16 : 6),
                bottomRight: Radius.circular(mine ? 6 : 16),
              ),
              boxShadow: mine
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.22),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      )
                    ],
              border: mine
                  ? null
                  : Border.all(color: const Color(0xFFEFEFEF), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.body,
                  style: TextStyle(
                      color: fg,
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                        color: fg.withOpacity(0.55),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (mine) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.isRead
                            ? Icons.done_all_rounded
                            : Icons.done_rounded,
                        size: 13,
                        color: message.isRead
                            ? Colors.lightBlueAccent
                            : fg.withOpacity(0.55),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 120.ms);
  }
}

/// Animated three-dot typing indicator shown when the other participant is typing.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            )
          ],
          border: Border.all(color: const Color(0xFFEFEFEF), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                // Each dot offset by 0.3 in the 0–1 cycle
                final offset = ((_ctrl.value + i * 0.3) % 1.0);
                // Bounce: goes up then down
                final dy = offset < 0.5
                    ? -4.0 * (offset / 0.5)
                    : -4.0 * (1 - (offset - 0.5) / 0.5);
                return Transform.translate(
                  offset: Offset(0, dy),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    ).animate().fadeIn(duration: 150.ms);
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, -6),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Message…',
                hintStyle: const TextStyle(color: AppColors.textLight),
                filled: true,
                fillColor: AppColors.primary.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: sending
                ? AppColors.primary.withOpacity(0.4)
                : AppColors.primary,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: sending ? null : onSend,
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 46,
                height: 46,
                child: Center(
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded,
                          size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}