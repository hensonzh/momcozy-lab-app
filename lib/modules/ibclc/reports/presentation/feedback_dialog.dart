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
    title: const Text('反馈修改'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.report.date} · 报告第 ${widget.report.version} 版'),
            const SizedBox(height: 14),
            const Text('请指出需要修改的回答或摘要，并说明具体意见。'),
            const SizedBox(height: 16),
            TextField(
              controller: text,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              maxLength: 3000,
              decoration: InputDecoration(labelText: '具体意见', errorText: error),
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
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (text.text.trim().runes.length < 5) {
            setState(() => error = '请填写至少 5 个字的具体意见。');
            return;
          }
          Navigator.pop(context, text.text.trim());
        },
        child: const Text('提交反馈'),
      ),
    ],
  );
}
