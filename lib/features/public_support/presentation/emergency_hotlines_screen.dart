import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _hotlines = [
  (
    category: 'National emergency',
    name: 'National Emergency Hotline',
    numbers: ['911'],
    note: null,
  ),
  (
    category: 'Local disaster & medical rescue',
    name:
        'CDRRMO / EMS — City Disaster Risk Reduction Management Office / Emergency Medical Service',
    numbers: ['0917 818 5374', '0917 159 1545'],
    note: null,
  ),
  (
    category: 'Local law enforcement',
    name: 'PNP — Philippine National Police, Urdaneta City Station',
    numbers: ['0920 369 9876', '0916 226 3641', '0998 598 5133'],
    note: null,
  ),
  (
    category: 'Local fire protection',
    name: 'BFP — Bureau of Fire Protection, Urdaneta City Station',
    numbers: ['0917 184 4611'],
    note: null,
  ),
  (
    category: 'Local health & medical assistance',
    name: 'CHO — City Health Office',
    numbers: ['075 568 6114'],
    note: null,
  ),
  (
    category: 'Local health & medical assistance',
    name: 'UDH — Urdaneta District Hospital',
    numbers: ['0975 632 6248'],
    note: null,
  ),
  (
    category: 'National support & agencies',
    name: 'Philippine Red Cross',
    numbers: ['143', '02 8527 8385'],
    note: null,
  ),
  (
    category: 'National support & agencies',
    name: 'NDRRMC — National Disaster Risk Reduction and Management Council',
    numbers: ['02 8911 5061'],
    note: 'Ask for extension 100 after your call connects.',
  ),
];

class EmergencyHotlinesScreen extends StatefulWidget {
  const EmergencyHotlinesScreen({super.key, this.openDialer});

  final Future<bool> Function(Uri)? openDialer;

  @override
  State<EmergencyHotlinesScreen> createState() =>
      _EmergencyHotlinesScreenState();
}

class _EmergencyHotlinesScreenState extends State<EmergencyHotlinesScreen> {
  bool _opening = false;

  Future<void> _confirm(String name, String number, String? note) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Open Phone?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name),
                const SizedBox(height: 12),
                Text(number, style: Theme.of(context).textTheme.titleLarge),
                if (note != null) ...[const SizedBox(height: 12), Text(note)],
                const SizedBox(height: 16),
                const Text(
                  'No call is placed automatically. The number will be filled in the Phone app. Tap Call there only when you intend to call.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open Phone'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
      var opened = false;
      try {
        opened =
            await (widget.openDialer?.call(uri) ??
                launchUrl(uri, mode: LaunchMode.externalApplication));
      } catch (_) {
        // Missing/disabled phone apps must leave the directory usable.
      }
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to open the Phone app. You can dial $number manually.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  static const _red = Color(0xFFE9232B);
  static const _ink = Color(0xFF10131C);
  static const _background = Color(0xFFF5F6F8);

  Widget _emergencyBanner() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF080B1D),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'IF LIFE IS IN DANGER',
          style: TextStyle(
            color: Color(0xFFFF6974),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Call 911 now',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Stay calm, share your location, and follow the operator's instructions.",
          style: TextStyle(
            color: Color(0xFFA9AFBE),
            fontSize: 14,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: _opening
              ? null
              : () => _confirm(_hotlines.first.name, '911', null),
          style: FilledButton.styleFrom(
            backgroundColor: _red,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _red.withValues(alpha: .45),
            minimumSize: const Size.fromHeight(48),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          icon: const Icon(Icons.phone_outlined, size: 21),
          label: const Text('Call 911'),
        ),
      ],
    ),
  );

  Widget _directoryCard(int index) {
    final hotline = _hotlines[index];
    final parts = hotline.name.split(' \u2014 ');
    final title = parts.first;
    final description = switch (title) {
      'National Emergency Hotline' => 'Police, fire, and medical emergency',
      'CDRRMO / EMS' => 'City disaster and medical rescue',
      'PNP' => 'Urdaneta City police assistance',
      'BFP' => 'Urdaneta City fire and rescue',
      'CHO' => 'City health assistance',
      'UDH' => 'District hospital assistance',
      'Philippine Red Cross' => 'Ambulance and disaster response',
      'NDRRMC' => 'National disaster coordination',
      _ => hotline.category,
    };
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          description,
          style: const TextStyle(
            color: Color(0xFF697789),
            fontSize: 12,
            height: 1.4,
          ),
        ),
        if (hotline.note != null) ...[
          const SizedBox(height: 6),
          Text(
            hotline.note!,
            style: const TextStyle(
              color: Color(0xFF697789),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
    final numbers = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final number in hotline.numbers)
          TextButton(
            onPressed: _opening
                ? null
                : () => _confirm(hotline.name, number, hotline.note),
            style: TextButton.styleFrom(
              foregroundColor: _red,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: Text(number, textAlign: TextAlign.right),
          ),
      ],
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0F1F4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D101828),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(14) > 18;
          final heading = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.phone_outlined, color: _red, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: details),
              if (!stacked) ...[const SizedBox(width: 8), numbers],
            ],
          );
          return stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [heading, const SizedBox(height: 8), numbers],
                )
              : heading;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: _ink,
      centerTitle: true,
      toolbarHeight: 72,
      leadingWidth: 72,
      leading: Center(
        child: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFF3F5F8),
            minimumSize: const Size(48, 48),
          ),
          icon: const Icon(Icons.chevron_left, size: 29),
        ),
      ),
      title: const Text(
        'Emergency hotlines',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 22),
          child: Icon(Icons.phone_outlined, color: _red, size: 25),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              _emergencyBanner(),
              const SizedBox(height: 28),
              const Text(
                'PHILIPPINES DIRECTORY',
                style: TextStyle(
                  color: Color(0xFF7B889A),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6,
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < _hotlines.length; i++) _directoryCard(i),
            ],
          ),
        ),
      ),
    ),
  );
}
