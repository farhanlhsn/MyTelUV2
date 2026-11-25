import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/kelas_hari_ini.dart';
import 'package:mobile/models/kelas.dart';
import 'package:mobile/models/matakuliah.dart';
import 'package:mobile/pages/home/kelas_hari_ini_card.dart';

const MatakuliahModel _mk = MatakuliahModel(
  idMatakuliah: 1,
  namaMatakuliah: 'Pemrograman Web',
  kodeMatakuliah: 'CSH4A3',
);

const DosenModel _dosen = DosenModel(
  idUser: 9,
  nama: 'Dr. Budi',
  username: 'budi',
);

SesiAbsensiModel _sesi({required bool requireFace}) => SesiAbsensiModel(
  idSesiAbsensi: 100,
  idKelas: 1,
  typeAbsensi: 'MASUK',
  requireFace: requireFace,
  mulai: DateTime.utc(2026, 10, 13, 1),
  selesai: DateTime.utc(2026, 10, 13, 2),
  status: true,
);

Future<void> _pumpCard(
  WidgetTester tester,
  KelasHariIniModel kelas, {
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          // same height the home carousel gives its cards
          child: SizedBox(
            width: 360,
            height: 200,
            child: KelasHariIniCard(kelas: kelas, onTap: onTap),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the course title as the headline of the card', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      const KelasHariIniModel(
        idKelas: 1,
        namaKelas: 'IF-44-01',
        ruangan: 'A101',
        jamMulai: '08:00:00',
        jamBerakhir: '10:00:00',
        matakuliah: _mk,
        dosen: _dosen,
      ),
    );

    expect(find.text('Pemrograman Web'), findsOneWidget);
    expect(find.text('Dosen: Dr. Budi'), findsOneWidget);
    expect(find.text('08:00 - 10:00'), findsOneWidget);
    expect(find.text('A101'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to the class name and survives a missing dosen', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      const KelasHariIniModel(idKelas: 1, namaKelas: 'IF-44-01'),
    );

    expect(find.text('IF-44-01'), findsOneWidget);
    expect(find.text('Jadwal tidak tersedia'), findsOneWidget);
    expect(find.text('Ruangan belum ditentukan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('badge says "Absen Wajah" when the session requires a face', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      KelasHariIniModel(
        idKelas: 1,
        namaKelas: 'IF-44-01',
        matakuliah: _mk,
        dosen: _dosen,
        hasActiveAbsensi: true,
        activeSesiAbsensi: _sesi(requireFace: true),
      ),
    );

    expect(find.text('Absen Wajah'), findsOneWidget);
    expect(find.text('Absen GPS'), findsNothing);
    expect(find.text('Pemrograman Web'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('badge says "Absen GPS" for a GPS-only session', (tester) async {
    await _pumpCard(
      tester,
      KelasHariIniModel(
        idKelas: 1,
        namaKelas: 'IF-44-01',
        matakuliah: _mk,
        dosen: _dosen,
        hasActiveAbsensi: true,
        activeSesiAbsensi: _sesi(requireFace: false),
      ),
    );

    expect(find.text('Absen GPS'), findsOneWidget);
    expect(find.text('Absen Wajah'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only a card with an active session reacts to taps', (
    tester,
  ) async {
    var taps = 0;
    await _pumpCard(
      tester,
      const KelasHariIniModel(
        idKelas: 1,
        namaKelas: 'IF-44-01',
        matakuliah: _mk,
      ),
      onTap: () => taps++,
    );
    await tester.tap(find.text('Pemrograman Web'));
    expect(taps, 0, reason: 'no active absensi session');

    await _pumpCard(
      tester,
      KelasHariIniModel(
        idKelas: 1,
        namaKelas: 'IF-44-01',
        matakuliah: _mk,
        hasActiveAbsensi: true,
        activeSesiAbsensi: _sesi(requireFace: false),
      ),
      onTap: () => taps++,
    );
    await tester.tap(find.text('Pemrograman Web'));
    expect(taps, 1);
  });
}
