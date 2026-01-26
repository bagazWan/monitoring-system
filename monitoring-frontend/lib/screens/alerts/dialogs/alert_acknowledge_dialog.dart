import 'package:flutter/material.dart';
import '../../../models/alert.dart';
import '../../../services/alert_service.dart';

class AlertAcknowledgeDialog extends StatefulWidget {
  final Alert alert;
  const AlertAcknowledgeDialog({super.key, required this.alert});

  @override
  State<AlertAcknowledgeDialog> createState() => _AlertAcknowledgeDialogState();
}

class _AlertAcknowledgeDialogState extends State<AlertAcknowledgeDialog> {
  late final TextEditingController _noteController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _noteController =
        TextEditingController(text: widget.alert.resolutionNote ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AlertService()
          .acknowledgeAlert(widget.alert.alertId, _noteController.text);

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Note saved"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAcked = widget.alert.assignedToUserId != null ||
        widget.alert.acknowledgedAt != null;

    return AlertDialog(
      title: Text(isAcked ? "Update Note" : "Acknowledge"),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Resolution Note:",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 4,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Text(
              "Alert message (LibreNMS):\n${widget.alert.message}",
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text("Save"),
        ),
      ],
    );
  }
}
