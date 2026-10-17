/* THE PHOTOS OF A SAVED DIESEL ISSUE (3.14.0) – the web's phView (update-85): the 4 photos of a fill, large, each with what it is,
 * when it was taken and where (the map); a picture opens full size when it is pressed. The server gives links that work for
 * 15 minutes (getDieselPhotos). */
import 'package:flutter/material.dart' hide Text;
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../core/rdoc.dart' show fmt;
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// The web's phStamp: dd-mm-yyyy hh:mm:ss on the phone's clock ('' = no time).
String photoStamp(String at) {
  final t = DateTime.tryParse(at)?.toLocal();
  if (t == null) return '';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.day)}-${two(t.month)}-${t.year} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

bool _has(Object? v) => v != null && v != '';

/// Opens the photos of the diesel issue [id] (a message when it has none).
Future<void> openDieselPhotos(BuildContext context, String id) async {
  final s = SessionScope.read(context);
  Map d;
  try {
    d = (await s.api.call('getDieselPhotos', [id])) as Map;
  } catch (e) {
    if (context.mounted) toast(context, errText(e), bad: true);
    return;
  }
  final photos = [for (final p in (d['photos'] as List? ?? const [])) if (p is Map) p];
  if (!context.mounted) return;
  if (photos.isEmpty) {
    toast(context, 'This entry has no photos.');
    return;
  }
  final title = 'Photos – ${d['id']} · ${d['no']} · ${showDate('${d['date'] ?? ''}')} ${d['shift'] ?? ''} · ${fmt(d['qty'])} L';
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DieselPhotosScreen(title: title, photos: photos)));
}

class DieselPhotosScreen extends StatelessWidget {
  const DieselPhotosScreen({super.key, required this.title, required this.photos});
  final String title;
  final List<Map> photos;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title, maxLines: 2, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700))),
        body: ListView(key: const Key('dp-list'), padding: const EdgeInsets.fromLTRB(14, 8, 14, 24), children: [
          for (final (i, x) in photos.indexed) _photo(context, i, x),
          Text('A picture opens full size when it is pressed. The links work for 15 minutes.', style: const TextStyle(fontSize: 12.5, color: C.muted)),
        ]),
      );

  Widget _photo(BuildContext context, int i, Map x) {
    final url = '${x['url'] ?? ''}';
    return Container(
      key: Key('dp-$i'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (url.isEmpty)
          Container(height: 120, color: C.bg, alignment: Alignment.center, child: Text('The picture was not found.', style: const TextStyle(color: C.muted)))
        else
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text('${x['label'] ?? ''}')),
                body: Center(child: InteractiveViewer(maxScale: 6, child: Image.network(url, errorBuilder: (_, __, ___) => Text('The picture could not be opened.', style: const TextStyle(color: Colors.white))))),
              ),
            )),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: C.bg, alignment: Alignment.center, child: Text('The picture could not be opened.', style: const TextStyle(color: C.muted)))),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${x['label'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                if (photoStamp('${x['at'] ?? ''}').isNotEmpty) Text(photoStamp('${x['at']}'), style: const TextStyle(fontSize: 12.5, color: C.muted)),
              ]),
            ),
            if (_has(x['lat']))
              TextButton.icon(
                key: Key('dp-map-$i'),
                onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps?q=${Uri.encodeComponent('${x['lat']},${x['lng']}')}'), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.place_rounded, size: 18),
                label: Text('Map${_has(x['acc']) ? ' (± ${x['acc']} m)' : ''}'),
              ),
          ]),
        ),
      ]),
    );
  }
}
