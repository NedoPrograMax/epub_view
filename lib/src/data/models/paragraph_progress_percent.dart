class ParagraphProgressPercent extends Comparable {
  final double start;
  final double end;

  ParagraphProgressPercent({required this.start, required this.end});

  @override
  int compareTo(other) {
    return start.compareTo((other as ParagraphProgressPercent).start);
  }

  ParagraphProgressPercent copyWith({
    double? start,
    double? end,
  }) =>
      ParagraphProgressPercent(
        start: start ?? this.start,
        end: end ?? this.end,
      );
}
