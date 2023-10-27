import 'package:epub_view/epub_view.dart';
import 'package:epub_view/src/ui/scroll_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class EpubViewBottomBar extends StatefulWidget {
  final EpubController controller;
  final Widget Function(double percent)? builder;
  final Color? backgroundColor;
  const EpubViewBottomBar({
    super.key,
    required this.controller,
    this.builder,
    this.backgroundColor,
  });

  @override
  State<EpubViewBottomBar> createState() => _EpubViewBottomBarState();
}

class _EpubViewBottomBarState extends State<EpubViewBottomBar> {
  bool showSlider = false;
  late final ValueNotifier<double> currentPercent;
  late final ScrollController? scrollController;

  @override
  void initState() {
    currentPercent =
        ValueNotifier(widget.controller.currentValue?.lastProgress ?? 0);
    scrollController = widget
        .controller.epubViewState?.itemScrollController?.primaryScrollController
      ?..addListener(scrollListener);
    super.initState();
  }

  @override
  void dispose() {
    scrollController?.removeListener(scrollListener);
    super.dispose();
  }

  void scrollListener() {
    if (scrollController != null) {
      if (scrollController!.position.userScrollDirection ==
          ScrollDirection.reverse) {
        showSlider = true;
      } else {
        showSlider = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 114,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnimatedSlide(
            duration: const Duration(milliseconds: 200),
            offset: showSlider ? Offset.zero : const Offset(0, 1),
            child: ScrollSlider(
              controller: widget.controller,
              backgroundColor: widget.backgroundColor,
              currentPercent: currentPercent,
            ),
          ),
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              border: const Border(
                top: BorderSide(
                    color: Color.fromARGB(255, 170, 170, 181), width: 0.5),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  showSlider = !showSlider;
                });
              },
              child: ValueListenableBuilder<double>(
                valueListenable: currentPercent,
                builder: (context, value, child) => widget.builder != null
                    ? widget.builder!(value)
                    : Center(
                        child: Text(
                          value.toString(),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
