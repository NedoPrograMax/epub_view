import 'package:collection/collection.dart';
import 'package:epub_view/src/data/models/last_place_model.dart';
import 'package:epub_view/src/data/models/paragraph.dart';

extension ParagraphsExtension on List<Paragraph> {
  List<LastPlaceModel> toLastModels() =>
      mapIndexed((index, paragraph) => paragraph.toLastPlace(index)).toList();

  List<Paragraph> removeZeros() {
    final newList = [...this];
    newList.removeWhere((element) => element.percent == 0);
    return newList;
  }
}
