import 'package:any_treemap/any_treemap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TreemapNormalizer', () {
    test('derives totals without mutating immutable input', () {
      final root = TreemapNode<String>(
        key: 'root',
        weight: 999,
        children: [
          TreemapNode(key: 'a', weight: 1),
          TreemapNode(key: 'b', weight: 2),
        ],
      );

      final normalized = TreemapNormalizer.normalize(root);

      expect(normalized.totals['root'], 3);
      expect(root.weight, 999);
      expect(normalized.pathTo('b').map((node) => node.key), ['root', 'b']);
      expect(() => normalized.nodes['x'] = root, throwsUnsupportedError);
      expect(() => root.children.add(root), throwsUnsupportedError);
    });

    test('reports duplicate, empty, negative and non-finite input', () {
      final root = TreemapNode<String>(
        key: 'root',
        children: [
          TreemapNode(key: '', weight: -1),
          TreemapNode(key: 'same', weight: double.nan),
          TreemapNode(key: 'same', weight: double.infinity),
        ],
      );

      expect(
        () => TreemapNormalizer.normalize(root),
        throwsA(
          isA<TreemapValidationException<String>>().having(
            (error) => error.issues.map((issue) => issue.code).toSet(),
            'codes',
            containsAll({
              TreemapValidationCode.emptyKey,
              TreemapValidationCode.duplicateKey,
              TreemapValidationCode.invalidWeight,
            }),
          ),
        ),
      );
    });

    test('keys containing s remain opaque source keys', () {
      final normalized = TreemapNormalizer.normalize(
        TreemapNode<String>(
          key: 'root',
          children: [TreemapNode(key: 'sales', weight: 1)],
        ),
      );
      expect(normalized.nodes['sales']?.key, 'sales');
      expect(const TreemapKey<String>.source('sales').isAggregate, isFalse);
    });
  });

  test(
    'flat records and an equivalent explicit tree normalize identically',
    () {
      final records = [
        (id: 'a', group: 'g1', weight: 2.0),
        (id: 'b', group: 'g1', weight: 3.0),
        (id: 'c', group: 'g2', weight: 5.0),
      ];
      final fromRecords =
          TreemapNode.fromRecords<
            ({String id, String group, double weight}),
            String
          >(
            rootKey: 'root',
            records: records,
            leafKey: (record) => record.id,
            weight: (record) => record.weight,
            levels: [TreemapRecordLevel(key: (record) => record.group)],
          );
      final explicit = TreemapNode<String>(
        key: 'root',
        children: [
          TreemapNode(
            key: 'g1',
            children: [
              TreemapNode(key: 'a', weight: 2),
              TreemapNode(key: 'b', weight: 3),
            ],
          ),
          TreemapNode(
            key: 'g2',
            children: [TreemapNode(key: 'c', weight: 5)],
          ),
        ],
      );

      final a = TreemapNormalizer.normalize(fromRecords);
      final b = TreemapNormalizer.normalize(explicit);
      expect(a.totals, b.totals);
      expect(a.parents, b.parents);
    },
  );
}
