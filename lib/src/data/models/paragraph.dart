import 'package:epub_view/src/data/models/last_place_model.dart';
import 'package:html/dom.dart' as dom;

class Paragraph {
  Paragraph({
    required this.element,
    required this.chapterIndex,
    required this.percent,
    this.wordsCount = 0,
    required this.wordsBefore,
  });

  final dom.Element element;
  final int chapterIndex;
  final int wordsCount;
  final int wordsBefore;
  double percent = 0;

  LastPlaceModel toLastPlace(int index) => LastPlaceModel(
        percent: percent,
        index: index + 1,
      );
}

extension ParagraphsExtension on List<Paragraph> {
  LastPlaceModel binarySearchForPlaceByPercent(double percent) {
    var min = 0;
    var max = length;
    final wordsByPercent = (last.wordsBefore + last.wordsCount) * percent;

    while (min < max) {
      var mid = min + ((max - min) >> 1);
      var element = this[mid];

      if (element.wordsBefore < wordsByPercent &&
          element.wordsBefore + element.wordsCount >= wordsByPercent) {
        return LastPlaceModel(
          percent: (element.wordsBefore + element.wordsCount - wordsByPercent) /
              element.wordsCount,
          index: mid,
        );
      } else if (element.wordsBefore < wordsByPercent &&
          element.wordsBefore + element.wordsCount < wordsByPercent) {
        min = mid + 1;
      } else {
        max = mid;
      }
    }
    return const LastPlaceModel(
      percent: 0,
      index: 0,
    );
  }
}
