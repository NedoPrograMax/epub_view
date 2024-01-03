import 'package:epub_view/epub_view.dart';
import 'package:epub_view/src/data/epub_parser.dart';
import 'package:epub_view/src/data/models/paragraph.dart';

class ParsedEpub {
  final EpubBook epubBook;
  final ParseParagraphsResult parseParagraphsResult;

  ParsedEpub({
    required this.epubBook,
    required this.parseParagraphsResult,
  });
}
