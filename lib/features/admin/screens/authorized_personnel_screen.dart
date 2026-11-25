import 'package:flutter/material.dart';
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
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.managementRepository
          .listAccounts(search: _search.text);
      if (!mounted) return;
      setState(() => _accounts = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to load Authorized personnel.');
    } finally {
      if (mounted) setState(() => _loading = false);
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
                      onPressed: _loading ? null : _load,
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
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: PortalColors.alertFg),
                  ),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _accounts.isEmpty
                        ? const PortalStateView(
                            icon: Icons.badge_outlined,
                            title: 'No Authorized Personnel Found',
                            message:
                                'Create school-scoped Authorized accounts for clinic or DRRM staff.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
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
                                  contentPadding: const EdgeInsets.symmetric(
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
                                    await _load();
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
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CreateAuthorizedAccountScreen(
              managementRepository: widget.managementRepository,
            ),
          ),
        );
        await _load();
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
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
      floatingActionButton: fab,
      body: content,
    );
  }
}
