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

void main() {
  test('navigation commands are typed and safe', () {
    final controller = TreemapController<String>()..synchronize(_tree());
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
      ..synchronize(_tree())
      ..zoomTo('deep');

    controller.synchronize(_tree(includeDeep: false));

    expect(controller.focusKey, const TreemapKey.source('group'));
    expect(controller.currentPath.map((entry) => entry.label), [
      'Root',
      'Group',
    ]);
  });

  test('single and multiple selection enforce ownership limits', () {
    final single = TreemapController<String>()..synchronize(_tree());
    single
      ..select('group')
      ..select('deep');
    expect(single.selectedKeys, {'deep'});
    single.select('deep', toggle: true);
    expect(single.selectedKeys, isEmpty);

    final multiple = TreemapController<String>(maximumSelections: null)
      ..synchronize(_tree())
      ..select('group')
      ..select('deep');
    expect(multiple.selectedKeys, {'group', 'deep'});
  });

  test('aggregate reveal maintains typed membership and path', () {
    final controller = TreemapController<String>()..synchronize(_tree());
    const key = TreemapKey<String>.aggregate(
      aggregateParent: TreemapKey.source('root'),
      aggregateSignature: 7,
    );
    final geometry = TreemapGeometryNode<String>(
      key: key,
      bounds: const TreemapBounds.fromLTWH(0, 0, 10, 10),
      weight: 1,
      depth: 1,
      kind: TreemapGeometryKind.aggregate,
      label: 'Other',
      parentKey: null,
      opacity: 1,
      aggregateMembers: [TreemapNode(key: 'member', weight: 1)],
    );

    final result = controller.revealAggregate(
      TreemapNodeDetails(geometry: geometry, path: controller.currentPath),
    );

    expect(result.succeeded, isTrue);
    expect(controller.focusKey, key);
    expect(controller.layoutFocus!.aggregateMembers.single.key, 'member');
  });
}
