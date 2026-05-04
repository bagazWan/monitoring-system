import 'package:flutter/material.dart';
import 'search_bar.dart';

class TableActionHeader extends StatelessWidget {
  final TextEditingController searchController;
  final String searchHint;
  final String buttonLabel;
  final IconData buttonIcon;
  final VoidCallback onButtonPressed;
  final List<Widget>? additionalActions;

  const TableActionHeader({
    super.key,
    required this.searchController,
    required this.searchHint,
    required this.buttonLabel,
    required this.buttonIcon,
    required this.onButtonPressed,
    this.additionalActions,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SearchBarWidget(
            controller: searchController,
            hintText: searchHint,
          ),
        ),
        const SizedBox(width: 16),
        if (additionalActions != null) ...[
          ...additionalActions!.map((w) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: w,
              )),
        ],
        SizedBox(
          height: 40,
          child: ElevatedButton.icon(
            onPressed: onButtonPressed,
            icon: Icon(buttonIcon),
            label: Text(buttonLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }
}
