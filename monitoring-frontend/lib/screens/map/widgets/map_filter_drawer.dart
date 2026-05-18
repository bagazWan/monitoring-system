import 'package:flutter/material.dart';

class MapFilterDrawer extends StatelessWidget {
  final Map<String, List<String>> filterHierarchy;
  final Set<String> hiddenLocations;
  final Function(String, bool, {bool isParent, String? parentName}) onToggle;
  final VoidCallback onReset;

  const MapFilterDrawer({
    super.key,
    required this.filterHierarchy,
    required this.hiddenLocations,
    required this.onToggle,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
        backgroundColor: const Color(0xFFF8F9FA),
        child: Column(children: [
          AppBar(
              title: const Text("Filter Lokasi",
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.bold)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                )
              ]),
          const Divider(height: 1),
          Expanded(
              child: ListView(
            padding: EdgeInsets.zero,
            children: filterHierarchy.entries.map((entry) {
              final parent = entry.key;
              final children = entry.value;

              if (children.isEmpty) {
                return CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(parent,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  value: !hiddenLocations.contains(parent),
                  onChanged: (val) =>
                      onToggle(parent, val ?? false, isParent: true),
                  contentPadding: const EdgeInsets.only(left: 8, right: 16),
                );
              }

              bool allSelected =
                  children.every((c) => !hiddenLocations.contains(c)) &&
                      !hiddenLocations.contains(parent);
              bool anySelected =
                  children.any((c) => !hiddenLocations.contains(c)) ||
                      !hiddenLocations.contains(parent);

              return Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.only(left: 8, right: 16),
                  leading: Checkbox(
                    value: allSelected ? true : (anySelected ? null : false),
                    tristate: true,
                    onChanged: (val) =>
                        onToggle(parent, val ?? false, isParent: true),
                  ),
                  title: Text(parent,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  children: children.map((child) {
                    return CheckboxListTile(
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(child,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      value: !hiddenLocations.contains(child),
                      contentPadding:
                          const EdgeInsets.only(left: 48, right: 16),
                      onChanged: (val) => onToggle(child, val ?? false,
                          isParent: false, parentName: parent),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          )),
          Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: onReset,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text("Reset Filter")),
              ))
        ]));
  }
}
