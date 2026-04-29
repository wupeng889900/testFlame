import 'dart:io';

import 'package:flutter/foundation.dart';

Future<String?> tryLoadProjectAsset(String assetPath) async {
  if (kReleaseMode) {
    return null;
  }
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return null;
  }

  final root = _findProjectRoot();
  if (root == null) {
    return null;
  }

  final file = File('${root.path}${Platform.pathSeparator}$assetPath');
  if (!await file.exists()) {
    return null;
  }

  return file.readAsString();
}

Future<bool> trySaveProjectAsset(String assetPath, String content) async {
  if (kReleaseMode) {
    return false;
  }
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return false;
  }

  final root = _findProjectRoot();
  if (root == null) {
    return false;
  }

  final file = File('${root.path}${Platform.pathSeparator}$assetPath');
  await file.writeAsString(content);
  return true;
}

Directory? _findProjectRoot() {
  var current = Directory.current.absolute;
  while (true) {
    final pubspec = File(
      '${current.path}${Platform.pathSeparator}pubspec.yaml',
    );
    if (pubspec.existsSync()) {
      return current;
    }

    final parent = current.parent;
    if (parent.path == current.path) {
      return null;
    }
    current = parent;
  }
}
