class PhotoRecord {
  final int? id;
  final String title;
  final String? originalPath;
  final String editedPath;
  final String filterApplied;
  final String sharpenApplied;
  final String note;
  final int rating;
  final bool isFavorite;
  final DateTime createdAt;

  PhotoRecord({
    this.id,
    required this.title,
    this.originalPath,
    required this.editedPath,
    this.filterApplied = 'Gốc',
    this.sharpenApplied = 'Không',
    this.note = '',
    this.rating = 5,
    this.isFavorite = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'original_path': originalPath,
      'edited_path': editedPath,
      'filter_applied': filterApplied,
      'sharpen_applied': sharpenApplied,
      'note': note,
      'rating': rating,
      'is_favorite': isFavorite ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PhotoRecord.fromMap(Map<String, dynamic> map) {
    return PhotoRecord(
      id: map['id'] as int?,
      title: map['title'] as String? ?? 'Ảnh không tên',
      originalPath: map['original_path'] as String?,
      editedPath: map['edited_path'] as String? ?? '',
      filterApplied: map['filter_applied'] as String? ?? 'Gốc',
      sharpenApplied: map['sharpen_applied'] as String? ?? 'Không',
      note: map['note'] as String? ?? '',
      rating: (map['rating'] as int?) ?? 5,
      isFavorite: (map['is_favorite'] as int?) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  PhotoRecord copyWith({
    int? id,
    String? title,
    String? originalPath,
    String? editedPath,
    String? filterApplied,
    String? sharpenApplied,
    String? note,
    int? rating,
    bool? isFavorite,
    DateTime? createdAt,
  }) {
    return PhotoRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      originalPath: originalPath ?? this.originalPath,
      editedPath: editedPath ?? this.editedPath,
      filterApplied: filterApplied ?? this.filterApplied,
      sharpenApplied: sharpenApplied ?? this.sharpenApplied,
      note: note ?? this.note,
      rating: rating ?? this.rating,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
