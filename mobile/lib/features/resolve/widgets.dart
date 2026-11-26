import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import 'models.dart';

// ─── Motion (gentle, <= 400ms, off when the user reduces motion) ───

extension GentleIn on Widget {
  Widget gentleIn(BuildContext context, {int index = 0}) {
    if (AppTheme.reduceMotion(context)) return this;
    return animate(delay: (60 * index).ms)
        .fadeIn(duration: 300.ms, curve: Curves.easeOut)
        .slideY(begin: 0.06, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}

/// Slight scale-down while pressed, for cards and big buttons.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  const Pressable({super.key, required this.child, this.onTap, this.semanticLabel});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final reduce = AppTheme.reduceMotion(context);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down && !reduce ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}

// ─── Small building blocks ───

class CompanyAvatar extends StatelessWidget {
  final String name;
  final String? section;
  final double size;
  const CompanyAvatar({super.key, required this.name, this.section, this.size = 44});
  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.accentSoft(section),
          shape: BoxShape.circle,
        ),
        child: Text(
          name.isEmpty ? '?' : name[0].toUpperCase(),
          style: TextStyle(
            color: AppColors.accent(section),
            fontWeight: FontWeight.w800,
            fontSize: size * 0.42,
          ),
        ),
      ),
    );
  }
}

class Tag extends StatelessWidget {
  final String text;
  final Color color, bg;
  final IconData? icon;
  const Tag(this.text, {super.key, required this.color, required this.bg, this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 15, color: color), const SizedBox(width: 4)],
        Flexible(
          child: Text(text,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ]),
    );
  }
}

class NotVerifiedTag extends StatelessWidget {
  const NotVerifiedTag({super.key});
  @override
  Widget build(BuildContext context) => const Tag('Not verified',
      color: AppColors.warn, bg: AppColors.warnSoft, icon: Icons.help_outline);
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 13, letterSpacing: 0.8, fontWeight: FontWeight.w800, color: AppColors.muted)),
      );
}

// ─── Time helpers ───

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String friendlyTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute == 0 ? '' : ':${t.minute.toString().padLeft(2, '0')}';
  final ampm = t.hour < 12 ? 'AM' : 'PM';
  final now = DateTime.now();
  final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
  final day = sameDay ? 'today' : '${_days[t.weekday - 1]} ${t.day}/${t.month}';
  return '$day $h$m $ampm';
}

String timeLeft(DateTime deadline) {
  final d = deadline.difference(DateTime.now());
  if (d.isNegative) return 'deadline passed';
  if (d.inDays >= 1) return '${d.inDays} day${d.inDays == 1 ? '' : 's'} ${d.inHours % 24} hr left';
  if (d.inHours >= 1) return '${d.inHours} hr ${d.inMinutes % 60} min left';
  return '${d.inMinutes} min left';
}

// ─── Contact actions ───

IconData contactIcon(String kind) => switch (kind) {
      'phone' => Icons.call_rounded,
      'email' => Icons.mail_rounded,
      'whatsapp' => Icons.chat_rounded,
      'url' => Icons.open_in_new_rounded,
      _ => Icons.info_outline_rounded,
    };

String contactVerb(Contact c) {
  if (!c.verified) return 'Check the official page';
  return switch (c.kind) {
    'phone' => 'Call ${firstNumber(c.value!)}',
    'email' => 'Email ${c.value}',
    'whatsapp' => 'WhatsApp',
    'url' => c.label.startsWith('Open') ? c.label : 'Open website',
    _ => c.label,
  };
}

/// "0124-4973838 / 0124-6173838" -> "0124-4973838"
String firstNumber(String v) => v.split('/').first.trim();

Future<bool> openContact(BuildContext context, Contact c, {Complaint? complaint}) async {
  final v = c.value;
  if (v == null || v.isEmpty) {
    _snack(context, "We couldn't verify this contact. Please check the company's official website.");
    return false;
  }
  Uri? uri;
  switch (c.kind) {
    case 'phone':
      uri = Uri(scheme: 'tel', path: firstNumber(v).replaceAll(RegExp(r'[^0-9+]'), ''));
    case 'email':
      uri = Uri(scheme: 'mailto', path: v, query: complaint == null
          ? null
          : _encodeQuery({'subject': complaint.subject, 'body': complaint.body}));
    case 'whatsapp':
      uri = Uri.parse('https://wa.me/${v.replaceAll(RegExp(r'[^0-9]'), '')}');
    default:
      uri = Uri.tryParse(v);
  }
  if (uri == null) return false;
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) await copyText(context, v);
    return ok;
  } catch (_) {
    if (context.mounted) await copyText(context, v);
    return false;
  }
}

String _encodeQuery(Map<String, String> p) =>
    p.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');

Future<void> copyText(BuildContext context, String text, {String msg = 'Copied'}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) _snack(context, msg);
}

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

void showSnack(BuildContext context, String msg) => _snack(context, msg);
