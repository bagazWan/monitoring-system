import 'package:flutter/material.dart';

class HoverLink extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const HoverLink({
    super.key,
    required this.text,
    required this.onTap,
  });

  @override
  State<HoverLink> createState() => _HoverLinkState();
}

class _HoverLinkState extends State<HoverLink> {
  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: widget.onTap,
      style: ButtonStyle(
        // Changes color on hover
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.hovered)) {
            return Colors.blue[900]!;
          }
          return Colors.blueAccent;
        }),
        // Adds underline on hover
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
      child: Text(widget.text),
    );
  }
}
