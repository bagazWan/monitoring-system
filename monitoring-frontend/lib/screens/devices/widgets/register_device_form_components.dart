part of '../register_device_screen.dart';

mixin RegisterDeviceFormComponents on State<RegisterDeviceScreen> {
  Widget buildResponsiveRow(
      {required bool isNarrow, required List<Widget> children}) {
    if (isNarrow) {
      return Column(
        children: children
            .map((c) =>
                Padding(padding: const EdgeInsets.only(bottom: 16), child: c))
            .toList(),
      );
    } else {
      List<Widget> rowChildren = [];
      for (int i = 0; i < children.length; i++) {
        rowChildren.add(Expanded(child: children[i]));
        if (i < children.length - 1) {
          rowChildren.add(const SizedBox(width: 16));
        }
      }
      return Row(
          crossAxisAlignment: CrossAxisAlignment.start, children: rowChildren);
    }
  }

  Widget buildNodeTypeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          const Text("Node Type:",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 24),
          _buildRadioChip("Device", "device"),
          const SizedBox(width: 12),
          _buildRadioChip("Switch", "switch"),
        ],
      ),
    );
  }

  Widget _buildRadioChip(String label, String val) {
    final state = this as _RegisterDeviceScreenState;
    final isSelected = state._nodeType == val;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => state._nodeType = val);
      },
      selectedColor: Colors.blue[50],
      labelStyle: TextStyle(
          color: isSelected ? Colors.blue[700] : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      backgroundColor: Colors.grey[50],
      side: BorderSide(color: isSelected ? Colors.blue : Colors.grey[300]!),
    );
  }

  Widget buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget buildFormCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget buildOptionCard() {
    final state = this as _RegisterDeviceScreenState;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: CheckboxListTile(
        title: const Text("Force Add"),
        subtitle: const Text("Skip ICMP check (for firewalled devices)",
            style: TextStyle(fontSize: 12)),
        value: state._forceAdd,
        activeColor: Colors.blue[700],
        onChanged: (v) => setState(() => state._forceAdd = v!),
        secondary: Icon(Icons.shield_outlined, color: Colors.blue[700]),
      ),
    );
  }

  Widget buildSnmpToggle() {
    final state = this as _RegisterDeviceScreenState;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: "SNMP",
        filled: true,
        fillColor: Colors.grey[50],
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            state._snmpEnabled ? "ON" : "OFF",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color:
                    state._snmpEnabled ? Colors.green[700] : Colors.grey[700]),
          ),
          Switch(
              value: state._snmpEnabled,
              onChanged: (v) => setState(() => state._snmpEnabled = v)),
        ],
      ),
    );
  }
}
