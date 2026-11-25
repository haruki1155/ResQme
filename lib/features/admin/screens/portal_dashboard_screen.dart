import 'package:flutter/material.dart';
import '../services/portal_student_repository.dart';
import '../services/staff_access_repository.dart';
import '../widgets/portal_widgets.dart';

class PortalDashboardScreen extends StatefulWidget {
  const PortalDashboardScreen({
    super.key,
    required this.access,
    required this.onScanStudentQr,
    this.onOpenLostQrManagement,
    this.portalStudentRepository,
  });

  final StaffAccess access;
  final VoidCallback? onScanStudentQr;
  final VoidCallback? onOpenLostQrManagement;
  final PortalStudentRepository? portalStudentRepository;

  @override
  State<PortalDashboardScreen> createState() => _PortalDashboardScreenState();
}

class _PortalDashboardScreenState extends State<PortalDashboardScreen> {
  PortalDashboardStats? _stats;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.portalStudentRepository != null) {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    final repo = widget.portalStudentRepository;
    if (repo == null || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await repo.loadDashboardStats();
      if (!mounted) return;
      setState(() => _stats = stats);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is PortalStudentException
            ? error.message
            : 'Unable to load school dashboard statistics.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = widget.access;
    final stats = _stats;

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              PortalSectionHeader(
                title: 'School Administration',
                subtitle:
                    'Assigned school: ${access.schoolId}${access.fullName != null ? ' • ${access.fullName}' : ''}',
                trailing: widget.portalStudentRepository != null
                    ? IconButton(
                        tooltip: 'Refresh statistics',
                        onPressed: _loading ? null : _loadStats,
                        icon: const Icon(Icons.refresh),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              // Prominent Emergency QR Scan Card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(
                    color: PortalColors.brandRed,
                    width: 1.2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.emergency_outlined,
                            color: PortalColors.brandRed,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Emergency Tier 2 Response',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: PortalColors.inkPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Scan a verified student QR credential using your enrolled biometric staff device.',
                        style: TextStyle(
                          fontSize: 13,
                          color: PortalColors.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: widget.onScanStudentQr,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan Student QR'),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.onOpenLostQrManagement != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: PortalColors.brandRedSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.qr_code_2_outlined,
                            color: PortalColors.brandRed,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lost QR Management',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: PortalColors.inkPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Replace lost, damaged, or compromised student QR codes.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: PortalColors.inkSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: widget.onOpenLostQrManagement,
                          child: const Text('Open'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (_loading && stats == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null && stats == null)
                PortalStateView(
                  icon: Icons.error_outline,
                  title: 'Statistics Unavailable',
                  message: _error!,
                  onRetry: _loadStats,
                )
              else if (stats != null) ...[
                const Text(
                  'Official School Roster Baseline',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: PortalColors.inkPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Imported official school records are tracked separately from student app accounts.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: PortalColors.inkSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                PortalStatCard(
                  label: 'Imported Roster Students',
                  value: stats.rosterAvailable
                      ? '${stats.importedRosterCount}'
                      : 'None on file',
                  caption: stats.rosterAvailable
                      ? 'Official school roster records available for LRN matching'
                      : 'No official school roster imported yet • Manual verification active',
                  icon: Icons.fact_check_outlined,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Registered Student Accounts & Staff',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: PortalColors.inkPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final cardWidth = (constraints.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: PortalStatCard(
                            label: 'Registered Accounts',
                            value: '${stats.registeredStudentsCount}',
                            caption: 'Total student app accounts',
                            icon: Icons.people_outline,
                            accentRed: true,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: PortalStatCard(
                            label: 'Verified Students',
                            value: '${stats.verifiedStudentsCount}',
                            caption: 'Approved school verification',
                            icon: Icons.verified_user_outlined,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: PortalStatCard(
                            label: 'Disabled Students',
                            value: '${stats.disabledStudentsCount}',
                            caption: 'Administratively disabled',
                            icon: Icons.person_off_outlined,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: PortalStatCard(
                            label: 'Active Personnel',
                            value: '${stats.authorizedPersonnelCount}',
                            caption: 'Authorized staff accounts',
                            icon: Icons.badge_outlined,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
