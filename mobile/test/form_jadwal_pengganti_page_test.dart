import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mobile/pages/jadwal/form_jadwal_pengganti_page.dart';
import 'package:mobile/services/akademik_service.dart';

import 'support/stub_http_adapter.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  tearDown(() => Get.reset());

  Future<void> openForm(WidgetTester tester, StubHttpAdapter adapter) async {
    // Wide: the test font is far wider than a real one, the radio row of the form needs the room
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        // 24-hour clock: the time picker's text fields are then hour and minute only
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
        home: const Scaffold(),
      ),
    );
    Get.to(
      () => FormJadwalPenggantiPage(akademikService: AkademikService(dio: adapter.dio())),
      arguments: <String, dynamic>{'id_kelas': 3, 'nama_kelas': 'IF-44-01'},
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickTanggalAsli(WidgetTester tester) async {
    await tester.tap(find.text('Pilih Tanggal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  // The label next to a Radio is plain text; the radio itself is the tap target
  Future<void> chooseGantiJadwal(WidgetTester tester) async {
    await tester.tap(
      find.byWidgetPredicate((Widget w) => w is Radio<String> && w.value == 'GANTI_JADWAL'),
    );
    await tester.pumpAndSettle();
  }

  // Fills the first time field that still says "Pilih Jam": mulai first, then berakhir. With
  // [end] the last one: berakhir while mulai is still empty.
  Future<void> pickTime(
    WidgetTester tester,
    String hour,
    String minute, {
    bool end = false,
  }) async {
    await tester.tap(end ? find.text('Pilih Jam').last : find.text('Pilih Jam').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    // the fields of the picker, not the ones of the form behind it
    final Finder fields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), hour);
    await tester.enterText(fields.at(1), minute);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> body(StubHttpAdapter adapter) =>
      adapter.lastRequest!.data as Map<String, dynamic>;

  // These tests look at what the form sends. The server refuses, so the form stays open with its
  // error dialog: the success snackbar of the page (Get.snackbar) is not what is under test.
  final Map<String, dynamic> refused = <String, dynamic>{
    'status': 'error',
    'message': 'Ditolak untuk uji',
  };

  testWidgets('LIBUR: posts to the class route without id_kelas and without times', (tester) async {
    final adapter = StubHttpAdapter(400, refused);
    await openForm(tester, adapter);

    await pickTanggalAsli(tester);
    await tester.enterText(find.byType(TextFormField).last, 'Dosen dinas luar');
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    expect(adapter.lastRequest!.path, '/api/v1/akademik/kelas/3/jadwal-pengganti');
    final Map<String, dynamic> sent = body(adapter);
    expect(sent.containsKey('id_kelas'), isFalse);
    expect(sent['status'], 'LIBUR');
    expect(sent['alasan'], 'Dosen dinas luar');
    expect(sent.containsKey('jam_mulai_ganti'), isFalse);
    expect(sent.containsKey('jam_berakhir_ganti'), isFalse);
  });

  testWidgets('GANTI_JADWAL: sends the chosen times as HH:MM', (tester) async {
    final adapter = StubHttpAdapter(400, refused);
    await openForm(tester, adapter);

    await pickTanggalAsli(tester);
    await chooseGantiJadwal(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih Tanggal Baru'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await pickTime(tester, '8', '5');
    await pickTime(tester, '10', '30');
    await tester.enterText(find.byType(TextFormField).last, 'Bentrok seminar');
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    final Map<String, dynamic> sent = body(adapter);
    expect(sent.containsKey('id_kelas'), isFalse);
    expect(sent['status'], 'GANTI_JADWAL');
    expect(sent['jam_mulai_ganti'], '08:05');
    expect(sent['jam_berakhir_ganti'], '10:30');
  });

  testWidgets('an end before the start is refused on the form, nothing is sent', (tester) async {
    final adapter = StubHttpAdapter(400, refused);
    await openForm(tester, adapter);

    await pickTanggalAsli(tester);
    await chooseGantiJadwal(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih Tanggal Baru'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await pickTime(tester, '10', '0');
    await pickTime(tester, '9', '0');

    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('Jam berakhir harus setelah jam mulai'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, 'Bentrok seminar');
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    expect(adapter.requests, isEmpty);
    expect(find.text('Jam berakhir harus setelah jam mulai'), findsOneWidget);
  });

  testWidgets('only one time chosen is refused, with the missing one named', (tester) async {
    final adapter = StubHttpAdapter(400, refused);
    await openForm(tester, adapter);

    await pickTanggalAsli(tester);
    await chooseGantiJadwal(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih Tanggal Baru'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await pickTime(tester, '10', '0');
    await tester.enterText(find.byType(TextFormField).last, 'Bentrok seminar');
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    expect(adapter.requests, isEmpty);
    expect(find.text('Pilih jam berakhir'), findsOneWidget);
  });

  Future<void> openGantiJadwal(WidgetTester tester, StubHttpAdapter adapter) async {
    await openForm(tester, adapter);
    await pickTanggalAsli(tester);
    await chooseGantiJadwal(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih Tanggal Baru'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('picking only the start time shows no error yet', (tester) async {
    final adapter = StubHttpAdapter(400, refused);
    await openGantiJadwal(tester, adapter);

    await pickTime(tester, '10', '0');

    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('Pilih jam berakhir'), findsNothing);
    // the usual hint stays
    expect(find.text('Kosongkan jika sama dengan jam kelas asli'), findsOneWidget);
  });

  testWidgets('picking only the end time shows no error yet either', (tester) async {
    final adapter = StubHttpAdapter(400, refused);
    await openGantiJadwal(tester, adapter);

    await pickTime(tester, '12', '0', end: true);

    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('Pilih jam mulai'), findsNothing);
    expect(find.text('Kosongkan jika sama dengan jam kelas asli'), findsOneWidget);
  });

  testWidgets('the pair is checked as soon as both are picked, and the error goes when it is fixed',
      (tester) async {
    final adapter = StubHttpAdapter(400, refused);
    await openGantiJadwal(tester, adapter);

    await pickTime(tester, '10', '0');
    await pickTime(tester, '9', '0');
    expect(find.text('Jam berakhir harus setelah jam mulai'), findsOneWidget);

    // start moved before the end: fine again
    await tester.tap(find.text('10:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final Finder fields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '8');
    await tester.enterText(fields.at(1), '0');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Jam berakhir harus setelah jam mulai'), findsNothing);
  });

  testWidgets('a missing end time is still refused on submit, and the message stays until it is picked',
      (tester) async {
    final adapter = StubHttpAdapter(400, refused);
    await openGantiJadwal(tester, adapter);

    await pickTime(tester, '10', '0');
    await tester.enterText(find.byType(TextFormField).last, 'Bentrok seminar');
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();
    expect(adapter.requests, isEmpty);
    expect(find.text('Pilih jam berakhir'), findsOneWidget);

    await pickTime(tester, '11', '0');
    expect(find.text('Pilih jam berakhir'), findsNothing);
  });

  testWidgets('a 400 of the server is shown as the server wrote it', (tester) async {
    final adapter = StubHttpAdapter(400, <String, dynamic>{
      'status': 'error',
      'message': 'Tanggal asli harus jatuh pada hari Rabu sesuai jadwal kelas',
    });
    await openForm(tester, adapter);

    await pickTanggalAsli(tester);
    await tester.enterText(find.byType(TextFormField).last, 'Libur');
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    expect(
      find.text('Tanggal asli harus jatuh pada hari Rabu sesuai jadwal kelas'),
      findsOneWidget,
    );
    expect(find.textContaining('Failed'), findsNothing);
    // the form is usable again
    expect(
      tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Simpan Perubahan')).onPressed,
      isNotNull,
    );
  });
}
