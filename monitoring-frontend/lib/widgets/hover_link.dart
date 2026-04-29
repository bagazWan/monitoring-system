import 'package:flutter/material.dart';

class HoverLink extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final IconData? icon;

  const HoverLink(
      {super.key, required this.text, required this.onTap, this.icon});

  @override
  State<HoverLink> createState() => _HoverLinkState();
}

class _HoverLinkState extends State<HoverLink> {
  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: widget.onTap,
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.hovered)) {
            return Colors.blue[900]!;
          }
          return Colors.blueAccent;
        }),
        textStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          return TextStyle(
            fontWeight: FontWeight.bold,
            decoration: states.contains(WidgetState.hovered)
                ? TextDecoration.underline
                : TextDecoration.none,
          );
        }),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.text),
          if (widget.icon != null) ...[
            const SizedBox(width: 4),
            Icon(widget.icon, size: 16),
          ],
        ],
      ),
    );
  }
}
