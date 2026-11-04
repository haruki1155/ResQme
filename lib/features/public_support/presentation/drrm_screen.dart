import 'package:flutter/material.dart';

class DrrmScreen extends StatefulWidget {
  const DrrmScreen({super.key});
  @override
  State<DrrmScreen> createState() => _DrrmScreenState();
}

class _DrrmScreenState extends State<DrrmScreen> {
  String q = '';
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
  @override
  Widget build(BuildContext c) {
    final items = data.entries
        .where((e) => e.key.toLowerCase().contains(q.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('DRRM instructions')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Disaster preparedness',
            style: Theme.of(c).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Follow official PAGASA, PHIVOLCS, CDRRMO, and local-authority instructions.',
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search hazards',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          for (final e in items)
            Card(
              child: ExpansionTile(
                title: Text(e.key),
                leading: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFFE92B32),
                ),
                childrenPadding: const EdgeInsets.all(16),
                children: [
                  Container(
                    height: 120,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text('Future action-plan image'),
                  ),
                  const SizedBox(height: 16),
                  Text(e.value, style: const TextStyle(height: 1.5)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
