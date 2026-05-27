import unittest
import urllib.request
import urllib.error
import json

class TestAIContract(unittest.TestCase):
    """
    End-to-End Contract and Integration Testing for Python AI Microservices
    Ensures that the API schemas and contracts between Node.js Backend and Python AI services are preserved.
    """
    
    FACE_SERVICE_URL = "http://localhost:5051"
    PLATE_SERVICE_URL = "http://localhost:5001"
    ANOMALY_SERVICE_URL = "http://localhost:5003"

    def _make_request(self, base_url, path, method="GET", data=None, headers=None):
        url = f"{base_url}{path}"
        req_headers = headers or {}
        
        req_data = None
        if data is not None:
            if isinstance(data, dict):
                req_data = json.dumps(data).encode("utf-8")
                req_headers["Content-Type"] = "application/json"
            else:
                req_data = data
                
        req = urllib.request.Request(url, data=req_data, headers=req_headers, method=method)
        
        try:
            with urllib.request.urlopen(req, timeout=5) as response:
                body = response.read().decode("utf-8")
                return response.status, json.loads(body)
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8")
            try:
                err_json = json.loads(body)
            except Exception:
                err_json = body
            return e.code, err_json
        except Exception as e:
            return 0, str(e)

    # ==================== HEALTH CHECKS ====================
    
    def test_face_health_check(self):
        """Verify Face Recognition Service Health Check Contract"""
        status, body = self._make_request(self.FACE_SERVICE_URL, "/health")
        self.assertEqual(status, 200, f"Face service unreachable: {body}")
        self.assertEqual(body.get("status"), "healthy")
        self.assertIn("Face Recognition API", body.get("service", ""))

    def test_plate_health_check(self):
        """Verify Plate Recognition Service Health Check Contract"""
        status, body = self._make_request(self.PLATE_SERVICE_URL, "/health")
        self.assertEqual(status, 200, f"Plate service unreachable: {body}")
        self.assertEqual(body.get("status"), "ok")
        self.assertEqual(body.get("service"), "plate-recognizer")

    def test_anomaly_health_check(self):
        """Verify Anomaly Detection Service Health Check Contract"""
        status, body = self._make_request(self.ANOMALY_SERVICE_URL, "/health")
        self.assertEqual(status, 200, f"Anomaly service unreachable: {body}")
        self.assertEqual(body.get("status"), "healthy")
        self.assertEqual(body.get("service"), "anomaly-detection-ai")

    # ==================== FACE RECOGNITION ====================

    def test_face_compare_contract(self):
        """Verify Face Comparison API Schema Contract"""
        # Two dummy 512-dimension face embedding vectors
        emb1 = [0.01] * 512
        emb2 = [0.015] * 512
        
        payload = {
            "embedding1": emb1,
            "embedding2": emb2
        }
        
        status, body = self._make_request(self.FACE_SERVICE_URL, "/compare", method="POST", data=payload)
        
        self.assertEqual(status, 200, f"Compare failed: {body}")
        self.assertIn("similarity", body)
        self.assertIn("is_same_person", body)
        self.assertIn("threshold", body)
        self.assertIsInstance(body["similarity"], float)
        self.assertIsInstance(body["is_same_person"], bool)

    def test_face_find_match_contract(self):
        """Verify Face Search/Match API Schema Contract"""
        target = [0.01] * 512
        embeddings = [
            [0.011] * 512,  # Close match
            [0.09] * 512    # Far match
        ]
        
        payload = {
            "target_embedding": target,
            "embeddings_list": embeddings
        }
        
        status, body = self._make_request(self.FACE_SERVICE_URL, "/find-match", method="POST", data=payload)
        
        self.assertEqual(status, 200, f"Find match failed: {body}")
        self.assertIn("best_match_index", body)
        self.assertIn("similarity", body)
        self.assertIn("is_match", body)
        self.assertIn("threshold", body)
        self.assertEqual(body["best_match_index"], 0) # emb1 is closer
        self.assertIsInstance(body["is_match"], bool)

    # ==================== ANOMALY DETECTION ====================

    def test_anomaly_detection_logic_and_ml_contract(self):
        """Verify Anomaly Detection API Logic & Isolation Forest Schema Contract"""
        # Dummy data simulating students and attendance patterns
        students = [
            {"id_user": 1},
            {"id_user": 2},
            {"id_user": 3}
        ]
        # Student 1 attended normally, Student 2 has low attendance (anomaly), Student 3 did duplicate check-ins
        attendance = [
            {"id_user": 1, "id_sesi": 1, "latitude": -6.97, "longitude": 107.63, "timestamp": "2026-05-25T08:05:00Z"},
            {"id_user": 1, "id_sesi": 2, "latitude": -6.97, "longitude": 107.63, "timestamp": "2026-05-25T09:05:00Z"},
            {"id_user": 3, "id_sesi": 1, "latitude": -6.97, "longitude": 107.63, "timestamp": "2026-05-25T08:05:00Z"},
            {"id_user": 3, "id_sesi": 1, "latitude": -6.97, "longitude": 107.63, "timestamp": "2026-05-25T08:06:00Z"}  # Duplicate
        ]
        sessions = [
            {"id_sesi": 1, "mulai": "2026-05-25T08:00:00Z", "selesai": "2026-05-25T09:00:00Z", "latitude": -6.97, "longitude": 107.63},
            {"id_sesi": 2, "mulai": "2026-05-25T09:00:00Z", "selesai": "2026-05-25T10:00:00Z", "latitude": -6.97, "longitude": 107.63}
        ]
        
        payload = {
            "students": students,
            "attendance": attendance,
            "sessions": sessions,
            "total_sessions": 2,
            "threshold": 0.5,
            "contamination": 0.1
        }
        
        status, body = self._make_request(self.ANOMALY_SERVICE_URL, "/detect-anomalies", method="POST", data=payload)
        
        self.assertEqual(status, 200, f"Anomaly failed: {body}")
        self.assertTrue(body.get("success"))
        self.assertIn("anomalies", body)
        self.assertGreaterEqual(body.get("count", 0), 1)
        
        # Verify specific anomaly types were identified correctly
        anom_types = [a["type_anomali"] for a in body["anomalies"]]
        self.assertIn("TIDAK_HADIR_BERULANG", anom_types) # Student 2 attended 0/2 sessions (< 50%)
        self.assertIn("KEHADIRAN_GANDA", anom_types) # Student 3 checked in twice in session 1

if __name__ == '__main__':
    unittest.main()
