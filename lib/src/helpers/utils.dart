import 'package:epub_view/src/data/models/paragraph.dart';
import 'package:html/dom.dart';

Duration countReadDurationOfParagraph(Paragraph paragraph) {
  final symbolsInParagraph = paragraph.wordsCount;
  const symbolsPerSecond = 25;
  final normalReadSeconds = symbolsInParagraph / symbolsPerSecond;
  const coef = 0.1;
  final coefReadSeconds = normalReadSeconds * coef;
  final coedReadMilliseconds = coefReadSeconds * 1000;
  return Duration(milliseconds: coedReadMilliseconds.round());
}

int countWordsInElement(Element element) {
  return getWordCountsInNodeList(element.nodes);
}

double countUserProgress(
  List<Paragraph> paragraphs, {
  required int chapterNumber,
  required int paragraphNumber,
}) {
  double allSymbols = 0;
  double readSymbols = 0;
  for (int i = 0; i < paragraphs.length; i++) {
    final paragraph = paragraphs[i];
    allSymbols += paragraph.wordsCount;
    if (paragraph.chapterIndex < chapterNumber) {
      readSymbols += paragraph.wordsCount;
    } else if (paragraph.chapterIndex == chapterNumber) {
      if (i < paragraphNumber) {
        readSymbols += paragraph.wordsCount;
      } else if (i == paragraphNumber) {
        readSymbols += paragraph.wordsCount * paragraph.percent;
      }
    }
  }
  final readPercent = readSymbols / allSymbols;
  return readPercent;
}

double countRealProgress(List<Paragraph> paragraphs) {
  double allSymbols = 0;
  double readSymbols = 0;
  for (int i = 0; i < paragraphs.length; i++) {
    final paragraph = paragraphs[i];
    allSymbols += paragraph.wordsCount;

    readSymbols += paragraph.wordsCount * paragraph.percent;
  }

  final readPercent = readSymbols / allSymbols;
  return readPercent;
}

int getWordCountsInNode(Node node) {
  var wordCount = node.text?.trim().split(' ').length ?? 0;
  if (node.nodes.isNotEmpty) {
    wordCount += getWordCountsInNodeList(node.nodes);
  }
  return wordCount;
}

int getWordCountsInNodeList(NodeList nodeList) {
  var wordCount = 0;
  for (var i = 0; i < nodeList.length; i++) {
    wordCount += getWordCountsInNode(nodeList[i]);
  }
  return wordCount;
}
