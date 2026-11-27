import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'rtheme.dart';
import 'analyse_screen.dart';

/// App-wide navigator, so a share can open the analyser from anywhere.
final appNavigatorKey = GlobalKey<NavigatorState>();

/// Listens for "Share → HTH" from other apps (cold start and while running)
/// and opens the analyser with the shared text.
class ShareListener extends StatefulWidget {
  final Widget child;
  const ShareListener({super.key, required this.child});
  @override
  State<ShareListener> createState() => _ShareListenerState();
}

class _ShareListenerState extends State<ShareListener> {
  StreamSubscription<List<SharedMediaFile>>? _sub;

  /// A cold-start share is held here until Home is on screen, so the splash
  /// screen's pushReplacement doesn't wipe the analyser.
  static String? pending;

  @override
  void initState() {
    super.initState();
    try {
      _sub = ReceiveSharingIntent.instance.getMediaStream().listen(_onShared, onError: (_) {});
      ReceiveSharingIntent.instance.getInitialMedia().then((files) {
        final text = _textOf(files);
        if (text != null) pending = text;
        ReceiveSharingIntent.instance.reset();
      }).catchError((_) {});
    } catch (_) {
      // Not available (tests, desktop): sharing simply doesn't work there.
    }
  }

  String? _textOf(List<SharedMediaFile> files) {
    for (final f in files) {
      if ((f.type == SharedMediaType.text || f.type == SharedMediaType.url) && f.path.trim().isNotEmpty) {
        return f.path;
      }
    }
    return null;
  }

  void _onShared(List<SharedMediaFile> files) {
    final text = _textOf(files);
    if (text == null) return;
    ReceiveSharingIntent.instance.reset();
    openAnalyser(text);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Called by Home once it's visible: opens a share that launched the app.
void takePendingShare() {
  _homeReady = true;
  final text = _ShareListenerState.pending;
  _ShareListenerState.pending = null;
  if (text != null) openAnalyser(text);
}

bool _homeReady = false;

void openAnalyser(String sharedText) {
  final nav = appNavigatorKey.currentState;
  if (nav == null || !_homeReady) {
    _ShareListenerState.pending = sharedText;
    return;
  }
  // Back from the result returns to Home, not to an older analysis.
  nav.popUntil((r) => r.isFirst);
  nav.push(reviewRoute(AnalyseScreen(sharedText: sharedText)));
}
