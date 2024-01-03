import 'package:epub_view/src/data/models/paragraph.dart';

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
