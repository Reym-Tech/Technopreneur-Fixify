// lib/presentation/screens/shared/chat_screen.dart
//
// ChatScreen — booking-scoped 1:1 realtime chat UI.
// MVC ROLE: VIEW
//   • Receives data and callbacks from the Controller (main.dart).
//   • Owns only local UI state (composer text, scroll).

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';

typedef ChatSubscribeFn = Object Function(void Function(ChatMessageEntity msg));
typedef ChatUnsubscribeFn = void Function(Object channel);

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

  @override
  void initState() {
    super.initState();
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

      _channel = widget.subscribe((msg) {
        if (!mounted) return;
        // Ignore duplicates (can happen if the INSERT arrives before initial fetch).
        final already = _messages.any((m) => m.id == msg.id);
        if (already) return;
        setState(() => _messages.add(msg));
        _scrollToBottom();
      });

      // Initial jump after first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_channel != null) {
      widget.unsubscribe(_channel!);
    }
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    _scroll.animateTo(
      max,
      duration: 220.ms,
      curve: Curves.easeOut,
    );
  }

  Future<void> _onSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final sent = await widget.sendMessage(bookingId: widget.bookingId, body: text);
      if (!mounted) return;
      _controller.clear();

      // Optimistic append; realtime will be deduped by id.
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
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
                    : _MessageList(
                        scroll: _scroll,
                        messages: _messages,
                        currentUserId: widget.currentUserId,
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

  const _MessageList({
    required this.scroll,
    required this.messages,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Text(
          'Say hi to get started.',
          style: TextStyle(
              color: AppColors.textMedium.withOpacity(0.9), fontSize: 13),
        ).animate().fadeIn(duration: 200.ms),
      );
    }

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      itemCount: messages.length,
      itemBuilder: (_, i) {
        final m = messages[i];
        final mine = m.senderId == currentUserId;
        return _Bubble(message: m, mine: mine);
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessageEntity message;
  final bool mine;

  const _Bubble({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    final bg = mine ? AppColors.primary : Colors.white;
    final fg = mine ? Colors.white : AppColors.textDark;
    final align = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
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
          child: Text(
            message.body,
            style: TextStyle(
                color: fg, fontSize: 13.5, height: 1.35, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 120.ms);
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