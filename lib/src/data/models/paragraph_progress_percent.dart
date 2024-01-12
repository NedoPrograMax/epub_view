class ParagraphProgressPercent extends Comparable {
  double start;
  double end;

  ParagraphProgressPercent({required this.start, required this.end});

  @override
  int compareTo(other) {
    return start.compareTo((other as ParagraphProgressPercent).start);
  }
}
