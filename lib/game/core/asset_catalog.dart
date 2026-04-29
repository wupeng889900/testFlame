import 'dart:convert';

import 'package:flutter/services.dart';

class GameAssetCatalog {
  GameAssetCatalog._();

  static final GameAssetCatalog instance = GameAssetCatalog._();

  bool _loaded = false;
  final Map<String, String> _characterCurrentPaths = {};
  final Map<String, String> _propCurrentPaths = {};
  final Set<String> _availableAssets = {};

  Future<void> load() async {
    if (_loaded) {
      return;
    }

    try {
      final manifestRaw = await rootBundle.loadString('AssetManifest.json');
      final manifest = jsonDecode(manifestRaw);
      if (manifest is Map<String, dynamic>) {
        _availableAssets.addAll(manifest.keys.whereType<String>());
      }
    } catch (_) {
      // Fall back to optimistic loading when the manifest is unavailable.
    }

    try {
      final raw = await rootBundle.loadString('assets/AssetCatalog.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _fillMap(source: json['characters'], target: _characterCurrentPaths);
      _fillMap(source: json['props'], target: _propCurrentPaths);
    } catch (_) {
      // Keep legacy paths when the catalog is absent or malformed.
    } finally {
      _loaded = true;
    }
  }

  List<String> characterCandidates(String legacyPath) {
    return _buildCandidates(_characterCurrentPaths[legacyPath], legacyPath);
  }

  List<String> propCandidates(String legacyPath) {
    return _buildCandidates(_propCurrentPaths[legacyPath], legacyPath);
  }

  List<String> floorCandidates() {
    return _filterAvailableAssets(const [
      'assets/environment/office_background_cutout.png',
      'assets/environment/floor_opt.png',
      'assets/environment/floor.png',
    ]);
  }

  List<String> hudCandidates() {
    return const [];
  }

  bool hasAsset(String path) {
    return _availableAssets.isEmpty || _availableAssets.contains(path);
  }

  void _fillMap({
    required Object? source,
    required Map<String, String> target,
  }) {
    if (source is! List) {
      return;
    }

    for (final item in source) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final legacyPath = item['legacyPath'];
      final currentPath = item['currentPath'];
      if (legacyPath is String &&
          legacyPath.isNotEmpty &&
          currentPath is String &&
          currentPath.isNotEmpty) {
        target[legacyPath] = currentPath;
      }
    }
  }

  List<String> _buildCandidates(String? preferredPath, String fallbackPath) {
    final candidates = <String>[];
    if (preferredPath != null && preferredPath.isNotEmpty) {
      candidates.add(preferredPath);
    }
    if (!candidates.contains(fallbackPath)) {
      candidates.add(fallbackPath);
    }

    if (_availableAssets.isEmpty) {
      return candidates;
    }
    return candidates.where(_availableAssets.contains).toList();
  }

  List<String> _filterAvailableAssets(List<String> candidates) {
    if (_availableAssets.isEmpty) {
      return candidates;
    }
    return candidates.where(_availableAssets.contains).toList();
  }
}
