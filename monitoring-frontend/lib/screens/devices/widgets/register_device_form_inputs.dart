part of '../register_device_screen.dart';

mixin RegisterDeviceFormInputs on State<RegisterDeviceScreen> {
  Widget buildLocationSelector() {
    final state = this as _RegisterDeviceScreenState;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: state._pickLocationWithSearch,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: "Location",
              filled: true,
              fillColor: Colors.grey[50],
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
            ),
            child: Text(
              state._selectedLocationLabel(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: state._openQuickAddLocationDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text("Add location"),
          ),
        ),
      ],
    );
  }

  Widget buildTextField(String label, TextEditingController controller,
      {bool required = false,
      IconData? icon,
      TextInputType keyboard = TextInputType.text,
      int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14),
      validator:
          required ? (v) => v == null || v.isEmpty ? "Required" : null : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
            icon != null ? Icon(icon, size: 18, color: Colors.grey[500]) : null,
        filled: true,
        fillColor: Colors.grey[50],
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
      ),
    );
  }

  Widget buildDropdown(
      String label, int? value, List<dynamic> items, Function(int?) onChanged) {
    return DropdownButtonFormField<int>(
      value: value,
      items: items
          .map((item) => DropdownMenuItem<int>(
                value: item.id,
                child: Text(item.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14)),
              ))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[50],
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!)),
      ),
    );
  }

  Widget buildNetworkNodeDropdown() {
    final state = this as _RegisterDeviceScreenState;
    return DropdownButtonFormField<int>(
      value: state._selectedNetworkNodeId,
      items: state._networkNodes
          .map((node) => DropdownMenuItem<int>(
                value: node.id,
                child: Text(node.name ?? "Node #${node.id} (${node.type})",
                    overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (val) => setState(() => state._selectedNetworkNodeId = val),
      decoration: InputDecoration(
          labelText: "Network Node",
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!))),
    );
  }
}
