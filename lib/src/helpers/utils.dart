import 'package:epub_view/src/data/models/paragraph.dart';
import 'package:html/dom.dart';

Duration countReadDurationOfParagraph(Paragraph paragraph) {
  final symbolsInParagraph = countWordsInParagraph(paragraph);
  const symbolsPerSecond = 25;
  final normalReadSeconds = symbolsInParagraph / symbolsPerSecond;
  const coef = 0.1;
  final coefReadSeconds = normalReadSeconds * coef;
  final coedReadMilliseconds = coefReadSeconds * 1000;
  return Duration(milliseconds: coedReadMilliseconds.round());
}

int countWordsInParagraph(Paragraph paragraph) {
  return getWordCountsInNodeList(paragraph.element.nodes);
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
