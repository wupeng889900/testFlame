import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:office_sim/game/core/office_asset_policy.dart';
import 'package:office_sim/game/world/scene_config.dart';

void main() {
  test('office scene uses the documented physical scale', () {
    expect(OfficeAssetPolicy.sceneDpToMillimeters, 8.0);
    expect(
      OfficeAssetPolicy.sceneDpToPhysicalMillimeters(
        OfficeSceneConfig.sceneSize.x,
      ),
      12800,
    );
    expect(
      OfficeAssetPolicy.sceneDpToPhysicalMillimeters(
        OfficeSceneConfig.sceneSize.y,
      ),
      8000,
    );
  });

  test('key furniture is calibrated within 2 percent of target dimensions', () {
    final desk = OfficeSceneConfig.desks.first;
    expect(
      OfficeAssetPolicy.withinPhysicalTolerance(
        actualSceneDp: desk.size.x,
        expectedMillimeters: 1200,
      ),
      isTrue,
    );
    expect(
      OfficeAssetPolicy.withinPhysicalTolerance(
        actualSceneDp: desk.size.y,
        expectedMillimeters: 904,
      ),
      isTrue,
    );

    final coffeeTable = OfficeSceneConfig.sofas.first;
    expect(
      OfficeAssetPolicy.withinPhysicalTolerance(
        actualSceneDp: coffeeTable.size.x,
        expectedMillimeters: 1200,
      ),
      isTrue,
    );
    expect(
      OfficeAssetPolicy.withinPhysicalTolerance(
        actualSceneDp: coffeeTable.size.y,
        expectedMillimeters: 704,
      ),
      isTrue,
    );
  });

  test('all atlas assets have explicit loading classifications', () {
    expect(
      OfficeAssetPolicy.firstScreenAssets,
      contains('assets/atlas/场景布局左边+资源目录规划.png'),
    );
    expect(
      OfficeAssetPolicy.firstScreenAssets,
      contains('assets/office_game/manifest.json'),
    );
    expect(OfficeAssetPolicy.delayedAssets, contains('assets/atlas/家具切图.png'));
    expect(OfficeAssetPolicy.delayedAssets, contains('assets/atlas/人物切图.png'));
  });

  test('image layout rules preserve asset aspect ratio', () {
    for (final rule in OfficeAssetPolicy.layoutRules.values) {
      expect(rule.fit, BoxFit.contain);
    }
  });
}
