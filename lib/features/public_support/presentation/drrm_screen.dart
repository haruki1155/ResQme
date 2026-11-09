import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class DrrmScreen extends StatefulWidget {
  const DrrmScreen({super.key});
  @override
  State<DrrmScreen> createState() => _DrrmScreenState();
}

class _DrrmScreenState extends State<DrrmScreen> {
  String q = '';
  final _search = TextEditingController();
  bool _showSearch = false;
  bool _planOpen = false;
  static const _red = Color(0xFFE3222A);
  static const _ink = Color(0xFF10131C);
  static const _muted = Color(0xFF697789);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static const data = {
    'Drought':
        'Before: Store clean drinking water; monitor PAGASA; prepare food and supplies; conserve water.\n\nDuring: Use water only when necessary; follow local guidance; stay hydrated; keep water covered.\n\nAfter: Continue conserving; check sources before drinking; report shortages; follow advisories.',
    'Landslides and mudslides':
        'Before: Identify prone areas; monitor warnings; prepare go bag; know routes.\n\nDuring: Evacuate when instructed; move away from slopes, rivers and valleys; follow authorities.\n\nAfter: Return only when safe; avoid damaged roads/power lines; report missing or injured.',
    'Tsunami':
        'Before: Know evacuation routes; prepare go bag; monitor PHIVOLCS; know natural signs.\n\nDuring: Move to higher ground; avoid beaches; follow evacuation orders; never watch waves.\n\nAfter: Wait for clearance; avoid damaged structures/floodwater; follow announcements.',
    'Severe thunderstorm':
        'Before: Monitor PAGASA; prepare kit; secure loose objects; charge devices.\n\nDuring: Stay indoors, away from windows/electrical appliances/trees; follow CDRRMO.\n\nAfter: Wait for announcements; avoid wires, damage and floodwater; report hazards.',
    'Flood':
        'Before: Monitor warnings; prepare kit/documents, supplies and water; know evacuation centre.\n\nDuring: Move higher when advised; do not walk/drive floodwater; turn off electricity if safe.\n\nAfter: Wait for safe declaration; avoid wires/appliances and contaminated water; clean/disinfect.',
    'Extreme heatwaves':
        'Before: Monitor advisories; prepare water; ventilate home; plan cooler-hour activity.\n\nDuring: Drink water; stay cool/shaded; wear light clothes; avoid peak exertion.\n\nAfter: Hydrate, check family, follow health advice and seek help for serious illness.',
    'Earthquake':
        'Before: Prepare kit; know safe places/exits; secure furniture; practice.\n\nDuring: Stay calm; get under a strong table; protect head; stay until shaking stops.\n\nAfter: Check injuries; avoid damage; expect aftershocks; follow authorities.',
    'Tropical cyclone':
        'Before: Monitor PAGASA; prepare kit, food/water; know evacuation centre.\n\nDuring: Stay inside, follow instructions/updates, evacuate if needed.\n\nAfter: Wait for safe announcement; check injuries; avoid damage; follow advisories.',
    'Fire':
        'Before: Check wires/outlets, make evacuation plan, keep extinguisher, know exits/drills.\n\nDuring: Alert others, exit safely, stay low in smoke, do not use elevators or return; call for help from safety.\n\nAfter: Check injuries, avoid burned area, do not enter until cleared, report danger.',
    'Transportation accidents':
        'Vehicular collision: Notify school/emergency responders, keep students away from traffic, do not move seriously injured unless immediate danger, let qualified rescuers assess.\n\nBrake failure/mechanical breakdown: Follow driver instructions; move only if instructed/safe; contact services for crash/injury; do not repair in dangerous traffic.\n\nPedestrian accidents: Follow the same safety actions: avoid traffic danger, call responders, do not move seriously injured unless immediate danger.',
  };
  String _label(String name) => switch (name) {
    'Extreme heatwaves' => 'Extreme heat',
    'Landslides and mudslides' => 'Landslide',
    'Severe thunderstorm' => 'Severe storm',
    'Transportation accidents' => 'Transportation',
    _ => name,
  };

  String _summary(String name) => switch (name) {
    'Earthquake' => 'Earthquake preparedness',
    'Tropical cyclone' => 'Storm preparedness',
    'Flood' => 'Flood preparedness',
    'Extreme heatwaves' => 'Heat safety',
    'Fire' => 'Fire preparedness',
    'Landslides and mudslides' => 'Slope and ground safety',
    'Tsunami' => 'Coastal preparedness',
    'Severe thunderstorm' => 'Severe weather safety',
    'Drought' => 'Water shortage preparedness',
    _ => 'Road safety and response',
  };

  Future<void> _openPlan(String name, String guidance) async {
    if (_planOpen) return;
    _planOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierColor: const Color(0x99080B1D),
        builder: (dialogContext) => BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Dialog(
            insetPadding: const EdgeInsets.all(20),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: MediaQuery.sizeOf(dialogContext).height * .86,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      color: const Color(0xFF080B1D),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _red,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Icon(
                                  Icons.shield_outlined,
                                  color: Colors.white,
                                  size: 25,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: const Color(0xFF202333),
                                  minimumSize: const Size(64, 48),
                                ),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'EMERGENCY ACTION PLAN',
                            style: TextStyle(
                              color: Color(0xFFFF6974),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _summary(name),
                            style: const TextStyle(
                              color: Color(0xFFA9AFBE),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'FOLLOW THESE STEPS',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 18),
                          for (final (index, section)
                              in guidance.split('\n\n').indexed)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: _red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      section,
                                      style: const TextStyle(
                                        color: Color(0xFF455165),
                                        fontSize: 14,
                                        height: 1.55,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 6),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: FilledButton.styleFrom(
                              backgroundColor: _red,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(50),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            child: const Text('I understand'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      _planOpen = false;
    }
  }

  Widget _hazardCard(MapEntry<String, String> entry) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 124),
    child: Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: const Color(0x16101828),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFF0F1F4)),
      ),
      child: InkWell(
        key: ValueKey('hazard-${entry.key}'),
        borderRadius: BorderRadius.circular(22),
        onTap: () => _openPlan(entry.key, entry.value),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, color: _red, size: 21),
              const SizedBox(height: 18),
              Text(
                _label(entry.key),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _summary(entry.key),
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    const priority = [
      'Earthquake',
      'Tropical cyclone',
      'Flood',
      'Extreme heatwaves',
      'Fire',
      'Landslides and mudslides',
      'Tsunami',
      'Severe thunderstorm',
    ];
    final ordered = [
      for (final name in priority) MapEntry(name, data[name]!),
      ...data.entries.where((e) => !priority.contains(e.key)),
    ];
    final items = ordered
        .where((e) => e.key.toLowerCase().contains(q.trim().toLowerCase()))
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
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
          'DRRM instructions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 22),
            child: Icon(Icons.shield_outlined, color: _red, size: 25),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'DISASTER PREPAREDNESS',
                    style: TextStyle(
                      color: _red,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Know what to do.\nAct with confidence.',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Choose a hazard to open its emergency action plan.',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Search hazards',
                        onPressed: () => setState(() {
                          _showSearch = !_showSearch;
                          if (!_showSearch) {
                            q = '';
                            _search.clear();
                          }
                        }),
                        icon: const Icon(Icons.search, color: _red, size: 22),
                      ),
                    ],
                  ),
                  if (_showSearch) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      onChanged: (value) => setState(() => q = value),
                      decoration: InputDecoration(
                        hintText: 'Search hazards',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'No hazards found',
                            style: TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              q = '';
                              _search.clear();
                            }),
                            child: const Text('Clear search'),
                          ),
                        ],
                      ),
                    ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          constraints.maxWidth < 320 ||
                              MediaQuery.textScalerOf(context).scale(14) > 18
                          ? 1
                          : 2;
                      return Column(
                        children: [
                          for (var i = 0; i < items.length; i += columns)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (var col = 0; col < columns; col++) ...[
                                      if (col > 0) const SizedBox(width: 12),
                                      Expanded(
                                        child: i + col < items.length
                                            ? _hazardCard(items[i + col])
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Follow official PAGASA, PHIVOLCS, CDRRMO, and local-authority instructions.',
                    style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
