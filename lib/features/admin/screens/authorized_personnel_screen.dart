import 'package:flutter/material.dart';
import '../services/portal_read_coordinator.dart';
import '../services/staff_access_repository.dart';
import '../services/staff_management_repository.dart';
import '../widgets/portal_widgets.dart';
import 'authorized_account_details_screen.dart';
import 'create_authorized_account_screen.dart';

class AuthorizedPersonnelScreen extends StatefulWidget {
  const AuthorizedPersonnelScreen({
    super.key,
    required this.accessRepository,
    required this.managementRepository,
    this.embedded = false,
  });

  final StaffAccessRepository accessRepository;
  final StaffManagementRepository managementRepository;
  final bool embedded;

  @override
  State<AuthorizedPersonnelScreen> createState() =>
      _AuthorizedPersonnelScreenState();
}

class _AuthorizedPersonnelScreenState extends State<AuthorizedPersonnelScreen> {
  final _search = TextEditingController();
  List<AuthorizedAccountSummary> _accounts = const [];
  PortalLoadStatus _status = PortalLoadStatus.initialLoading;
  bool _hasLoadedOnce = false;
  int _requestSeq = 0;
  int? _lastObservedMutationVersion;
  String? _error;

  bool get _isInitialLoading =>
      !_hasLoadedOnce && _status == PortalLoadStatus.initialLoading;
  bool get _isRefreshing => _status == PortalLoadStatus.refreshing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final coordinator = PortalScope.maybeOf(context)?.notifier;
    if (coordinator != null) {
      if (!_hasLoadedOnce) {
        final cached = coordinator.peekCached<List<AuthorizedAccountSummary>>(
          'listAuthorizedAccounts:search=${_search.text.trim()}',
        );
        if (cached != null) {
          _hasLoadedOnce = true;
          _accounts = cached;
          _status =
              cached.isEmpty ? PortalLoadStatus.empty : PortalLoadStatus.loaded;
        }
      }
      final currentMutation = coordinator.mutationVersion;
      if (_lastObservedMutationVersion != null &&
          _lastObservedMutationVersion != currentMutation) {
        _lastObservedMutationVersion = currentMutation;
        _load();
      } else {
        _lastObservedMutationVersion = currentMutation;
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_requestSeq;
    final searchSnapshot = _search.text;
    setState(() {
      _status = _hasLoadedOnce
          ? PortalLoadStatus.refreshing
          : PortalLoadStatus.initialLoading;
      _error = null;
    });
    try {
      final list = await widget.managementRepository.listAccounts(
        search: searchSnapshot,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _hasLoadedOnce = true;
        _accounts = list;
        _error = null;
        _status =
            list.isEmpty ? PortalLoadStatus.empty : PortalLoadStatus.loaded;
      });
    } catch (error) {
      if (!mounted || seq != _requestSeq) return;
      if (PortalErrorClassifier.isSessionAuthorizationError(error)) {
        setState(() {
          _hasLoadedOnce = false;
          _accounts = const [];
          _status = PortalLoadStatus.authorizationError;
          _error = 'Session authorization expired. Sign in again.';
        });
        PortalScope.reportIfSessionAuthorizationLost(context, error);
        return;
      }
      setState(() {
        _status = PortalLoadStatus.transientError;
        _error = error is StaffManagementException
            ? error.message
            : 'Unable to load Authorized personnel.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            children: [
              if (widget.embedded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: PortalSectionHeader(
                    title: 'Authorized Personnel',
                    subtitle:
                        'Issue and manage school-scoped Authorized staff accounts and devices.',
                    trailing: IconButton(
                      tooltip: 'Refresh',
                      onPressed:
                          _isInitialLoading || _isRefreshing ? null : _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _search,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: 'Search by name, position, or Login ID',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: IconButton(
                      tooltip: 'Search',
                      onPressed: _load,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PortalRefreshStrip(refreshing: _isRefreshing),
                    if (_hasLoadedOnce && _error != null)
                      PortalInlineErrorBanner(
                        message: _error!,
                        onRetry: _load,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _isInitialLoading
                    ? const Center(child: CircularProgressIndicator())
                    : !_hasLoadedOnce && _error != null
                        ? PortalStateView(
                            icon: Icons.error_outline,
                            title: 'Authorized Personnel Unavailable',
                            message: _error!,
                            onRetry: _load,
                          )
                        : _accounts.isEmpty
                            ? const PortalStateView(
                                icon: Icons.badge_outlined,
                                title: 'No Authorized Personnel Found',
                                message:
                                    'Create school-scoped Authorized accounts for clinic or DRRM staff.',
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 88),
                                itemCount: _accounts.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (ctx, index) {
                                  final acc = _accounts[index];
                                  final tone = acc.isRevoked
                                      ? PortalBadgeTone.alert
                                      : acc.active
                                          ? PortalBadgeTone.verified
                                          : PortalBadgeTone.neutral;
                                  return Card(
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6,
                                      ),
                                      title: Text(
                                        acc.fullName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: PortalColors.inkPrimary,
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '${acc.position} • ${acc.loginId}${acc.mustChangePassword ? '\nPassword setup pending' : ''}',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: PortalColors.inkSecondary,
                                          ),
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          PortalStatusBadge(
                                            label: acc.status.toUpperCase(),
                                            tone: tone,
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.chevron_right,
                                            color: PortalColors.inkSecondary,
                                          ),
                                        ],
                                      ),
                                      onTap: () async {
                                        final scope = PortalScope.maybeOf(ctx);
                                        await Navigator.of(ctx).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                AuthorizedAccountDetailsScreen(
                                              account: acc,
                                              accessRepository:
                                                  widget.accessRepository,
                                              managementRepository:
                                                  widget.managementRepository,
                                            ),
                                          ),
                                        );
                                        if (scope?.notifier != null &&
                                            scope!.notifier!.activeScopeKey ==
                                                null) {
                                          return;
                                        }
                                        if (ctx.mounted) {
                                          PortalScope.notifyMutation(ctx);
                                        }
                                        if (mounted) {
                                          await _load();
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );

    final fab = FloatingActionButton.extended(
      backgroundColor: PortalColors.brandRed,
      foregroundColor: Colors.white,
      onPressed: () async {
        final scope = PortalScope.maybeOf(context);
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CreateAuthorizedAccountScreen(
              managementRepository: widget.managementRepository,
            ),
          ),
        );
        if (scope?.notifier != null &&
            scope!.notifier!.activeScopeKey == null) {
          return;
        }
        if (context.mounted) {
          PortalScope.notifyMutation(context);
        }
        if (mounted) {
          await _load();
        }
      },
      icon: const Icon(Icons.person_add_outlined),
      label: const Text('Create Account'),
    );

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Authorized Personnel'),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed:
                      _isInitialLoading || _isRefreshing ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
      floatingActionButton: fab,
      body: content,
    );
  }
}
