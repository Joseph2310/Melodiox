import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ScaleImageStorageService {
  static const folderName = 'scale_image';

  Future<String> importImage(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Selected image does not exist', sourcePath);
    }

    final appDirectory = await getApplicationDocumentsDirectory();
    final imageDirectory = Directory(
      path.join(appDirectory.path, 'melodiox_media', folderName),
    );
    await imageDirectory.create(recursive: true);

    final extension = path.extension(sourcePath);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final destination = File(
      path.join(imageDirectory.path, '$timestamp$extension'),
    );
    await source.copy(destination.path);
    return destination.path;
  }
}
