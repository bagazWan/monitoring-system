import 'dart:async';
import 'package:flutter/material.dart';

mixin SearchPaginationMixin<T extends StatefulWidget> on State<T> {
  final TextEditingController searchController = TextEditingController();
  Timer? _searchDebounce;
  int currentPage = 1;
  final int itemsPerPage = 10;

  void onSearchTriggered();

  @override
  void initState() {
    super.initState();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() => currentPage = 1);
        onSearchTriggered();
      }
    });
  }

  void handlePageChanged(int page) {
    setState(() => currentPage = page);
    onSearchTriggered();
  }
}
