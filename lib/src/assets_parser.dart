import 'dart:io';
import 'package:path/path.dart' as path;

class Asset {
  final String name;
  final String path;

  Asset({this.name, this.path});

  @override
  String toString() {
    return "Asset(name: $name, path: $path)";
  }
}

List<Asset> parseAssets(yaml) {
  final flutter = yaml["flutter"];
  if (flutter == null) {
    return [];
  }

  List assets = flutter["assets"];
  if (assets == null) {
    return [];
  }

  Set<String> assetFiles = Set();
  for (var asset in assets) {
    assetFiles.addAll(_findFiles(asset));
  }
  return _convertToAssets(assetFiles.toList());
}

List<String> _findFiles(String asset) {
  switch (FileSystemEntity.typeSync(asset)) {
    case FileSystemEntityType.file:
      return [asset];
    case FileSystemEntityType.directory:
      {
        final dir = Directory(asset);
        return dir
            .listSync()
            .map((entry) {
              final entryType = FileSystemEntity.typeSync(entry.path);
              if (entryType == FileSystemEntityType.file) {
                return entry.path;
              }
              return null;
            })
            .where((it) => it != null)
            .toList();
      }
    default:
      return [];
  }
}

List<Asset> _convertToAssets(List<String> assetPaths) {
  List<Asset> rawAssets = assetPaths
      .map((pathString) => Asset(
          name: path.basenameWithoutExtension(pathString), path: pathString))
      .toList();

  List<Asset> assets = [];
  for (var asset in rawAssets) {
    if (assets.any((item) => item.path == asset.path)) {
      // asset already added
      continue;
    }

    var duplicateNames =
        rawAssets.where((item) => item.name == asset.name).toList();
    if (duplicateNames.length == 1) {
      // no duplicates found
      assets.add(asset);
      continue;
    }

    assets.addAll(specifyAssetNames(duplicateNames));
  }

  return assets;
}

List<Asset> specifyAssetNames(List<Asset> assets) {
  bool containsDuplicates(List<_Pair<Asset, Directory>> list) {
    final first = list.first;
    for (var item in list) {
      if (list.any((item2) {
        if (item == item2) {
          return false;
        }
        return item.first.name == item2.first.name;
      })) {
        return true;
      }
    }
    return false;
  }

  var list = assets.map((item) => _Pair(item, File(item.path).parent)).toList();

  int iteration = 0;
  while (iteration < 5 && containsDuplicates(list)) {
    iteration++;
    list = list.map((item) {
      var newName = item.first.name;
      var newParentDir = item.second;
      if (item.second.path != ".") {
        newName = path.basenameWithoutExtension(item.second.path) +
            "_" +
            item.first.name;
        newParentDir = item.second.parent;
      }
      return _Pair(Asset(name: newName, path: item.first.path), newParentDir);
    }).toList();
  }
  return list.map((item) => item.first).toList();
}

class _Pair<T, S> {
  final T first;
  final S second;

  _Pair(this.first, this.second);
}
