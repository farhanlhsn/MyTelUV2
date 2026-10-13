"""
Tests for server_result.parse_server_result (edge device <-> backend contract).

Dependency-free on purpose (standard library only), so it runs anywhere:

    python -m unittest edge_device/test_parse_server_result.py
    # or, from inside edge_device/
    python -m unittest test_parse_server_result

The backend (POST /api/v1/parkir/edge-entry) answers every outcome with
{ status, message, data: { gate_action: "OPEN" | "DENY", ... } }. The gate may
only open on an explicit OPEN; a DENY, an unknown value, a missing value or a
network error must all leave the gate closed (fail closed).
"""

import os
import sys
import unittest

# Make `server_result` importable no matter where the tests are started from
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from server_result import parse_server_result  # noqa: E402


def nested(status, message, **data):
    """Build a response in the shape the backend really sends"""
    return {'status': status, 'message': message, 'data': data}


class ParseServerResultTest(unittest.TestCase):
    def test_nested_open_opens_gate(self):
        result = nested(
            'success',
            'Selamat datang Budi! Kendaraan B1234XYZ masuk.',
            gate_action='OPEN',
            plate_text='B1234XYZ',
            owner='Budi',
            parkiran='Parkiran Utama',
            slot_tersisa=12,
            ocr_confidence=0.93,
        )

        parsed = parse_server_result(result)

        self.assertEqual(parsed['gate_action'], 'OPEN')
        self.assertTrue(parsed['success'])
        self.assertEqual(parsed['plate_text'], 'B1234XYZ')
        self.assertEqual(parsed['message'], 'Selamat datang Budi! Kendaraan B1234XYZ masuk.')
        self.assertAlmostEqual(parsed['ocr_confidence'], 0.93)

    def test_nested_deny_keeps_gate_closed(self):
        result = nested('error', 'Parkiran Utama penuh', gate_action='DENY')

        parsed = parse_server_result(result)

        self.assertEqual(parsed['gate_action'], 'DENY')
        self.assertFalse(parsed['success'])
        self.assertEqual(parsed['message'], 'Parkiran Utama penuh')
        self.assertEqual(parsed['plate_text'], '')
        self.assertEqual(parsed['ocr_confidence'], 0.0)

    def test_every_backend_deny_response_keeps_gate_closed(self):
        # The deny paths of parkirController.processEdgeEntry: 401, 400, 404, 403
        deny_responses = [
            nested('error', 'Unauthorized edge device', gate_action='DENY'),
            nested('error', 'Missing required fields: plate_text, parkiran_id, gate_type', gate_action='DENY'),
            nested('error', 'Kendaraan B1234XYZ tidak terdaftar atau belum terverifikasi', gate_action='DENY'),
            nested('error', 'Akun pemilik kendaraan tidak aktif', gate_action='DENY'),
            nested('error', 'Lokasi parkiran tidak ditemukan', gate_action='DENY'),
            nested('error', 'Kendaraan B1234XYZ sudah berada di dalam parkiran', gate_action='DENY'),
            nested('error', 'Kendaraan B1234XYZ tidak tercatat masuk di parkiran ini', gate_action='DENY'),
            nested('error', "Invalid gate_type. Use 'MASUK' or 'KELUAR'", gate_action='DENY'),
        ]

        for result in deny_responses:
            with self.subTest(message=result['message']):
                parsed = parse_server_result(result)
                self.assertEqual(parsed['gate_action'], 'DENY')
                self.assertFalse(parsed['success'])
                self.assertEqual(parsed['message'], result['message'])

    def test_legacy_top_level_open_still_opens(self):
        result = {
            'gate_action': 'OPEN',
            'plate_text': 'B1234XYZ',
            'message': 'ok',
            'ocr_confidence': 0.8,
        }

        parsed = parse_server_result(result)

        self.assertEqual(parsed['gate_action'], 'OPEN')
        self.assertEqual(parsed['plate_text'], 'B1234XYZ')
        self.assertEqual(parsed['message'], 'ok')
        self.assertAlmostEqual(parsed['ocr_confidence'], 0.8)

    def test_legacy_top_level_confidence_key_is_used(self):
        parsed = parse_server_result({'gate_action': 'OPEN', 'confidence': 0.7})

        self.assertAlmostEqual(parsed['ocr_confidence'], 0.7)

    def test_empty_dict_denies(self):
        parsed = parse_server_result({})

        self.assertEqual(parsed['gate_action'], 'DENY')
        self.assertFalse(parsed['success'])
        self.assertEqual(parsed['message'], '')
        self.assertEqual(parsed['plate_text'], '')
        self.assertEqual(parsed['ocr_confidence'], 0.0)

    def test_exception_dict_denies(self):
        # Shape returned by PlateDetector.send_to_server on a network/JSON error
        parsed = parse_server_result({'gate_action': 'DENY', 'error': 'x'})

        self.assertEqual(parsed['gate_action'], 'DENY')
        self.assertFalse(parsed['success'])
        self.assertEqual(parsed['message'], 'x')

    def test_non_dict_results_deny(self):
        for bad in (None, [], ['OPEN'], 'OPEN', 42, True):
            with self.subTest(value=bad):
                parsed = parse_server_result(bad)
                self.assertEqual(parsed['gate_action'], 'DENY')
                self.assertFalse(parsed['success'])

    def test_nested_value_wins_over_top_level(self):
        # A stray top-level OPEN must never override a nested DENY
        result = {
            'status': 'error',
            'gate_action': 'OPEN',
            'message': 'ditolak',
            'data': {'gate_action': 'DENY'},
        }

        parsed = parse_server_result(result)

        self.assertEqual(parsed['gate_action'], 'DENY')
        self.assertFalse(parsed['success'])

    def test_unknown_or_malformed_gate_action_denies(self):
        for action in ('ALLOW', 'open', ' OPEN', 'OPEN ', '', None, True, 1, ['OPEN'], {'a': 1}):
            with self.subTest(action=action):
                parsed = parse_server_result(nested('success', 'x', gate_action=action))
                self.assertEqual(parsed['gate_action'], 'DENY')
                self.assertFalse(parsed['success'])

    def test_missing_gate_action_in_data_denies(self):
        parsed = parse_server_result(nested('success', 'x', plate_text='B1234XYZ'))

        self.assertEqual(parsed['gate_action'], 'DENY')
        self.assertFalse(parsed['success'])
        self.assertEqual(parsed['plate_text'], 'B1234XYZ')

    def test_success_requires_success_status_and_open(self):
        self.assertTrue(parse_server_result(nested('success', 'x', gate_action='OPEN'))['success'])
        self.assertFalse(parse_server_result(nested('error', 'x', gate_action='OPEN'))['success'])
        self.assertFalse(parse_server_result(nested('success', 'x', gate_action='DENY'))['success'])
        self.assertFalse(parse_server_result({'gate_action': 'OPEN'})['success'])

    def test_non_dict_data_falls_back_to_top_level(self):
        for data in (None, [], 'x', 5):
            with self.subTest(data=data):
                parsed = parse_server_result({'gate_action': 'OPEN', 'message': 'ok', 'data': data})
                self.assertEqual(parsed['gate_action'], 'OPEN')
                self.assertEqual(parsed['message'], 'ok')

    def test_ocr_confidence_is_always_a_float(self):
        cases = [
            (0.5, 0.5),
            (1, 1.0),
            ('0.9', 0.9),
            (None, 0.0),
            ('not-a-number', 0.0),
            ([], 0.0),
        ]

        for raw, expected in cases:
            with self.subTest(raw=raw):
                parsed = parse_server_result(nested('success', 'x', gate_action='OPEN', ocr_confidence=raw))
                self.assertIsInstance(parsed['ocr_confidence'], float)
                self.assertAlmostEqual(parsed['ocr_confidence'], expected)

    def test_plate_text_is_always_a_string(self):
        parsed = parse_server_result(nested('success', 'x', gate_action='OPEN', plate_text=None))

        self.assertEqual(parsed['plate_text'], '')

    def test_result_has_exactly_the_documented_keys(self):
        parsed = parse_server_result({})

        self.assertEqual(
            sorted(parsed.keys()),
            ['gate_action', 'message', 'ocr_confidence', 'plate_text', 'success'],
        )

    def test_input_is_not_mutated(self):
        result = nested('success', 'x', gate_action='OPEN', plate_text='B1')
        snapshot = {'status': 'success', 'message': 'x', 'data': {'gate_action': 'OPEN', 'plate_text': 'B1'}}

        parse_server_result(result)

        self.assertEqual(result, snapshot)


if __name__ == '__main__':
    unittest.main()
