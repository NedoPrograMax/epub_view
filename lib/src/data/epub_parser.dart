import 'dart:math';

import 'package:collection/collection.dart';
import 'package:epub_view/src/data/epub_cfi_reader.dart';
import 'package:epub_view/src/helpers/extensions.dart';
import 'package:epub_view/src/helpers/utils.dart';
import 'package:html/dom.dart' as dom;

import 'models/paragraph.dart';

export 'package:epubx/epubx.dart' hide Image;

class EpubParser {
  int wordsBefore = 0;
  static List<EpubChapter> parseChapters(EpubBook epubBook) =>
      epubBook.getRealChaptersOrCreated().fold<List<EpubChapter>>(
        [],
        (acc, next) {
          acc.add(next);
          next.SubChapters?.forEach(acc.add);
          return acc;
        },
      );

  static List<dom.Element> convertDocumentToElements(dom.Document document) =>
      document.getElementsByTagName('body').first.children;

  static List<dom.Element> _removeAllDiv(
      List<dom.Element> elements, Map<String, String> hrefMap) {
    final List<dom.Element> result = [];

    for (final node in elements) {
      setNodeId(node, hrefMap);
      setNodeIds(node, hrefMap);

      if (node.localName == 'div' && node.children.length > 1) {
        result.addAll(_removeAllDiv(node.children, hrefMap));
      } else {
        result.add(node);
      }
    }

    return result;
  }

  static void setNodeIds(dom.Element node, Map<String, String> hrefMap) {
    for (var element in node.children) {
      setNodeId(element, hrefMap);
    }
  }

  static void setNodeId(dom.Element node, Map<String, String> hrefMap) {
    if (node.id.isEmpty) {
      final ids = node.querySelectorAll('[id]').map((e) => e.id);
      final newId = ids.first;
      if (newId.contains("footnote")) {
        node.id = newId;
      }
      for (var element in ids) {
        hrefMap[element] = newId;
      }
    }
    setNodeIds(node, hrefMap);
  }

  ParseParagraphsResult parseParagraphs(
    List<EpubChapter> chapters,
  ) {
    int? hashcode = 0;
    final List<int> chapterIndexes = [];
    final Map<String, String> hrefMap = {};
    wordsBefore = 0;
    final paragraphs = chapters.fold<List<Paragraph>>(
      [],
      (acc, next) {
        List<dom.Element> elmList = [];
        if (hashcode != next.hashCode) {
          hashcode = next.hashCode;
          final document = EpubCfiReader().chapterDocument(next.HtmlContent);
          if (document != null) {
            final result = convertDocumentToElements(document);
            elmList = _removeAllDiv(result, hrefMap);
          }
        }

        if (next.Anchor == null) {
          // last element from document index as chapter index
          chapterIndexes.add(acc.length);
          acc.addAll(
            elmList.map(
              (element) => _countParagraphAndWordsCount(
                element: element,
                chapterIndex: chapterIndexes.length - 1,
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
                (element) => _countParagraphAndWordsCount(
                  element: element,
                  chapterIndex: chapterIndexes.length - 1,
                ),
              ),
            );
            return acc;
          }

          chapterIndexes.add(index + acc.length);
          acc.addAll(
            elmList.mapIndexed(
              (elementIndex, element) => _countParagraphAndWordsCount(
                element: element,
                chapterIndex: elementIndex < index
                    ? max(chapterIndexes.length - 2, 0)
                    : chapterIndexes.length - 1,
              ),
            ),
          );
          return acc;
        }
      },
    );

    return ParseParagraphsResult(paragraphs, chapterIndexes, hrefMap);
  }

  Paragraph _countParagraphAndWordsCount({
    required dom.Element element,
    required int chapterIndex,
  }) {
    final paragraph = Paragraph(
      element: element,
      chapterIndex: chapterIndex,
      percent: 0,
      symbolsCount: countSymbolsInElement(element),
      wordsBefore: wordsBefore,
    );
    wordsBefore += paragraph.symbolsCount;
    return paragraph;
  }
}

class ParseParagraphsResult {
  ParseParagraphsResult(
    this.flatParagraphs,
    this.chapterIndexes,
    this.hrefMap,
  );

  final List<Paragraph> flatParagraphs;
  final List<int> chapterIndexes;
  final Map<String, String> hrefMap;
}
