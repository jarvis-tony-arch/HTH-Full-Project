import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'history_store.dart';
import 'rtheme.dart';

/// Demo mode: saved real products, so a demo never depends on live pages.
class DemoSettings extends ChangeNotifier {
  static const _key = 'demo_mode_v1';
  bool _on = false;
  bool get on => _on;

  Future<void> load() async {
    try {
      _on = (await SharedPreferences.getInstance()).getBool(_key) ?? false;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> set(bool v) async {
    _on = v;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setBool(_key, v);
    } catch (_) {}
  }
}

Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    builder: (sheetContext) => Theme(
      data: Theme.of(context),
      child: Builder(builder: (context) {
        final c = RC.of(context);
        final demo = context.watch<DemoSettings>();
        final history = context.watch<HistoryStore>();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('Settings', style: Theme.of(context).textTheme.titleLarge),
              ),
              SwitchListTile(
                value: demo.on,
                onChanged: demo.set,
                title: const Text('Demo mode', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Show saved products with real reviews collected earlier. Works without the live shop pages.',
                    style: TextStyle(color: c.muted)),
              ),
              ListTile(
                enabled: history.items.isNotEmpty,
                leading: const Icon(Icons.delete_sweep_outlined),
                title: const Text('Clear recent checks'),
                subtitle: Text('Saved only on this phone', style: TextStyle(color: c.muted)),
                onTap: () async {
                  await history.clear();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark mode'),
                subtitle: Text('Follows your phone setting', style: TextStyle(color: c.muted)),
              ),
            ]),
          ),
        );
      }),
    ),
  );
}
