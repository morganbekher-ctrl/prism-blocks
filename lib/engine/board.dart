import 'shape.dart';

/// Result of placing a shape: which lines completed and which cells were cleared.
class PlaceResult {
  final List<Cell> placedCells;
  final List<int> rows;
  final List<int> cols;
  final List<Cell> clearedCells;
  final List<int> clearedColors; // parallel to clearedCells
  const PlaceResult(
      this.placedCells, this.rows, this.cols, this.clearedCells, this.clearedColors);

  int get lines => rows.length + cols.length;
}

class Board {
  static const int defaultSize = 8;

  final int size;
  final List<int> cells; // -1 = empty, otherwise colour index

  Board([this.size = defaultSize]) : cells = List<int>.filled(size * size, -1);

  Board.fromCells(this.size, List<int> source) : cells = List<int>.of(source) {
    if (source.length != size * size) {
      throw ArgumentError('Expected ${size * size} cells, got ${source.length}');
    }
  }

  Board clone() => Board.fromCells(size, cells);

  int at(int r, int c) => cells[r * size + c];
  void setAt(int r, int c, int v) => cells[r * size + c] = v;
  bool inBounds(int r, int c) => r >= 0 && c >= 0 && r < size && c < size;
  bool isFree(int r, int c) => at(r, c) == -1;

  int get filledCount => cells.where((v) => v != -1).length;
  bool get isCompletelyEmpty => cells.every((v) => v == -1);

  /// (row, col) is the top-left corner of the shape's bounding box.
  bool canPlace(Shape s, int row, int col) {
    for (final cell in s.cells) {
      final r = row + cell.r;
      final c = col + cell.c;
      if (!inBounds(r, c) || !isFree(r, c)) return false;
    }
    return true;
  }

  bool canPlaceAnywhere(Shape s) {
    for (var r = 0; r <= size - s.height; r++) {
      for (var c = 0; c <= size - s.width; c++) {
        if (canPlace(s, r, c)) return true;
      }
    }
    return false;
  }

  /// All valid top-left positions for [s], row-major.
  List<Cell> placements(Shape s) {
    final out = <Cell>[];
    for (var r = 0; r <= size - s.height; r++) {
      for (var c = 0; c <= size - s.width; c++) {
        if (canPlace(s, r, c)) out.add(Cell(r, c));
      }
    }
    return out;
  }

  List<int> fullRows() {
    final out = <int>[];
    for (var r = 0; r < size; r++) {
      var full = true;
      for (var c = 0; c < size; c++) {
        if (isFree(r, c)) {
          full = false;
          break;
        }
      }
      if (full) out.add(r);
    }
    return out;
  }

  List<int> fullCols() {
    final out = <int>[];
    for (var c = 0; c < size; c++) {
      var full = true;
      for (var r = 0; r < size; r++) {
        if (isFree(r, c)) {
          full = false;
          break;
        }
      }
      if (full) out.add(c);
    }
    return out;
  }

  /// Places [s] and clears every completed row/column at once.
  /// Rows and columns are detected *before* any clearing, so a row and a
  /// column completed by the same move both clear (their intersection counts once).
  PlaceResult place(Shape s, int row, int col) {
    if (!canPlace(s, row, col)) {
      throw ArgumentError('Invalid placement of ${s.id} at ($row,$col)');
    }
    final placed = <Cell>[];
    for (final cell in s.cells) {
      final r = row + cell.r;
      final c = col + cell.c;
      setAt(r, c, s.color);
      placed.add(Cell(r, c));
    }
    final rows = fullRows();
    final cols = fullCols();
    final toClear = <int>{};
    for (final r in rows) {
      for (var c = 0; c < size; c++) {
        toClear.add(r * size + c);
      }
    }
    for (final c in cols) {
      for (var r = 0; r < size; r++) {
        toClear.add(r * size + c);
      }
    }
    final clearedCells = <Cell>[];
    final clearedColors = <int>[];
    final sorted = toClear.toList()..sort();
    for (final idx in sorted) {
      clearedCells.add(Cell(idx ~/ size, idx % size));
      clearedColors.add(cells[idx]);
      cells[idx] = -1;
    }
    return PlaceResult(placed, rows, cols, clearedCells, clearedColors);
  }

  /// Non-mutating preview of [place].
  PlaceResult previewPlace(Shape s, int row, int col) => clone().place(s, row, col);
}
