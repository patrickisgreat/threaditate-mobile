import 'package:flutter_test/flutter_test.dart';
import 'package:threaditate/features/projects/domain/project.dart';

void main() {
  group('Project.fromJson', () {
    test('parses a fully-populated row', () {
      final project = Project.fromJson({
        'id': 'p1',
        'user_id': 'u1',
        'name': 'My Design',
        'pin_count': 240,
        'max_lines': 4000,
        'min_distance': 40,
        'line_weight': 10,
        'current_line': 123,
        'created_at': '2026-05-01T12:00:00Z',
        'updated_at': '2026-05-13T09:30:00Z',
        'line_sequence': [0, 50, 50, 120],
      });

      expect(project.id, 'p1');
      expect(project.userId, 'u1');
      expect(project.pinCount, 240);
      expect(project.currentLine, 123);
      expect(project.lineSequence, [0, 50, 50, 120]);
    });

    test('defaults current_line to 0 when missing', () {
      final project = Project.fromJson({
        'id': 'p1',
        'user_id': 'u1',
        'name': 'My Design',
        'pin_count': 240,
        'max_lines': 4000,
        'min_distance': 40,
        'line_weight': 10,
        'created_at': '2026-05-01T12:00:00Z',
        'updated_at': '2026-05-13T09:30:00Z',
      });

      expect(project.currentLine, 0);
      expect(project.lineSequence, isNull);
    });
  });
}
