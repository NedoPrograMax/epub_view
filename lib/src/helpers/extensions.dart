import 'package:collection/collection.dart';
import 'package:epub_view/epub_view.dart';
import 'package:epub_view/src/data/models/paragraph.dart';
import 'package:epub_view/src/data/models/paragraph_progress_percent.dart';
import 'package:html/dom.dart';
import 'package:scrollable_positioned_list_extended/scrollable_positioned_list_extended.dart';

extension ParagraphsExtension on List<Paragraph> {
  List<LastPlaceModel> toLastModels() {
    final newList =
        mapIndexed((index, paragraph) => paragraph.toLastPlace(index)).toList();
    if (newList.isEmpty) {
      newList.add(const LastPlaceModel(percent: 0.01, index: 1));
    }
    return newList;
  }

  List<Paragraph> removeZeros() {
    final newList = [...this];
    newList.removeWhere((element) => element.percent == 0);

    return newList;
  }
}

extension EpubBookExtension on EpubBook {
  List<EpubChapter> getRealChaptersOrCreated() {
    List<EpubChapter> chapters = [...(Chapters ?? [])];
    if (chapters.isEmpty) {
      chapters = Content?.Html?.values
              .mapIndexed((i, e) => EpubChapter()
                ..HtmlContent = e.Content
                ..ContentFileName = e.FileName
                ..Title = "Глава ${i + 1}")
              .toList() ??
          [];
    }
    chapters.removeWhere((element) =>
        element.ContentFileName?.toLowerCase().startsWith("cover") ?? false);
    return chapters;
  }
}

extension ElementExtesnion on Element {
  bool doesMatchId(String id) =>
      this.id == id || (children.isNotEmpty && children[0].id == id);
}

extension PositionExtension on ItemPosition {
  ParagraphProgressPercent get seenPart {
    final itemLeadingEdgeAbsolute = itemLeadingEdge.abs();

    final positionHeight = itemLeadingEdgeAbsolute + itemTrailingEdge;
    final seenFrom =
        itemLeadingEdge < 0.0 ? itemLeadingEdgeAbsolute / positionHeight : 0.0;
    final seenTo = itemTrailingEdge < 1
        ? 1.0
        : 1 - (itemTrailingEdge - 1) / positionHeight;

    return ParagraphProgressPercent(start: seenFrom, end: seenTo);
  }
}
