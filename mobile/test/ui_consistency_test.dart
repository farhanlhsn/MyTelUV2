import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source scans that keep the consistency sweep of the UI from rotting: one theme colour, accessible
/// back buttons, cached network images, readable text sizes, one date formatting path.
///
/// Run from mobile/ (flutter test).
void main() {
  final List<File> sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart') && !f.path.contains('._'))
      .toList();

  String normalised(File f) => f.path.replaceAll('\\', '/');

  /// `file:line` of every line of lib/ matching [pattern], outside [except] (path suffixes).
  List<String> lines(RegExp pattern, {List<String> except = const <String>[]}) {
    final List<String> found = <String>[];
    for (final File file in sources) {
      if (except.any(normalised(file).endsWith)) continue;
      final List<String> content = file.readAsLinesSync();
      for (int i = 0; i < content.length; i++) {
        if (pattern.hasMatch(content[i])) found.add('${normalised(file)}:${i + 1}');
      }
    }
    return found;
  }

  test('the brand red comes from AppColors, not from a literal', () {
    expect(
      lines(RegExp(r'0xFFE63946', caseSensitive: false), except: <String>['utils/app_theme.dart']),
      isEmpty,
    );
  });

  test('network images are cached (CachedNetworkImage), never Image.network / NetworkImage', () {
    // "CachedNetworkImage(" contains "NetworkImage(" too, hence the look-behind
    expect(lines(RegExp(r'Image\.network\(|(?<!Cached)NetworkImage\(')), isEmpty);
  });

  test('RichText is Text.rich (RichText ignores the text scale)', () {
    expect(lines(RegExp(r'\bRichText\(')), isEmpty);
  });

  test('no text is smaller than 11', () {
    expect(
      lines(RegExp(r'fontSize:\s*(?<![\d.])([0-9](\.\d+)?|10(\.\d+)?)(?![\d.])')),
      isEmpty,
    );
  });

  test('every back arrow is an IconButton with a tooltip, not a bare GestureDetector icon', () {
    final List<String> offenders = <String>[];
    final RegExp gestureBack = RegExp(
      r'GestureDetector\(\s*onTap:[^;{}]*?child:\s*(const\s+)?Icon\(\s*Icons\.arrow_back',
      dotAll: true,
    );
    for (final File file in sources) {
      final String content = file.readAsStringSync();
      if (gestureBack.hasMatch(content)) offenders.add('${normalised(file)}: GestureDetector back');
      final int arrows = RegExp(r'Icons\.arrow_back').allMatches(content).length;
      final int tooltips = RegExp(r"tooltip: 'Kembali").allMatches(content).length;
      if (arrows > tooltips) {
        offenders.add('${normalised(file)}: $arrows back icons, $tooltips tooltips');
      }
    }
    expect(offenders, isEmpty);
  });

  test('dates are formatted by date_helper (WIB, id_ID), not by DateFormat in a page', () {
    expect(
      lines(RegExp(r'\bDateFormat\('), except: <String>['utils/date_helper.dart']),
      isEmpty,
    );
  });
}
