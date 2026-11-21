import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app/palette.dart';
import '../providers/tickets_provider.dart';
import '../widgets/motion.dart';
import 'home_screen.dart';
import 'tickets_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  /// Any screen can switch tabs with: MainShell.tab.value = 1;
  static final ValueNotifier<int> tab = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: tab,
      builder: (context, index, _) {
        final pages = const <Widget>[
          HomeScreen(),
          TicketsScreen(),
          DashboardScreen(),
          SettingsScreen(),
        ];
        return Scaffold(
          backgroundColor: Pal.bg,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOut,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey<int>(index),
              child: pages[index],
            ),
          ),
          bottomNavigationBar: _NavBar(
            index: index,
            onTap: (i) => tab.value = i,
          ),
        );
      },
    );
  }
}

class _NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _NavBar({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final openCount = context
        .watch<TicketsProvider>()
        .tickets
        .where((t) => t.status != 'RESOLVED')
        .length;

    const icons = [
      Icons.home_rounded,
      Icons.confirmation_number_rounded,
      Icons.dashboard_rounded,
      Icons.settings_rounded,
    ];
    const labels = ['Home', 'Tickets', 'Agent', 'Settings'];

    return Container(
      decoration: const BoxDecoration(
        color: Pal.nav,
        border: Border(top: BorderSide(color: Pal.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            children: List.generate(4, (i) {
              final active = i == index;
              return Expanded(
                child: Pressable(
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: active
                          ? Pal.blue.withOpacity(0.14)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedScale(
                              scale: active ? 1.12 : 1.0,
                              duration: const Duration(milliseconds: 250),
                              child: Icon(
                                icons[i],
                                size: 22,
                                color: active ? Pal.blue : Colors.white30,
                              ),
                            ),
                            if (i == 1 && openCount > 0)
                              Positioned(
                                right: -8,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Pal.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$openCount',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          labels[i],
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight:
                                active ? FontWeight.w600 : FontWeight.w400,
                            color: active ? Pal.blue : Colors.white30,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}