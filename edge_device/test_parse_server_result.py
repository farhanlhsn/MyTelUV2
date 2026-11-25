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

from server_result import (  # noqa: E402
    parse_server_result,
    should_start_cooldown,
    transport_error_result,
)


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
        cases = [
            # (response, expected gate_action, expected success)
            (nested('success', 'x', gate_action='OPEN'), 'OPEN', True),
            (nested('error', 'x', gate_action='OPEN'), 'DENY', False),
            (nested('success', 'x', gate_action='DENY'), 'DENY', False),
            # legacy flat body without a status: still opens, but is not a "success" response
            ({'gate_action': 'OPEN'}, 'OPEN', False),
        ]

        for result, gate_action, success in cases:
            with self.subTest(result=result):
                parsed = parse_server_result(result)
                self.assertEqual(parsed['gate_action'], gate_action)
                self.assertEqual(parsed['success'], success)

    def test_contradictory_error_status_with_open_denies(self):
        # status says error but the body claims OPEN: never open the gate
        nested_result = {'status': 'error', 'message': 'x', 'data': {'gate_action': 'OPEN'}}
        flat_result = {'status': 'error', 'message': 'x', 'gate_action': 'OPEN'}

        for result in (nested_result, flat_result):
            with self.subTest(result=result):
                parsed = parse_server_result(result)
                self.assertEqual(parsed['gate_action'], 'DENY')
                self.assertFalse(parsed['success'])

    def test_any_status_other_than_success_denies_open(self):
        for status in ('error', 'fail', 'SUCCESS', 'Success', '', 0, False, True, 200, ['success']):
            with self.subTest(status=status):
                parsed = parse_server_result(nested(status, 'x', gate_action='OPEN'))
                self.assertEqual(parsed['gate_action'], 'DENY')
                self.assertFalse(parsed['success'])

    def test_absent_or_null_status_does_not_block_legacy_open(self):
        self.assertEqual(parse_server_result({'gate_action': 'OPEN'})['gate_action'], 'OPEN')
        self.assertEqual(parse_server_result({'status': None, 'gate_action': 'OPEN'})['gate_action'], 'OPEN')

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


class ShouldStartCooldownTest(unittest.TestCase):
    """Only a real server answer starts the duplicate cool-down; a transport error retries at once"""

    def test_server_open_starts_cooldown(self):
        self.assertTrue(should_start_cooldown(nested('success', 'ok', gate_action='OPEN')))

    def test_server_deny_starts_cooldown(self):
        # Every deny path of the backend carries status "error"
        self.assertTrue(should_start_cooldown(nested('error', 'Parkiran Utama penuh', gate_action='DENY')))
        self.assertTrue(should_start_cooldown({'status': 'error', 'message': 'Unauthorized edge device'}))

    def test_transport_error_does_not_start_cooldown(self):
        result = transport_error_result(Exception('network down'))

        self.assertFalse(should_start_cooldown(result))

    def test_legacy_exception_dict_without_marker_does_not_start_cooldown(self):
        # No status key: not a server answer
        self.assertFalse(should_start_cooldown({'gate_action': 'DENY', 'error': 'x'}))

    def test_marker_wins_even_if_a_status_is_present(self):
        self.assertFalse(should_start_cooldown({'status': 'error', '_transport_error': True}))

    def test_empty_null_and_non_dict_bodies_do_not_start_cooldown(self):
        for body in ({}, {'status': None}, None, [], ['x'], 'html', 42, True):
            with self.subTest(body=body):
                self.assertFalse(should_start_cooldown(body))


class TransportErrorResultTest(unittest.TestCase):
    def test_shape_and_gate_stays_closed(self):
        result = transport_error_result(ValueError('no json'))

        self.assertEqual(result['gate_action'], 'DENY')
        self.assertEqual(result['error'], 'no json')
        self.assertIs(result['_transport_error'], True)

        parsed = parse_server_result(result)
        self.assertEqual(parsed['gate_action'], 'DENY')
        self.assertFalse(parsed['success'])
        self.assertEqual(parsed['message'], 'no json')


if __name__ == '__main__':
    unittest.main()
