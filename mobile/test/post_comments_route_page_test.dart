import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mobile/models/post_model.dart';
import 'package:mobile/pages/home/post_comments_route_page.dart';

/// The page behind a social notification: only the post id is known, so the post is fetched first.
/// (The success path hands the post to the existing CommentsPage, which has its own tests' worth of
/// network calls and is not rendered here.)
void main() {
  tearDown(() => Get.reset());

  Future<void> pumpPage(
    WidgetTester tester, {
    required Future<PostModel?> Function(int) loadPost,
    int? idPost,
    Object? arguments,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/',
        getPages: [
          GetPage<dynamic>(
            name: '/',
            page: () => PostCommentsRoutePage(loadPost: loadPost, idPost: idPost),
          ),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets('shows a spinner while the post loads, and asks for the right post', (tester) async {
    final completer = Completer<PostModel?>();
    final asked = <int>[];

    await pumpPage(
      tester,
      idPost: 42,
      loadPost: (id) {
        asked.add(id);
        return completer.future;
      },
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(asked, <int>[42]);
  });

  testWidgets('a post that does not exist (deleted) says so, and Coba Lagi asks again', (tester) async {
    var calls = 0;
    await pumpPage(
      tester,
      idPost: 42,
      loadPost: (id) async {
        calls++;
        return null;
      },
    );
    await tester.pump();

    expect(find.text('Postingan tidak ditemukan atau sudah dihapus.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Coba Lagi'));
    await tester.pump();
    await tester.pump();

    expect(calls, 2);
  });

  testWidgets('a network failure shows an Indonesian message and can be retried', (tester) async {
    var calls = 0;
    await pumpPage(
      tester,
      idPost: 42,
      loadPost: (id) async {
        calls++;
        throw Exception('Failed to get post: connection error');
      },
    );
    await tester.pump();

    expect(
      find.text('Tidak dapat memuat postingan. Periksa koneksi Anda lalu coba lagi.'),
      findsOneWidget,
    );
    expect(find.textContaining('Failed to get post'), findsNothing);

    await tester.tap(find.text('Coba Lagi'));
    await tester.pump();
    await tester.pump();
    expect(calls, 2);
  });

  testWidgets('without a usable post id nothing is requested', (tester) async {
    var calls = 0;
    await pumpPage(
      tester,
      idPost: null,
      loadPost: (id) async {
        calls++;
        return null;
      },
    );
    await tester.pump();

    expect(calls, 0);
    expect(find.text('Postingan tidak ditemukan atau sudah dihapus.'), findsOneWidget);
  });

  testWidgets('reads the post id from the route arguments', (tester) async {
    final asked = <int>[];
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/start',
        getPages: [
          GetPage<dynamic>(
            name: '/start',
            page: () => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Get.toNamed<dynamic>('/post', arguments: <String, dynamic>{'id_post': 9}),
                  child: const Text('buka'),
                ),
              ),
            ),
          ),
          GetPage<dynamic>(
            name: '/post',
            page: () => PostCommentsRoutePage(
              loadPost: (id) async {
                asked.add(id);
                return null;
              },
            ),
          ),
        ],
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(asked, <int>[9]);
  });
}
