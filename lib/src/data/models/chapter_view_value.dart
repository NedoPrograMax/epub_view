import 'package:epub_view/src/data/epub_parser.dart';
import 'package:flutter/cupertino.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

export 'package:epubx/epubx.dart' hide Image;

class EpubChapterViewValue {
  const EpubChapterViewValue({
    required this.chapter,
    required this.chapterNumber,
    required this.paragraphNumber,
    required this.position,
    this.scrollPosition,
    this.lastProgress,
  });

  final EpubChapter? chapter;
  final int chapterNumber;
  final int paragraphNumber;
  final ItemPosition position;
  final double? lastProgress;
  final ScrollPosition? scrollPosition;
  EpubChapterViewValue copyWith({
    double? lastProgress,
    ScrollPosition? scrollPosition,
  }) =>
      EpubChapterViewValue(
          chapter: chapter,
          chapterNumber: chapterNumber,
          paragraphNumber: paragraphNumber,
          position: position,
          lastProgress: lastProgress ?? this.lastProgress,
          scrollPosition: scrollPosition ?? this.scrollPosition);

  /// Chapter view in percents
  double get progress {
    final itemLeadingEdgeAbsolute = position.itemLeadingEdge.abs();
    final fullHeight = itemLeadingEdgeAbsolute + position.itemTrailingEdge;
    final heightPercent = fullHeight / 100;
    return itemLeadingEdgeAbsolute / heightPercent;
  }
}
