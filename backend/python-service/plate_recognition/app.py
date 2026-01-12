"""
License Plate Recognition Service (OCR)
========================================

Server-side Python service for character recognition from license plate images.
Uses YOLOv8 for character detection and reconstruction.

This service receives cropped plate images from edge devices (Raspberry Pi)
and returns the recognized plate text.
"""

import cv2
import numpy as np
from pathlib import Path
import yaml
import logging
from flask import Flask, request, jsonify
from PIL import Image
import io
import os
import time
import requests as http_requests
from dotenv import load_dotenv

try:
    from ultralytics import YOLO
    USE_ULTRALYTICS = True
except ImportError:
    print("Ultralytics not available, trying ONNX...")
    import onnxruntime as ort
    USE_ULTRALYTICS = False

# Load environment variables from root project .env
# Path: backend/python-service/plate_recognition -> root
ROOT_DIR = Path(__file__).resolve().parent.parent.parent.parent  # Go up 4 levels to project root
ENV_PATH = ROOT_DIR / '.env'
load_dotenv(dotenv_path=ENV_PATH)

# Environment Configuration
NODEJS_BACKEND_URL = os.getenv('NODEJS_BACKEND_URL', 'http://localhost:3000')
EDGE_DEVICE_SECRET = os.getenv('EDGE_DEVICE_SECRET', 'your-secret-key')

class PlateRecognizer:
    def __init__(self, model_path, classes_path):
        """Initialize plate recognizer"""
        self.logger = logging.getLogger(__name__)
        
        # Load class names
        with open(classes_path, 'r') as f:
            self.class_names = [line.strip() for line in f.readlines()]
        
        self.logger.info(f"Loaded {len(self.class_names)} character classes")
        
        # Load model
        if USE_ULTRALYTICS and model_path.endswith('.pt'):
            self.model = YOLO(model_path)
            self.use_ultralytics = True
            self.logger.info(f"Loaded YOLOv8 model from {model_path}")
        else:
            # Use ONNX
            self.session = ort.InferenceSession(model_path)
            self.use_ultralytics = False
            self.logger.info(f"Loaded ONNX model from {model_path}")
    
    def reconstruct_plate_text(self, detections, img_width):
        """
        Reconstruct license plate text from character detections.
        Sort characters by x-coordinate (left to right).
        """
        if len(detections) == 0:
            return "", 0.0
        
        # Extract and sort by x-coordinate
        chars = []
        for det in detections:
            x_center = (det['x1'] + det['x2']) / 2
            char = self.class_names[det['class_id']]
            conf = det['confidence']
            chars.append((x_center, char, conf))
        
        # Sort left to right
        chars.sort(key=lambda x: x[0])
        
        # Build text
        plate_text = ''.join([char for _, char, _ in chars])
        avg_confidence = np.mean([conf for _, _, conf in chars])
        
        return plate_text, float(avg_confidence)
    
    def recognize_ultralytics(self, img, conf_threshold=0.25):
        """Recognize using Ultralytics YOLOv8"""
        results = self.model(img, conf=conf_threshold, verbose=False)
        
        detections = []
        if len(results) > 0 and len(results[0].boxes) > 0:
            boxes = results[0].boxes
            
            for box in boxes:
                x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
                conf = float(box.conf[0])
                cls = int(box.cls[0])
                
                detections.append({
                    'x1': float(x1),
                    'y1': float(y1),
                    'x2': float(x2),
                    'y2': float(y2),
                    'confidence': conf,
                    'class_id': cls,
                    'character': self.class_names[cls]
                })
        
        return detections
    
    def recognize_onnx(self, img, conf_threshold=0.25):
        """Recognize using ONNX model"""
        # Preprocess
        img_resized = cv2.resize(img, (640, 640))
        img_input = img_resized.transpose(2, 0, 1)
        img_input = np.expand_dims(img_input, 0).astype(np.float32) / 255.0
        
        # Inference
        input_name = self.session.get_inputs()[0].name
        outputs = self.session.run(None, {input_name: img_input})
        
        # Parse outputs (simplified, adjust based on actual output format)
        detections = []
        # TODO: Implement ONNX output parsing similar to Ultralytics
        
        return detections
    
    def recognize(self, img, conf_threshold=0.25):
        """
        Recognize characters in license plate image.
        
        Args:
            img: numpy array (BGR image)
            conf_threshold: confidence threshold for detections
        
        Returns:
            dict with plate_text, confidence, and character_count
        """
        try:
            # Run recognition
            if self.use_ultralytics:
                detections = self.recognize_ultralytics(img, conf_threshold)
            else:
                detections = self.recognize_onnx(img, conf_threshold)
            
            # Reconstruct plate text
            img_width = img.shape[1]
            plate_text, avg_conf = self.reconstruct_plate_text(detections, img_width)
            
            return {
                'success': True,
                'plate_text': plate_text,
                'confidence': avg_conf,
                'character_count': len(detections),
                'characters': detections
            }
        
        except Exception as e:
            self.logger.error(f"Recognition error: {e}")
            return {
                'success': False,
                'error': str(e)
            }


# Flask app
app = Flask(__name__)

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

# Initialize recognizer - models are in local models/ folder
MODEL_PATH = Path(__file__).parent / 'models' / 'license_plate_recognition.pt'
CLASSES_PATH = Path(__file__).parent / 'models' / 'classes.names'

recognizer = None

def init_recognizer():
    """Initialize recognizer on first request"""
    global recognizer
    if recognizer is None:
        app.logger.info("Initializing plate recognizer...")
        recognizer = PlateRecognizer(str(MODEL_PATH), str(CLASSES_PATH))
        app.logger.info("Plate recognizer ready!")


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'ok', 'service': 'plate-recognizer'})


@app.route('/api/recognize-plate', methods=['POST'])
def recognize_plate():
    """
    Recognize license plate characters from image.
    
    Expects: multipart/form-data with 'image' file
    Returns: JSON with plate_text and confidence
    """
    init_recognizer()
    
    try:
        # Check if image is in request
        if 'image' not in request.files:
            return jsonify({'error': 'No image provided'}), 400
        
        file = request.files['image']
        
        # Read image
        img_bytes = file.read()
        img_array = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
        
        if img is None:
            return jsonify({'error': 'Invalid image'}), 400
        
        # Get confidence threshold from query params (lowered default for better detection)
        conf_threshold = float(request.args.get('confidence', 0.15))
        
        # Recognize
        result = recognizer.recognize(img, conf_threshold)
        
        if result['success']:
            app.logger.info(
                f"Recognized plate: {result['plate_text']} "
                f"(conf: {result['confidence']:.2f}, chars: {result['character_count']})"
            )
            return jsonify(result), 200
        else:
            return jsonify(result), 500
    
    except Exception as e:
        app.logger.error(f"Error processing request: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/parking/process', methods=['POST'])
def process_parking():
    """
    Process parking entry/exit from edge device.
    
    Expects: multipart/form-data with 'image' file and form fields:
    - parkiran_id: int
    - gate_type: 'MASUK' or 'KELUAR'
    
    Returns: JSON with gate_action and message
    """
    init_recognizer()
    start_time = time.time()
    
    try:
        # 1. Validate request
        print(f"DEBUG: process_parking called", flush=True)
        if 'image' not in request.files:
            print(f"DEBUG: No image in request files. Files: {request.files}", flush=True)
            return jsonify({'gate_action': 'DENY', 'error': 'No image provided'}), 400
        
        file = request.files['image']
        print(f"DEBUG: Image received: {file.filename}", flush=True)

        
        parkiran_id = request.form.get('parkiran_id')
        gate_type = request.form.get('gate_type', 'MASUK')
        face_detected = request.form.get('face_detected', 'false')
        
        # Get face image if present (from edge device)
        face_image_file = request.files.get('face_image')
        face_img_bytes = None
        if face_image_file:
            face_img_bytes = face_image_file.read()
            app.logger.info(f"Face image received: {len(face_img_bytes)} bytes, detected: {face_detected}")
        
        if not parkiran_id:
            return jsonify({'gate_action': 'DENY', 'error': 'parkiran_id required'}), 400
        
        # 2. Recognize plate
        file = request.files['image']
        img_bytes = file.read()
        img_array = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
        
        if img is None:
            return jsonify({'gate_action': 'DENY', 'error': 'Invalid image'}), 400
        
        result = recognizer.recognize(img)
        
        if not result['success'] or not result['plate_text']:
            return jsonify({
                'gate_action': 'DENY',
                'error': 'Tidak dapat membaca plat nomor',
                'ocr_result': result
            }), 400
        
        plate_text = result['plate_text']
        confidence = result['confidence']
        
        app.logger.info(f"Recognized: {plate_text} (conf: {confidence:.2f})")
        
        # 3. Forward to Node.js backend for validation
        try:
            # Prepare multipart/form-data
            files = {
                'image': ('plate.jpg', img_bytes, 'image/jpeg')
            }
            
            # Add face image if present
            if face_img_bytes:
                files['face_image'] = ('face.jpg', face_img_bytes, 'image/jpeg')
            
            data = {
                'plate_text': plate_text,
                'confidence': str(confidence),
                'parkiran_id': str(parkiran_id),
                'gate_type': gate_type,
                'face_detected': face_detected
            }

            print(f"DEBUG: Forwarding to backend: {NODEJS_BACKEND_URL}/api/parkir/edge-entry", flush=True)
            response = http_requests.post(
                f"{NODEJS_BACKEND_URL}/api/parkir/edge-entry",
                files=files,
                data=data,
                headers={'X-Edge-Secret': EDGE_DEVICE_SECRET},
                timeout=10
            )
            print(f"DEBUG: Backend response status: {response.status_code}", flush=True)
            
            backend_result = response.json()
            
            # Add OCR info to response
            backend_result['plate_text'] = plate_text
            backend_result['ocr_confidence'] = confidence
            
            process_time = (time.time() - start_time) * 1000
            app.logger.info(f"backend response: {backend_result.get('gate_action')} - {backend_result.get('message')} (took {process_time:.1f}ms)")
            
            return jsonify(backend_result), response.status_code
            
        except http_requests.exceptions.RequestException as e:
            app.logger.error(f"Backend connection error: {e}")
            return jsonify({
                'gate_action': 'DENY',
                'error': f'Backend tidak dapat dihubungi: {str(e)}',
                'plate_text': plate_text
            }), 503
    
    except Exception as e:
        app.logger.error(f"Error processing parking: {e}")
        return jsonify({'gate_action': 'DENY', 'error': str(e)}), 500


# Keep old endpoint for backward compatibility
@app.route('/api/parking/entry', methods=['POST'])
def parking_entry():
    """Legacy endpoint - redirects to process_parking"""
    return process_parking()


if __name__ == '__main__':
    # Run Flask app
    app.run(host='0.0.0.0', port=5001, debug=False)
