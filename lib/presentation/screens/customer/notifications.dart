// lib/presentation/screens/customer/notifications.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';

enum NotificationType {
  booking,
  payment,
  promotion,
  system,
  reminder,
}

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  final bool isRead;
  final Map<String, dynamic>? data;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.data,
  });
}

class NotificationsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final Function(String notificationId)? onNotificationTap;
  final Function()? onMarkAllAsRead;

  const NotificationsScreen({
    super.key,
    this.onBack,
    this.onNotificationTap,
    this.onMarkAllAsRead,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Sample notifications data
  final List<NotificationModel> _notifications = [
    NotificationModel(
      id: '1',
      title: 'Booking Confirmed',
      message:
          'Your plumbing service booking has been confirmed. Professional will arrive at 2:00 PM.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      type: NotificationType.booking,
    ),
    NotificationModel(
      id: '2',
      title: 'Payment Successful',
      message:
          'Your payment of ₱1,500 for Drain Cleaning has been processed successfully.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      type: NotificationType.payment,
      isRead: true,
    ),
    NotificationModel(
      id: '3',
      title: 'Special Offer',
      message: 'Get 20% off on your next electrical repair service. Book now!',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      type: NotificationType.promotion,
    ),
    NotificationModel(
      id: '4',
      title: 'Service Reminder',
      message: 'Your appointment for Wall Painting is tomorrow at 10:00 AM.',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 12)),
      type: NotificationType.reminder,
      isRead: true,
    ),
    NotificationModel(
      id: '5',
      title: 'Professional En Route',
      message: 'Your handyman is on the way. ETA: 15 minutes.',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      type: NotificationType.booking,
    ),
    NotificationModel(
      id: '6',
      title: 'Rating Request',
      message: 'How was your service? Rate your recent booking experience.',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      type: NotificationType.system,
    ),
    NotificationModel(
      id: '7',
      title: 'Weekend Special',
      message: 'Book any service this weekend and get free inspection!',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      type: NotificationType.promotion,
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

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.booking:
        return const Color(0xFF007AFF); // Blue
      case NotificationType.payment:
        return const Color(0xFF34C759); // Green
      case NotificationType.promotion:
        return const Color(0xFFFF9500); // Orange
      case NotificationType.system:
        return const Color(0xFF5856D6); // Purple
      case NotificationType.reminder:
        return const Color(0xFFFF3B30); // Red
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.booking:
        return Icons.calendar_today_rounded;
      case NotificationType.payment:
        return Icons.payment_rounded;
      case NotificationType.promotion:
        return Icons.local_offer_rounded;
      case NotificationType.system:
        return Icons.info_rounded;
      case NotificationType.reminder:
        return Icons.alarm_rounded;
    }
  }

  void _markAsRead(String id) {
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index] = NotificationModel(
          id: _notifications[index].id,
          title: _notifications[index].title,
          message: _notifications[index].message,
          timestamp: _notifications[index].timestamp,
          type: _notifications[index].type,
          isRead: true,
          data: _notifications[index].data,
        );
      }
    });
    widget.onNotificationTap?.call(id);
  }

  void _markAllAsRead() {
    setState(() {
      for (int i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          _notifications[i] = NotificationModel(
            id: _notifications[i].id,
            title: _notifications[i].title,
            message: _notifications[i].message,
            timestamp: _notifications[i].timestamp,
            type: _notifications[i].type,
            isRead: true,
            data: _notifications[i].data,
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
                    'Recent Notifications',
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
                    return _NotificationTile(
                      notification: notification,
                      timestamp: _formatTimestamp(notification.timestamp),
                      color: _getNotificationColor(notification.type),
                      icon: _getNotificationIcon(notification.type),
                      onTap: () => _markAsRead(notification.id),
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
                              'Stay Updated',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your Activity Feed',
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
              icon: Icons.today_rounded,
              value: '$todayCount',
              label: 'Today',
              color: const Color(0xFF007AFF),
            ),
            Container(
              height: 30,
              width: 1,
              color: Colors.grey.shade200,
            ),
            _buildStatItem(
              icon: Icons.notifications_rounded,
              value: '${_notifications.length}',
              label: 'Total',
              color: const Color(0xFF34C759),
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
            'All Caught Up!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'You have no notifications at the moment.\nWe\'ll notify you when something arrives.',
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

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final String timestamp;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.timestamp,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
        child: Row(
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
                    ],
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
