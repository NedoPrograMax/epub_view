part of 'ui/epub_view.dart';

class EpubController {
  EpubController({
    required this.document,
    required this.lastResult,
    required this.onSave,
    this.epubCfi,
  });

  Future<EpubBook> document;
  final Function(ReaderResult result) onSave;
  final ReaderResult lastResult;

  final String? epubCfi;

  _EpubViewState? _epubViewState;
  List<EpubViewChapter>? _cacheTableOfContents;
  EpubBook? _document;

  EpubChapterViewValue? get currentValue => _epubViewState?._currentValue;

  EpubBook? getDocument() => _document;

  final isBookLoaded = ValueNotifier<bool>(false);
  final ValueNotifier<EpubViewLoadingState> loadingState =
      ValueNotifier(EpubViewLoadingState.loading);

  final currentValueListenable = ValueNotifier<EpubChapterViewValue?>(null);

  final tableOfContentsListenable = ValueNotifier<List<EpubViewChapter>>([]);

  void jumpTo({required int index, double alignment = 0}) =>
      _epubViewState?._itemScrollController?.jumpTo(
        index: index,
        alignment: alignment,
      );

  Future<void>? scrollTo({
    required int index,
    Duration duration = const Duration(milliseconds: 250),
    double alignment = 0,
    Curve curve = Curves.linear,
  }) =>
      _epubViewState?._itemScrollController?.scrollTo(
        index: index,
        duration: duration,
        alignment: alignment,
        curve: curve,
      );

  Future<void>? jumpToPercent({
    required double percent,
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.linear,
  }) {
    final lastPlace =
        _epubViewState?._paragraphs.binarySearchForPlaceByPercent(percent);
    return _epubViewState?.jumpToLastPlace(
      lastPlace: lastPlace ?? const LastPlaceModel(percent: 0, index: 0),
      duration: duration,
      curve: curve,
    );
  }

  void gotoEpubCfi(
    String epubCfi, {
    double alignment = 0,
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.linear,
  }) {
    _epubViewState?._gotoEpubCfi(
      epubCfi,
      alignment: alignment,
      duration: duration,
      curve: curve,
    );
  }

  String? generateEpubCfi() => _epubViewState?._epubCfiReader?.generateCfi(
        book: _document,
        chapter: _epubViewState?._currentValue?.chapter,
        paragraphIndex: _epubViewState?._getAbsParagraphIndexBy(
          positionIndex: _epubViewState?._currentValue?.position.index ?? 0,
          trailingEdge:
              _epubViewState?._currentValue?.position.itemTrailingEdge,
          leadingEdge: _epubViewState?._currentValue?.position.itemLeadingEdge,
        ),
      );

  List<EpubViewChapter> tableOfContents() {
    if (_cacheTableOfContents != null) {
      return _cacheTableOfContents ?? [];
    }

    if (_document == null) {
      return [];
    }

    int index = -1;

    return _cacheTableOfContents =
        _document!.getRealChaptersOrCreated().fold<List<EpubViewChapter>>(
      [],
      (acc, next) {
        index += 1;
        acc.add(EpubViewChapter(next.Title, _getChapterStartIndex(index)));
        for (final subChapter in next.SubChapters ?? []) {
          index += 1;
          acc.add(EpubViewSubChapter(
              subChapter.Title, _getChapterStartIndex(index)));
        }
        return acc;
      },
    );
  }

  ReaderResult? getReaderResult() => _epubViewState?.countResult();

  Future<void> loadDocument(Future<EpubBook> document) {
    this.document = document;
    return _loadDocument(document);
  }

  void dispose() {
    _epubViewState = null;
    isBookLoaded.dispose();
    currentValueListenable.dispose();
    tableOfContentsListenable.dispose();
  }

  Future<void> _loadDocument(Future<EpubBook> document) async {
    isBookLoaded.value = false;
    try {
      loadingState.value = EpubViewLoadingState.loading;
      _document = await document;
      await _epubViewState!._init();
      tableOfContentsListenable.value = tableOfContents();
      loadingState.value = EpubViewLoadingState.success;
    } catch (error) {
      _epubViewState!._loadingError = error is Exception
          ? error
          : Exception('An unexpected error occurred');
      loadingState.value = EpubViewLoadingState.error;
    }
  }

  int _getChapterStartIndex(int index) {
    final startIndex = index < _epubViewState!._chapterIndexes.length
        ? _epubViewState!._chapterIndexes[index]
        : 0;
    return startIndex;
  }

  void _attach(_EpubViewState epubReaderViewState) {
    _epubViewState = epubReaderViewState;

    _loadDocument(document);
  }

  void _detach() {
    _epubViewState = null;
  }
}
