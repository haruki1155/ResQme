import 'package:flutter/material.dart';

class FirstAidGuide {
  const FirstAidGuide(this.title, this.category, this.icon, this.details);

  final String title;
  final String category;
  final IconData icon;
  final String details;
}

const _guides = <FirstAidGuide>[
  FirstAidGuide(
    'Asthma',
    'Breathing & response',
    Icons.air,
    '''Step 1: Sit the person upright\nBe calm and reassuring. Do not leave them alone.\n\nStep 2: Give 4 separate puffs of blue/grey reliever puffer\nShake the puffer. Put 1 puff into the spacer. Get the person to take 4 breaths from the spacer. Repeat until 4 puffs have been taken. If no spacer is available, give 1 puff as they take 1 slow, deep breath and hold their breath for as long as comfortable. Remember: Shake, 1 puff, 4 breaths.\n\nStep 3: Wait 4 minutes\nIf there is no improvement, give 4 more separate puffs of blue/grey reliever as above.\n\nStep 4: If breathing does not return to normal, call emergency assistance for an ambulance\nTell the operator someone is having an asthma emergency. Keep giving 4 separate puffs, taking 4 breaths for each puff, every 4 minutes until help arrives.\n\nWhat if only 1 puff is available?\nStep 1: Use the puffer\nHelp the person use their available inhaler. Give 1 puff as the person begins a slow, deep breath, then have them hold their breath for as long as comfortable.\n\nStep 2: Seek emergency assistance\nSince not enough reliever medication is available, immediately call 911 or any emergency hotline. Explain that the person is having an asthma emergency and only one puff is available.\n\nStep 3: While waiting for responders\nObserve breathing, level of consciousness, and whether symptoms improve or worsen. Give enough space, loosen tight clothing if necessary, and avoid smoke or known triggers.''',
  ),
  FirstAidGuide(
    'Anemia',
    'Breathing & response',
    Icons.favorite_outline,
    '''Steps and procedures during an emergency\nStep 1: Make sure the area is safe. Check surroundings are safe for both helper and person.\n\nStep 2: Check the person's condition. Ask how they feel; check if they are awake, responding normally, and breathing normally. Ask about symptoms and a known history of anemia.\n\nStep 3: Call emergency services if there are serious symptoms. Call 911 for chest pain, severe difficulty breathing, fainting, confusion, or other serious symptoms. Explain the condition and exact location.\n\nStep 4: Help the person rest. Help them sit or lie comfortably. If faint, help them lie flat when safe and comfortable. Do not let them walk or exert themselves.\n\nStep 5: Monitor their condition. Observe breathing, awareness, and symptoms; watch for worsening weakness, breathing difficulties, or loss of consciousness.\n\nStep 6: Turn over the patient to healthcare professionals. Explain what happened, symptoms noticed, when they started, and any known medical history or medications. Allow professionals to assess and treat.''',
  ),
  FirstAidGuide(
    'Nosebleed',
    'Bleeding & wounds',
    Icons.water_drop_outlined,
    '''Steps and procedures during an emergency\nStep 1: Sit the person upright. Help them sit upright and lean slightly forward. Stay calm and reassure them. Do not let them lie down or tilt their head backward.\n\nStep 2: Pinch the nose. Pinch the soft part with thumb and index finger continuously for 10–15 minutes. Tell them to breathe through their mouth.\n\nStep 3: Check the bleeding. Slowly release after 10–15 minutes. If still bleeding, pinch again for another 10–15 minutes.\n\nStep 4: Seek medical assistance if needed. Get help if bleeding is heavy, continues a long time, follows serious injury, or the person is weak or faint. Keep them calm while waiting.''',
  ),
  FirstAidGuide(
    'Hyperventilation',
    'Breathing & response',
    Icons.slow_motion_video_outlined,
    '''Step 1: Help the person sit comfortably in a safe position. Stay calm, reassure them, and do not leave them alone.\n\nStep 2: Encourage slow breathing. Ask for slow, gentle, normal breaths instead of very deep or rapid breaths.\n\nStep 3: Make them comfortable. Loosen tight clothing if necessary; move away from smoke, strong smells, or possible triggers. Give space and keep the area calm.\n\nStep 4: Seek emergency assistance if needed. Call if breathing does not improve or worsens, or for chest pain, fainting, confusion, or severe difficulty breathing. Stay and monitor while waiting.''',
  ),
  FirstAidGuide(
    'Moving an injured person',
    'Moving safely',
    Icons.accessibility_new,
    '''Wheelchair\nLock the wheelchair before helping the person sit. Help them move carefully, make sure they sit safely, and push slowly away from uneven or dangerous areas.\n\nStretcher\nPlace the person carefully on the stretcher. Keep them supported and still, secure them before moving, and have enough people help carry it.\n\nSpine Board\nUse when a spinal injury is suspected. Keep head, neck, and body aligned; secure properly to prevent movement. Only trained rescuers should move a person using a spine board.\n\nCarrying an injured person\nCheck the area is safe. Use a method suited to the condition, support the head, neck, and injured areas when needed, and ask for help instead of carrying seriously injured people alone.''',
  ),
  FirstAidGuide(
    'Basic life support (BLS) / CPR',
    'Life-saving response',
    Icons.monitor_heart_outlined,
    '''A. Hands-Only CPR\nCheck the area is safe. Tap the shoulder and shout to check response. Ask someone to call 911 and get an AED. Lay the person on their back on a firm, flat surface. Put the heel of one hand in the centre of the chest, other hand on top, fingers locked. Push hard and fast with straight arms. Let the chest rise after every push. Continue until normal breathing, help arrives, or you cannot continue.\n\nChest compression rate and depth\nPush 100–120 times per minute. Push at least 2 inches (5 cm), but not deeper than 2.4 inches (6 cm). Keep hands centred, one on top of the other. Allow full chest recoil and do not lean on the chest.\n\nB. How to use an AED\nTurn it on and follow spoken instructions. Remove chest clothing and dry the chest. Attach pads to bare skin: one upper right chest, one lower left below the armpit. Do not touch while it checks rhythm. If a shock is advised, make sure everyone moves away before pressing shock. Continue CPR immediately after a shock or if no shock is advised. Follow the AED until medical help arrives.''',
  ),
  FirstAidGuide(
    'Choking (blocked airway)',
    'Life-saving response',
    Icons.warning_amber_outlined,
    '''A. Adults and children: Back blows and abdominal thrusts\nSigns: cannot breathe, speak, make sounds, or cough properly; may hold throat. Ask if choking. Ask someone to call 911. Stand behind and slightly to one side, support chest, lean forward, and give 5 firm back blows between shoulder blades. If not cleared, make a fist just above belly button, hold it with the other hand, and give 5 quick inward-and-upward abdominal thrusts. Alternate 5 back blows and 5 thrusts until cleared or unresponsive.\n\nB. Infants: Back blows and chest thrusts\nFor babies under one, do not use abdominal thrusts. Hold face-down along forearm, support head and jaw, and keep head lower than body. Give 5 back blows. Turn face-up supporting head and neck, keep head lower than chest, and give 5 chest thrusts following current AHA technique. Repeat until cleared or unresponsive. If unresponsive, place on firm flat surface and begin infant CPR according to training.''',
  ),
  FirstAidGuide(
    'Bleeding and wound care',
    'Bleeding & wounds',
    Icons.healing_outlined,
    '''A. Direct pressure\nEnsure safety. Wear disposable gloves if available. Put clean gauze or cloth directly over the wound and press firmly and continuously until bleeding stops. For severe bleeding that does not stop, get emergency help immediately; a tourniquet may be needed for a serious arm or leg injury. Cover with a clean dressing.\n\nB. Elevation\nApply direct pressure first. Avoid unnecessary movement. If a broken bone or serious injury is suspected, do not raise or move it unnecessarily. Get medical help for serious injuries.\n\nC. Cleaning a wound\nWash hands. Rinse with clean running water, gently clean surrounding skin, and avoid dirty hands. Seek help if an object is deeply stuck. Watch for redness, swelling, warmth, or pus.\n\nD. Dressing and bandaging\nControl bleeding. Cover completely with sterile dressing or clean bandage. Secure without wrapping too tightly. Change if wet or dirty; check for swelling, unusual colour, numbness, or tightness.\n\nE. Tourniquets for severe bleeding\nCall emergency services. Apply direct pressure while preparing if possible. Use a commercially made tourniquet and follow its instructions. Place 2–3 inches above the wound, between wound and heart; never over a joint or wound. Tighten until bleeding stops, secure it, record the time, and do not loosen or remove it.''',
  ),
  FirstAidGuide(
    'Burns',
    'Burns & injuries',
    Icons.local_fire_department_outlined,
    '''Thermal burns\nStop the burning process if safe. Cool under cool running water for about 20 minutes. Remove jewellery or tight items before swelling if not stuck. Cover loosely with a clean non-stick dressing or cloth. Do not apply ice, toothpaste, butter, oil, or home remedies. Seek medical help for large, deep, serious burns; burns to face, hands, feet, genitals, major joints; or electrical/chemical burns.\n\nChemical burns\nProtect yourself; avoid direct contact. Remove contaminated clothing carefully. Brush off dry chemicals before water. Flush with plenty of running water for at least 20 minutes. Do not neutralize with another substance. Get medical attention, especially for significant burns or eye exposure.\n\nElectrical injuries\nTurn off the power first; do not touch someone still connected. Once safe, check breathing and responsiveness. Call emergency medical services if needed. Cover visible burns with a clean, dry, non-stick dressing. Electrical injuries need medical evaluation even when skin damage seems small.''',
  ),
  FirstAidGuide(
    'Fractures, sprains, dislocations & seizures',
    'Burns & injuries',
    Icons.personal_injury_outlined,
    '''Fractures, sprains, and dislocations\nKeep the person still and calm. Do not straighten, push back, or realign. Immobilize in the position found; if appropriate support with a splint or sling including joints above and below. Apply a cold pack wrapped in cloth. For sprains: RICE—Rest, Ice in short wrapped periods, Compression not tight enough to cause numbness/tingling/colour changes, Elevation when comfortable.\n\nWhen not to move a victim\nAvoid unnecessary movement for suspected spinal/neck injury, severe injury or deformity, if moving could worsen injury, or if unconscious/seriously injured—unless immediate safety or lifesaving first aid requires it.\n\nSeizure and convulsions: during\nStay calm and stay with them. Clear nearby hazards, protect head with something soft, loosen neck clothing. Do not restrain, put anything in their mouth, force it open, or give food, water, or medicine until fully alert. Time the seizure.\n\nAfter\nCheck breathing. If breathing but unconscious, place in recovery position on their side. Reassure as awareness returns and monitor until help arrives. Call emergency services if it lasts 5 minutes or longer, repeats before recovery, is a first known seizure, causes breathing difficulty/unconsciousness, serious injury, or happens in water.''',
  ),
];

class FirstAidLibraryScreen extends StatefulWidget {
  const FirstAidLibraryScreen({super.key});
  @override
  State<FirstAidLibraryScreen> createState() => _FirstAidLibraryScreenState();
}

class _FirstAidLibraryScreenState extends State<FirstAidLibraryScreen> {
  static const _red = Color(0xFFE3222A);
  static const _ink = Color(0xFF10131C);
  static const _muted = Color(0xFF697789);
  final _search = TextEditingController();
  String _query = '';
  String _category = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _submitSearch() {
    FocusScope.of(context).unfocus();
    setState(() => _query = _search.text);
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _category = 'All';
    });
  }

  Widget _guideCard(
    FirstAidGuide guide, {
    required bool initiallyExpanded,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 16),
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
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: ExpansionTile(
        key: PageStorageKey(guide.title),
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: const Color(0xFFA4ADBA),
        collapsedIconColor: const Color(0xFFA4ADBA),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(guide.icon, color: _red, size: 23),
        ),
        title: Text(
          guide.title,
          style: const TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            guide.category,
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
          ),
        ),
        children: [
          const Divider(height: 1, color: Color(0xFFF0F1F4)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BEFORE YOU BEGIN',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Use professional emergency services for serious or life-threatening conditions.',
                        style: TextStyle(
                          color: Color(0xFF455165),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'WHAT TO DO',
                  style: TextStyle(
                    color: _red,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                for (final section in guide.details.split('\n\n'))
                  _instruction(section),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FirstAidDetailScreen(guide: guide),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: _red,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open full guide'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _instruction(String section) {
    final match = RegExp(r'^Step (\d+):\s*').firstMatch(section);
    final text = Text(
      match == null ? section : section.substring(match.end),
      style: const TextStyle(
        color: Color(0xFF455165),
        fontSize: 14,
        height: 1.55,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: match == null
          ? text
          : Row(
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
                    match.group(1)!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: text),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      'All',
      ...{for (final guide in _guides) guide.category},
    ];
    final guides = _guides
        .where(
          (guide) =>
              (_category == 'All' || guide.category == _category) &&
              guide.title.toLowerCase().contains(_query.trim().toLowerCase()),
        )
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
          'First-aid instructions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 22),
            child: Icon(Icons.add_circle_outline, color: _red, size: 25),
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
                const Text(
                  'IMMEDIATE CARE GUIDE',
                  style: TextStyle(
                    color: _red,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'What do you need\nhelp with?',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        textInputAction: TextInputAction.search,
                        onChanged: (value) => setState(() => _query = value),
                        onSubmitted: (_) => _submitSearch(),
                        style: const TextStyle(fontSize: 14, color: _ink),
                        decoration: InputDecoration(
                          hintText: 'Search injury or symptom',
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF7B889A),
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 21,
                            color: Color(0xFF8B98AA),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE1E5EB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE1E5EB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: _red,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Search guides',
                      onPressed: _submitSearch,
                      style: IconButton.styleFrom(
                        backgroundColor: _red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(52, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.search, size: 25),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${guides.length} ${guides.length == 1 ? 'GUIDE' : 'GUIDES'}',
                        style: const TextStyle(
                          color: Color(0xFF7B889A),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .6,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Filter guides',
                      initialValue: _category,
                      onSelected: (value) => setState(() => _category = value),
                      itemBuilder: (_) => [
                        for (final category in categories)
                          CheckedPopupMenuItem(
                            value: category,
                            checked: category == _category,
                            child: Text(category),
                          ),
                      ],
                      icon: Icon(
                        Icons.filter_list,
                        color: _category == 'All' ? _muted : _red,
                        size: 21,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (guides.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'No guides found',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Try another search or clear the selected filters.',
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Clear search & filters'),
                        ),
                      ],
                    ),
                  ),
                for (var i = 0; i < guides.length; i++)
                  _guideCard(
                    guides[i],
                    initiallyExpanded:
                        i == 0 && _query.isEmpty && _category == 'All',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FirstAidDetailScreen extends StatelessWidget {
  const FirstAidDetailScreen({super.key, required this.guide});
  final FirstAidGuide guide;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(guide.title)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_outlined, size: 48, color: Color(0xFFE92B32)),
                SizedBox(height: 8),
                Text('Instruction image'),
                Text('Reserved for a reviewed visual guide'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            guide.category.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFE92B32),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Follow emergency professionals whenever available.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          for (final section in guide.details.split('\n\n'))
            _InstructionSection(section: section),
        ],
      ),
    ),
  );
}

class _InstructionSection extends StatelessWidget {
  const _InstructionSection({required this.section});
  final String section;
  @override
  Widget build(BuildContext context) {
    final lines = section.split('\n');
    final expandable = lines.first == 'What if only 1 puff is available?';
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lines.first, style: Theme.of(context).textTheme.titleMedium),
        for (final line in lines.skip(1))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(line, style: const TextStyle(height: 1.45)),
          ),
      ],
    );
    return Card(
      child: expandable
          ? ExpansionTile(
              title: Text(lines.first),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [body],
            )
          : Padding(padding: const EdgeInsets.all(16), child: body),
    );
  }
}
