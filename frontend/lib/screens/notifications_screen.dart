import 'package:flutter/material.dart';
import '../config/api.dart';
import '../models/dashboard.dart';
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationItem> _notifications = [];
  bool _loading = true;
  final _api = ApiService(apiClient);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final notifs = await _api.getNotifications();
      setState(() { _notifications = notifs; _loading = false; });
    } catch (_) {
      setState(() { _loading = false; });
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'MATCH_VERIFIED': return Icons.check_circle;
      case 'MATCH_REJECTED': return Icons.cancel;
      case 'ADMIN_REVIEW_REQUIRED': return Icons.rate_review;
      case 'DISPUTE_UPDATE': return Icons.gavel;
      case 'TOURNAMENT_INVITATION': return Icons.emoji_events;
      case 'TOURNAMENT_REGISTRATION': return Icons.how_to_reg;
      case 'AWARD_RECEIVED': return Icons.military_tech;
      default: return Icons.notifications;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'MATCH_VERIFIED': return Colors.green;
      case 'MATCH_REJECTED': return Colors.red;
      case 'ADMIN_REVIEW_REQUIRED': return Colors.orange;
      case 'DISPUTE_UPDATE': return Colors.amber;
      case 'AWARD_RECEIVED': return Colors.amber;
      case 'TOURNAMENT_INVITATION': return Colors.blue;
      default: return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('Notifications', style: TextStyle(color: Colors.white)),
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all, color: Colors.amber, size: 18),
              label: const Text('Mark all read', style: TextStyle(color: Colors.amber)),
            ),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFe94560)))
          : _notifications.isEmpty
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none, size: 64, color: Colors.white.withValues(alpha: 0.2)),
                    const SizedBox(height: 16),
                    Text('No notifications yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _notifications.length,
                    itemBuilder: (_, i) => _notifCard(_notifications[i]),
                  ),
                ),
    );
  }

  Future<void> _markRead(int id) async {
    setState(() {
      _notifications = _notifications
          .map((n) => n.id == id && !n.isRead ? n.copyWith(isRead: true) : n)
          .toList();
    });
    try {
      await _api.markNotificationRead(id);
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    setState(() {
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    });
    try {
      await _api.markAllNotificationsRead();
    } catch (_) {}
  }

  Future<void> _delete(int id) async {
    setState(() => _notifications.removeWhere((n) => n.id == id));
    try {
      await _api.deleteNotification(id);
    } catch (_) {}
  }

  Widget _notifCard(NotificationItem n) {
    final c = _color(n.type);
    return Dismissible(
      key: ValueKey('notif-${n.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _delete(n.id),
      child: InkWell(
        onTap: n.isRead ? null : () => _markRead(n.id),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: n.isRead ? const Color(0xFF1a1a2e) : c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: n.isRead ? Colors.transparent : c.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(_icon(n.type), color: c, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.title, style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: n.isRead ? Colors.white.withValues(alpha: 0.7) : Colors.white,
                    )),
                    const SizedBox(height: 4),
                    Text(n.message, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(n.createdAt, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3))),
                  ],
                ),
              ),
              if (!n.isRead)
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}