import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:epub_view/src/data/epub_cfi_reader.dart';
import 'package:epub_view/src/data/epub_parser.dart';
import 'package:epub_view/src/data/models/chapter.dart';
import 'package:epub_view/src/data/models/chapter_view_value.dart';
import 'package:epub_view/src/data/models/last_place_model.dart';
import 'package:epub_view/src/data/models/paragraph.dart';
import 'package:epub_view/src/data/models/reader_result.dart';
import 'package:epub_view/src/data/repository.dart';
import 'package:epub_view/src/helpers/extensions.dart';
import 'package:epub_view/src/helpers/utils.dart';
import 'package:epub_view/src/ui/reader_test_selection_toolbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

export 'package:epubx/epubx.dart' hide Image;

part '../epub_controller.dart';
part '../helpers/epub_view_builders.dart';

const _minTrailingEdge = 0.55;
const _minLeadingEdge = -0.05;

typedef ExternalLinkPressed = void Function(String href);

class EpubView extends StatefulWidget {
  const EpubView({
    required this.controller,
    this.onExternalLinkPressed,
    this.onChapterChanged,
    this.onDocumentLoaded,
    this.onDocumentError,
    this.builders = const EpubViewBuilders<DefaultBuilderOptions>(
      options: DefaultBuilderOptions(),
    ),
    this.shrinkWrap = false,
    Key? key,
  }) : super(key: key);

  final EpubController controller;
  final ExternalLinkPressed? onExternalLinkPressed;
  final bool shrinkWrap;
  final void Function(EpubChapterViewValue? value)? onChapterChanged;

  /// Called when a document is loaded
  final void Function(EpubBook document)? onDocumentLoaded;

  /// Called when a document loading error
  final void Function(Exception? error)? onDocumentError;

  /// Builders
  final EpubViewBuilders builders;

  @override
  State<EpubView> createState() => _EpubViewState();
}

class _EpubViewState extends State<EpubView> {
  Exception? _loadingError;
  ItemScrollController? _itemScrollController;
  ItemPositionsListener? _itemPositionListener;
  List<EpubChapter> _chapters = [];
  List<Paragraph> _paragraphs = [];
  EpubCfiReader? _epubCfiReader;
  EpubChapterViewValue? _currentValue;
  final _chapterIndexes = <int>[];
  DateTime paragraphStartTime = DateTime.now();
  DateTime lastChangeTime = DateTime.now();
  Duration paragraphDuration = Duration.zero;
  late final Repository repository;
  double paragraphStartPercent = 0;
  Map<String, String> hrefMap = {};

  EpubController get _controller => widget.controller;
  bool didScrollToLastPlace = false;
  LastPlaceModel? scrollToPlace;

  @override
  void initState() {
    super.initState();
    _itemScrollController = ItemScrollController();
    _itemPositionListener = ItemPositionsListener.create();
    _controller._attach(this);
    _controller.loadingState.addListener(() {
      switch (_controller.loadingState.value) {
        case EpubViewLoadingState.loading:
          break;
        case EpubViewLoadingState.success:
          widget.onDocumentLoaded?.call(_controller._document!);
          break;
        case EpubViewLoadingState.error:
          widget.onDocumentError?.call(_loadingError);
          break;
      }

      if (mounted) {
        setState(() {});
      }
    });
    repository = Repository(
      onSave: _controller.onSave,
      lastReadResult: _controller.lastResult,
    );
  }

  @override
  void dispose() {
    _itemPositionListener!.itemPositions.removeListener(_changeListener);
    _controller._detach();
    repository.closeStream();

    super.dispose();
  }

  Future<bool> _init() async {
    if (_controller.isBookLoaded.value) {
      return true;
    }
    _chapters = EpubParser.parseChapters(_controller._document!);

    final parseParagraphsResult =
        await compute(EpubParser().parseParagraphs, _chapters);
    _paragraphs = parseParagraphsResult.flatParagraphs;
    _syncParagraphs();
    _chapterIndexes.addAll(parseParagraphsResult.chapterIndexes);
    hrefMap = parseParagraphsResult.hrefMap;

    _epubCfiReader = EpubCfiReader.parser(
      cfiInput: _controller.epubCfi,
      chapters: _chapters,
      paragraphs: _paragraphs,
    );
    _itemPositionListener!.itemPositions.addListener(_changeListener);

    _controller.isBookLoaded.value = true;

    return true;
  }

  void _syncParagraphs() {
    final lastParagraphs = _controller.lastResult.chapters;
    for (var lastParagraph in lastParagraphs) {
      _paragraphs[(lastParagraph.index ?? 1) - 1].percent =
          lastParagraph.percent ?? 0;
    }
  }

  void _changeListener() {
    final result = countResult();
    if (result != null) {
      repository.addData(result);
    }
  }

  ReaderResult? countResult() {
    if (_paragraphs.isEmpty ||
        _itemPositionListener!.itemPositions.value.isEmpty) {
      return null;
    }

    final position = _itemPositionListener!.itemPositions.value.first;
    final chapterIndex = _getChapterIndexBy(
      positionIndex: position.index,
      trailingEdge: position.itemTrailingEdge,
      leadingEdge: position.itemLeadingEdge,
    );
    final paragraphIndex = _getParagraphIndexBy(
      positionIndex: position.index,
      trailingEdge: position.itemTrailingEdge,
      leadingEdge: position.itemLeadingEdge,
    );
    final paragraphAbsIndex = _getAbsParagraphIndexBy(
      positionIndex: position.index,
      trailingEdge: position.itemTrailingEdge,
      leadingEdge: position.itemLeadingEdge,
    );
    final paragraph = _paragraphs[paragraphAbsIndex];
    final isTheSameParagraph =
        _currentValue?.chapterNumber == chapterIndex + 1 &&
            _currentValue?.paragraphNumber == paragraphIndex + 1;

    if (!isTheSameParagraph) {
      paragraphDuration = countReadDurationOfParagraph(paragraph);
      paragraphStartTime = lastChangeTime;
      paragraphStartPercent = paragraph.percent;
    }
    _currentValue = EpubChapterViewValue(
      chapter: chapterIndex >= 0 ? _chapters[chapterIndex] : null,
      chapterNumber: chapterIndex + 1,
      paragraphNumber: paragraphIndex + 1,
      position: position,
    );

    final now = DateTime.now();
    final timePercent = min(
      1.0,
      now.difference(paragraphStartTime).inMilliseconds /
              paragraphDuration.inMilliseconds +
          paragraphStartPercent,
    );

    final viewPercent = (_currentValue?.progress ?? 0.0) / 100.0;
    final currentPercentWithTime = min(timePercent, viewPercent);
    paragraph.percent = max(paragraph.percent, currentPercentWithTime);

    lastChangeTime = DateTime.now();
    final countedProgress = countUserProgress(
      _paragraphs,
      chapterNumber: chapterIndex,
      paragraphNumber: paragraphAbsIndex,
      lastPercent: viewPercent,
    );
    /* final userProgress = max(
      countedProgress,
      repository.lastReadResult.lastProgress,
    ); */

    _controller.currentValueListenable.value = _currentValue?.copyWith(
        lastProgress: countedProgress,
        scrollPosition:
            _itemScrollController?.primaryScrollController?.position);
    widget.onChapterChanged?.call(_currentValue);

    // +10k is needed so the percent is > 0. then it -
    final countedLastPlace = LastPlaceModel(
      percent: convertProgressToSmallModel(position.itemLeadingEdge),
      index: position.index + 1,
    );
    /*  final lastPlace = repository.lastReadResult.lastPlace == null ||
            countedLastPlace.isAfter(repository.lastReadResult.lastPlace!)
        ? countedLastPlace
        : repository.lastReadResult.lastPlace; */

    return ReaderResult(
      lastPlace: countedLastPlace,
      chapters: _paragraphs.removeZeros().toLastModels(),
      lastProgress: countedProgress,
      realProgress: countRealProgress(
        _paragraphs,
      ),
      cfi: _controller.generateEpubCfi() ?? "",
    );
  }

  void _gotoEpubCfi(
    String? epubCfi, {
    double alignment = 0,
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.linear,
  }) {
    _epubCfiReader?.epubCfi = epubCfi;
    final index = _epubCfiReader?.paragraphIndexByCfiFragment;

    if (index == null) {
      return;
    }

    _itemScrollController?.scrollTo(
      index: index,
      duration: duration,
      alignment: alignment,
      curve: curve,
    );
  }

  void _onLinkPressed(String maybeHref) {
    if (maybeHref.contains('://')) {
      widget.onExternalLinkPressed?.call(maybeHref);
      return;
    }

    final href = hrefMap[maybeHref] ?? maybeHref;

    // Chapter01.xhtml#ph1_1 -> [ph1_1, Chapter01.xhtml] || [ph1_1]
    String? hrefIdRef;
    String? hrefFileName;

    if (href.contains('#')) {
      final dividedHref = href.split('#');
      if (dividedHref.length == 1) {
        hrefIdRef = href;
      } else {
        hrefFileName = dividedHref[0];
        hrefIdRef = dividedHref[1];
      }
    } else {
      hrefFileName = href;
    }

    if (hrefIdRef == null) {
      final chapter = _chapterByFileName(hrefFileName);
      if (chapter != null) {
        final cfi = _epubCfiReader?.generateCfiChapter(
          book: _controller._document,
          chapter: chapter,
          additional: ['/4/2'],
        );

        _gotoEpubCfi(cfi);
      }
      return;
    } else {
      final paragraph = _paragraphByIdRef(hrefIdRef);
      final chapter =
          paragraph != null ? _chapters[paragraph.chapterIndex] : null;

      if (chapter != null && paragraph != null) {
        final paragraphIndex =
            _epubCfiReader?.getParagraphIndexByElement(paragraph.element);
        final cfi = _epubCfiReader?.generateCfi(
          book: _controller._document,
          chapter: chapter,
          paragraphIndex: paragraphIndex,
        );

        _gotoEpubCfi(cfi);
      }

      return;
    }
  }

  Paragraph? _paragraphByIdRef(String idRef) =>
      _paragraphs.firstWhereOrNull((paragraph) {
        if (paragraph.element.id == idRef) {
          return true;
        }

        return paragraph.element.children.isNotEmpty &&
            paragraph.element.children[0].id == idRef;
      });

  EpubChapter? _chapterByFileName(String? fileName) =>
      _chapters.firstWhereOrNull((chapter) {
        if (fileName != null) {
          if (chapter.ContentFileName!.contains(fileName)) {
            return true;
          } else {
            return false;
          }
        }
        return false;
      });

  int _getChapterIndexBy({
    required int positionIndex,
    double? trailingEdge,
    double? leadingEdge,
  }) {
    final posIndex = _getAbsParagraphIndexBy(
      positionIndex: positionIndex,
      trailingEdge: trailingEdge,
      leadingEdge: leadingEdge,
    );
    final index = posIndex >= _chapterIndexes.last
        ? _chapterIndexes.length
        : _chapterIndexes.indexWhere((chapterIndex) {
            if (posIndex < chapterIndex) {
              return true;
            }
            return false;
          });

    return index - 1;
  }

  int _getParagraphIndexBy({
    required int positionIndex,
    double? trailingEdge,
    double? leadingEdge,
  }) {
    final posIndex = _getAbsParagraphIndexBy(
      positionIndex: positionIndex,
      trailingEdge: trailingEdge,
      leadingEdge: leadingEdge,
    );

    final index = _getChapterIndexBy(positionIndex: posIndex);

    if (index == -1) {
      return posIndex;
    }

    return posIndex - _chapterIndexes[index];
  }

  int _getAbsParagraphIndexBy({
    required int positionIndex,
    double? trailingEdge,
    double? leadingEdge,
  }) {
    int posIndex = positionIndex;
    if (trailingEdge != null &&
        leadingEdge != null &&
        trailingEdge < _minTrailingEdge &&
        leadingEdge < _minLeadingEdge) {
      posIndex += 1;
    }

    return posIndex;
  }

  static Widget _chapterDividerBuilder(EpubChapter chapter) => Container(
        height: 56,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0x24000000),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          chapter.Title ?? '',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  static Widget _chapterBuilder(
    BuildContext context,
    EpubViewBuilders builders,
    EpubBook document,
    List<EpubChapter> chapters,
    List<Paragraph> paragraphs,
    int index,
    int chapterIndex,
    int paragraphIndex,
    ExternalLinkPressed onExternalLinkPressed,
  ) {
    if (paragraphs.isEmpty) {
      return Container();
    }

    final defaultBuilder = builders as EpubViewBuilders<DefaultBuilderOptions>;
    final options = defaultBuilder.options;

    return Column(
      children: <Widget>[
        if (chapterIndex >= 0 && paragraphIndex == 0)
          builders.chapterDividerBuilder(chapters[chapterIndex]),
        Html(
          data: paragraphs[index].element.outerHtml,
          onLinkTap: (href, _, __) => onExternalLinkPressed(href!),
          style: {
            'html': Style(
              padding: HtmlPaddings.only(
                top: (options.paragraphPadding as EdgeInsets?)?.top,
                right: (options.paragraphPadding as EdgeInsets?)?.right,
                bottom: (options.paragraphPadding as EdgeInsets?)?.bottom,
                left: (options.paragraphPadding as EdgeInsets?)?.left,
              ),
            ).merge(Style.fromTextStyle(options.textStyle)),
          },
          extensions: [
            TagExtension(
              tagsToExtend: {"img"},
              builder: (imageContext) {
                final url =
                    imageContext.attributes['src']!.replaceAll('../', '');
                final content = Uint8List.fromList(
                    document.Content!.Images![url]!.Content!);
                return Image(
                  image: MemoryImage(content),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoaded(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      child: ScrollablePositionedList.builder(
        shrinkWrap: widget.shrinkWrap,
        initialScrollIndex: (_controller.lastResult.lastPlace?.index ?? 1) - 1,
        initialAlignment: convertSmallModelToProgress(
            _controller.lastResult.lastPlace?.percent ?? 0),
        itemCount: _paragraphs.length,
        itemScrollController: _itemScrollController,
        itemPositionsListener: _itemPositionListener,
        itemBuilder: (BuildContext context, int index) {
          return widget.builders.chapterBuilder(
            context,
            widget.builders,
            widget.controller._document!,
            _chapters,
            _paragraphs,
            index,
            _getChapterIndexBy(positionIndex: index),
            _getParagraphIndexBy(positionIndex: index),
            _onLinkPressed,
          );
        },
      ),
    );
  }

  static Widget _builder(
    BuildContext context,
    EpubViewBuilders builders,
    EpubViewLoadingState state,
    WidgetBuilder loadedBuilder,
    Exception? loadingError,
  ) {
    final Widget content = () {
      switch (state) {
        case EpubViewLoadingState.loading:
          return KeyedSubtree(
            key: const Key('epubx.root.loading'),
            child: builders.loaderBuilder?.call(context) ?? const SizedBox(),
          );
        case EpubViewLoadingState.error:
          return KeyedSubtree(
            key: const Key('epubx.root.error'),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: builders.errorBuilder?.call(context, loadingError!) ??
                  Center(child: Text(loadingError.toString())),
            ),
          );
        case EpubViewLoadingState.success:
          return KeyedSubtree(
            key: const Key('epubx.root.success'),
            child: loadedBuilder(context),
          );
      }
    }();

    final defaultBuilder = builders as EpubViewBuilders<DefaultBuilderOptions>;
    final options = defaultBuilder.options;

    return AnimatedSwitcher(
      duration: options.loaderSwitchDuration,
      transitionBuilder: options.transitionBuilder,
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      contextMenuBuilder: (context, selectableRegionState) {
        return ReaderTextSelectionToolbar(
            selectableRegionState: selectableRegionState);
      },
      child: widget.builders.builder(
        context,
        widget.builders,
        _controller.loadingState.value,
        _buildLoaded,
        _loadingError,
      ),
    );
  }

  Future<void>? jumpToLastPlace({
    required LastPlaceModel lastPlace,
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.linear,
  }) async {
    _itemPositionListener?.itemPositions.removeListener(positionScrollListener);
    scrollToPlace = lastPlace;
    didScrollToLastPlace = false;
    _itemScrollController?.jumpTo(
      index: lastPlace.index ?? 0,
      alignment: 0,
    );
    _itemPositionListener?.itemPositions.addListener(positionScrollListener);
  }

  void positionScrollListener() async {
    if (!didScrollToLastPlace) {
      final position = _itemPositionListener?.itemPositions.value.first;
      if (position?.index == scrollToPlace?.index &&
          scrollToPlace?.index != null) {
        didScrollToLastPlace = true;
        _itemScrollController?.jumpTo(
          index: scrollToPlace!.index!,
          alignment: -(position?.itemTrailingEdge ?? 0) *
              (scrollToPlace?.percent ?? 0),
        );
      }
    }
  }
}
