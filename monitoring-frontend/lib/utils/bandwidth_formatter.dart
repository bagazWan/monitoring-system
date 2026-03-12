class BandwidthFormatter {
  static String format(double mbps, {int mbpsDecimals = 2, int gbpsDecimals = 2}) {
    if (mbps >= 1000) {
      final gbps = mbps/1000;
      return "${gbps.toStringAsFixed(gbpsDecimals)} Gbps";
    }

    if (mbps < 1) {
      final kbps = mbps * 1000;
      return "${kbps.toStringAsFixed(0)} Kbps";
    }
    return "${mbps.toStringAsFixed(mbpsDecimals)} Mbps";
  }

  // Return numeric value + unit for chart axis/tooltip.
  static Map<String, dynamic> formatParts(double mbps,
      {int mbpsDecimals = 1, int kbpsDecimals = 0, int gbpsDecimals = 1}) {
    if (mbps >= 1000) {
      return {
        "value": (mbps / 1000).toStringAsFixed(gbpsDecimals),
        "unit":"Gbps"
      };
    }

    if (mbps < 1) {
      return {
        "value": (mbps * 1000).toStringAsFixed(kbpsDecimals),
        "unit": "Kbps"
      };
    }
    return {"value": mbps.toStringAsFixed(mbpsDecimals), "unit": "Mbps"};
  }
}
