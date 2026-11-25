/// Centralized developer-controlled feature configuration for the IFRC 2025
/// First Aid Instructions and Learning Library expansion.
///
/// Default is `false` while awaiting IFRC content reuse clarification and
/// qualified human clinical sign-off. Ordinary users cannot toggle this flag.
abstract final class FirstAidFeatureFlags {
  static const bool enableExpandedFirstAid = false;
}
