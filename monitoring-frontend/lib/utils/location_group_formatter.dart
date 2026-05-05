class LocationGroupFormatter {
  static List<String> formatNames(List<dynamic> groups) {
    final List<String> formattedNames = [];

    final parents = groups.where((g) => g.parentId == null).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    for (final parent in parents) {
      formattedNames.add(parent.name);

      final children = groups
          .where((g) => g.parentId == parent.groupId)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      for (final child in children) {
        formattedNames.add("   ↳ ${child.name}");
      }
    }

    final accountedFor = groups
        .where((g) =>
            g.parentId == null || parents.any((p) => p.groupId == g.parentId))
        .map((e) => e.groupId)
        .toSet();

    final orphans = groups
        .where((g) => !accountedFor.contains(g.groupId))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    for (final orphan in orphans) {
      formattedNames.add(orphan.name);
    }

    return formattedNames;
  }
}
