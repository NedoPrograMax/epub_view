// ignore: unnecessary_import
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:universal_file/universal_file.dart';

class EpubDocument {
  static Future<EpubBook> openAsset(String assetName) async {
    final byteData = await rootBundle.load(assetName);
    final bytes = byteData.buffer.asUint8List();
    final book = compute<Uint8List, EpubBook>(
        (bytes) => EpubReader.readBook(bytes), bytes);
    return book;
  }

  static Future<EpubBook> openData(Uint8List bytes) async {
    final book = compute<Uint8List, EpubBook>(
        (bytes) => EpubReader.readBook(bytes), bytes);
    return book;
  }

  static Future<EpubBook> openFile(File file) async {
    final bytes = await file.readAsBytes();
    final book = compute<Uint8List, EpubBook>(
        (bytes) => EpubReader.readBook(bytes), bytes);
    return book;
  }

  static Future<EpubBook> openUrl(String url) async {
    final result = await Dio().get(url,
        options: Options(
          responseType: ResponseType.bytes,
          sendTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 120),
        ));
    final book = compute<Uint8List, EpubBook>(
        (bytes) => EpubReader.readBook(bytes), result.data);
    return book;
  }
}
