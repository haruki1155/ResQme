import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:resqme/features/public_support/data/first_aid_local_file_stub.dart'
    if (dart.library.io) 'package:resqme/features/public_support/data/first_aid_local_file_io.dart';
import 'package:resqme/features/public_support/domain/first_aid_models.dart';
import 'package:resqme/features/public_support/domain/first_aid_release_policy.dart';

class FirstAidRepository {
  FirstAidRepository({
    AssetBundle? assetBundle,
    this.assetPath = defaultAssetPath,
  }) : _assetBundle = assetBundle ?? rootBundle;

  static const String defaultAssetPath = 'assets/data/first_aid_library.json';

  static final Map<String, Map<String, dynamic>> _decodedJsonCache =
      <String, Map<String, dynamic>>{};

  final AssetBundle _assetBundle;
  final String assetPath;

  static void clearCache() => _decodedJsonCache.clear();

  /// Returns the parsed bundle synchronously if already cached in memory (or
  /// directly readable from workspace assets during `flutter test`), avoiding
  /// any loading flash or FakeAsync asset-channel deadlock.
  FirstAidLibraryBundle? tryLoadLibrarySync({FirstAidReleasePolicy? policy}) {
    final effectivePolicy = policy ?? FirstAidReleasePolicy.fromEnvironment();
    if (!identical(_assetBundle, rootBundle)) {
      return null;
    }
    final cacheKey = '${identityHashCode(_assetBundle)}::$assetPath';
    var decoded = _decodedJsonCache[cacheKey];
    if (decoded == null) {
      final rawSync = tryReadLocalAssetFileSync(assetPath);
      if (rawSync == null) return null;
      try {
        final parsed = jsonDecode(rawSync);
        if (parsed is! Map) return null;
        decoded = Map<String, dynamic>.from(parsed);
        _decodedJsonCache[cacheKey] = decoded;
      } catch (_) {
        return null;
      }
    }
    try {
      return parseLibraryMap(decoded, policy: effectivePolicy);
    } catch (error) {
      return _errorBundle(error);
    }
  }

  Future<FirstAidLibraryBundle> loadLibrary({
    FirstAidReleasePolicy? policy,
  }) {
    final effectivePolicy = policy ?? FirstAidReleasePolicy.fromEnvironment();
    final syncResult = tryLoadLibrarySync(policy: effectivePolicy);
    if (syncResult != null) {
      return SynchronousFuture<FirstAidLibraryBundle>(syncResult);
    }
    return _loadLibraryAsync(effectivePolicy);
  }

  Future<FirstAidLibraryBundle> _loadLibraryAsync(
    FirstAidReleasePolicy effectivePolicy,
  ) async {
    try {
      final cacheKey = '${identityHashCode(_assetBundle)}::$assetPath';
      var decoded = _decodedJsonCache[cacheKey];
      if (decoded == null) {
        final rawJson = await _assetBundle.loadString(assetPath);
        final parsed = jsonDecode(rawJson);
        if (parsed is! Map) {
          throw const FormatException('Root JSON must be an object');
        }
        decoded = Map<String, dynamic>.from(parsed);
        if (identical(_assetBundle, rootBundle)) {
          _decodedJsonCache[cacheKey] = decoded;
        }
      }
      return parseLibraryMap(decoded, policy: effectivePolicy);
    } catch (error) {
      return _errorBundle(error);
    }
  }

  static FirstAidLibraryBundle _errorBundle(Object error) {
    return FirstAidLibraryBundle(
      schemaVersion: '1.0.0',
      contentVersion: 'unavailable',
      governingPrinciple: 'Act first. Learn more when needed.',
      nonEndorsementNotice:
          'Adapted from the IFRC International First Aid, Resuscitation and Education Guidelines 2025. Not endorsed or certified by the IFRC.',
      medicalDisclaimer:
          'First-aid instructions do not replace emergency medical care. Call 911 in a life-threatening emergency.',
      primarySource: const FirstAidPrimarySource(
        title:
            'International first aid, resuscitation and education guidelines 2025',
        organization: 'IFRC',
        edition: '2025',
        publicationYear: 2025,
        url:
            'https://www.ifrc.org/document/ifrc-international-first-aid-resuscitation-and-education-guidelines-2025',
        sha256: '',
      ),
      categories: const <String>[],
      topics: const <FirstAidTopic>[],
      loadError:
          'Offline first-aid reference library could not be loaded ($error). Use Call 911 or Emergency Hotlines immediately if someone is in danger.',
    );
  }

  static FirstAidLibraryBundle parseLibraryMap(
    Map<String, dynamic> decoded, {
    required FirstAidReleasePolicy policy,
  }) {
    final rawTopics = decoded['topics'];
    if (rawTopics is! List) {
      throw const FormatException('Missing topics array');
    }

    final seenIds = <String>{};
    final allTopics = <FirstAidTopic>[];
    for (final rawItem in rawTopics) {
      if (rawItem is! Map) {
        throw const FormatException('Topic entry must be an object');
      }
      final topic = FirstAidTopic.fromJson(Map<String, dynamic>.from(rawItem));
      if (!seenIds.add(topic.id)) {
        throw FormatException('Duplicate topic id: ${topic.id}');
      }
      allTopics.add(topic);
    }

    final allowedTopics = <FirstAidTopic>[];
    var excludedPending = 0;
    for (final topic in allTopics) {
      if (policy.allowsTopic(topic)) {
        allowedTopics.add(topic);
      } else {
        excludedPending++;
      }
    }

    final allowedIds = {for (final t in allowedTopics) t.id};
    final rawCategories = decoded['categories'];
    final declaredCategories = rawCategories is List
        ? rawCategories
              .map((c) => c.toString().trim())
              .where((c) => c.isNotEmpty)
              .toList()
        : <String>[];
    final activeCategories = declaredCategories
        .where((cat) => allowedTopics.any((t) => t.category == cat))
        .toList(growable: false);

    final sanitizedTopics = allowedTopics
        .map(
          (t) => FirstAidTopic(
            id: t.id,
            displayOrder: t.displayOrder,
            title: t.title,
            shortTitle: t.shortTitle,
            category: t.category,
            classification: t.classification,
            urgency: t.urgency,
            ageGroup: t.ageGroup,
            audience: t.audience,
            isCommonEmergency: t.isCommonEmergency,
            requiresEmergencyCall: t.requiresEmergencyCall,
            iconName: t.iconName,
            searchKeywords: t.searchKeywords,
            quickInstructions: t.quickInstructions,
            learnMore: t.learnMore,
            relatedTopics: t.relatedTopics
                .where(allowedIds.contains)
                .toList(growable: false),
            source: t.source,
            contentVersion: t.contentVersion,
            review: t.review,
          ),
        )
        .toList(growable: false);

    return FirstAidLibraryBundle(
      schemaVersion: (decoded['schemaVersion'] as String?)?.trim() ?? '1.0.0',
      contentVersion:
          (decoded['contentVersion'] as String?)?.trim() ?? '2025.1',
      governingPrinciple:
          (decoded['governingPrinciple'] as String?)?.trim() ??
          'Act first. Learn more when needed.',
      nonEndorsementNotice:
          (decoded['nonEndorsementNotice'] as String?)?.trim() ?? '',
      medicalDisclaimer:
          (decoded['medicalDisclaimer'] as String?)?.trim() ?? '',
      primarySource: FirstAidPrimarySource.fromJson(
        Map<String, dynamic>.from(
          (decoded['primarySource'] as Map?) ?? const <String, dynamic>{},
        ),
      ),
      categories: activeCategories,
      topics: sanitizedTopics,
      excludedPendingApprovalCount: excludedPending,
    );
  }
}
