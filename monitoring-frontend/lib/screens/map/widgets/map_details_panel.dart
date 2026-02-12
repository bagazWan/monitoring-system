import 'package:flutter/material.dart';
import '../../../models/device.dart';
import '../../../models/location.dart';
import 'location_details_content.dart';

class MapDetailsPanel extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onClose;
  final Location? location;
  final List<BaseNode> nodesAtLocation;

  const MapDetailsPanel({
    super.key,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onClose,
    required this.location,
    required this.nodesAtLocation,
  });

  static void showBottomSheet(
    BuildContext context, {
    required Location location,
    required List<BaseNode> nodesAtLocation,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: LocationDetailsContent(
          location: location,
          nodesAtLocation: nodesAtLocation,
          isSheet: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double expandedWidth = 300;
    const double collapsedWidth = 60;

    const iconConstraints = BoxConstraints.tightFor(width: 36, height: 36);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: expanded ? expandedWidth : collapsedWidth,
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(left: 4, right: 4),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: "Collapse",
                          onPressed: onToggleExpanded,
                          constraints: iconConstraints,
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.chevron_right),
                        ),
                        const Expanded(
                          child: Text(
                            "Details",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: "Close",
                          onPressed: onClose,
                          constraints: iconConstraints,
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: IconButton(
                      tooltip: "Expand",
                      onPressed: onToggleExpanded,
                      constraints: iconConstraints,
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.chevron_left),
                    ),
                  ),
          ),
          Expanded(
            child: !expanded
                ? const SizedBox.shrink()
                : (location == null
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text("Tap a marker to see location details."),
                        ),
                      )
                    : LocationDetailsContent(
                        location: location!,
                        nodesAtLocation: nodesAtLocation,
                      )),
          ),
        ],
      ),
    );
  }
}
