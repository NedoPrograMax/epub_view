import 'package:epub_view/src/data/models/reader_result.dart';
import 'package:rxdart/rxdart.dart';

class Repository {
  ReaderResult lastReadResult;
  final void Function(ReaderResult result) onSave;

  Repository({
    required this.onSave,
    required this.lastReadResult,
  }) {
    _textStream.debounceTime(_debounceTime).listen((result) {
      onSave(result);
    });
  }

  final _textStream = BehaviorSubject<ReaderResult>();

  static const _debounceTime = Duration(seconds: 2);

  void addData(ReaderResult model) {
    lastReadResult = model;
    _textStream.add(model);
  }

  void closeStream() {
    _textStream.close();
  }
}
