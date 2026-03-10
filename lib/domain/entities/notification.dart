class NotificationItem {
  final String id;
  final String user_id;
  final String type;
  final Map<String, dynamic> payload;
  final bool isRead;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.user_id,
    required this.type,
    required this.payload,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    return NotificationItem(
      id: map['id'],
      user_id: map['user_id']?.toString() ?? '',
      type: map['type'],
      payload: map['payload'] != null
          ? Map<String, dynamic>.from(map['payload'])
          : {},
      isRead: map['is_read'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
