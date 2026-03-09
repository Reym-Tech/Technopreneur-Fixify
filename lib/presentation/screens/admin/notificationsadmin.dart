// lib/presentation/screens/admin/notificationsadmin.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/data/datasources/notification_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminNotificationsScreen extends StatefulWidget {
  final String userId;
  final VoidCallback? onBack;
  final Function(AppNotification notification)? onNotificationTap;
  final NotificationDataSource? notificationDataSource;
  final Function(String applicationId)? onApprove;
  final Function(String applicationId)? onReject;

  const AdminNotificationsScreen({
    super.key,
    required this.userId,
    this.onBack,
    this.onNotificationTap,
    this.notificationDataSource,
    this.onApprove,
    this.onReject,
  });

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  late final NotificationDataSource _ds;
  RealtimeChannel? _channel;

  List<AppNotification> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ds = widget.notificationDataSource ??
        NotificationDataSource(Supabase.instance.client);
    _loadNotifications();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    if (_channel != null) _ds.unsubscribe(_channel!);
    super.dispose();
  }

  Future<void> _loadNotifications({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await _ds.getNotifications(userId: widget.userId);
      if (mounted) setState(() => _notifications = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    _channel = _ds.subscribeToNotifications(
      userId: widget.userId,
      onNew: (n) {
        if (mounted) setState(() => _notifications = [n, ..._notifications]);
      },
    );
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;
  int get _applicationCount => _notifications
      .where((n) => n.type == NotificationTypeStrings.newApplication)
      .length;
  int get _pendingApplicationCount => _notifications
      .where(
          (n) => n.type == NotificationTypeStrings.newApplication && !n.isRead)
      .length;

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) {
      widget.onNotificationTap?.call(notification);
      return;
    }
    setState(() {
      _notifications = _notifications
          .map((n) => n.id == notification.id ? n.copyAsRead() : n)
          .toList();
    });
    try {
      await _ds.markAsRead(notification.id);
    } catch (_) {
      if (mounted) {
        setState(() {
          _notifications = _notifications
              .map((n) => n.id == notification.id ? notification : n)
              .toList();
        });
      }
    }
    widget.onNotificationTap?.call(notification);
  }

  Future<void> _markAllAsRead() async {
    final previous = List<AppNotification>.from(_notifications);
    setState(() {
      _notifications = _notifications.map((n) => n.copyAsRead()).toList();
    });
    try {
      await _ds.markAllAsRead(widget.userId);
    } catch (_) {
      if (mounted) setState(() => _notifications = previous);
    }
  }

  Future<void> _deleteNotification(AppNotification notification) async {
    setState(() {
      _notifications =
          _notifications.where((n) => n.id != notification.id).toList();
    });
    try {
      await _ds.deleteNotification(notification.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _notifications = [notification, ..._notifications];
          _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Failed to delete notification'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Notifications',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: const Text(
          'This will permanently delete all your notifications. This cannot be undone.',
          style: TextStyle(fontSize: 14, color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMedium)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Clear All',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final previous = List<AppNotification>.from(_notifications);
    setState(() => _notifications = []);
    try {
      await _ds.clearAllNotifications(widget.userId);
    } catch (e) {
      if (mounted) {
        setState(() => _notifications = previous);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Failed to clear notifications'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  Color _colorFor(String type) {
    switch (type) {
      case NotificationTypeStrings.newApplication:
        return const Color(0xFFFF9500);
      case NotificationTypeStrings.applicationReviewed:
        return const Color(0xFF34C759);
      case NotificationTypeStrings.userReport:
        return const Color(0xFFFF3B30);
      case NotificationTypeStrings.systemAdmin:
        return const Color(0xFF007AFF);
      default:
        return const Color(0xFF5856D6);
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case NotificationTypeStrings.newApplication:
        return Icons.assignment_rounded;
      case NotificationTypeStrings.applicationReviewed:
        return Icons.verified_rounded;
      case NotificationTypeStrings.userReport:
        return Icons.flag_rounded;
      case NotificationTypeStrings.systemAdmin:
        return Icons.settings_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  String? _actionLabelFor(String type) {
    switch (type) {
      case NotificationTypeStrings.newApplication:
        return 'Review';
      case NotificationTypeStrings.userReport:
        return 'Investigate';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: _loading
          ? _buildLoader()
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => _loadNotifications(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  if (_error != null) SliverToBoxAdapter(child: _buildError()),
                  if (_unreadCount > 0 && _error == null)
                    SliverToBoxAdapter(
                      child: _buildStatsCard()
                          .animate()
                          .fadeIn(delay: 100.ms)
                          .slideY(begin: 0.1, end: 0),
                    ),
                  if (_error == null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Admin Notifications',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark)),
                            Row(children: [
                              if (_unreadCount > 0)
                                TextButton(
                                  onPressed: _markAllAsRead,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                  ),
                                  child: const Text('Mark all read',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary)),
                                ),
                              if (_notifications.isNotEmpty)
                                TextButton(
                                  onPressed: _clearAll,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                  ),
                                  child: const Text('Clear All',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.error)),
                                ),
                            ]),
                          ],
                        ),
                      ).animate().fadeIn(delay: 150.ms),
                    ),
                  if (_notifications.isEmpty && _error == null)
                    SliverFillRemaining(child: _buildEmptyState())
                  else if (_error == null)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final n = _notifications[index];
                            return Dismissible(
                              key: Key(n.id),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (_) async {
                                await _deleteNotification(n);
                                return false;
                              },
                              background: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.delete_rounded,
                                        color: Colors.white, size: 26),
                                    SizedBox(height: 4),
                                    Text('Delete',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              // ── FIX: removed animate() from the tile entirely.
                              // flutter_animate's slideX/fadeIn passes unconstrained
                              // width to children during the first layout pass, which
                              // causes OutlinedButton to receive w=Infinity and crash.
                              // The header & stats card still animate; individual tiles
                              // use a simple staggered fade via AnimatedOpacity instead.
                              child: _AdminNotificationTile(
                                notification: n,
                                timestamp: _formatTimestamp(n.createdAt),
                                color: _colorFor(n.type),
                                icon: _iconFor(n.type),
                                actionLabel: _actionLabelFor(n.type),
                                onTap: () => _markAsRead(n),
                                onApprove: (widget.onApprove != null &&
                                        n.type ==
                                            NotificationTypeStrings
                                                .newApplication &&
                                        !n.isRead &&
                                        n.referenceId != null)
                                    ? () => widget.onApprove!(n.referenceId!)
                                    : null,
                                onReject: (widget.onReject != null &&
                                        n.type ==
                                            NotificationTypeStrings
                                                .newApplication &&
                                        !n.isRead &&
                                        n.referenceId != null)
                                    ? () => widget.onReject!(n.referenceId!)
                                    : null,
                              ),
                            );
                          },
                          childCount: _notifications.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildLoader() => const Center(
        child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primary)),
      );

  Widget _buildError() => Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Text(_error!,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMedium))),
            TextButton(
              onPressed: _loadNotifications,
              child: const Text('Retry',
                  style: TextStyle(color: AppColors.primary)),
            ),
          ]),
        ),
      );

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF082218), Color(0xFF0F3D2E), Color(0xFF1A5C43)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Positioned(top: -30, right: -20, child: _circle(180, 0.04)),
          Positioned(top: 70, right: 40, child: _circle(90, 0.06)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    GestureDetector(
                      onTap: widget.onBack ??
                          () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Notifications',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin Center',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.65),
                                  fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('System Updates & Alerts',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    _unreadBadge(),
                  ]),
                  if (_pendingApplicationCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9500).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFFF9500).withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.pending_actions_rounded,
                                color: Color(0xFFFF9500), size: 14),
                            const SizedBox(width: 6),
                            Text(
                              '$_pendingApplicationCount pending '
                              '${_pendingApplicationCount == 1 ? 'application' : 'applications'}',
                              style: const TextStyle(
                                  color: Color(0xFFFF9500),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.05, end: 0);
  }

  Widget _unreadBadge() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Row(children: [
          Text('$_unreadCount',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Text('unread',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7), fontSize: 12)),
        ]),
      );

  Widget _circle(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: Colors.white.withOpacity(opacity)),
      );

  Widget _buildStatsCard() {
    final now = DateTime.now();
    final todayCount = _notifications
        .where((n) =>
            n.createdAt.year == now.year &&
            n.createdAt.month == now.month &&
            n.createdAt.day == now.day)
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
                icon: Icons.notifications_active_rounded,
                value: '$_unreadCount',
                label: 'Unread',
                color: AppColors.primary),
            _divider(),
            _buildStatItem(
                icon: Icons.pending_actions_rounded,
                value: '$_applicationCount',
                label: 'Applications',
                color: const Color(0xFFFF9500)),
            _divider(),
            _buildStatItem(
                icon: Icons.today_rounded,
                value: '$todayCount',
                label: 'Today',
                color: const Color(0xFF007AFF)),
          ],
        ),
      ),
    );
  }

  Widget _divider() =>
      Container(height: 30, width: 1, color: Colors.grey.shade200);

  Widget _buildStatItem(
          {required IconData icon,
          required String value,
          required String label,
          required Color color}) =>
      Column(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
      ]);

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle),
              child: Icon(Icons.notifications_none_rounded,
                  size: 64, color: AppColors.primary.withOpacity(0.5)),
            ),
            const SizedBox(height: 24),
            const Text('All Clear!',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 12),
            const Text(
              'No new notifications.\nWe\'ll alert you when there are new applications or system updates.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: AppColors.textLight, height: 1.5),
            ),
          ],
        ),
      );
}

// ── Admin Tile ────────────────────────────────────────────────

class _AdminNotificationTile extends StatelessWidget {
  final AppNotification notification;
  final String timestamp;
  final Color color;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _AdminNotificationTile({
    required this.notification,
    required this.timestamp,
    required this.color,
    required this.icon,
    required this.onTap,
    this.actionLabel,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final hasActionButtons =
        (onApprove != null || onReject != null) && !notification.isRead;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: notification.isRead
                ? Colors.transparent
                : color.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: icon + text content
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(notification.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                color: notification.isRead
                                    ? AppColors.textMedium
                                    : AppColors.textDark,
                              )),
                        ),
                        if (!notification.isRead)
                          Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle)),
                      ]),
                      const SizedBox(height: 6),
                      Text(notification.message,
                          style: TextStyle(
                              fontSize: 13,
                              color: notification.isRead
                                  ? AppColors.textLight
                                  : AppColors.textMedium,
                              height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(children: [
                        Icon(Icons.access_time_rounded,
                            size: 12,
                            color: AppColors.textLight.withOpacity(0.6)),
                        const SizedBox(width: 4),
                        Text(timestamp,
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight.withOpacity(0.8))),
                        if (actionLabel != null) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(actionLabel!,
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: color)),
                          ),
                        ],
                        const Spacer(),
                        Text('Swipe to delete',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textLight.withOpacity(0.4))),
                      ]),
                    ],
                  ),
                ),
              ],
            ),

            // ── Action buttons: use GestureDetector+Container instead of
            // OutlinedButton/ElevatedButton. Material buttons enforce a minimum
            // tap-target size of 48×48 and set w=Infinity when the parent
            // passes unconstrained width (which Dismissible inside SliverList
            // does). Plain Containers never impose that constraint.
            if (hasActionButtons)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    if (onReject != null)
                      GestureDetector(
                        onTap: onReject,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFFFF3B30), width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Decline',
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFFF3B30),
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    if (onReject != null && onApprove != null)
                      const SizedBox(width: 8),
                    if (onApprove != null)
                      GestureDetector(
                        onTap: onApprove,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Approve',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
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
