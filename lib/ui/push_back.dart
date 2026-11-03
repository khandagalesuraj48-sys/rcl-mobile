/* (3.83.0, asked 03-11-2026 with the preview he OK'd: "menu web plus app madhe push back use kraych aahe the page shrink back and
 * side right revealing the menu behind it") THE MENU BEHIND THE PAGE – the Home tab's ≡ (and "View All"): the whole screen (the
 * page with the tab bar) shrinks back and moves to the right; the menu is behind it on the left. A tap on the page, a swipe to the
 * left, Back or a row of the menu closes it; a swipe from the left edge of Home opens it (as the drawer did). The menu keeps its
 * colours (light). The web's menu on a phone does the same (Mechanical update-209). */
import 'package:flutter/material.dart' hide Text;

/// Put around the screen that shrinks; [PushBack.maybeOf] opens a menu behind it.
class PushBack extends StatefulWidget {
  const PushBack({super.key, required this.child, this.color = const Color(0xFFFAF8F2)});
  final Widget child;

  /// What is behind the page (the menu's own colour).
  final Color color;

  static PushBackState? maybeOf(BuildContext context) => context.findAncestorStateOfType<PushBackState>();

  @override
  State<PushBack> createState() => PushBackState();
}

class PushBackState extends State<PushBack> with SingleTickerProviderStateMixin {
  /// how far the page goes to the right (of the screen's width) and how small it gets
  static const shift = .66, small = .8;
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
  Widget? _menu;

  bool get isOpen => _menu != null;

  /// Opens [menu] behind the page.
  void open(Widget menu) {
    setState(() => _menu = menu);
    _c.forward();
  }

  /// Closes it (the page comes back to the whole screen).
  void close() {
    if (_menu == null) return;
    _c.reverse().whenComplete(_gone);
  }

  void _gone() {
    if (mounted && _c.value == 0 && _menu != null) setState(() => _menu = null);
  }

  /// A finger moving the page: [menu] behind it while it moves; [dx] in pixels.
  void drag(Widget menu, double dx) {
    if (_menu == null) setState(() => _menu = menu);
    final w = MediaQuery.sizeOf(context).width * shift;
    if (w > 0) _c.value = (_c.value + dx / w).clamp(0.0, 1.0);
  }

  /// The finger let go: open or closed, by where the page is and how fast it went.
  void dragEnd(double velocity) {
    if (_menu == null) return;
    if (velocity > 300 || (velocity > -300 && _c.value > .5)) {
      _c.forward();
    } else {
      close();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context), menu = _menu;
    // the same three layers always (the page keeps its state): the menu's ground, the menu, the page
    return ColoredBox(
      color: widget.color,
      child: Stack(children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: size.width * shift,
          child: menu == null
              ? const SizedBox.shrink()
              : AnimatedBuilder(
                  animation: _c,
                  builder: (context, child) {
                    final t = Curves.easeOutCubic.transform(_c.value);
                    return Opacity(opacity: (.25 + .75 * t).clamp(0.0, 1.0), child: Transform.translate(offset: Offset(-18 * (1 - t), 0), child: Transform.scale(scale: .94 + .06 * t, alignment: Alignment.centerLeft, child: child)));
                  },
                  child: menu,
                ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              final t = Curves.easeOutCubic.transform(_c.value), r = 30 * t;
              return Transform.translate(
                offset: Offset(size.width * shift * t, 0),
                child: Transform.scale(
                  scale: 1 - (1 - small) * t,
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(r), boxShadow: t == 0 ? null : [BoxShadow(color: Colors.black.withValues(alpha: .34 * t), blurRadius: 50, offset: const Offset(-20, 0))]),
                  child: ClipRRect(borderRadius: BorderRadius.circular(r), clipBehavior: t == 0 ? Clip.none : Clip.antiAlias, child: child),
                  ),
                ),
              );
            },
            child: Stack(children: [
              Positioned.fill(child: widget.child),
              // open: the page is not used – a tap closes, a swipe to the left closes
              Positioned.fill(
                child: menu == null
                    ? const SizedBox.shrink()
                    : GestureDetector(
                        key: const Key('pushback-page'),
                        behavior: HitTestBehavior.opaque,
                        onTap: close,
                        onHorizontalDragUpdate: (d) => drag(menu, d.delta.dx),
                        onHorizontalDragEnd: (d) => dragEnd(d.primaryVelocity ?? 0),
                      ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
