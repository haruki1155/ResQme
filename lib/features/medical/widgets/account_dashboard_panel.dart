import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/app_routes.dart';
import '../../registration/services/student_registration_repository.dart';
import '../services/synthetic_medical_repository.dart';
import 'finish_medical_record_reminder.dart';

class AccountDashboardPanel extends StatefulWidget {
  const AccountDashboardPanel({
    super.key,
    required this.registration,
    required this.medical,
    this.authChanges,
  });
  final StudentRegistrationRepository registration;
  final SyntheticMedicalRepository medical;
  final Stream<void>? authChanges;
  @override
  State<AccountDashboardPanel> createState() => _AccountDashboardPanelState();
}

class _AccountDashboardPanelState extends State<AccountDashboardPanel> {
  StreamSubscription<void>? subscription;
  MedicalSnapshot? snapshot;
  bool unavailable = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    subscription = widget.authChanges?.listen((_) => load());
    load();
  }

  @override
  void dispose() {
    generation++;
    subscription?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    final run = ++generation;
    setState(() {
      snapshot = null;
      unavailable = false;
    });
    widget.medical.syncSession();
    if (widget.medical.client.uid == null) return;
    try {
      final account = await widget.registration.loadOwnProfile();
      if (account.state != RegistrationState.pending) {
        throw StateError('Registration unavailable.');
      }
      final result = await widget.medical.loadMine();
      if (mounted && generation == run) {
        setState(() => snapshot = result);
      }
    } catch (_) {
      if (mounted && generation == run) {
        setState(() => unavailable = true);
      }
    }
  }

  Future<void> openAccount({bool medical = false}) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.profile,
      arguments: medical ? 'medical' : null,
    );
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 16),
      const Text(
        'TEST MODE — Synthetic pilot only',
        style: TextStyle(color: Color(0xFFE92B32), fontWeight: FontWeight.w700),
      ),
      OutlinedButton(
        onPressed: openAccount,
        child: Text(
          widget.medical.client.uid == null
              ? 'Student Account — Sign in / Register'
              : 'My Account / My QR',
        ),
      ),
      if (unavailable)
        TextButton(
          onPressed: load,
          child: const Text('Account state unavailable — retry'),
        ),
      if (snapshot != null &&
          (snapshot!.completed || !widget.medical.reminderSnoozed))
        FinishMedicalRecordReminder(
          completed: snapshot!.completed,
          onOpen: () => openAccount(medical: true),
          onDismiss: () {
            setState(widget.medical.snoozeReminder);
          },
        ),
    ],
  );
}
