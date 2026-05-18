import 'package:flutter/material.dart';

class MapSummaryBox extends StatefulWidget {
  final int totalDevices;
  final int totalOnline;
  final int totalOffline;
  final Map<String, Map<String, int>> typeStats;

  const MapSummaryBox({
    super.key,
    required this.totalDevices,
    required this.totalOnline,
    required this.totalOffline,
    required this.typeStats,
  });

  @override
  State<MapSummaryBox> createState() => _MapSummaryBoxState();
}

class _MapSummaryBoxState extends State<MapSummaryBox> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Positioned(
      top: 16.0,
      left: 16.0,
      child: GestureDetector(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: Container(
          width: _isExpanded ? 320 : null,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_isExpanded ? 8 : 24),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
            ],
          ),
          child: _isExpanded ? _buildExpanded(screenHeight) : _buildCollapsed(),
        ),
      ),
    );
  }

  Widget _buildExpanded(double screenHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.all(12.0),
          child: Text("Status Perangkat",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: Text("Perangkat",
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  Text("Status", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                constraints: BoxConstraints(
                  maxHeight: screenHeight * 0.4,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: widget.typeStats.entries.map((entry) {
                      final typeName = entry.key;
                      final stats = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(typeName,
                                  style: const TextStyle(fontSize: 14)),
                            ),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                    color: Colors.black87, fontSize: 14),
                                children: [
                                  TextSpan(text: "${stats['online']} "),
                                  const TextSpan(
                                      text: "Online",
                                      style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600)),
                                  const TextSpan(text: " / "),
                                  TextSpan(text: "${stats['offline']} "),
                                  const TextSpan(
                                      text: "Offline",
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Total ${widget.totalDevices} Perangkat :",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                      "${widget.totalOnline} Online | ${widget.totalOffline} Offline",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsed() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bar_chart, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 8),
          Text("Total: ${widget.totalDevices}",
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: Colors.green, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text("${widget.totalOnline}"),
          const SizedBox(width: 12),
          Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: Colors.grey, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text("${widget.totalOffline}"),
        ],
      ),
    );
  }
}
