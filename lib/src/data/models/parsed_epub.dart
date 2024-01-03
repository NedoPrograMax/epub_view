import 'package:epub_view/epub_view.dart';
import 'package:epub_view/src/data/epub_parser.dart';
import 'package:epub_view/src/data/models/paragraph.dart';
import 'package:epub_view/src/data/models/parse_paragraph_result.dart';

class ParsedEpub {
  final ParseParagraphsResult parseParagraphsResult;

  ParsedEpub({
    required this.parseParagraphsResult,
  });
}
