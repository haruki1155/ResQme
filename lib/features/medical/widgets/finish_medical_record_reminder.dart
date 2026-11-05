import 'package:flutter/material.dart';

class FinishMedicalRecordReminder extends StatelessWidget {
  const FinishMedicalRecordReminder({
    super.key,
    required this.completed,
    required this.onOpen,
    required this.onDismiss,
  });
  final bool completed;
  final VoidCallback onOpen, onDismiss;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            completed
                ? 'Private synthetic test record'
                : 'Finish Medical Record',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'Optional. Fictional test data only; not for emergency response.',
          ),
          TextButton(
            onPressed: onOpen,
            child: Text(
              completed ? 'View/Update Medical Record' : 'Finish now',
            ),
          ),
          if (!completed)
            TextButton(onPressed: onDismiss, child: const Text('Later')),
        ],
      ),
    ),
  );
}
