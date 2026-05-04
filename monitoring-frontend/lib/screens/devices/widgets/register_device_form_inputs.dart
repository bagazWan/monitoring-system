part of '../register_device_screen.dart';

mixin RegisterDeviceFormInputs on State<RegisterDeviceScreen> {
  InputDecoration get _sharedDropdownDecoration => InputDecoration(
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
      );

  Widget buildLocationSelector() {
    final state = this as _RegisterDeviceScreenState;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: state._pickLocationWithSearch,
          child: InputDecorator(
            decoration: _sharedDropdownDecoration.copyWith(
              labelText: "Lokasi",
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
            label: const Text("Tambah lokasi"),
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
    return AppTextField(
      label: label,
      controller: controller,
      isRequired: required,
      prefixIcon:
          icon != null ? Icon(icon, size: 18, color: Colors.grey[500]) : null,
      keyboardType: keyboard,
      maxLines: maxLines,
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
      decoration: _sharedDropdownDecoration.copyWith(labelText: label),
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
      decoration:
          _sharedDropdownDecoration.copyWith(labelText: "Node Jaringan"),
    );
  }
}
