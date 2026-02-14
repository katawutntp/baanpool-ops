/// PM Schedule model — maps to `pm_schedules` table in Supabase
class PmSchedule {
  final String id;
  final String propertyId;
  final String? assetId;
  final String title;
  final String? description;
  final PmFrequency frequency;
  final DateTime nextDueDate;
  final DateTime? lastCompletedDate;
  final bool isActive;
  final DateTime createdAt;

  const PmSchedule({
    required this.id,
    required this.propertyId,
    this.assetId,
    required this.title,
    this.description,
    required this.frequency,
    required this.nextDueDate,
    this.lastCompletedDate,
    this.isActive = true,
    required this.createdAt,
  });

  factory PmSchedule.fromJson(Map<String, dynamic> json) {
    return PmSchedule(
      id: json['id'] as String,
      propertyId: json['property_id'] as String,
      assetId: json['asset_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      frequency: PmFrequency.fromString(json['frequency'] as String),
      nextDueDate: DateTime.parse(json['next_due_date'] as String),
      lastCompletedDate: json['last_completed_date'] != null
          ? DateTime.parse(json['last_completed_date'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'property_id': propertyId,
    'asset_id': assetId,
    'title': title,
    'description': description,
    'frequency': frequency.name,
    'next_due_date': nextDueDate.toIso8601String(),
    'last_completed_date': lastCompletedDate?.toIso8601String(),
    'is_active': isActive,
  };

  bool get isDueSoon =>
      nextDueDate.difference(DateTime.now()).inDays <= 7 && isActive;
}

enum PmFrequency {
  weekly,
  biweekly,
  monthly,
  quarterly,
  semiannual,
  annual;

  static PmFrequency fromString(String value) {
    return PmFrequency.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PmFrequency.monthly,
    );
  }

  String get displayName {
    switch (this) {
      case PmFrequency.weekly:
        return 'รายสัปดาห์';
      case PmFrequency.biweekly:
        return 'ทุก 2 สัปดาห์';
      case PmFrequency.monthly:
        return 'รายเดือน';
      case PmFrequency.quarterly:
        return 'ราย 3 เดือน';
      case PmFrequency.semiannual:
        return 'ราย 6 เดือน';
      case PmFrequency.annual:
        return 'รายปี';
    }
  }
}
