"""
End-to-End Contract and Integration Tests for Python AI Microservices.

Tests ensure that the API schemas and contracts between the Node.js backend and
the three Python AI services (Face Recognition, Plate Recognition, Anomaly
Detection) remain stable over time.

Only standard-library modules are used (urllib, io, json, uuid, unittest).
"""

import io
import json
import unittest
import urllib.error
import urllib.request
import uuid

# ---------------------------------------------------------------------------
# Minimal valid JPEG bytes (JFIF header + empty quantisation table + EOI)
# ---------------------------------------------------------------------------
MINIMAL_JPEG = (
    bytes(
        [
            0xFF,
            0xD8,
            0xFF,
            0xE0,
            0x00,
            0x10,
            0x4A,
            0x46,
            0x49,
            0x46,
            0x00,
            0x01,
            0x01,
            0x00,
            0x00,
            0x01,
            0x00,
            0x01,
            0x00,
            0x00,
            0xFF,
            0xDB,
            0x00,
            0x43,
            0x00,
        ]
    )
    + bytes(64)
    + bytes([0xFF, 0xD9])
)


class TestAIContract(unittest.TestCase):
    """
    Contract and integration tests for the three Python AI microservices.

    Test ordering:
        1. Health checks          — verify each service is alive and reports the correct contract
        2. Face Recognition       — /detect-face, /compare, /find-match
        3. Plate Recognition      — /api/recognize-plate
        4. Anomaly Detection      — /detect-anomalies
    """

    FACE_SERVICE_URL = "http://localhost:5051"
    PLATE_SERVICE_URL = "http://localhost:5001"
    ANOMALY_SERVICE_URL = "http://localhost:5003"

    # -----------------------------------------------------------------------
    # Low-level helpers
    # -----------------------------------------------------------------------

    def _make_request(self, base_url, path, method="GET", data=None, headers=None):
        """
        Send an HTTP request and return (status_code, parsed_body).

        * If *data* is a dict it is JSON-encoded and Content-Type is set to
          application/json automatically.
        * If *data* is bytes it is sent as-is; the caller must supply the
          correct Content-Type via *headers*.
        * On a connection-level error the function returns (0, error_string)
          so that callers can detect the service being offline and call
          self.skipTest().
        * The response body is always a dict (JSON keys) or, when the service
          returns non-JSON, a dict with a single ``"error"`` key whose value
          is the raw text.
        """
        url = f"{base_url}{path}"
        req_headers = dict(headers or {})

        req_data = None
        if data is not None:
            if isinstance(data, dict):
                req_data = json.dumps(data).encode("utf-8")
                req_headers["Content-Type"] = "application/json"
            else:
                req_data = data  # caller sets Content-Type in headers

        req = urllib.request.Request(
            url, data=req_data, headers=req_headers, method=method
        )

        try:
            with urllib.request.urlopen(req, timeout=5) as response:
                raw = response.read().decode("utf-8")
                return response.status, json.loads(raw)
        except urllib.error.HTTPError as exc:
            raw = exc.read().decode("utf-8")
            try:
                return exc.code, json.loads(raw)
            except Exception:
                return exc.code, {"error": raw}
        except Exception as exc:
            return 0, str(exc)

    def _make_multipart_request(
        self,
        base_url,
        path,
        fields=None,
        files=None,
        extra_headers=None,
    ):
        """
        Build and send a multipart/form-data request using only the standard
        library (urllib, io, uuid).

        :param fields:        dict of ``{name: value}`` for plain-text form
                              fields.
        :param files:         dict of ``{name: (filename, data_bytes,
                              content_type)}`` for file uploads.
        :param extra_headers: additional HTTP headers, e.g.
                              ``{"X-Test-Mode": "true"}``.
        :returns:             ``(status_code, response_dict)`` — same contract
                              as :meth:`_make_request`.
        """
        boundary = uuid.uuid4().hex
        body = io.BytesIO()

        # --- text fields ---
        if fields:
            for name, value in fields.items():
                body.write(f"--{boundary}\r\n".encode())
                body.write(
                    f'Content-Disposition: form-data; name="{name}"\r\n'.encode()
                )
                body.write(b"\r\n")
                body.write(str(value).encode("utf-8"))
                body.write(b"\r\n")

        # --- file uploads ---
        if files:
            for name, (filename, data_bytes, content_type) in files.items():
                body.write(f"--{boundary}\r\n".encode())
                body.write(
                    f'Content-Disposition: form-data; name="{name}"; '
                    f'filename="{filename}"\r\n'.encode()
                )
                body.write(f"Content-Type: {content_type}\r\n".encode())
                body.write(b"\r\n")
                body.write(data_bytes)
                body.write(b"\r\n")

        body.write(f"--{boundary}--\r\n".encode())

        headers = dict(extra_headers or {})
        headers["Content-Type"] = f"multipart/form-data; boundary={boundary}"

        return self._make_request(
            base_url, path, method="POST", data=body.getvalue(), headers=headers
        )

    def _skip_if_unavailable(self, status, body, service_name):
        """Skip the current test with an informative message when *status* is
        0, which indicates a connection-level failure (service not running)."""
        if status == 0:
            self.skipTest(f"Service unavailable: {service_name} — {body}")

    # -----------------------------------------------------------------------
    # 1. Health Checks
    # -----------------------------------------------------------------------

    def test_face_health_check(self):
        """Face Recognition /health must return status='healthy' and the correct service name."""
        status, body = self._make_request(self.FACE_SERVICE_URL, "/health")
        self._skip_if_unavailable(status, body, "Face Recognition (5051)")
        self.assertEqual(
            status,
            200,
            f"Expected HTTP 200 from /health, got {status}: {body}",
        )
        self.assertEqual(
            body.get("status"),
            "healthy",
            f"Expected status='healthy', got: {body}",
        )
        self.assertIn(
            "Face Recognition API",
            body.get("service", ""),
            f"Expected 'Face Recognition API' in service field, got: {body}",
        )

    def test_plate_health_check(self):
        """Plate Recognition /health must return status='ok' and service='plate-recognizer'."""
        status, body = self._make_request(self.PLATE_SERVICE_URL, "/health")
        self._skip_if_unavailable(status, body, "Plate Recognition (5001)")
        self.assertEqual(
            status,
            200,
            f"Expected HTTP 200 from /health, got {status}: {body}",
        )
        self.assertEqual(
            body.get("status"),
            "ok",
            f"Expected status='ok', got: {body}",
        )
        self.assertEqual(
            body.get("service"),
            "plate-recognizer",
            f"Expected service='plate-recognizer', got: {body}",
        )

    def test_anomaly_health_check(self):
        """Anomaly Detection /health must return status='healthy' and the correct service name."""
        status, body = self._make_request(self.ANOMALY_SERVICE_URL, "/health")
        self._skip_if_unavailable(status, body, "Anomaly Detection (5003)")
        self.assertEqual(
            status,
            200,
            f"Expected HTTP 200 from /health, got {status}: {body}",
        )
        self.assertEqual(
            body.get("status"),
            "healthy",
            f"Expected status='healthy', got: {body}",
        )
        self.assertEqual(
            body.get("service"),
            "anomaly-detection-ai",
            f"Expected service='anomaly-detection-ai', got: {body}",
        )

    # -----------------------------------------------------------------------
    # 2. Face Recognition
    # -----------------------------------------------------------------------

    def test_face_detect_single_in_test_mode(self):
        """POST /detect-face with a dummy JPEG + X-Test-Mode: true must return a full embedding."""
        status, body = self._make_multipart_request(
            self.FACE_SERVICE_URL,
            "/detect-face",
            files={"image": ("test.jpg", MINIMAL_JPEG, "image/jpeg")},
            extra_headers={"X-Test-Mode": "true"},
        )
        self._skip_if_unavailable(status, body, "Face Recognition (5051)")
        self.assertEqual(
            status,
            200,
            f"Expected HTTP 200 from /detect-face (test mode), got {status}: {body}",
        )
        self.assertTrue(
            body.get("success"),
            f"Expected success=True, got: {body}",
        )

        # embedding: list of 512 floats
        embedding = body.get("embedding", [])
        self.assertIsInstance(
            embedding,
            list,
            f"Expected embedding to be a list, got {type(embedding)}",
        )
        self.assertEqual(
            len(embedding),
            512,
            f"Expected embedding length 512, got {len(embedding)}",
        )

        # bbox: [x, y, w, h]
        bbox = body.get("bbox", [])
        self.assertIsInstance(
            bbox,
            list,
            f"Expected bbox to be a list, got {type(bbox)}",
        )
        self.assertEqual(
            len(bbox),
            4,
            f"Expected bbox length 4 ([x, y, w, h]), got {len(bbox)}",
        )

        # face_score: positive number
        face_score = body.get("face_score")
        self.assertIsInstance(
            face_score,
            (int, float),
            f"Expected face_score to be numeric, got {type(face_score)}",
        )
        self.assertGreater(
            face_score,
            0,
            f"Expected face_score > 0, got {face_score}",
        )

    def test_face_detect_no_image_returns_400(self):
        """POST /detect-face without an 'image' field must return HTTP 400 with success=False."""
        # Send a multipart body that has an unrelated field — no 'image' key
        status, body = self._make_multipart_request(
            self.FACE_SERVICE_URL,
            "/detect-face",
            fields={"wrong_field": "dummy_value"},
        )
        self._skip_if_unavailable(status, body, "Face Recognition (5051)")
        self.assertEqual(
            status,
            400,
            f"Expected HTTP 400 when 'image' field is absent, got {status}: {body}",
        )
        self.assertFalse(
            body.get("success"),
            f"Expected success=False, got: {body}",
        )
        self.assertIn(
            "error",
            body,
            f"Expected an 'error' key in the response body, got: {body}",
        )

    def test_face_compare_contract(self):
        """POST /compare with two valid 512-dim embeddings must return similarity, is_same_person, threshold."""
        emb1 = [0.01] * 512
        emb2 = [0.015] * 512
        payload = {"embedding1": emb1, "embedding2": emb2}

        status, body = self._make_request(
            self.FACE_SERVICE_URL, "/compare", method="POST", data=payload
        )
        self._skip_if_unavailable(status, body, "Face Recognition (5051)")
        self.assertEqual(
            status,
            200,
            f"Expected HTTP 200 from /compare, got {status}: {body}",
        )
        self.assertIn(
            "similarity", body, f"Expected 'similarity' key in response, got: {body}"
        )
        self.assertIn(
            "is_same_person",
            body,
            f"Expected 'is_same_person' key in response, got: {body}",
        )
        self.assertIn(
            "threshold", body, f"Expected 'threshold' key in response, got: {body}"
        )
        self.assertIsInstance(
            body["similarity"],
            float,
            f"Expected similarity to be float, got {type(body['similarity'])}",
        )
        self.assertIsInstance(
            body["is_same_person"],
            bool,
            f"Expected is_same_person to be bool, got {type(body['is_same_person'])}",
        )

    def test_face_compare_missing_embedding_returns_400(self):
        """POST /compare with only embedding1 (embedding2 absent) must return HTTP 400."""
        payload = {"embedding1": [0.1] * 512}  # embedding2 intentionally omitted

        status, body = self._make_request(
            self.FACE_SERVICE_URL, "/compare", method="POST", data=payload
        )
        self._skip_if_unavailable(status, body, "Face Recognition (5051)")
        self.assertEqual(
            status,
            400,
            f"Expected HTTP 400 when embedding2 is missing, got {status}: {body}",
        )
        self.assertIsNotNone(
            body.get("error"),
            f"Expected a non-None 'error' field in response, got: {body}",
        )

    def test_face_find_match_contract(self):
        """POST /find-match with a target and candidate list must return index, similarity, is_match, threshold."""
        target = [0.01] * 512
        embeddings = [
            [0.011] * 512,  # close match → expected best_match_index = 0
            [0.09] * 512,  # far match
        ]
        payload = {"target_embedding": target, "embeddings_list": embeddings}

        status, body = self._make_request(
            self.FACE_SERVICE_URL, "/find-match", method="POST", data=payload
        )
        self._skip_if_unavailable(status, body, "Face Recognition (5051)")
        self.assertEqual(
            status,
            200,
            f"Expected HTTP 200 from /find-match, got {status}: {body}",
        )
        self.assertIn(
            "best_match_index",
            body,
            f"Expected 'best_match_index' in response, got: {body}",
        )
        self.assertIn(
            "similarity", body, f"Expected 'similarity' in response, got: {body}"
        )
        self.assertIn("is_match", body, f"Expected 'is_match' in response, got: {body}")
        self.assertIn(
            "threshold", body, f"Expected 'threshold' in response, got: {body}"
        )
        self.assertEqual(
            body["best_match_index"],
            0,
            f"Expected best_match_index=0 (closest embedding is index 0), got: {body}",
        )
        self.assertIsInstance(
            body["is_match"],
            bool,
            f"Expected is_match to be bool, got {type(body['is_match'])}",
        )

    def test_face_find_match_missing_field_returns_400(self):
        """POST /find-match with only target_embedding (embeddings_list absent) must return HTTP 400."""
        payload = {
            "target_embedding": [0.1] * 512
        }  # embeddings_list intentionally omitted

        status, body = self._make_request(
            self.FACE_SERVICE_URL, "/find-match", method="POST", data=payload
        )
        self._skip_if_unavailable(status, body, "Face Recognition (5051)")
        self.assertEqual(
            status,
            400,
            f"Expected HTTP 400 when embeddings_list is missing, got {status}: {body}",
        )
        self.assertIsNotNone(
            body.get("error"),
            f"Expected a non-None 'error' field in response, got: {body}",
        )

    # -----------------------------------------------------------------------
    # 3. Plate Recognition
    # -----------------------------------------------------------------------

    def test_plate_recognize_in_test_mode(self):
        """POST /api/recognize-plate with a dummy JPEG + X-Test-Mode: true must return plate data."""
        status, body = self._make_multipart_request(
            self.PLATE_SERVICE_URL,
            "/api/recognize-plate",
            files={"image": ("test.jpg", MINIMAL_JPEG, "image/jpeg")},
            extra_headers={"X-Test-Mode": "true"},
        )
        self._skip_if_unavailable(status, body, "Plate Recognition (5001)")
        self.assertEqual(
            status,
            200,
            f"Expected HTTP 200 from /api/recognize-plate (test mode), got {status}: {body}",
        )
        self.assertTrue(
            body.get("success"),
            f"Expected success=True, got: {body}",
        )

        # plate_text: non-empty string
        plate_text = body.get("plate_text", "")
        self.assertIsInstance(
            plate_text,
            str,
            f"Expected plate_text to be str, got {type(plate_text)}",
        )
        self.assertGreater(
            len(plate_text),
            0,
            f"Expected plate_text to be non-empty, got: '{plate_text}'",
        )

        # confidence: float in [0, 1]
        confidence = body.get("confidence")
        self.assertIsInstance(
            confidence,
            (int, float),
            f"Expected confidence to be numeric, got {type(confidence)}",
        )
        self.assertGreaterEqual(
            confidence,
            0,
            f"Expected confidence >= 0, got {confidence}",
        )
        self.assertLessEqual(
            confidence,
            1,
            f"Expected confidence <= 1, got {confidence}",
        )

    def test_plate_recognize_no_image_returns_error(self):
        """POST /api/recognize-plate with no 'image' field must return a non-200 status (ideally 400)."""
        status, body = self._make_multipart_request(
            self.PLATE_SERVICE_URL,
            "/api/recognize-plate",
            fields={"other_field": "no_image_here"},
        )
        self._skip_if_unavailable(status, body, "Plate Recognition (5001)")
        self.assertNotEqual(
            status,
            200,
            f"Expected a non-200 response when 'image' field is absent, got {status}: {body}",
        )

    # -----------------------------------------------------------------------
    # 4. Anomaly Detection
    # -----------------------------------------------------------------------

    def test_anomaly_detection_logic_and_ml_contract(self):
        """
        Verify Anomaly Detection API Logic and Isolation Forest schema contract.

        Student 2 attends 0 out of 2 sessions  → TIDAK_HADIR_BERULANG
        Student 3 checks in twice in session 1  → KEHADIRAN_GANDA
        """
        students = [
            {"id_user": 1},
            {"id_user": 2},
            {"id_user": 3},
        ]
        attendance = [
            {
                "id_user": 1,
                "id_sesi": 1,
                "latitude": -6.97,
                "longitude": 107.63,
                "timestamp": "2026-05-25T08:05:00Z",
            },
            {
                "id_user": 1,
                "id_sesi": 2,
                "latitude": -6.97,
                "longitude": 107.63,
                "timestamp": "2026-05-25T09:05:00Z",
            },
            {
                "id_user": 3,
                "id_sesi": 1,
                "latitude": -6.97,
                "longitude": 107.63,
                "timestamp": "2026-05-25T08:05:00Z",
            },
            {
                # Duplicate check-in → KEHADIRAN_GANDA
                "id_user": 3,
                "id_sesi": 1,
                "latitude": -6.97,
                "longitude": 107.63,
                "timestamp": "2026-05-25T08:06:00Z",
            },
        ]
        sessions = [
            {
                "id_sesi": 1,
                "mulai": "2026-05-25T08:00:00Z",
                "selesai": "2026-05-25T09:00:00Z",
                "latitude": -6.97,
                "longitude": 107.63,
            },
            {
                "id_sesi": 2,
                "mulai": "2026-05-25T09:00:00Z",
                "selesai": "2026-05-25T10:00:00Z",
                "latitude": -6.97,
                "longitude": 107.63,
            },
        ]
        payload = {
            "students": students,
            "attendance": attendance,
            "sessions": sessions,
            "total_sessions": 2,
            "threshold": 0.5,
            "contamination": 0.1,
        }

        status, body = self._make_request(
            self.ANOMALY_SERVICE_URL, "/detect-anomalies", method="POST", data=payload
        )
        self._skip_if_unavailable(status, body, "Anomaly Detection (5003)")
        self.assertEqual(
            status,
            200,
            f"Expected HTTP 200 from /detect-anomalies, got {status}: {body}",
        )
        self.assertTrue(
            body.get("success"),
            f"Expected success=True, got: {body}",
        )
        self.assertIn(
            "anomalies",
            body,
            f"Expected 'anomalies' key in response, got: {body}",
        )
        self.assertGreaterEqual(
            body.get("count", 0),
            1,
            f"Expected at least 1 anomaly, got count={body.get('count')}",
        )

        anom_types = [a["type_anomali"] for a in body["anomalies"]]
        self.assertIn(
            "TIDAK_HADIR_BERULANG",
            anom_types,
            f"Expected TIDAK_HADIR_BERULANG (student 2 absent 0/2 sessions), "
            f"got anomaly types: {anom_types}",
        )
        self.assertIn(
            "KEHADIRAN_GANDA",
            anom_types,
            f"Expected KEHADIRAN_GANDA (student 3 duplicate check-in), "
            f"got anomaly types: {anom_types}",
        )

    def test_anomaly_empty_students_returns_zero(self):
        """POST /detect-anomalies with empty lists must return count=0 and an empty anomalies list."""
        payload = {
            "students": [],
            "attendance": [],
            "sessions": [],
            "total_sessions": 1,
        }
        status, body = self._make_request(
            self.ANOMALY_SERVICE_URL, "/detect-anomalies", method="POST", data=payload
        )
        self._skip_if_unavailable(status, body, "Anomaly Detection (5003)")
        self.assertEqual(
            status,
            200,
            f"Expected HTTP 200 for empty-students input, got {status}: {body}",
        )
        self.assertTrue(
            body.get("success"),
            f"Expected success=True, got: {body}",
        )
        self.assertEqual(
            body.get("count"),
            0,
            f"Expected count=0 for zero students, got {body.get('count')}",
        )
        self.assertEqual(
            body.get("anomalies"),
            [],
            f"Expected anomalies=[], got {body.get('anomalies')}",
        )

    def test_anomaly_missing_attendance_field_returns_400(self):
        """
        POST /detect-anomalies where an attendance record is missing the required
        'id_sesi' field must return HTTP 400 with success=False and an error
        message that contains the word 'missing'.
        """
        payload = {
            "students": [{"id_user": 1}],
            "attendance": [{"id_user": 1}],  # id_sesi intentionally absent
            "sessions": [],
            "total_sessions": 1,
        }
        status, body = self._make_request(
            self.ANOMALY_SERVICE_URL, "/detect-anomalies", method="POST", data=payload
        )
        self._skip_if_unavailable(status, body, "Anomaly Detection (5003)")
        self.assertEqual(
            status,
            400,
            f"Expected HTTP 400 for attendance record missing 'id_sesi', "
            f"got {status}: {body}",
        )
        self.assertFalse(
            body.get("success"),
            f"Expected success=False, got: {body}",
        )
        error_msg = body.get("error", "")
        self.assertIsInstance(
            error_msg,
            str,
            f"Expected 'error' to be a string, got {type(error_msg)}",
        )
        self.assertIn(
            "missing",
            error_msg.lower(),
            f"Expected error message to mention 'missing', got: '{error_msg}'",
        )

    def test_anomaly_invalid_total_sessions_returns_400(self):
        """POST /detect-anomalies with total_sessions=0 (below minimum of 1) must return HTTP 400."""
        payload = {
            "students": [],
            "attendance": [],
            "sessions": [],
            "total_sessions": 0,  # invalid: must be >= 1
        }
        status, body = self._make_request(
            self.ANOMALY_SERVICE_URL, "/detect-anomalies", method="POST", data=payload
        )
        self._skip_if_unavailable(status, body, "Anomaly Detection (5003)")
        self.assertEqual(
            status,
            400,
            f"Expected HTTP 400 for total_sessions=0, got {status}: {body}",
        )
        self.assertFalse(
            body.get("success"),
            f"Expected success=False for invalid total_sessions, got: {body}",
        )

    def test_anomaly_non_json_body_returns_400(self):
        """POST /detect-anomalies with a plain-text (non-JSON) body must return HTTP 400."""
        status, body = self._make_request(
            self.ANOMALY_SERVICE_URL,
            "/detect-anomalies",
            method="POST",
            data=b"this is not valid json",
            headers={"Content-Type": "text/plain"},
        )
        self._skip_if_unavailable(status, body, "Anomaly Detection (5003)")
        self.assertEqual(
            status,
            400,
            f"Expected HTTP 400 for non-JSON body, got {status}: {body}",
        )
        if isinstance(body, dict):
            self.assertFalse(
                body.get("success"),
                f"Expected success=False for non-JSON body, got: {body}",
            )

    def test_anomaly_schema_validation_fields(self):
        """
        Every anomaly object returned by /detect-anomalies must expose four
        typed fields:
            - id_user     (int)
            - type_anomali (str)
            - confidence  (float, 0 <= x <= 1)
            - description (str)
        """
        students = [
            {"id_user": 1},
            {"id_user": 2},
            {"id_user": 3},
        ]
        attendance = [
            {
                "id_user": 1,
                "id_sesi": 1,
                "latitude": -6.97,
                "longitude": 107.63,
                "timestamp": "2026-05-25T08:05:00Z",
            },
            {
                "id_user": 1,
                "id_sesi": 2,
                "latitude": -6.97,
                "longitude": 107.63,
                "timestamp": "2026-05-25T09:05:00Z",
            },
            {
                "id_user": 3,
                "id_sesi": 1,
                "latitude": -6.97,
                "longitude": 107.63,
                "timestamp": "2026-05-25T08:05:00Z",
            },
            {
                "id_user": 3,
                "id_sesi": 1,
                "latitude": -6.97,
                "longitude": 107.63,
                "timestamp": "2026-05-25T08:06:00Z",
            },
        ]
        sessions = [
            {
                "id_sesi": 1,
                "mulai": "2026-05-25T08:00:00Z",
                "selesai": "2026-05-25T09:00:00Z",
                "latitude": -6.97,
                "longitude": 107.63,
            },
            {
                "id_sesi": 2,
                "mulai": "2026-05-25T09:00:00Z",
                "selesai": "2026-05-25T10:00:00Z",
                "latitude": -6.97,
                "longitude": 107.63,
            },
        ]
        payload = {
            "students": students,
            "attendance": attendance,
            "sessions": sessions,
            "total_sessions": 2,
            "threshold": 0.5,
            "contamination": 0.1,
        }

        status, body = self._make_request(
            self.ANOMALY_SERVICE_URL, "/detect-anomalies", method="POST", data=payload
        )
        self._skip_if_unavailable(status, body, "Anomaly Detection (5003)")
        self.assertEqual(
            status,
            200,
            f"Expected HTTP 200, got {status}: {body}",
        )
        self.assertTrue(
            body.get("success"),
            f"Expected success=True, got: {body}",
        )

        anomalies = body.get("anomalies", [])
        self.assertGreater(
            len(anomalies),
            0,
            "Expected at least one anomaly in the response to validate the schema against",
        )

        for idx, anomaly in enumerate(anomalies):
            loc = f"anomalies[{idx}]"

            # id_user — int
            self.assertIn(
                "id_user",
                anomaly,
                f"{loc} is missing required field 'id_user': {anomaly}",
            )
            self.assertIsInstance(
                anomaly["id_user"],
                int,
                f"{loc}.id_user must be int, got {type(anomaly['id_user'])}",
            )

            # type_anomali — str
            self.assertIn(
                "type_anomali",
                anomaly,
                f"{loc} is missing required field 'type_anomali': {anomaly}",
            )
            self.assertIsInstance(
                anomaly["type_anomali"],
                str,
                f"{loc}.type_anomali must be str, got {type(anomaly['type_anomali'])}",
            )

            # confidence — float in [0, 1]
            self.assertIn(
                "confidence",
                anomaly,
                f"{loc} is missing required field 'confidence': {anomaly}",
            )
            self.assertIsInstance(
                anomaly["confidence"],
                (int, float),
                f"{loc}.confidence must be numeric, got {type(anomaly['confidence'])}",
            )
            self.assertGreaterEqual(
                anomaly["confidence"],
                0,
                f"{loc}.confidence must be >= 0, got {anomaly['confidence']}",
            )
            self.assertLessEqual(
                anomaly["confidence"],
                1,
                f"{loc}.confidence must be <= 1, got {anomaly['confidence']}",
            )

            # description — str
            self.assertIn(
                "description",
                anomaly,
                f"{loc} is missing required field 'description': {anomaly}",
            )
            self.assertIsInstance(
                anomaly["description"],
                str,
                f"{loc}.description must be str, got {type(anomaly['description'])}",
            )


if __name__ == "__main__":
    unittest.main()
