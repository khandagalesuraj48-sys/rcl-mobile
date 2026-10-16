/* PRINT: the page the web asked to print (a Log Book, a bill, a report) shown as it will be on paper, and Android's printing
 * opened for it – a printer, or "Save as PDF" to send it on. "Print" at the top opens it again. */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../config.dart';
import '../core/print_fit.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/t.dart';

class PrintView extends StatefulWidget {
  const PrintView({super.key, required this.html, required this.title, this.fit = false});
  final String html, title;
  /// (3.8.0) the web's own fitting of the pages before printing: each bill on one A4 page, each Log Book sheet on one page with
  /// the signatures at its foot (only for the app's own bill / Log Book pages – their data is escaped)
  final bool fit;
  @override
  State<PrintView> createState() => _PrintViewState();
}

class _PrintViewState extends State<PrintView> {
  InAppWebViewController? _c;
  bool _ready = false, _printedOnce = false;

  Future<void> _print() async {
    final c = _c;
    if (c == null) return;
    try {
      await c.printCurrentPage(settings: PrintJobSettings(jobName: widget.title.isEmpty ? 'RCL ERP' : widget.title));
    } catch (_) {
      if (mounted) toast(context, 'Printing could not be opened on this phone.', bad: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: C.greenDark,
          foregroundColor: Colors.white,
          titleTextStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
          title: Text(widget.title.isEmpty ? 'Print' : widget.title, overflow: TextOverflow.ellipsis),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: C.greenDark, minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16)),
                onPressed: _ready ? _print : null,
                icon: const Icon(Icons.print_rounded, size: 20),
                label: const Text('Print / PDF'),
              ),
            ),
          ],
        ),
        body: Stack(children: [
          InAppWebView(
            initialData: InAppWebViewInitialData(data: widget.html, baseUrl: WebUri(kMainUrl), mimeType: 'text/html', encoding: 'utf8'),
            initialSettings: InAppWebViewSettings(supportZoom: true, builtInZoomControls: true, displayZoomControls: false, javaScriptEnabled: widget.fit, useWideViewPort: true, loadWithOverviewMode: true),
            onWebViewCreated: (c) => _c = c,
            onLoadStop: (c, _) async {
              if (_printedOnce) return;
              _printedOnce = true;
              await Future<void>.delayed(const Duration(milliseconds: 700)); // the logo comes in
              if (widget.fit) {
                try {
                  await c.evaluateJavascript(source: '$kPrintFit;try{fitBillPages(document)}catch(e){};try{fitWideTables(document)}catch(e){};try{fitLogPages(document)}catch(e){};');
                } catch (_) {/* printed as it is */}
              }
              if (!mounted) return;
              setState(() => _ready = true);
              await _print();
            },
          ),
          if (!_ready) const LinearProgressIndicator(minHeight: 3, color: C.green, backgroundColor: Colors.transparent),
        ]),
      );
}
