import 'package:flutter/material.dart';
import '../services/staff_access_repository.dart';
import '../services/staff_management_repository.dart';
import 'authorized_account_details_screen.dart';
import 'create_authorized_account_screen.dart';

class AuthorizedPersonnelScreen extends StatefulWidget {
  const AuthorizedPersonnelScreen({
    super.key,
    required this.accessRepository,
    required this.managementRepository,
  });

  final StaffAccessRepository accessRepository;
  final StaffManagementRepository managementRepository;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Authorized Personnel'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _search,
                    onSubmitted: (_) => _load(),
                    decoration: InputDecoration(
                      labelText: 'Search by name, position, or Login ID',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: 'Search',
                        onPressed: _load,
                        icon: const Icon(Icons.search),
                      ),
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _accounts.isEmpty
                          ? const Center(
                              child: Text('No Authorized personnel found.'),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                              itemCount: _accounts.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (ctx, index) {
                                final acc = _accounts[index];
                                return Card(
                                  child: ListTile(
                                    title: Text(acc.fullName),
                                    subtitle: Text(
                                      '${acc.position} • ${acc.loginId}\nStatus: ${acc.status.toUpperCase()}${acc.mustChangePassword ? ' • Setup Pending' : ''}',
                                    ),
                                    isThreeLine: true,
                                    trailing: const Icon(Icons.chevron_right),
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
      ),
    );
  }
}
