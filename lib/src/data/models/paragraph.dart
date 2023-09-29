import 'package:epub_view/src/data/models/last_place_model.dart';
import 'package:html/dom.dart' as dom;

class Paragraph {
  Paragraph({
    required this.element,
    required this.chapterIndex,
    required this.percent,
    this.wordsCount = 0,
  });

  final dom.Element element;
  final int chapterIndex;
  final int wordsCount;
  double percent = 0;

  LastPlaceModel toLastPlace(int index) => LastPlaceModel(
        percent: percent,
        index: index,
      );
}
