import 'package:resqme/features/public_support/domain/first_aid_models.dart';

enum FirstAidSortOrder { logical, alphabetical }

/// Deterministic offline search and filtering engine for First Aid procedures.
///
/// Never infers or diagnoses clinical conditions; ranks canonical topics by
/// transparent lexical match priority:
/// 1. Exact title / shortTitle match
/// 2. Title / shortTitle prefix match
/// 3. Whole-word title match
/// 4. Exact keyword / Filipino synonym match
/// 5. Keyword prefix / token match
/// 6. Title or keyword substring match
/// 7. Category, recognition sign, or overview token match
class FirstAidSearchEngine {
  const FirstAidSearchEngine._();

  static final RegExp _nonAlnum = RegExp(r'[^a-z0-9\s]+');
  static final RegExp _multiSpace = RegExp(r'\s+');

  static String normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(_nonAlnum, ' ')
        .replaceAll(_multiSpace, ' ')
        .trim();
  }

  static List<FirstAidTopic> search(
    List<FirstAidTopic> topics, {
    String query = '',
    String category = 'All',
    FirstAidSortOrder sortOrder = FirstAidSortOrder.logical,
  }) {
    final categoryFiltered = category == 'All'
        ? topics
        : topics.where((t) => t.category == category).toList(growable: false);

    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty) {
      final copy = List<FirstAidTopic>.of(categoryFiltered);
      if (sortOrder == FirstAidSortOrder.alphabetical) {
        copy.sort((a, b) => a.title.compareTo(b.title));
      } else {
        copy.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      }
      return copy;
    }

    final queryTokens = normalizedQuery.split(' ');
    final scored = <({FirstAidTopic topic, int score})>[];

    for (final topic in categoryFiltered) {
      final score = _scoreTopic(topic, normalizedQuery, queryTokens);
      if (score > 0) {
        scored.add((topic: topic, score: score));
      }
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      if (sortOrder == FirstAidSortOrder.alphabetical) {
        return a.topic.title.compareTo(b.topic.title);
      }
      return a.topic.displayOrder.compareTo(b.topic.displayOrder);
    });

    return [for (final entry in scored) entry.topic];
  }

  static int _scoreTopic(
    FirstAidTopic topic,
    String normalizedQuery,
    List<String> queryTokens,
  ) {
    final normTitle = normalize(topic.title);
    final normShort = normalize(topic.shortTitle);
    final titleWords = <String>{
      ...normTitle.split(' '),
      ...normShort.split(' '),
    };

    final urgencyTieBoost =
        (topic.isCriticalEmergency ? 12 : 0) + (topic.isCommonEmergency ? 6 : 0);

    // Tier 1: Exact title or shortTitle
    if (normTitle == normalizedQuery || normShort == normalizedQuery) {
      return 1000 + urgencyTieBoost;
    }

    // Tier 2: Title or shortTitle starts with query
    if (normTitle.startsWith('$normalizedQuery ') ||
        normShort.startsWith('$normalizedQuery ') ||
        normTitle.startsWith(normalizedQuery) ||
        normShort.startsWith(normalizedQuery)) {
      final exactWordPrefix =
          normTitle.startsWith('$normalizedQuery ') ||
          normShort.startsWith('$normalizedQuery ');
      return (exactWordPrefix ? 880 : 840) + urgencyTieBoost;
    }

    // Tier 3: Every query token matches an exact word in title/shortTitle
    if (queryTokens.every(titleWords.contains)) {
      return 780 + urgencyTieBoost;
    }

    final normKeywords = [for (final kw in topic.searchKeywords) normalize(kw)];

    // Tier 4: Exact match on any searchKeyword / Filipino synonym
    if (normKeywords.contains(normalizedQuery)) {
      return 700 + urgencyTieBoost;
    }

    // Tier 5: Keyword starts with query or all query tokens match words/prefixes in a keyword or title
    for (final kw in normKeywords) {
      if (kw.startsWith('$normalizedQuery ') || kw.startsWith(normalizedQuery)) {
        return 600 + urgencyTieBoost;
      }
      final kwWords = kw.split(' ');
      if (queryTokens.every(
        (qt) => kwWords.any((w) => w.startsWith(qt)),
      )) {
        return 560 + urgencyTieBoost;
      }
    }

    if (queryTokens.every(
      (qt) => titleWords.any((w) => w.startsWith(qt)),
    )) {
      return 540 + urgencyTieBoost;
    }

    // Tier 6: Substring in title or searchKeywords
    if (normTitle.contains(normalizedQuery) ||
        normKeywords.any((kw) => kw.contains(normalizedQuery))) {
      return 430 + urgencyTieBoost;
    }

    // Tier 7: Multi-field token match across category, recognitionSigns, immediateAction, overview
    final corpus = normalize([
      topic.title,
      topic.shortTitle,
      topic.category,
      ...topic.searchKeywords,
      topic.quickInstructions.immediateAction,
      ...topic.quickInstructions.recognitionSigns,
      topic.learnMore.overview,
    ].join(' '));

    final corpusWords = corpus.split(' ');
    if (queryTokens.every((qt) => corpusWords.any((w) => w.startsWith(qt)))) {
      return 280 + urgencyTieBoost;
    }

    return 0;
  }
}
