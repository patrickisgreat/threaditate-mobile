/// Mirrors the `projects` Supabase row used by the web app. Field names use
/// snake_case to match the JSON the SDK returns; the constructor takes Dart
/// camelCase for ergonomic call sites.
///
/// Keep this in sync with the schema in the web repo's `supabase/migrations/`.
class Project {
  const Project({
    required this.id,
    required this.userId,
    required this.name,
    required this.pinCount,
    required this.maxLines,
    required this.minDistance,
    required this.lineWeight,
    required this.currentLine,
    required this.createdAt,
    required this.updatedAt,
    this.lineSequence,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      pinCount: (json['pin_count'] as num).toInt(),
      maxLines: (json['max_lines'] as num).toInt(),
      minDistance: (json['min_distance'] as num).toInt(),
      lineWeight: (json['line_weight'] as num).toInt(),
      currentLine: (json['current_line'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lineSequence: (json['line_sequence'] as List?)
          ?.map((e) => (e as num).toInt())
          .toList(growable: false),
    );
  }

  final String id;
  final String userId;
  final String name;
  final int pinCount;
  final int maxLines;
  final int minDistance;
  final int lineWeight;
  final int currentLine;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<int>? lineSequence;
}
