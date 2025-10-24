import 'dart:convert';

/// نموذج بيانات الزيارة المؤقتة للحفظ المحلي
class DraftVisit {
  final int visitId;
  final int projectId;
  final String description;
  final String notes;
  final List<String> images;
  final List<String> videos;
  final bool contactCustomer;
  final bool contactContractor;
  final DateTime lastModified;
  final String status; // 'draft', 'in_progress', 'completed'

  DraftVisit({
    required this.visitId,
    required this.projectId,
    this.description = '',
    this.notes = '',
    this.images = const [],
    this.videos = const [],
    this.contactCustomer = false,
    this.contactContractor = false,
    DateTime? lastModified,
    this.status = 'draft',
  }) : lastModified = lastModified ?? DateTime.now();

  /// تحويل إلى JSON للحفظ
  Map<String, dynamic> toJson() {
    return {
      'visitId': visitId,
      'projectId': projectId,
      'description': description,
      'notes': notes,
      'images': images,
      'videos': videos,
      'contactCustomer': contactCustomer,
      'contactContractor': contactContractor,
      'lastModified': lastModified.toIso8601String(),
      'status': status,
    };
  }

  /// إنشاء من JSON
  factory DraftVisit.fromJson(Map<String, dynamic> json) {
    return DraftVisit(
      visitId: json['visitId'] ?? 0,
      projectId: json['projectId'] ?? 0,
      description: json['description'] ?? '',
      notes: json['notes'] ?? '',
      images: List<String>.from(json['images'] ?? []),
      videos: List<String>.from(json['videos'] ?? []),
      contactCustomer: json['contactCustomer'] ?? false,
      contactContractor: json['contactContractor'] ?? false,
      lastModified: DateTime.parse(json['lastModified'] ?? DateTime.now().toIso8601String()),
      status: json['status'] ?? 'draft',
    );
  }

  /// تحويل إلى String للحفظ في SharedPreferences
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// إنشاء من String
  factory DraftVisit.fromJsonString(String jsonString) {
    return DraftVisit.fromJson(jsonDecode(jsonString));
  }

  /// إنشاء نسخة محدثة
  DraftVisit copyWith({
    int? visitId,
    int? projectId,
    String? description,
    String? notes,
    List<String>? images,
    List<String>? videos,
    bool? contactCustomer,
    bool? contactContractor,
    DateTime? lastModified,
    String? status,
  }) {
    return DraftVisit(
      visitId: visitId ?? this.visitId,
      projectId: projectId ?? this.projectId,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      images: images ?? this.images,
      videos: videos ?? this.videos,
      contactCustomer: contactCustomer ?? this.contactCustomer,
      contactContractor: contactContractor ?? this.contactContractor,
      lastModified: lastModified ?? DateTime.now(),
      status: status ?? this.status,
    );
  }

  /// التحقق من وجود بيانات
  bool get hasData {
    return description.isNotEmpty || 
           notes.isNotEmpty || 
           images.isNotEmpty || 
           videos.isNotEmpty ||
           contactCustomer ||
           contactContractor;
  }

  /// الحصول على حجم البيانات (تقريبي)
  int get dataSize {
    int size = 0;
    size += description.length * 2; // UTF-16 encoding
    size += notes.length * 2;
    size += images.length * 100; // تقدير متوسط لطول مسار الملف
    size += videos.length * 100;
    return size;
  }

  @override
  String toString() {
    return 'DraftVisit(visitId: $visitId, projectId: $projectId, status: $status, hasData: $hasData, lastModified: $lastModified)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DraftVisit &&
        other.visitId == visitId &&
        other.projectId == projectId &&
        other.description == description &&
        other.notes == notes &&
        other.images.toString() == images.toString() &&
        other.videos.toString() == videos.toString() &&
        other.contactCustomer == contactCustomer &&
        other.contactContractor == contactContractor &&
        other.status == status;
  }

  @override
  int get hashCode {
    return Object.hash(
      visitId,
      projectId,
      description,
      notes,
      images,
      videos,
      contactCustomer,
      contactContractor,
      status,
    );
  }
}
