import 'dart:math' show min, max;

/// A single grid coordinate (row, column).
class Cell {
  final int r;
  final int c;
  const Cell(this.r, this.c);

  @override
  bool operator ==(Object other) => other is Cell && other.r == r && other.c == c;

  @override
  int get hashCode => r * 1000 + c;

  @override
  String toString() => '($r,$c)';
}

/// An immutable block shape. Cells are normalised so the bounding box starts at (0,0).
/// Shapes never rotate during play: every orientation is its own shape, which keeps
/// behaviour predictable (what you see in the tray is exactly what you place).
class Shape {
  final String id;
  final String family;
  final List<Cell> cells;
  final int color; // index into the palette (0..6)
  final int width;
  final int height;

  Shape._(this.id, this.family, this.cells, this.color, this.width, this.height);

  factory Shape.fromCells(String id, String family, List<Cell> raw, int color) {
    if (raw.isEmpty) throw ArgumentError('Shape must have at least one cell');
    final minR = raw.map((e) => e.r).reduce(min);
    final minC = raw.map((e) => e.c).reduce(min);
    final cells = raw.map((e) => Cell(e.r - minR, e.c - minC)).toList()
      ..sort((a, b) => a.r != b.r ? a.r - b.r : a.c - b.c);
    final h = cells.map((e) => e.r).reduce(max) + 1;
    final w = cells.map((e) => e.c).reduce(max) + 1;
    return Shape._(id, family, List.unmodifiable(cells), color, w, h);
  }

  int get size => cells.length;

  /// Canonical key used to remove duplicate orientations.
  String get key => cells.map((e) => '${e.r}:${e.c}').join('|');

  @override
  String toString() => 'Shape($id)';
}

class _Family {
  final String name;
  final List<String> rows;
  final bool rotate;
  final bool mirror;
  final int weight;
  const _Family(this.name, this.rows, this.rotate, this.mirror, this.weight);
}

/// All shapes in the game, generated from a small set of base patterns.
class ShapeLibrary {
  ShapeLibrary._();

  static const List<_Family> _families = [
    _Family('dot', ['#'], false, false, 1),
    _Family('i2', ['##'], true, false, 3),
    _Family('i3', ['###'], true, false, 3),
    _Family('i4', ['####'], true, false, 2),
    _Family('i5', ['#####'], true, false, 1),
    _Family('o2', ['##', '##'], false, false, 3),
    _Family('o3', ['###', '###', '###'], false, false, 1),
    _Family('r23', ['###', '###'], true, false, 2),
    _Family('c3', ['#.', '##'], true, false, 3),
    _Family('c5', ['#..', '#..', '###'], true, false, 1),
    _Family('l4', ['#.', '#.', '##'], true, true, 3),
    _Family('t4', ['###', '.#.'], true, false, 2),
    _Family('s4', ['.##', '##.'], true, true, 2),
  ];

  static final List<Shape> all = _build();
  static final Map<String, Shape> byId = {for (final s in all) s.id: s};

  static final Map<String, List<Shape>> byFamily = () {
    final m = <String, List<Shape>>{};
    for (final s in all) {
      m.putIfAbsent(s.family, () => []).add(s);
    }
    return m;
  }();

  static List<String> get familyNames => _families.map((f) => f.name).toList();

  static int weightOf(String family) =>
      _families.firstWhere((f) => f.name == family).weight;

  static List<Cell> _rotate(List<Cell> cells) {
    final h = cells.map((e) => e.r).reduce(max) + 1;
    return cells.map((e) => Cell(e.c, h - 1 - e.r)).toList();
  }

  static List<Cell> _mirror(List<Cell> cells) {
    final w = cells.map((e) => e.c).reduce(max) + 1;
    return cells.map((e) => Cell(e.r, w - 1 - e.c)).toList();
  }

  static List<Shape> _build() {
    final out = <Shape>[];
    for (var fi = 0; fi < _families.length; fi++) {
      final f = _families[fi];
      final base = <Cell>[];
      for (var r = 0; r < f.rows.length; r++) {
        for (var c = 0; c < f.rows[r].length; c++) {
          if (f.rows[r][c] == '#') base.add(Cell(r, c));
        }
      }
      final variants = <List<Cell>>[base];
      if (f.rotate) {
        var cur = base;
        for (var i = 0; i < 3; i++) {
          cur = _rotate(cur);
          variants.add(cur);
        }
      }
      if (f.mirror) {
        final mirrored = variants.map(_mirror).toList();
        variants.addAll(mirrored);
      }
      final seen = <String>{};
      var n = 0;
      for (final v in variants) {
        final candidate = Shape.fromCells('${f.name}_$n', f.name, v, fi % 7);
        if (seen.add(candidate.key)) {
          out.add(candidate);
          n++;
        }
      }
    }
    return out;
  }
}
