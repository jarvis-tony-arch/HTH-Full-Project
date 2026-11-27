import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';

/// Same idea as Chrome's "Desktop site" switch. Some stores (Myntra) only
/// show reviews on their desktop pages. It does not hide checks or sign-in
/// pages: those are detected and handed to the user.
const desktopUserAgent =
    'Mozilla/5.0 (Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

/// One web view on the user's phone, plus the bundled reader script.
/// Pages are loaded exactly as the user's own browser would load them.
class PageReader {
  late final WebViewController controller;
  final _replies = <int, Completer<Map<String, dynamic>?>>{};
  Completer<void>? _finished;
  var _nextId = 1;
  String currentUrl = '';
  bool disposed = false;

  static String? _script;

  PageReader() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(desktopUserAgent)
      ..enableZoom(true)
      ..addJavaScriptChannel('HTH', onMessageReceived: _onMessage)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (u) => currentUrl = u,
        onUrlChange: (c) => currentUrl = c.url ?? currentUrl,
        onPageFinished: (u) {
          currentUrl = u;
          final f = _finished;
          if (f != null && !f.isCompleted) f.complete();
        },
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? false) {
            final f = _finished;
            if (f != null && !f.isCompleted) f.complete();
          }
        },
      ));
  }

  void _onMessage(JavaScriptMessage m) {
    try {
      final j = jsonDecode(m.message) as Map<String, dynamic>;
      final c = _replies.remove(j['id']);
      c?.complete(j['result'] as Map<String, dynamic>?);
    } catch (_) {}
  }

  /// Loads a page and waits for it (plus a short settle for scripts).
  Future<bool> load(Uri url, {Duration timeout = const Duration(seconds: 15)}) async {
    if (disposed) return false;
    _finished = Completer<void>();
    try {
      await controller.loadRequest(url);
      await _finished!.future.timeout(timeout);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      return true;
    } on TimeoutException {
      return false; // Still try to read whatever rendered.
    } catch (_) {
      return false;
    }
  }

  /// Runs one reader action in the page and returns its JSON result.
  Future<Map<String, dynamic>?> call(String action, Map<String, dynamic> cfg,
      {Map<String, dynamic> opts = const {}, Duration timeout = const Duration(seconds: 25)}) async {
    if (disposed) return null;
    _script ??= await rootBundle.loadString('assets/extract.js');
    final id = _nextId++;
    final c = Completer<Map<String, dynamic>?>();
    _replies[id] = c;
    try {
      await controller.runJavaScript(_script!);
      await controller.runJavaScript(
          '__hth.run($id, ${jsonEncode(action)}, ${jsonEncode(cfg)}, ${jsonEncode(opts)});');
      return await c.future.timeout(timeout);
    } catch (_) {
      return null;
    } finally {
      _replies.remove(id);
    }
  }

  void dispose() {
    disposed = true;
    for (final c in _replies.values) {
      if (!c.isCompleted) c.complete(null);
    }
    _replies.clear();
    controller.loadRequest(Uri.parse('about:blank')).catchError((_) {});
  }
}
