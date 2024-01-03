import 'package:epub_view/src/data/epub_parser.dart';
import 'package:epub_view/src/data/models/parse_paragraph_result.dart';

export 'package:epubx/epubx.dart' hide Image;

class ParseResult {
  const ParseResult(this.epubBook, this.chapters, this.parseResult);

  final EpubBook epubBook;
  final List<EpubChapter> chapters;
  final ParseParagraphsResult parseResult;
}
