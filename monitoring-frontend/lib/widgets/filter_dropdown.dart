import 'package:flutter/material.dart';

class FilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final void Function(String?) onChanged;
  final bool showAllOption;

  const FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.showAllOption = true,
  });

  @override
  Widget build(BuildContext context) {
    final dropdownItems = <DropdownMenuItem<String>>[];

    if (showAllOption) {
      dropdownItems.add(
        DropdownMenuItem<String>(
          value: null,
          child: Text('All $label', style: const TextStyle(fontSize: 13)),
        ),
      );
    }

    dropdownItems.addAll(
      items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item, style: const TextStyle(fontSize: 13)),
          )),
    );

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          icon: Icon(Icons.keyboard_arrow_down,
              size: 18, color: Colors.grey[600]),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          isDense: true,
          items: dropdownItems,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
