import 'package:flutter/material.dart';

class CustomDataTable extends StatefulWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;

  const CustomDataTable({
    super.key,
    required this.columns,
    required this.rows,
  });

  @override
  State<CustomDataTable> createState() => _CustomDataTableState();
}

class _CustomDataTableState extends State<CustomDataTable> {
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.black12)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                  showCheckboxColumn: false,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 48,
                  columns: widget.columns,
                  rows: widget.rows,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
