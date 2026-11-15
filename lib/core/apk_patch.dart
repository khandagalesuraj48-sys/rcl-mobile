/* (3.126.0, asked 15-11-2026: "app updet krtana je kahi new updet aley tech fkt updet hoil … pratek weli full app download krayla ka
 * lawatoys, karan changes small hotat ani updet matr sagle app") THE SMALL UPDATE. Android installs only a WHOLE app file, so the
 * phone makes it itself: the app file already on the phone + the small file of the release with only what changed (a "patch",
 * about 1–3 MB instead of 75) = the new app file, byte for byte the released one. Its fingerprint (SHA-256) is checked as always
 * before it is installed (lib/core/update.dart); when it is not right – another file on the phone – the whole file is downloaded.
 *
 * The patch (made and checked by tool/apk_patch.py in the release): the 6 bytes "RCLP1\n", then ONE zlib stream of
 *   int64 size of the new file, then until that many bytes are made:
 *   int64 x, int64 y, int64 z · x bytes (each ADDED to the byte of the old file at its place) · y bytes (new, as they are)
 *   – after it the place in the old file moves on by x + z. Every int64: little-endian, signed.
 * Nothing is held whole in memory: the old file is read and the new one written piece by piece. */
import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';

/// Why a patch could not make the new file.
class PatchProblem implements Exception {
  const PatchProblem(this.message);
  final String message;
  @override
  String toString() => message;
}

const _magic = [0x52, 0x43, 0x4C, 0x50, 0x31, 0x0A]; // "RCLP1\n"

/// Makes the file [out] from the file [old] and the [patch]. Throws when the patch is not one, is cut short or does not fit [old]
/// (what is made is right only when its fingerprint is the release's – the caller checks it).
void applyPatch(String old, String patch, String out) {
  final o = File(old).openSync(), p = File(patch).openSync(), w = File(out).openSync(mode: FileMode.write);
  try {
    final head = p.readSync(_magic.length);
    if (head.length != _magic.length) throw const PatchProblem('not a patch file');
    for (var i = 0; i < _magic.length; i++) {
      if (head[i] != _magic[i]) throw const PatchProblem('not a patch file');
    }
    final maker = _Maker(o, w);
    final unpack = ZLibDecoder().startChunkedConversion(maker);
    while (true) {
      final part = p.readSync(1 << 16);
      if (part.isEmpty) break;
      unpack.add(part);
    }
    unpack.close();
    if (!maker.whole) throw const PatchProblem('the patch is cut short');
  } finally {
    o.closeSync();
    p.closeSync();
    w.closeSync();
  }
}

/// Takes the unpacked patch as it comes and writes the new file.
class _Maker implements Sink<List<int>> {
  _Maker(this._old, this._out) : _oldSize = _old.lengthSync();
  final RandomAccessFile _old, _out;
  final int _oldSize;
  final _num = Uint8List(24);
  int _have = 0; // the bytes of the number(s) read so far
  int _step = 0; // 0 the size · 1 x, y, z · 2 the x bytes · 3 the y bytes
  int _size = -1, _made = 0, _at = 0, _x = 0, _y = 0, _z = 0;

  bool get whole => _size >= 0 && _made == _size;

  @override
  void add(List<int> data) {
    final d = data is Uint8List ? data : Uint8List.fromList(data);
    var i = 0;
    while (i < d.length) {
      if (_step < 2) {
        if (_step == 1 && whole) throw const PatchProblem('the patch is longer than the file it makes');
        final need = _step == 0 ? 8 : 24, n = min(need - _have, d.length - i);
        _num.setRange(_have, _have + n, d, i);
        _have += n;
        i += n;
        if (_have < need) break;
        _have = 0;
        final b = ByteData.sublistView(_num);
        if (_step == 0) {
          _size = b.getInt64(0, Endian.little);
          if (_size < 0) throw const PatchProblem('not a patch file');
          _step = 1;
          continue;
        }
        _x = b.getInt64(0, Endian.little);
        _y = b.getInt64(8, Endian.little);
        _z = b.getInt64(16, Endian.little);
        if (_x < 0 || _y < 0 || _at < 0 || _at + _x > _oldSize || _made + _x + _y > _size) throw const PatchProblem('the patch does not fit the app on this phone');
        if (_x > 0) {
          _old.setPositionSync(_at);
          _step = 2;
        } else {
          _at += _z;
          _step = _y > 0 ? 3 : 1;
        }
      } else if (_step == 2) {
        final n = min(_x, d.length - i), was = _old.readSync(n);
        if (was.length != n) throw const PatchProblem('the patch does not fit the app on this phone');
        final now = Uint8List(n);
        for (var k = 0; k < n; k++) {
          now[k] = (d[i + k] + was[k]) & 0xFF;
        }
        _out.writeFromSync(now);
        _x -= n;
        _at += n;
        _made += n;
        i += n;
        if (_x == 0) {
          _at += _z;
          _step = _y > 0 ? 3 : 1;
        }
      } else {
        final n = min(_y, d.length - i);
        _out.writeFromSync(d, i, i + n);
        _y -= n;
        _made += n;
        i += n;
        if (_y == 0) _step = 1;
      }
    }
  }

  @override
  void close() {}
}
