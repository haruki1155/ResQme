import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/public_support/data/first_aid_repository.dart';
import 'package:resqme/features/public_support/domain/first_aid_models.dart';
import 'package:resqme/features/public_support/domain/first_aid_release_policy.dart';
import 'package:resqme/features/public_support/domain/first_aid_search_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<FirstAidTopic> topics;

  setUpAll(() async {
    final bundle = await FirstAidRepository().loadLibrary(
      policy: FirstAidReleasePolicy.clinicalReviewDraft,
    );
    topics = bundle.topics;
  });

  test('prioritizes exact title matches above keyword or partial matches', () {
    final burnsResults = FirstAidSearchEngine.search(topics, query: 'Burns');
    expect(burnsResults, isNotEmpty);
    expect(burnsResults.first.id, 'burns');

    final strokeResults = FirstAidSearchEngine.search(topics, query: 'Stroke');
    expect(strokeResults, isNotEmpty);
    expect(strokeResults.first.id, 'stroke');

    final shockResults = FirstAidSearchEngine.search(topics, query: 'Shock');
    expect(shockResults, isNotEmpty);
    expect(shockResults.first.id, 'shock');
  });

  test('matches required Filipino / Tagalog emergency synonyms accurately', () {
    final cases = <String, String>{
      'Nabulunan': 'choking-adult',
      'Hika': 'asthma-attack',
      'Paso': 'burns',
      'Pilay': 'sprains',
      'Balinguyngoy': 'nosebleeds',
      'Walang malay': 'unresponsive-normal-breathing',
      'Kagat ng aso': 'mammal-bites',
      'Nalunod': 'drowning',
      'Kombulsyon': 'seizures',
      'Lason': 'poisoning',
      'Atake sa puso': 'cardiac-chest-pain',
      'Heat stroke': 'heatstroke',
    };

    for (final entry in cases.entries) {
      final results = FirstAidSearchEngine.search(topics, query: entry.key);
      expect(
        results.map((t) => t.id),
        contains(entry.value),
        reason: 'Expected "${entry.key}" to match ${entry.value}',
      );
    }
  });

  test(
    'returns multiple age-specific procedures for choking and CPR without diagnosing',
    () {
      final choking = FirstAidSearchEngine.search(topics, query: 'choking');
      final chokingIds = choking.take(4).map((t) => t.id).toSet();
      expect(
        chokingIds,
        containsAll(['choking-adult', 'choking-child', 'choking-infant']),
      );

      final cpr = FirstAidSearchEngine.search(topics, query: 'CPR');
      final cprIds = cpr.take(5).map((t) => t.id).toSet();
      expect(cprIds, containsAll(['cpr-adult', 'cpr-child', 'cpr-infant']));
    },
  );

  test('supports legacy ResQMe search terms (hyperventilation, moving injured)', () {
    final hyper = FirstAidSearchEngine.search(
      topics,
      query: 'hyperventilation',
    );
    expect(
      hyper.map((t) => t.id),
      containsAll(['anxiety-and-panic', 'breathing-difficulties']),
    );

    final moving = FirstAidSearchEngine.search(
      topics,
      query: 'moving an injured person',
    );
    expect(moving.map((t) => t.id), contains('scene-safety'));
  });

  test('combines category filter, alphabetical sort, and <300 ms latency target', () {
    final traumaAlpha = FirstAidSearchEngine.search(
      topics,
      category: 'Trauma & Injuries',
      sortOrder: FirstAidSortOrder.alphabetical,
    );
    expect(traumaAlpha.length, 21);
    expect(traumaAlpha.first.title.compareTo(traumaAlpha.last.title), lessThan(0));

    final sw = Stopwatch()..start();
    for (final q in const [
      'bleeding',
      'nabulunan',
      'chest pain',
      'unconscious',
      'epipen',
      'fever baby',
    ]) {
      final res = FirstAidSearchEngine.search(topics, query: q);
      expect(res, isNotEmpty);
    }
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(300));
  });
}
