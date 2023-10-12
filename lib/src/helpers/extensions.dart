import 'package:collection/collection.dart';
import 'package:epub_view/epub_view.dart';
import 'package:epub_view/src/data/models/paragraph.dart';
import 'package:html/dom.dart';

extension ParagraphsExtension on List<Paragraph> {
  List<LastPlaceModel> toLastModels() =>
      mapIndexed((index, paragraph) => paragraph.toLastPlace(index)).toList();

  List<Paragraph> removeZeros() {
    final newList = [...this];
    newList.removeWhere((element) => element.percent == 0);
    if (newList.isEmpty) {
      newList.add(
        Paragraph(element: Element.html(""), chapterIndex: 1, percent: 0.001),
      );
    }
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
