import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../core/constants/media_types.dart';

class MediaStorageService {
  Future<String> importFile(String sourcePath, MediaType type) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Selected file does not exist', sourcePath);
    }

    final appDirectory = await getApplicationDocumentsDirectory();
    final mediaDirectory = Directory(
      path.join(appDirectory.path, 'melodiox_media', type.storageValue),
    );
    await mediaDirectory.create(recursive: true);

    final extension = path.extension(sourcePath);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final destination = File(
      path.join(mediaDirectory.path, '$timestamp$extension'),
    );
    await source.copy(destination.path);
    return destination.path;
  }
}
