import 'package:epub_view/src/data/models/chapter.dart';
import 'package:epub_view/src/ui/epub_view.dart';
import 'package:flutter/material.dart';

class EpubViewTableOfContents extends StatelessWidget {
  const EpubViewTableOfContents({
    required this.controller,
    this.padding,
    this.onScrollStarted,
    this.itemBuilder,
    this.loader,
    this.titleBuilder,
    Key? key,
  }) : super(key: key);

  final EdgeInsetsGeometry? padding;
  final EpubController controller;
  final VoidCallback? onScrollStarted;

  final Widget Function(
    BuildContext context,
    int index,
    EpubViewChapter chapter,
    int itemCount,
    bool isSelected,
  )? itemBuilder;
  final Widget? loader;
  final Widget Function(
    String title,
  )? titleBuilder;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<List<EpubViewChapter>>(
        valueListenable: controller.tableOfContentsListenable,
        builder: (_, data, child) {
          Widget content;

          if (data.isNotEmpty) {
            content = Padding(
              padding: EdgeInsets.only(
                left: 12,
                top: MediaQuery.of(context).padding.top + 4,
              ),
              child: Column(
                children: [
                  titleBuilder?.call(controller.getDocument()?.Title ?? "") ??
                      Text(controller.getDocument()?.Title ?? ""),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      key: Key('$runtimeType.content'),
                      itemBuilder: (context, index) => Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (onScrollStarted != null) {
                              onScrollStarted!();
                            }
                            controller.scrollTo(index: data[index].startIndex);
                          },
                          child: Ink(
                            child: itemBuilder?.call(
                                  context,
                                  index,
                                  data[index],
                                  data.length,
                                  index ==
                                      controller.currentValue?.chapterNumber,
                                ) ??
                                ListTile(
                                  title: Text(data[index].title!.trim()),
                                ),
                          ),
                        ),
                      ),
                      itemCount: data.length,
                    ),
                  ),
                ],
              ),
            );
          } else {
            content = KeyedSubtree(
              key: Key('$runtimeType.loader'),
              child: loader ?? const Center(child: CircularProgressIndicator()),
            );
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (Widget child, Animation<double> animation) =>
                FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: content,
          );
        },
      );
}
