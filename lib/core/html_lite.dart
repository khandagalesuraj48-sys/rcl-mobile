/* A SMALL HTML READER (3.9.0) – for a page the server writes as HTML text (Admin → Read Me): the tags into a tree, so the app
 * draws it with its own widgets (headings, paragraphs, lists, tables, code to copy) – no web view. Only what such a page has:
 * no script, no style is run or used. */

class HNode {
  HNode(this.tag, [this.attrs = const {}]);
  final String tag; // '' = text
  final Map<String, String> attrs;
  final kids = <HNode>[];
  String text = '';
  String attr(String k) => attrs[k] ?? '';
  List<String> get classes => attr('class').split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  bool has(String cls) => classes.contains(cls);

  /// All the text inside, as it reads.
  String get plain {
    if (tag.isEmpty) return text;
    if (tag == 'br') return '\n';
    return kids.map((k) => k.plain).join();
  }

  Iterable<HNode> all() sync* {
    yield this;
    for (final k in kids) {
      yield* k.all();
    }
  }
}

const _void = {'br', 'input', 'img', 'hr', 'meta', 'link', 'col', 'wbr'};
const kBlockTags = {'div', 'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li', 'table', 'thead', 'tbody', 'tr', 'td', 'th', 'pre', 'details', 'summary', 'section', 'label', 'hr'};

const _closesP = {'p', 'div', 'ul', 'ol', 'table', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'pre', 'details', 'section', 'hr'};

const _ent = {'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'", 'nbsp': ' ', 'rarr': '→', 'larr': '←', 'ndash': '–', 'mdash': '—', 'hellip': '…', 'rsquo': '’', 'lsquo': '‘', 'times': '×', 'middot': '·', 'bull': '•', 'copy': '©'};

String unescapeHtml(String s) => s.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);'), (m) {
      final k = m[1]!;
      if (k.startsWith('#x')) return String.fromCharCode(int.parse(k.substring(2), radix: 16));
      if (k.startsWith('#')) return String.fromCharCode(int.parse(k.substring(1)));
      return _ent[k] ?? m[0]!;
    });

/// The page as a tree (the root's tag is 'root').
HNode parseHtml(String html) {
  final root = HNode('root'), stack = <HNode>[root];
  final re = RegExp(r'<!--[\s\S]*?-->|<(/?)([a-zA-Z][a-zA-Z0-9]*)((?:\s+[^\s=>/]+(?:\s*=\s*(?:"[^"]*"|' "'[^']*'" r'|[^\s>]+))?)*)\s*(/?)>|([^<]+|<)');
  final attrRe = RegExp(r'([^\s=>/]+)(?:\s*=\s*(?:"([^"]*)"|' "'([^']*)'" r'|([^\s>]+)))?');
  for (final m in re.allMatches(html)) {
    final full = m[0]!;
    if (full.startsWith('<!--')) continue;
    if (m[5] != null) {
      final t = HNode('')..text = unescapeHtml(m[5]!);
      stack.last.kids.add(t);
      continue;
    }
    final close = m[1] == '/', tag = m[2]!.toLowerCase();
    if (close) {
      final i = stack.lastIndexWhere((n) => n.tag == tag);
      if (i > 0) stack.removeRange(i, stack.length);
      continue;
    }
    final attrs = <String, String>{};
    for (final a in attrRe.allMatches(m[3] ?? '')) {
      attrs[a[1]!.toLowerCase()] = unescapeHtml(a[2] ?? a[3] ?? a[4] ?? '');
    }
    final n = HNode(tag, attrs);
    // a block closes a paragraph still open; a new item / row / cell closes the one still open (as a browser does)
    if (_closesP.contains(tag)) {
      for (var i = stack.length - 1; i > 0; i--) {
        if (stack[i].tag == 'p') {
          stack.removeRange(i, stack.length);
          break;
        }
        if (kBlockTags.contains(stack[i].tag)) break;
      }
    }
    if (tag == 'li' || tag == 'tr' || tag == 'td' || tag == 'th') {
      final stop = tag == 'li' ? {'ul', 'ol'} : tag == 'tr' ? {'table', 'tbody', 'thead'} : {'tr', 'table'};
      for (var i = stack.length - 1; i > 0; i--) {
        if (stop.contains(stack[i].tag)) break;
        if (stack[i].tag == tag || ((tag == 'td' || tag == 'th') && (stack[i].tag == 'td' || stack[i].tag == 'th'))) {
          stack.removeRange(i, stack.length);
          break;
        }
      }
    }
    stack.last.kids.add(n);
    if (!_void.contains(tag) && m[4] != '/') stack.add(n);
  }
  return root;
}
