import 'package:flutter/material.dart';
import '../../../../domain/care/care_report.dart';

class ReportFeedbackDialog extends StatefulWidget {
  const ReportFeedbackDialog({
    super.key,
    required this.report,
    required this.initialValue,
    required this.onDraft,
  });
  final CareReport report;
  final String initialValue;
  final ValueChanged<String> onDraft;
  @override
  State<ReportFeedbackDialog> createState() => _ReportFeedbackDialogState();
}

class _ReportFeedbackDialogState extends State<ReportFeedbackDialog> {
  late final text = TextEditingController(text: widget.initialValue);
  String? error;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Suggest changes'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.report.date} · Report version ${widget.report.version}'),
            const SizedBox(height: 14),
            const Text('Identify the answer or summary that needs to change and explain your feedback.'),
            const SizedBox(height: 16),
            TextField(
              controller: text,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              maxLength: 3000,
              decoration: InputDecoration(labelText: 'Specific feedback', errorText: error),
              onChanged: (value) {
                widget.onDraft(value);
                if (error != null) setState(() => error = null);
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (text.text.trim().runes.length < 5) {
            setState(() => error = 'Enter at least 5 characters of specific feedback.');
            return;
          }
          Navigator.pop(context, text.text.trim());
        },
        child: const Text('Submit feedback'),
      ),
    ],
  );
}
