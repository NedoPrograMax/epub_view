import 'package:epub_view/src/ui/selection_toolbar_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ReaderTextSelectionToolbar extends StatelessWidget {
  final SelectableRegionState selectableRegionState;
  const ReaderTextSelectionToolbar({
    super.key,
    required this.selectableRegionState,
  });

  @override
  Widget build(BuildContext context) {
    return AdaptiveTextSelectionToolbar(
      anchors: selectableRegionState.contextMenuAnchors,
      children: selectableRegionState.contextMenuButtonItems
          .map((ContextMenuButtonItem buttonItem) {
        return SelectionToolbarItem(
          text: CupertinoTextSelectionToolbarButton.getButtonLabel(
            context,
            buttonItem,
          ),
          onTap: buttonItem.onPressed,
        );
      }).toList(),
    );
  }
}
