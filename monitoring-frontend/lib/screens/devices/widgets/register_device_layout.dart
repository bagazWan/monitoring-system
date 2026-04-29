part of '../register_device_screen.dart';

mixin RegisterDeviceLayout
    on
        State<RegisterDeviceScreen>,
        RegisterDeviceFormInputs,
        RegisterDeviceFormComponents {
  Widget buildRegisterDeviceScreen(BuildContext context) {
    final state = this as _RegisterDeviceScreenState;
    final isEditing = widget.initialData != null;
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(
            isEditing ? "Hubung Kembali Perangkat" : "Daftar Perangkat Baru",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Form(
            key: state._formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                buildNodeTypeCard(),
                const SizedBox(height: 24),
                buildSectionHeader("Koneksi Jaringan", Icons.lan),
                buildFormCard([
                  buildResponsiveRow(
                    isNarrow: isNarrow,
                    children: [
                      buildTextField("Hostname / IP", state._hostnameController,
                          required: true),
                      buildSnmpToggle(),
                    ],
                  ),
                  if (state._snmpEnabled) ...[
                    const SizedBox(height: 16),
                    buildResponsiveRow(
                      isNarrow: isNarrow,
                      children: [
                        buildTextField("Port", state._portController,
                            keyboard: TextInputType.number),
                        buildTextField("Transport", state._transportController),
                      ],
                    ),
                    const SizedBox(height: 16),
                    buildResponsiveRow(
                      isNarrow: isNarrow,
                      children: [
                        buildTextField("Versi SNMP", state._snmpController),
                        buildTextField(
                          "Community String",
                          state._communityController,
                          required: true,
                          icon: Icons.vpn_key,
                        ),
                      ],
                    ),
                  ],
                ]),
                const SizedBox(height: 24),
                buildSectionHeader("Identitas & Lokasi", Icons.info_outline),
                buildFormCard([
                  buildResponsiveRow(
                    isNarrow: isNarrow,
                    children: [
                      buildTextField("Nama Tampilan", state._nameController),
                      buildTextField(
                          "Tipe (contoh: CCTV)", state._deviceTypeController),
                    ],
                  ),
                  const SizedBox(height: 16),
                  buildResponsiveRow(
                    isNarrow: isNarrow,
                    children: [
                      buildLocationSelector(),
                      if (state._nodeType == 'device')
                        buildDropdown(
                            "Hub/switch induk",
                            state._selectedSwitchId,
                            state._switches,
                            (val) =>
                                setState(() => state._selectedSwitchId = val)),
                      if (state._nodeType == 'switch')
                        buildNetworkNodeDropdown(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  buildTextField("Deskripsi", state._descriptionController,
                      maxLines: 3),
                ]),
                const SizedBox(height: 24),
                buildOptionCard(),
                const SizedBox(height: 32),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: state._loading ? null : state._submit,
                    child: state._loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            isEditing ? "UPDATE KONEKSI" : "DAFTAR PERANGKAT",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
