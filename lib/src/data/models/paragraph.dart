import 'package:html/dom.dart' as dom;

class Paragraph {
  Paragraph({
    required this.element,
    required this.chapterIndex,
    required this.percent,
  });

  final dom.Element element;
  final int chapterIndex;
  double percent = 0;
}
