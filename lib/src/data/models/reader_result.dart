import 'package:epub_view/src/data/models/last_place_model.dart';

class ReaderResult {
  final LastPlaceModel? lastPlace;
  final List<LastPlaceModel> chapters;
  final double lastProgress;
  final double realProgress;
  final int charactersRead;

  ReaderResult({
    required this.lastPlace,
    required this.chapters,
    required this.lastProgress,
    required this.realProgress,
    required this.charactersRead,
  });
}
