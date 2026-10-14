import 'package:any_treemap/any_treemap.dart';
import 'package:flutter_test/flutter_test.dart';

TreemapNode<String> _tree({bool includeDeep = true}) => TreemapNode(
  key: 'root',
  label: 'Root',
  children: [
    TreemapNode(
      key: 'group',
      label: 'Group',
      children: [
        if (includeDeep)
          TreemapNode(
            key: 'deep',
            label: 'Deep',
            children: [TreemapNode(key: 'leaf', weight: 1)],
          )
        else
          TreemapNode(key: 'leaf', weight: 1),
      ],
    ),
  ],
);

TreemapNormalizedTree<String> _aggregateTree({
  String parent = 'p',
  String label = 'Parent',
  bool wrapped = false,
  bool split = false,
  bool includeFirst = true,
}) {
  final branch = TreemapNode<String>(
    key: parent,
    label: label,
    children: [
      if (includeFirst) TreemapNode(key: 'a', weight: 10, color: label),
      if (!split) TreemapNode(key: 'b', weight: 20),
    ],
  );
  return TreemapNormalizer.normalize(
    TreemapNode<String>(
      key: 'root',
      children: [
        if (wrapped)
          TreemapNode(key: 'wrapper', label: 'Wrapper', children: [branch])
        else
          branch,
        if (split)
          TreemapNode(
            key: 'q',
            children: [TreemapNode(key: 'b', weight: 20)],
          ),
      ],
    ),
  );
}

const _aggregateKey = TreemapKey<String>.aggregate(
  aggregateParent: TreemapKey.source('p'),
  aggregateSignature: 42,
);

void main() {
  test('navigation commands are typed and safe', () {
    final controller = TreemapController<String>()
      ..synchronize(TreemapNormalizer.normalize(_tree()));
    expect(controller.currentPath.map((entry) => entry.label), ['Root']);
    expect(
      controller.zoomTo('missing').status,
      TreemapCommandStatus.missingKey,
    );
    expect(
      controller.zoomTo('leaf').status,
      TreemapCommandStatus.leafCannotBeFocused,
    );
    expect(controller.zoomTo('deep').succeeded, isTrue);
    expect(controller.currentPath.map((entry) => entry.label), [
      'Root',
      'Group',
      'Deep',
    ]);
    expect(controller.canZoomOut, isTrue);
    expect(controller.zoomOut().succeeded, isTrue);
    expect(controller.focusKey, const TreemapKey.source('group'));
    expect(controller.reset().succeeded, isTrue);
    expect(controller.focusKey, const TreemapKey.source('root'));
  });

  test('removed focus falls back to nearest surviving ancestor', () {
    final controller = TreemapController<String>()
      ..synchronize(TreemapNormalizer.normalize(_tree()))
      ..zoomTo('deep');

    controller.synchronize(
      TreemapNormalizer.normalize(_tree(includeDeep: false)),
    );

    expect(controller.focusKey, const TreemapKey.source('group'));
    expect(controller.currentPath.map((entry) => entry.label), [
      'Root',
      'Group',
    ]);
  });

  test('a focused branch becoming a leaf falls back to a surviving branch', () {
    final controller = TreemapController<String>()
      ..synchronize(TreemapNormalizer.normalize(_tree()))
      ..zoomTo('deep');
    addTearDown(controller.dispose);
    controller.synchronize(
      TreemapNormalizer.normalize(
        TreemapNode<String>(
          key: 'root',
          children: [
            TreemapNode(
              key: 'group',
              children: [TreemapNode(key: 'deep', weight: 1)],
            ),
          ],
        ),
      ),
    );
    expect(controller.focusKey, const TreemapKey.source('group'));
  });

  test('single and multiple selection enforce ownership limits', () {
    final single = TreemapController<String>()
      ..synchronize(TreemapNormalizer.normalize(_tree()));
    single
      ..select('group')
      ..select('deep');
    expect(single.selectedKeys, {'deep'});
    single.select('deep', toggle: true);
    expect(single.selectedKeys, isEmpty);

    final multiple = TreemapController<String>(maximumSelections: null)
      ..synchronize(TreemapNormalizer.normalize(_tree()))
      ..select('group')
      ..select('deep');
    expect(multiple.selectedKeys, {'group', 'deep'});
  });

  test('aggregate navigation rejects missing or nonsibling source members', () {
    final controller = TreemapController<String>()
      ..synchronize(TreemapNormalizer.normalize(_tree()));
    addTearDown(controller.dispose);
    const key = TreemapKey<String>.aggregate(
      aggregateParent: TreemapKey.source('root'),
      aggregateSignature: 8,
    );
    expect(
      controller.revealAggregate(key, memberKeys: ['missing']).status,
      TreemapCommandStatus.missingKey,
    );
    expect(
      controller.revealAggregate(key, memberKeys: ['root']).status,
      TreemapCommandStatus.missingKey,
    );
    expect(
      controller.revealAggregate(key, memberKeys: ['group', 'leaf']).status,
      TreemapCommandStatus.missingKey,
    );
    expect(controller.focusKey, const TreemapKey.source('root'));
  });

  test('aggregate reveal maintains typed membership and path', () {
    final controller = TreemapController<String>()
      ..synchronize(TreemapNormalizer.normalize(_tree()));
    const key = TreemapKey<String>.aggregate(
      aggregateParent: TreemapKey.source('root'),
      aggregateSignature: 7,
    );
    final result = controller.revealAggregate(key, memberKeys: ['leaf']);

    expect(result.succeeded, isTrue);
    expect(controller.focusKey, key);
    expect(controller.layoutFocus!.aggregateMembers.single.key, 'leaf');
  });
  test(
    'aggregate paths follow source ancestry and refresh labels, depths and members',
    () {
      final controller = TreemapController<String>()
        ..synchronize(_aggregateTree());
      addTearDown(controller.dispose);
      // Reveal a nested aggregate directly from the root focus.
      controller.revealAggregate(_aggregateKey, memberKeys: ['a', 'b']);
      expect(controller.currentPath.map((entry) => entry.key), [
        const TreemapKey.source('root'),
        const TreemapKey.source('p'),
        _aggregateKey,
      ]);
      final oldPath = controller.currentPath;
      final next = _aggregateTree(label: 'Renamed', wrapped: true);
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.synchronize(next, notify: false);
      expect(notifications, 0);
      expect(controller.focusKey, _aggregateKey);
      expect(controller.currentPath.map((entry) => entry.label), [
        null,
        'Wrapper',
        'Renamed',
        null,
      ]);
      expect(controller.currentPath.map((entry) => entry.depth), [0, 1, 2, 3]);
      expect(controller.layoutFocus!.path, controller.currentPath);
      expect(
        controller.layoutFocus!.aggregateMembers.first,
        same(next.nodes['a']),
      );
      expect(oldPath[1].label, 'Parent');
      expect(controller.zoomOut().succeeded, isTrue);
      expect(controller.focusKey, const TreemapKey.source('p'));
      expect(controller.zoomOut().succeeded, isTrue);
      expect(controller.focusKey, const TreemapKey.source('wrapper'));
    },
  );

  test(
    'aggregate reparenting invalidates its old identity and keeps navigation usable',
    () {
      final controller = TreemapController<String>()
        ..synchronize(_aggregateTree());
      addTearDown(controller.dispose);
      controller.revealAggregate(_aggregateKey, memberKeys: ['a', 'b']);
      controller.synchronize(_aggregateTree(parent: 'q'));
      expect(controller.focusKey, const TreemapKey.source('root'));
      expect(controller.currentPath, hasLength(1));
      expect(controller.zoomOut().status, TreemapCommandStatus.noAncestor);
      expect(controller.zoomTo('q').succeeded, isTrue);
      expect(controller.zoomOut().succeeded, isTrue);
    },
  );

  test(
    'aggregate members split across parents fall back to a surviving ancestor',
    () {
      final controller = TreemapController<String>()
        ..synchronize(_aggregateTree());
      addTearDown(controller.dispose);
      controller.revealAggregate(_aggregateKey, memberKeys: ['a', 'b']);
      controller.synchronize(_aggregateTree(split: true));
      expect(controller.focusKey, const TreemapKey.source('p'));
      expect(controller.zoomOut().succeeded, isTrue);
    },
  );

  test('aggregate retains surviving siblings when a member disappears', () {
    final controller = TreemapController<String>()
      ..synchronize(_aggregateTree());
    addTearDown(controller.dispose);
    controller.revealAggregate(_aggregateKey, memberKeys: ['a', 'b']);
    final next = _aggregateTree(includeFirst: false, label: 'Updated');
    controller.synchronize(next);
    expect(controller.focusKey, _aggregateKey);
    expect(controller.layoutFocus!.aggregateMembers, [next.nodes['b']]);
    expect(controller.currentPath[1].label, 'Updated');
    expect(controller.zoomOut().succeeded, isTrue);
  });
}
