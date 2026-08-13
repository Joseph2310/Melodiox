import '../constants/music_keys.dart';

int compareMusicKeys(String left, String right) {
  final leftOrder = musicKeyOrder(left);
  final rightOrder = musicKeyOrder(right);
  if (leftOrder != rightOrder) {
    return leftOrder.compareTo(rightOrder);
  }
  return left.toLowerCase().compareTo(right.toLowerCase());
}

int musicKeyOrder(String value) {
  final normalized = value.trim().toLowerCase();
  for (var index = 0; index < MusicKeys.values.length; index++) {
    if (MusicKeys.values[index].toLowerCase() == normalized) {
      return index;
    }
  }
  return MusicKeys.values.length;
}
