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

  test('no near-miss copies of the brand red either', () {
    // Each of these was a slightly different red on one page or another
    expect(
      lines(RegExp(r'0x(FFF85E55|FFF76F68|FFFC5F57|FFFF6B6B|FFD32F2F|FFB3261E)', caseSensitive: false)),
      isEmpty,
    );
  });

  test('one back arrow: appBackIcon, never a Material arrow_back of its own', () {
    expect(
      lines(RegExp(r'Icons\.arrow_back'), except: <String>['utils/app_theme.dart']),
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
      if (normalised(file).endsWith('utils/app_theme.dart')) continue;
      final String content = file.readAsStringSync();
      if (gestureBack.hasMatch(content)) offenders.add('${normalised(file)}: GestureDetector back');
      final int arrows = RegExp(r'Icons\.arrow_back|\bappBackIcon\b').allMatches(content).length;
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

  group('what the user reads is Indonesian and mapped, not a raw Dart error', () {
    // A log line may quote the raw error; what is shown must not
    final RegExp logLine = RegExp(r'debugLog|debugPrint|\bprint\(');

    List<String> userFacing(RegExp pattern, {List<String> except = const <String>[]}) {
      final List<String> found = <String>[];
      for (final File file in sources) {
        if (except.any(normalised(file).endsWith)) continue;
        final List<String> content = file.readAsLinesSync();
        for (int i = 0; i < content.length; i++) {
          final String line = content[i];
          if (line.trimLeft().startsWith('//')) continue;
          if (!logLine.hasMatch(line) && pattern.hasMatch(line)) {
            found.add('${normalised(file)}:${i + 1}');
          }
        }
      }
      return found;
    }

    test('no raw e.toString() is stored as an error message', () {
      expect(
        userFacing(RegExp(r'(_?error\w*|errorMessage(\.value)?)\s*=\s*e\.toString\(\)')),
        isEmpty,
      );
    });

    test('the caught error is never interpolated into the text', () {
      // $e followed by a quote, a space or a parenthesis; ${e} and ${e.toString()}
      expect(
        userFacing(RegExp(r'''\$e['"\s)]|\$\{e\}|\$\{e\.toString\(\)\}''')),
        isEmpty,
      );
    });

    test('no English "Failed to ...", "Network error", "Unknown" text', () {
      expect(
        userFacing(
          RegExp(r'''['"](Failed to |Network error|Unexpected error|Unknown\b|Invalid response)'''),
          // It still recognises the English wrappers that older service versions threw
          except: <String>['utils/kendaraan_helper.dart'],
        ),
        isEmpty,
      );
    });
  });
}
