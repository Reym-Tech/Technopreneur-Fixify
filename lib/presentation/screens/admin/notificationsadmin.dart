// lib/presentation/screens/admin/notifications_admin.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';

enum AdminNotificationType {
  application,
  verification,
  payment,
  report,
  system,
  reminder,
}

class AdminNotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final AdminNotificationType type;
  final bool isRead;
  final Map<String, dynamic>? data;
  final String? actionRequired; // e.g., "Review", "Approve", "View"

  const AdminNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.data,
    this.actionRequired,
  });
}

class AdminNotificationsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final Function(String notificationId)? onNotificationTap;
  final Function()? onMarkAllAsRead;
  final Function(String notificationId)? onApprove;
  final Function(String notificationId)? onReject;

  const AdminNotificationsScreen({
    super.key,
    this.onBack,
    this.onNotificationTap,
    this.onMarkAllAsRead,
    this.onApprove,
    this.onReject,
  });

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  // Sample notifications data for admin
  final List<AdminNotificationModel> _notifications = [
    AdminNotificationModel(
      id: '1',
      title: 'New Professional Application',
      message:
          'Juan Dela Cruz applied for Plumbing services. Review credentials and verify.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      type: AdminNotificationType.application,
      actionRequired: 'Review',
      data: {'applicantId': 'PRO-001', 'serviceType': 'Plumbing'},
    ),
    AdminNotificationModel(
      id: '2',
      title: 'Verification Request',
      message:
          'Maria Santos submitted valid ID and certification for Electrical services.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
      type: AdminNotificationType.verification,
      actionRequired: 'Verify',
      data: {'applicantId': 'PRO-002', 'serviceType': 'Electrical'},
    ),
    AdminNotificationModel(
      id: '3',
      title: 'Payment Dispute',
      message:
          'Customer reported an issue with payment for booking #BK-1234. Please review.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      type: AdminNotificationType.payment,
      actionRequired: 'Review',
      isRead: true,
    ),
    AdminNotificationModel(
      id: '4',
      title: 'Application Approved',
      message:
          'You approved Pedro Reyes\'s Carpentry application. They can now receive bookings.',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      type: AdminNotificationType.system,
      isRead: true,
    ),
    AdminNotificationModel(
      id: '5',
      title: 'User Report',
      message:
          'Multiple reports received about professional "Mike Tan". Please investigate.',
      timestamp: DateTime.now().subtract(const Duration(hours: 8)),
      type: AdminNotificationType.report,
      actionRequired: 'Investigate',
      data: {'professionalId': 'PRO-005', 'reportCount': 3},
    ),
    AdminNotificationModel(
      id: '6',
      title: 'System Update',
      message: 'New version of Fixify is available. Review release notes.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      type: AdminNotificationType.system,
      isRead: true,
    ),
    AdminNotificationModel(
      id: '7',
      title: 'Pending Applications',
      message:
          '5 professional applications waiting for review. Please check the approvals section.',
      timestamp: DateTime.now().subtract(const Duration(hours: 12)),
      type: AdminNotificationType.reminder,
      actionRequired: 'View',
    ),
    AdminNotificationModel(
      id: '8',
      title: 'Verification Expiring',
      message:
          '3 professionals have documents expiring in 7 days. Remind them to update.',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      type: AdminNotificationType.reminder,
      actionRequired: 'Review',
    ),
    AdminNotificationModel(
      id: '9',
      title: 'Payout Processed',
      message: 'Weekly payouts for 12 professionals have been processed.',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      type: AdminNotificationType.payment,
      isRead: true,
    ),
  ];

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  Color _getNotificationColor(AdminNotificationType type) {
    switch (type) {
      case AdminNotificationType.application:
        return const Color(0xFFFF9500); // Orange for new applications
      case AdminNotificationType.verification:
        return const Color(0xFF5856D6); // Purple for verification
      case AdminNotificationType.payment:
        return const Color(0xFF34C759); // Green for payments
      case AdminNotificationType.report:
        return const Color(0xFFFF3B30); // Red for reports
      case AdminNotificationType.system:
        return const Color(0xFF007AFF); // Blue for system
      case AdminNotificationType.reminder:
        return const Color(0xFFFF9F0A); // Gold for reminders
    }
  }

  IconData _getNotificationIcon(AdminNotificationType type) {
    switch (type) {
      case AdminNotificationType.application:
        return Icons.assignment_rounded;
      case AdminNotificationType.verification:
        return Icons.verified_rounded;
      case AdminNotificationType.payment:
        return Icons.payments_rounded;
      case AdminNotificationType.report:
        return Icons.flag_rounded;
      case AdminNotificationType.system:
        return Icons.settings_rounded;
      case AdminNotificationType.reminder:
        return Icons.notifications_active_rounded;
    }
  }

  void _markAsRead(String id) {
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index] = AdminNotificationModel(
          id: _notifications[index].id,
          title: _notifications[index].title,
          message: _notifications[index].message,
          timestamp: _notifications[index].timestamp,
          type: _notifications[index].type,
          isRead: true,
          data: _notifications[index].data,
          actionRequired: _notifications[index].actionRequired,
        );
      }
    });
    widget.onNotificationTap?.call(id);
  }

  void _markAllAsRead() {
    setState(() {
      for (int i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          _notifications[i] = AdminNotificationModel(
            id: _notifications[i].id,
            title: _notifications[i].title,
            message: _notifications[i].message,
            timestamp: _notifications[i].timestamp,
            type: _notifications[i].type,
            isRead: true,
            data: _notifications[i].data,
            actionRequired: _notifications[i].actionRequired,
          );
        }
      }
    });
    widget.onMarkAllAsRead?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          // Header Sliver
          SliverToBoxAdapter(
            child: _buildHeader(),
          ),

          // Stats Section
          if (_unreadCount > 0)
            SliverToBoxAdapter(
              child: _buildStatsCard()
                  .animate()
                  .fadeIn(delay: 100.ms)
                  .slideY(begin: 0.1, end: 0),
            ),

          // Notifications List Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Admin Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (_unreadCount > 0)
                    TextButton(
                      onPressed: _markAllAsRead,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      child: Text(
                        'Mark all as read',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ).animate().fadeIn(delay: 150.ms),
          ),

          // Notifications List
          if (_notifications.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final notification = _notifications[index];
                    return _AdminNotificationTile(
                      notification: notification,
                      timestamp: _formatTimestamp(notification.timestamp),
                      color: _getNotificationColor(notification.type),
                      icon: _getNotificationIcon(notification.type),
                      onTap: () => _markAsRead(notification.id),
                      onApprove: widget.onApprove,
                      onReject: widget.onReject,
                    )
                        .animate()
                        .fadeIn(delay: (200 + index * 50).ms)
                        .slideX(begin: 0.05, end: 0);
                  },
                  childCount: _notifications.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final pendingCount = _notifications
        .where((n) => n.type == AdminNotificationType.application && !n.isRead)
        .length;

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
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (widget.onBack != null) {
                            widget.onBack!();
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin Center',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'System Updates & Alerts',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '$_unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'unread',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (pendingCount > 0)
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
                              '$pendingCount pending ${pendingCount == 1 ? 'application' : 'applications'}',
                              style: const TextStyle(
                                color: Color(0xFFFF9500),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
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

  Widget _circle(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity),
        ),
      );

  Widget _buildStatsCard() {
    final now = DateTime.now();
    final todayCount = _notifications
        .where((n) =>
            n.timestamp.year == now.year &&
            n.timestamp.month == now.month &&
            n.timestamp.day == now.day)
        .length;

    final applicationCount = _notifications
        .where((n) => n.type == AdminNotificationType.application)
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
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.notifications_active_rounded,
              value: '$_unreadCount',
              label: 'Unread',
              color: AppColors.primary,
            ),
            Container(
              height: 30,
              width: 1,
              color: Colors.grey.shade200,
            ),
            _buildStatItem(
              icon: Icons.pending_actions_rounded,
              value: '$applicationCount',
              label: 'Applications',
              color: const Color(0xFFFF9500),
            ),
            Container(
              height: 30,
              width: 1,
              color: Colors.grey.shade200,
            ),
            _buildStatItem(
              icon: Icons.today_rounded,
              value: '$todayCount',
              label: 'Today',
              color: const Color(0xFF007AFF),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textLight,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: AppColors.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'All Clear!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No new notifications.\nWe\'ll alert you when there are new applications or system updates.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminNotificationTile extends StatelessWidget {
  final AdminNotificationModel notification;
  final String timestamp;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final Function(String)? onApprove;
  final Function(String)? onReject;

  const _AdminNotificationTile({
    required this.notification,
    required this.timestamp,
    required this.color,
    required this.icon,
    required this.onTap,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final hasAction = notification.actionRequired != null &&
        (notification.type == AdminNotificationType.application ||
            notification.type == AdminNotificationType.verification);

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
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Container
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                color: notification.isRead
                                    ? AppColors.textMedium
                                    : AppColors.textDark,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: 13,
                          color: notification.isRead
                              ? AppColors.textLight
                              : AppColors.textMedium,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: AppColors.textLight.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timestamp,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight.withOpacity(0.8),
                            ),
                          ),
                          if (notification.actionRequired != null) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                notification.actionRequired!,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Action buttons for application/verification
            if (hasAction && !notification.isRead)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onReject != null)
                      OutlinedButton(
                        onPressed: () => onReject?.call(notification.id),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFF3B30)),
                          foregroundColor: const Color(0xFFFF3B30),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                        child: const Text('Decline',
                            style: TextStyle(fontSize: 12)),
                      ),
                    const SizedBox(width: 8),
                    if (onApprove != null)
                      ElevatedButton(
                        onPressed: () => onApprove?.call(notification.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                        child: const Text('Approve',
                            style: TextStyle(fontSize: 12)),
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
