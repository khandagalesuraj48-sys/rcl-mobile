/* MY WORK LOCATIONS ON HOME (3.153.0 – asked 20-11-2026: "ya page war user la tyache allow locations disawet … to jya location la
 * asel ti location green asel ani … red astil tr … kiti lamb aahet te show krel … google map asel ani get direction"; and "map
 * disayla haw, map war touch keli ki te open hoil, close kela ki user jya thikani aahe tyawar prt … open zala chukun scroll pn
 * hoto map"):
 *   – the places he may mark attendance at (myAttend's `places`), each with where he stands: green "You are here" inside it, red
 *     with how far its edge is outside it; "Directions" opens Google Maps with the way to it;
 *   – a SMALL MAP on Home that does not move (a touch on it never scrolls the map – it opens the big one);
 *   – the BIG MAP on its own screen: it moves and zooms; ✕ goes back to Home exactly where he was.
 * The Google map when the app is built with the key (--dart-define=GMAPS=true), else OpenStreetMap (as Live Tracking).
 * Only a view: nothing is decided here – a punch is checked where it always was (the HR server). */
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmf;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/attend.dart';
import '../ui/hr_skin.dart';
import '../ui/t.dart';

String _t(String en, String mr) => Lang.i.pair(en, mr);

const bool _useGoogle = bool.fromEnvironment('GMAPS');
const _green = Color(0xFF0F7A45), _greenSoft = Color(0xFFE3F7EC), _red = Color(0xFFC22A1B), _redSoft = Color(0xFFFFE9E5), _blue = Color(0xFF1A56C4), _blueSoft = Color(0xFFE9F0FE);

/// The map pictures of OpenStreetMap are asked for on a phone only (a test has no internet).
bool placesMapTiles = !Platform.environment.containsKey('FLUTTER_TEST');

/// "Directions": Google Maps with the way to this point (the Maps app when the phone has it, else the browser). A test puts its own.
Future<void> Function(double lat, double lng) openDirections = (lat, lng) async {
  try {
    await launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'), mode: LaunchMode.externalApplication);
  } catch (_) {/* no Maps and no browser on this phone: nothing to open */}
};

/// His real work places ("Anywhere" – a circle round the whole earth the server adds for a person who may mark from any place –
/// is not a place to show or to go to).
List<WorkPlace> shownPlaces(Iterable<WorkPlace> all) => [for (final p in all) if (p.id != 'anywhere' && !(p.shape == 'circle' && p.radius > 1000000)) p];

/// The middle of a place: a circle's own point; an area's or a road's points taken together. null: it has no point at all.
LatLng? placeCentre(WorkPlace p) {
  if (p.shape == 'circle' && p.lat.isFinite && p.lng.isFinite) return LatLng(p.lat, p.lng);
  if (p.points.isEmpty) return p.lat.isFinite && p.lng.isFinite ? LatLng(p.lat, p.lng) : null;
  var a = 0.0, b = 0.0;
  for (final q in p.points) {
    a += q[0];
    b += q[1];
  }
  return LatLng(a / p.points.length, b / p.points.length);
}

/// "350 m away" / "2.4 km away".
String awayText(int metres) {
  final d = metres < 1000 ? '$metres m' : '${(metres / 1000).toStringAsFixed(metres < 10000 ? 1 : 0)} km';
  return _t('$d away', '$d दूर');
}

/// One place of the list: its sign (green inside, red outside, grey while the phone's place is not known), its name, where he
/// stands, and "Inside" or "Directions".
Widget placeRow(WorkPlace p, PlaceHit? hit, {required bool first}) {
  final inside = hit != null && hit.inside, known = hit != null, dist = hit == null ? 0 : hit.distance;
  final (Color c, Color soft) = !known ? (sk.muted, sk.blank) : inside ? sk.tint(_green, _greenSoft) : sk.tint(_red, _redSoft);
  final (Color bc, Color bsoft) = sk.tint(_blue, _blueSoft);
  final at = placeCentre(p);
  return Container(
    key: Key('pl-${p.id}'),
    padding: EdgeInsets.only(top: first ? 0 : 9, bottom: 9),
    decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: sk.hair))),
    child: Row(children: [
      Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(11)), child: Icon(Icons.location_on_rounded, size: 18, color: c)),
      const SizedBox(width: 11),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          m.Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: sk.ink)),
          m.Text(!known ? _t('Finding your place…', 'जागा शोधत आहे…') : inside ? _t('You are here', 'तुम्ही इथे आहात') : awayText(dist), key: Key('pl-at-${p.id}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c)),
        ]),
      ),
      const SizedBox(width: 8),
      if (inside)
        Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6), decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(99)), child: Text('Inside', mr: 'आत', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c)))
      else if (at != null)
        GestureDetector(
          key: Key('pl-dir-${p.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => openDirections(at.latitude, at.longitude),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: bsoft, borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.directions_rounded, size: 14, color: bc),
              const SizedBox(width: 4),
              Text('Directions', mr: 'रस्ता', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: bc)),
            ]),
          ),
        ),
    ]),
  );
}

/// Where he stands for each of [places] (by the place's id); empty while the phone's place is not known.
Map<String, PlaceHit> placeHits(List<WorkPlace> places, AttendFix? fix) => fix == null ? const {} : {for (final p in places) p.id: placeCheck(p, fix.lat, fix.lng)};

/// The places on a map. [live]: it moves and zooms (the big map); else a picture that stays still (Home).
class PlacesMap extends StatelessWidget {
  const PlacesMap({super.key, required this.places, required this.fix, required this.live});
  final List<WorkPlace> places;
  final AttendFix? fix;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final hits = placeHits(places, fix), f = fix;
    final pts = <LatLng>[
      for (final p in places) ...[
        if (placeCentre(p) != null) placeCentre(p)!,
        // (a circle's own edge is part of what must be seen: its top and its bottom)
        if (p.shape == 'circle' && p.lat.isFinite && p.lng.isFinite && p.radius > 0) ...[LatLng(p.lat + p.radius * 1.6 / 111320, p.lng), LatLng(p.lat - p.radius * 1.6 / 111320, p.lng)],
        if (p.shape != 'circle') for (final q in p.points) LatLng(q[0], q[1]),
      ],
      if (f != null) LatLng(f.lat, f.lng),
    ];
    // the middle of everything and how near to look: all of it on the map, with some room round it
    var mid = const LatLng(19.0, 75.5);
    var zoom = 7.0;
    if (pts.isNotEmpty) {
      var a = pts.first.latitude, b = a, c = pts.first.longitude, d = c;
      for (final p in pts) {
        a = math.min(a, p.latitude);
        b = math.max(b, p.latitude);
        c = math.min(c, p.longitude);
        d = math.max(d, p.longitude);
      }
      mid = LatLng((a + b) / 2, (c + d) / 2);
      final span = math.max(b - a, (d - c) * math.cos(mid.latitude * math.pi / 180) * (live ? 1.0 : .55));
      zoom = span <= 0.0004 ? 16.0 : (math.log(360 / span) / math.ln2 - 1.35).clamp(3.0, 17.0).toDouble();
    }
    Color hue(WorkPlace p) => hits[p.id]?.inside == true ? _green : _red;
    if (_useGoogle) {
      gmf.LatLng g(List<double> q) => gmf.LatLng(q[0], q[1]);
      return gmf.GoogleMap(
        key: Key(live ? 'pm-map' : 'hh-map'),
        initialCameraPosition: gmf.CameraPosition(target: gmf.LatLng(mid.latitude, mid.longitude), zoom: zoom),
        liteModeEnabled: !live && Platform.isAndroid, // (Home: a still picture of the map – cheap, and it cannot be dragged)
        markers: {
          for (final p in places)
            if (placeCentre(p) != null)
              gmf.Marker(markerId: gmf.MarkerId('p-${p.id}'), position: gmf.LatLng(placeCentre(p)!.latitude, placeCentre(p)!.longitude), infoWindow: gmf.InfoWindow(title: p.name), icon: gmf.BitmapDescriptor.defaultMarkerWithHue(hits[p.id]?.inside == true ? gmf.BitmapDescriptor.hueGreen : gmf.BitmapDescriptor.hueRed)),
          if (f != null && !live) gmf.Marker(markerId: const gmf.MarkerId('me'), position: gmf.LatLng(f.lat, f.lng), icon: gmf.BitmapDescriptor.defaultMarkerWithHue(gmf.BitmapDescriptor.hueAzure)),
        },
        circles: {
          for (final p in places)
            if (p.shape == 'circle' && p.lat.isFinite && p.lng.isFinite) gmf.Circle(circleId: gmf.CircleId('c-${p.id}'), center: gmf.LatLng(p.lat, p.lng), radius: p.radius, fillColor: hue(p).withValues(alpha: .14), strokeColor: hue(p), strokeWidth: 2),
        },
        polygons: {
          for (final p in places)
            if (p.shape == 'polygon' && p.points.length > 2) gmf.Polygon(polygonId: gmf.PolygonId('a-${p.id}'), points: [for (final q in p.points) g(q)], fillColor: hue(p).withValues(alpha: .14), strokeColor: hue(p), strokeWidth: 2),
        },
        polylines: {
          for (final p in places)
            if (p.shape != 'circle' && p.shape != 'polygon' && p.points.length > 1) gmf.Polyline(polylineId: gmf.PolylineId('r-${p.id}'), points: [for (final q in p.points) g(q)], color: hue(p), width: 5),
        },
        myLocationEnabled: live,
        myLocationButtonEnabled: live,
        zoomControlsEnabled: live,
        zoomGesturesEnabled: live,
        scrollGesturesEnabled: live,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: false,
      );
    }
    return FlutterMap(
      key: Key(live ? 'pm-map' : 'hh-map'),
      options: MapOptions(
        initialCenter: mid,
        initialZoom: zoom,
        backgroundColor: sk.dark ? const Color(0xFF1D2646) : const Color(0xFFEAF0E6),
        interactionOptions: InteractionOptions(flags: live ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none),
      ),
      children: [
        if (placesMapTiles) TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'in.rachana.rcl.rcl_mobile', maxZoom: 19),
        PolygonLayer(polygons: [
          for (final p in places)
            if (p.shape == 'polygon' && p.points.length > 2) Polygon(points: [for (final q in p.points) LatLng(q[0], q[1])], color: hue(p).withValues(alpha: .14), borderColor: hue(p), borderStrokeWidth: 2),
        ]),
        PolylineLayer(polylines: [
          for (final p in places)
            if (p.shape != 'circle' && p.shape != 'polygon' && p.points.length > 1) Polyline(points: [for (final q in p.points) LatLng(q[0], q[1])], color: hue(p), strokeWidth: 5),
        ]),
        CircleLayer(circles: [
          for (final p in places)
            if (p.shape == 'circle' && p.lat.isFinite && p.lng.isFinite) CircleMarker(point: LatLng(p.lat, p.lng), radius: p.radius, useRadiusInMeter: true, color: hue(p).withValues(alpha: .14), borderColor: hue(p), borderStrokeWidth: 1.5),
          if (f != null) CircleMarker(point: LatLng(f.lat, f.lng), radius: 7, color: const Color(0xFF1A73E8), borderColor: Colors.white, borderStrokeWidth: 2.5),
        ]),
        MarkerLayer(markers: [
          for (final p in places)
            if (placeCentre(p) != null) Marker(point: placeCentre(p)!, width: 34, height: 34, alignment: Alignment.topCenter, child: Icon(Icons.location_on_rounded, size: 34, color: hue(p))),
        ]),
      ],
    );
  }
}

/// THE BIG MAP: his work places, where he stands, the same list under it. It moves and zooms; ✕ goes back to where he was.
class PlacesMapScreen extends StatefulWidget {
  const PlacesMapScreen({super.key, required this.places});
  final List<WorkPlace> places;
  @override
  State<PlacesMapScreen> createState() => _PlacesMapScreenState();
}

class _PlacesMapScreenState extends State<PlacesMapScreen> {
  @override
  void initState() {
    super.initState();
    AttendWhere.i.addListener(_moved);
  }

  @override
  void dispose() {
    AttendWhere.i.removeListener(_moved);
    super.dispose();
  }

  void _moved() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    final fix = AttendWhere.i.fix, hits = placeHits(widget.places, fix);
    Widget round(Key key, IconData icon, VoidCallback onTap) => GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(width: 46, height: 46, alignment: Alignment.center, decoration: BoxDecoration(color: sk.card, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 6))]), child: Icon(icon, size: 22, color: sk.ink)),
        );
    return Scaffold(
      key: const Key('pm-page'),
      backgroundColor: sk.bg,
      body: Column(children: [
        Expanded(
          child: Stack(children: [
            Positioned.fill(child: PlacesMap(places: widget.places, fix: fix, live: true)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(children: [
                  round(const Key('pm-close'), Icons.close_rounded, () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      decoration: BoxDecoration(color: sk.card, borderRadius: BorderRadius.circular(99), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))]),
                      child: Text('My work locations', mr: 'माझी कामाची ठिकाणं', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Montserrat', fontSize: 14.5, fontWeight: FontWeight.w800, color: sk.ink)),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
        Container(
          width: double.infinity,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .42),
          decoration: BoxDecoration(color: sk.card, border: Border(top: BorderSide(color: sk.cardLine ?? sk.line))),
          child: SafeArea(
            top: false,
            child: ListView(key: const Key('pm-list'), shrinkWrap: true, padding: const EdgeInsets.fromLTRB(18, 14, 18, 12), children: [
              for (var i = 0; i < widget.places.length; i++) placeRow(widget.places[i], hits[widget.places[i].id], first: i == 0),
            ]),
          ),
        ),
      ]),
    );
  }
}
