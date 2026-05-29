import 'package:flutter_test/flutter_test.dart';
import 'package:threaditate/features/projects/data/project_repository.dart';

void main() {
  group('GuestProjectRepository', () {
    test('returns an empty list', () async {
      final repo = GuestProjectRepository();
      expect(await repo.listProjects(), isEmpty);
    });
  });
}
