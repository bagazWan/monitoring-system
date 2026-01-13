import 'package:flutter/material.dart';
import 'dart:math' as math;

class PaginationWidget extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final void Function(int) onPageChanged;

  const PaginationWidget({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous button
        IconButton(
          onPressed:
              currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous page',
        ),

        // Page numbers
        ..._buildPageNumbers(),

        // Next button
        IconButton(
          onPressed: currentPage < totalPages
              ? () => onPageChanged(currentPage + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next page',
        ),
      ],
    );
  }

  List<Widget> _buildPageNumbers() {
    List<Widget> pages = [];

    int startPage = currentPage - 2;
    int endPage = currentPage + 2;

    if (startPage < 1) {
      startPage = 1;
      endPage = math.min(5, totalPages);
    }
    if (endPage > totalPages) {
      endPage = totalPages;
      startPage = math.max(1, totalPages - 4);
    }

    // First page
    if (startPage > 1) {
      pages.add(_buildPageButton(1));
      if (startPage > 2) {
        pages.add(_buildEllipsis());
      }
    }

    // Middle pages
    for (int i = startPage; i <= endPage; i++) {
      pages.add(_buildPageButton(i));
    }

    // Last page
    if (endPage < totalPages) {
      if (endPage < totalPages - 1) {
        pages.add(_buildEllipsis());
      }
      pages.add(_buildPageButton(totalPages));
    }

    return pages;
  }

  Widget _buildEllipsis() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text('...'),
    );
  }

  Widget _buildPageButton(int page) {
    final isSelected = page == currentPage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: isSelected ? null : () => onPageChanged(page),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey[300]!,
            ),
          ),
          child: Text(
            '$page',
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
