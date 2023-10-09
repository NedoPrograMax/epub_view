import 'package:epub_view/src/data/epub_cfi_reader.dart';
import 'package:epub_view/src/helpers/extensions.dart';
import 'package:epub_view/src/helpers/utils.dart';
import 'package:html/dom.dart' as dom;

import 'models/paragraph.dart';

export 'package:epubx/epubx.dart' hide Image;

List<EpubChapter> parseChapters(EpubBook epubBook) =>
    epubBook.getRealChaptersOrCreated().fold<List<EpubChapter>>(
      [],
      (acc, next) {
        acc.add(next);
        next.SubChapters!.forEach(acc.add);
        return acc;
      },
    );

List<dom.Element> convertDocumentToElements(dom.Document document) =>
    document.getElementsByTagName('body').first.children;

List<dom.Element> _removeAllDiv(List<dom.Element> elements) {
  final List<dom.Element> result = [];

  for (final node in elements) {
    if (node.localName == 'div' && node.children.length > 1) {
      result.addAll(_removeAllDiv(node.children));
    } else {
      result.add(node);
    }
  }

  return result;
}

ParseParagraphsResult parseParagraphs(
  List<EpubChapter> chapters,
) {
  int? hashcode = 0;
  final List<int> chapterIndexes = [];
  final paragraphs = chapters.fold<List<Paragraph>>(
    [],
    (acc, next) {
      List<dom.Element> elmList = [];
      if (hashcode != next.hashCode) {
        hashcode = next.hashCode;
        final document = EpubCfiReader().chapterDocument(next.HtmlContent);
        if (document != null) {
          final result = convertDocumentToElements(document);
          elmList = _removeAllDiv(result);
        }
      }

      if (next.Anchor == null) {
        // last element from document index as chapter index
        chapterIndexes.add(acc.length);
        acc.addAll(
          elmList.map(
            (element) => Paragraph(
              element: element,
              chapterIndex: chapterIndexes.length - 1,
              percent: 0,
              wordsCount: countWordsInElement(element),
            ),
          ),
        );
        return acc;
      } else {
        final index = elmList.indexWhere(
          (elm) => elm.outerHtml.contains(
            'id="${next.Anchor}"',
          ),
        );
        if (index == -1) {
          chapterIndexes.add(acc.length);
          acc.addAll(
            elmList.map(
              (element) => Paragraph(
                element: element,
                chapterIndex: chapterIndexes.length - 1,
                percent: 0,
                wordsCount: countWordsInElement(element),
              ),
            ),
          );
          return acc;
        }

        chapterIndexes.add(index + acc.length);
        acc.addAll(
          elmList.map(
            (element) => Paragraph(
              element: element,
              chapterIndex: chapterIndexes.length - 1,
              percent: 0,
              wordsCount: countWordsInElement(element),
            ),
          ),
        );
        return acc;
      }
    },
  );

  return ParseParagraphsResult(paragraphs, chapterIndexes);
}

class ParseParagraphsResult {
  ParseParagraphsResult(this.flatParagraphs, this.chapterIndexes);

  final List<Paragraph> flatParagraphs;
  final List<int> chapterIndexes;
}
