import 'package:share_plus/share_plus.dart';
import '../../domain/entities/track.dart';

class ShareHelper {
  static void shareTrack(Track track, String shareText) {
    final url =
        'https://music.youtube.com/search?q=${Uri.encodeComponent('${track.title} ${track.artist}')}';
    Share.share('$shareText\n$url');
  }
}
