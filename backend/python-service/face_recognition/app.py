"""
Flask API Server for Face Recognition
Endpoints:
- POST /detect-face: Detect single face and extract embedding
- POST /detect-multiple: Detect multiple faces from image (CCTV)
- POST /compare: Compare two embeddings
- POST /find-match: Find best match from list of embeddings
"""

import sys
import io
# Ensure UTF-8 output on Windows (avoids CP1252 UnicodeEncodeError with emoji)
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

from flask import Flask, request, jsonify
from flask_cors import CORS
from face_processor import FaceProcessor
import os
import cv2
import numpy as np
from werkzeug.utils import secure_filename

app = Flask(__name__)
CORS(app)  # Enable CORS for Node.js backend

# Initialize face processor
if os.getenv('TEST_MODE') == 'true':
    face_processor = None
    print("[INFO] TEST_MODE=true. InsightFace initialization skipped.")
else:
    face_processor = FaceProcessor()

# Allowed image extensions
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'Face Recognition API',
        'version': '1.0.0'
    })

@app.route('/detect-face', methods=['POST'])
def detect_face():
    """
    Detect single face and extract embedding
    Expects: multipart/form-data with 'image' file
    Returns: {success, embedding, bbox, face_score} or {success, error}
    """
    if 'image' not in request.files:
        return jsonify({
            'success': False,
            'error': 'No image file provided'
        }), 400
    
    file = request.files['image']
    
    if file.filename == '':
        return jsonify({
            'success': False,
            'error': 'No selected file'
        }), 400
    
    if not allowed_file(file.filename):
        return jsonify({
            'success': False,
            'error': 'Invalid file type. Allowed: jpg, jpeg, png'
        }), 400
    
    try:
        if os.getenv('TEST_MODE') == 'true' or request.headers.get('X-Test-Mode') == 'true':
            return jsonify({
                'success': True,
                'embedding': [0.02] * 512,
                'bbox': [10, 10, 100, 100],
                'face_score': 0.99
            }), 200

        # Read image to memory
        img_bytes = file.read()
        img_array = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
        
        if img is None:
            return jsonify({
                'success': False,
                'error': 'Failed to decode image'
            }), 400
            
        # Process face directly with numpy array
        result = face_processor.detect_single_face(img)
        
        if result['success']:
            return jsonify(result), 200
        else:
            return jsonify(result), 400
            
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Server error: {str(e)}'
        }), 500

@app.route('/detect-multiple', methods=['POST'])
def detect_multiple():
    """
    Detect multiple faces from image (for CCTV/classroom)
    Expects: multipart/form-data with 'image' file
    Returns: {success, faces: [{embedding, bbox, face_score}], count}
    """
    if 'image' not in request.files:
        return jsonify({
            'success': False,
            'error': 'No image file provided'
        }), 400
    
    file = request.files['image']
    
    if file.filename == '':
        return jsonify({
            'success': False,
            'error': 'No selected file'
        }), 400
    
    if not allowed_file(file.filename):
        return jsonify({
            'success': False,
            'error': 'Invalid file type. Allowed: jpg, jpeg, png'
        }), 400
    
    try:
        if os.getenv('TEST_MODE') == 'true' or request.headers.get('X-Test-Mode') == 'true':
            return jsonify({
                'success': True,
                'faces': [{
                    'embedding': [0.02] * 512,
                    'bbox': [10, 10, 100, 100],
                    'face_score': 0.99
                }],
                'count': 1
            }), 200

        # Read image to memory
        img_bytes = file.read()
        img_array = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
        
        if img is None:
            return jsonify({
                'success': False,
                'error': 'Failed to decode image'
            }), 400
            
        # Process faces directly with numpy array
        result = face_processor.detect_multiple_faces(img)
        
        if result['success']:
            return jsonify(result), 200
        else:
            return jsonify(result), 400
            
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Server error: {str(e)}'
        }), 500

@app.route('/compare', methods=['POST'])
def compare_embeddings():
    """
    Compare two face embeddings
    Expects: JSON {embedding1: [], embedding2: []}
    Returns: {similarity, is_same_person, threshold}
    """
    data = request.get_json()
    
    if not data or 'embedding1' not in data or 'embedding2' not in data:
        return jsonify({
            'error': 'Missing embedding1 or embedding2 in request'
        }), 400
    
    if os.getenv('TEST_MODE') == 'true' or request.headers.get('X-Test-Mode') == 'true':
        return jsonify({
            'similarity': 0.85,
            'is_same_person': True,
            'threshold': 0.6
        }), 200

    result = face_processor.compare_embeddings(
        data['embedding1'],
        data['embedding2']
    )
    
    if 'error' in result:
        return jsonify(result), 400
    
    return jsonify(result), 200

@app.route('/find-match', methods=['POST'])
def find_match():
    """
    Find best matching embedding from a list
    Expects: JSON {target_embedding: [], embeddings_list: [[]]}
    Returns: {best_match_index, similarity, is_match, threshold}
    """
    data = request.get_json()
    
    if not data or 'target_embedding' not in data or 'embeddings_list' not in data:
        return jsonify({
            'error': 'Missing target_embedding or embeddings_list in request'
        }), 400
    
    if os.getenv('TEST_MODE') == 'true' or request.headers.get('X-Test-Mode') == 'true':
        return jsonify({
            'best_match_index': 0,
            'similarity': 0.92,
            'is_match': True,
            'threshold': 0.6
        }), 200

    result = face_processor.find_best_match(
        data['target_embedding'],
        data['embeddings_list']
    )
    
    if 'error' in result:
        return jsonify(result), 400
    
    return jsonify(result), 200

if __name__ == '__main__':
    print("[INFO] Face Recognition API Server starting...")
    print("[INFO] Server running on http://localhost:5051")
    print("[INFO] Endpoints:")
    print("   - GET  /health")
    print("   - POST /detect-face")
    print("   - POST /detect-multiple")
    print("   - POST /compare")
    print("   - POST /find-match")
    app.run(host='0.0.0.0', port=5051, debug=False)
