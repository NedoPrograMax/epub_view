import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:epub_view/src/data/epub_cfi_reader.dart';
import 'package:epub_view/src/data/epub_parser.dart';
import 'package:epub_view/src/data/models/chapter.dart';
import 'package:epub_view/src/data/models/chapter_view_value.dart';
import 'package:epub_view/src/data/models/last_place_model.dart';
import 'package:epub_view/src/data/models/paragraph.dart';
import 'package:epub_view/src/data/models/parsed_epub.dart';
import 'package:epub_view/src/data/models/reader_result.dart';
import 'package:epub_view/src/data/repository.dart';
import 'package:epub_view/src/helpers/extensions.dart';
import 'package:epub_view/src/helpers/utils.dart';
import 'package:epub_view/src/ui/chapter_divider.dart';
import 'package:epub_view/src/ui/reader_test_selection_toolbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:html/dom.dart' as dom;
import 'package:scrollable_positioned_list_extended/scrollable_positioned_list_extended.dart';

import '../data/models/parse_paragraph_result.dart';

export 'package:epubx/epubx.dart' hide Image;

part '../epub_controller.dart';
part '../helpers/epub_view_builders.dart';

//const _minTrailingEdge = 0.55;
//const _minLeadingEdge = -0.05;

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
  List<Paragraph> lastParagraphs = [];

  Duration paragraphDuration = Duration.zero;
  late final Repository repository;
  double paragraphStartPercent = 0;
  Map<String, String> hrefMap = {};
  final scrollTag = "scrollTag";

  EpubController get _controller => widget.controller;
  bool didScrollToLastPlace = false;
  LastPlaceModel? scrollToPlace;
  ScrollPosition? lastScrollPosition;

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
          SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
            widget.onDocumentError?.call(_loadingError);
          });

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
    // EasyDebounce.cancel(scrollTag);

    super.dispose();
  }

  void _scrollListener(ScrollNotifier notification) {
    lastScrollPosition = notification.position;
  }

  Future<bool> _init() async {
    if (_controller.isBookLoaded.value) {
      return true;
    }
    _chapters = EpubParser.parseChapters(_controller._document!);
    late final ParseParagraphsResult parseParagraphsResult;
    if (_controller._parsedEpub != null) {
      parseParagraphsResult = _controller._parsedEpub!.parseParagraphsResult;
    } else {
      parseParagraphsResult =
          await compute(EpubParser().parseParagraphs, _chapters);
      _controller.onParsedSave(
        ParsedEpub(
          parseParagraphsResult: parseParagraphsResult,
          epubBook: _controller._document!,
        ),
      );
    }
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
      _paragraphs[(lastParagraph.index ?? 1) - 1]
          .setPercent(lastParagraph.percent ?? 0);
    }
  }

  void _changeListener() {
    // EasyDebounce.debounce(scrollTag, const Duration(milliseconds: 100), () {
    final result = countResult();
    if (result != null) {
      repository.addData(result);
    }
    //   });
  }

  List<ItemPosition> getCurrentPositions() {
    final positions = _itemPositionListener!.itemPositions.value;
    final sortedPositions = positions
        .sorted((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
    final onScreenPositions = sortedPositions
        .where(
          (element) =>
              (element.itemLeadingEdge >= 0 && element.itemLeadingEdge < 1) ||
              (element.itemTrailingEdge > 0 && element.itemTrailingEdge <= 1) ||
              (element.itemLeadingEdge < 0 && element.itemTrailingEdge >= 1),
        )
        .toList();

    return onScreenPositions;
  }

  ReaderResult? countResult() {
    if (_paragraphs.isEmpty ||
        _itemPositionListener!.itemPositions.value.isEmpty) {
      return null;
    }

    final positions = getCurrentPositions();
    final chapterIndex = _getChapterIndexBy(
      positionIndex: positions.first.index,
      trailingEdge: positions.first.itemTrailingEdge,
      leadingEdge: positions.first.itemLeadingEdge,
    );
    final paragraphsIndexes = _getAbsParagraphsIndexesBy(positions);
    final paragraphsAbsIndexes = _getAbsParagraphsIndexesBy(positions);
    final paragraphs = [
      for (var index in paragraphsAbsIndexes) _paragraphs[index]
    ];
    for (var i = 0; i < paragraphs.length; i++) {
      if (!lastParagraphs.contains(paragraphs[i])) {
        paragraphs[i].enterScreen();
      }
    }
    for (var i = 0; i < lastParagraphs.length; i++) {
      if (!paragraphs.contains(lastParagraphs[i])) {
        lastParagraphs[i].leaveScreen();
      }
    }

    lastParagraphs = paragraphs;
    _currentValue = EpubChapterViewValue(
      chapter: chapterIndex >= 0 ? _chapters[chapterIndex] : null,
      chapterNumber: chapterIndex + 1,
      paragraphNumber: paragraphsIndexes.first + 1,
      position: positions.first,
    );

    final viewPercent = (_currentValue?.progress ?? 0.0) / 100.0;

    final positionsSeenParts = positions.map((e) => e.seenPart).toList();
    paragraphs.countProgress(
        DateTime.now().difference(paragraphStartTime), positionsSeenParts);

    paragraphStartTime = DateTime.now();
    final currentScrollPosition = getCurrentScrollPosition();
    final isTheEnd = currentScrollPosition?.atEdge == true &&
        currentScrollPosition?.pixels == currentScrollPosition?.maxScrollExtent;
    final countedProgress = isTheEnd
        ? 1.0
        : countUserProgress(
            _paragraphs,
            chapterNumber: chapterIndex,
            paragraphNumber: paragraphsAbsIndexes.first,
            lastPercent: viewPercent,
          );
    /* final userProgress = max(
      countedProgress,
      repository.lastReadResult.lastProgress,
    ); */

    _controller.currentValueListenable.value = _currentValue?.copyWith(
      lastProgress: countedProgress,
      scrollPosition: currentScrollPosition,
    );
    widget.onChapterChanged?.call(_currentValue);

    // +10k is needed so the percent is > 0. then it -
    final convertedPercent =
        convertProgressToSmallModel(positions.first.itemLeadingEdge);
    final countedLastPlace = LastPlaceModel(
      percent: convertedPercent,
      index: positions.first.index + 1,
    );
    /*  final lastPlace = repository.lastReadResult.lastPlace == null ||
            countedLastPlace.isAfter(repository.lastReadResult.lastPlace!)
        ? countedLastPlace
        : repository.lastReadResult.lastPlace; */
    final realProgressResult = countRealProgress(
      _paragraphs,
    );
    return ReaderResult(
      lastPlace: countedLastPlace,
      chapters: _paragraphs.removeZeros().toLastModels(),
      lastProgress: countedProgress,
      realProgress: realProgressResult.progress,
      charactersRead: realProgressResult.charactersRead,
    );
  }

  ScrollPosition? getCurrentScrollPosition() {
    if (lastScrollPosition == null) {
      _itemScrollController!.scrollListener(_scrollListener);
    }
    return lastScrollPosition;
  }

  void _gotoEpubCfi(
    String? epubCfi, {
    int? paragraphIndex,
    double alignment = 0,
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.linear,
  }) {
    final index = paragraphIndex;
    if (index == null) {
      _epubCfiReader?.epubCfi = epubCfi;
      _epubCfiReader?.paragraphIndexByCfiFragment;

      if (index == null) {
        return;
      }
    }

    _itemScrollController?.jumpTo(
      index: index,
      // duration: duration,
      alignment: alignment,
      //  curve: curve,
    );
  }

  int _getChapterStartIndex(EpubChapter chapter) {
    final index = _chapters.indexOf(chapter);
    if (index != -1) {
      final startIndex =
          index < _chapterIndexes.length ? _chapterIndexes[index] : 0;
      return startIndex;
    }
    return -1;
  }

  void _onLinkPressed(String href) {
    if (href.contains('://')) {
      widget.onExternalLinkPressed?.call(href);
      return;
    }

    href = hrefMap[href] ?? href;

    // Chapter01.xhtml#ph1_1 -> [ph1_1, Chapter01.xhtml] || [ph1_1]
    String? hrefIdRef;
    String? realIdRef;
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
    realIdRef = hrefIdRef;
    hrefIdRef = hrefMap[hrefIdRef] ?? hrefIdRef;

    if (hrefIdRef == null) {
      final chapter = _chapterByFileName(hrefFileName);

      if (chapter != null) {
        final startIndex = _getChapterStartIndex(chapter);
        if (startIndex != -1) {
          _gotoEpubCfi(null, paragraphIndex: startIndex);
        } else {
          final cfi = _epubCfiReader?.generateCfiChapter(
            book: _controller._document,
            chapter: chapter,
            additional: ['/4/2'],
          );

          _gotoEpubCfi(cfi);
        }
      }
      return;
    } else {
      final paragraphIndex = _paragraphIndexByIdRef(hrefIdRef, realIdRef);
      /*final chapter =
          paragraph != null ? _chapters[paragraph.chapterIndex] : null;

      if (chapter != null && paragraph != null) {
        final paragraphIndex =
            _epubCfiReader?.getParagraphIndexByElement(paragraph.element);
        final cfi = _epubCfiReader?.generateCfi(
          book: _controller._document,
          chapter: chapter,
          paragraphIndex: paragraphIndex,
        );
*/
      _gotoEpubCfi(null, paragraphIndex: paragraphIndex);
    }

    return;
  }

  int? _paragraphIndexByIdRef(String idRef, realIdRef) {
    int? maybeId;
    for (int i = 0; i < _paragraphs.length; i++) {
      final paragraph = _paragraphs[i];
      if (paragraph.element.doesMatchId(realIdRef)) {
        return i;
      }
      if (paragraph.element.doesMatchId(idRef)) {
        maybeId = i;
      }
    }
    return maybeId;
  }

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

  List<int> _getParagraphsIndexesBy(List<ItemPosition> positions) {
    final indexes = positions
        .map((e) => _getAbsParagraphIndexBy(
              positionIndex: e.index,
              leadingEdge: e.itemLeadingEdge,
              trailingEdge: e.itemTrailingEdge,
            ))
        .toList();

    return indexes;
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

  List<int> _getAbsParagraphsIndexesBy(List<ItemPosition> positions) {
    final indexes = positions
        .map((e) => _getAbsParagraphIndexBy(
              positionIndex: e.index,
              leadingEdge: e.itemLeadingEdge,
              trailingEdge: e.itemTrailingEdge,
            ))
        .toList();

    return indexes;
  }

  int _getAbsParagraphIndexBy({
    required int positionIndex,
    double? trailingEdge,
    double? leadingEdge,
  }) {
    int posIndex = positionIndex;

    return posIndex;
  }

  static Widget _chapterDividerBuilder(EpubChapter chapter) =>
      EpubChapterDivider(title: chapter.Title ?? "");

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
                try {
                  final url =
                      imageContext.attributes['src']!.replaceAll('../', '');
                  return displayImage(url, document.Content!.Images!);
                } catch (_) {
                  return const Text("Couldn't display the image");
                }
              },
            ),
            TagExtension(
              tagsToExtend: {"svg"},
              builder: (imageContext) {
                try {
                  final imageTag = imageContext.elementChildren
                      .firstWhere((element) => element.localName == 'image');
                  final attributeKey = imageTag.attributes.keys.firstWhere(
                    (element) =>
                        element is dom.AttributeName &&
                            element.name == "href" &&
                            element.prefix == "xlink" ||
                        element == "xlink:href",
                  );
                  final url =
                      imageTag.attributes[attributeKey]!.replaceAll('../', '');

                  return displayImage(url, document.Content!.Images!);
                } catch (_) {
                  return const Text("Couldn't display the image");
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  static Widget displayImage(
      String url, Map<String, EpubByteContentFile> images) {
    final content = getImageNoMatterCode(url, images);
    if (url.endsWith('svg')) {
      return SvgPicture.memory(content);
    } else {
      return Image(
        image: MemoryImage(content),
      );
    }
  }

  static Uint8List getImageNoMatterCode(
      String url, Map<String, EpubByteContentFile> images) {
    late final EpubByteContentFile image;

    if (images.containsKey(url)) {
      image = images[url]!;
    } else {
      final codedUrl = Uri.encodeFull(url);
      if (images.containsKey(codedUrl)) {
        image = images[codedUrl]!;
      } else {
        final fileName = getFileName(url);
        images.forEach((key, value) {
          if (getFileName(key) == fileName) {
            image = value;
            return;
          }
        });
      }
    }

    return Uint8List.fromList(image.Content!);
  }

  static String getFileName(String path) {
    final uri = Uri.parse(path);
    final fileName = uri.pathSegments.last;
    return fileName;
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
        addAutomaticKeepAlives: false,
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
      final position = getCurrentPositions().first;
      if (position.index == scrollToPlace?.index &&
          scrollToPlace?.index != null) {
        didScrollToLastPlace = true;
        _itemScrollController?.jumpTo(
          index: scrollToPlace!.index!,
          alignment:
              -(position.itemTrailingEdge ?? 0) * (scrollToPlace?.percent ?? 0),
        );
      }
    }
  }
}
