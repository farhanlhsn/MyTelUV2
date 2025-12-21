"""
Face Recognition Processor using InsightFace
Handles face detection, embedding extraction, and comparison
"""

import numpy as np
import cv2
from insightface.app import FaceAnalysis
from insightface.utils import face_align
import os

class FaceProcessor:
    def __init__(self):
        """Initialize InsightFace model"""
        self.app = FaceAnalysis(
            name='buffalo_l',  # Use buffalo_l model (accurate & fast)
            providers=['CPUExecutionProvider']  # Use CPU (can change to CUDA if GPU available)
        )
        self.app.prepare(ctx_id=0, det_size=(640, 640))
        
    def detect_single_face(self, image_path):
        """
        Detect and extract embedding from a single face
        Args:
            image_path: Path to image file
        Returns:
            dict: {
                'success': bool,
                'embedding': list (512D),
                'bbox': list [x, y, w, h],
                'error': str (if failed)
            }
        """
        try:
            # Read image
            img = cv2.imread(image_path)
            if img is None:
                return {
                    'success': False,
                    'error': 'Failed to read image'
                }
            
            # Detect faces
            faces = self.app.get(img)
            
            if len(faces) == 0:
                return {
                    'success': False,
                    'error': 'No face detected in image'
                }
            
            if len(faces) > 1:
                return {
                    'success': False,
                    'error': f'Multiple faces detected ({len(faces)}). Please provide image with single face.'
                }
            
            # Get face embedding
            face = faces[0]
            embedding = face.embedding.tolist()  # Convert to list for JSON
            bbox = face.bbox.tolist()  # [x1, y1, x2, y2]
            
            return {
                'success': True,
                'embedding': embedding,
                'bbox': bbox,
                'face_score': float(face.det_score)  # Detection confidence
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': f'Error processing image: {str(e)}'
            }
    
    def detect_multiple_faces(self, image_path):
        """
        Detect and extract embeddings from multiple faces (for CCTV)
        Args:
            image_path: Path to image file
        Returns:
            dict: {
                'success': bool,
                'faces': list of {
                    'embedding': list (512D),
                    'bbox': list [x, y, w, h],
                    'face_score': float
                },
                'count': int,
                'error': str (if failed)
            }
        """
        try:
            # Read image
            img = cv2.imread(image_path)
            if img is None:
                return {
                    'success': False,
                    'error': 'Failed to read image'
                }
            
            # Detect faces
            faces = self.app.get(img)
            
            if len(faces) == 0:
                return {
                    'success': False,
                    'error': 'No faces detected in image'
                }
            
            # Extract embeddings for all faces
            results = []
            for face in faces:
                results.append({
                    'embedding': face.embedding.tolist(),
                    'bbox': face.bbox.tolist(),  # [x1, y1, x2, y2]
                    'face_score': float(face.det_score)
                })
            
            return {
                'success': True,
                'faces': results,
                'count': len(results)
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': f'Error processing image: {str(e)}'
            }
    
    def compare_embeddings(self, embedding1, embedding2):
        """
        Compare two face embeddings using cosine similarity
        Args:
            embedding1: First embedding (list or numpy array)
            embedding2: Second embedding (list or numpy array)
        Returns:
            dict: {
                'similarity': float (0-1, higher = more similar),
                'is_same_person': bool (threshold > 0.6)
            }
        """
        try:
            # Convert to numpy arrays
            emb1 = np.array(embedding1)
            emb2 = np.array(embedding2)
            
            # Calculate cosine similarity
            similarity = np.dot(emb1, emb2) / (np.linalg.norm(emb1) * np.linalg.norm(emb2))
            similarity = float(similarity)
            
            # Threshold for same person (can be adjusted)
            threshold = 0.6
            is_same = similarity > threshold
            
            return {
                'similarity': similarity,
                'is_same_person': is_same,
                'threshold': threshold
            }
            
        except Exception as e:
            return {
                'error': f'Error comparing embeddings: {str(e)}'
            }
    
    def find_best_match(self, target_embedding, embeddings_list, threshold=0.6):
        """
        Find best matching face from a list of embeddings
        
        Args:
            target_embedding: Target face embedding (512D array)
            embeddings_list: List of face embeddings to compare against
            threshold: Similarity threshold for match (default 0.6)
            
        Returns:
            dict: {best_match_index, similarity, is_match, threshold} or {error}
        """
        try:
            if not embeddings_list:
                return {'error': 'Empty embeddings list'}
            
            best_similarity = -1
            best_index = -1
            
            for idx, embedding in enumerate(embeddings_list):
                comparison_result = self.compare_embeddings(target_embedding, embedding)
                if 'error' in comparison_result:
                    raise Exception(comparison_result['error'])
                similarity = comparison_result['similarity']
                
                if similarity > best_similarity:
                    best_similarity = similarity
                    best_index = idx
            
            return {
                'best_match_index': int(best_index),  # Convert numpy int to Python int
                'similarity': float(best_similarity),  # Convert numpy float to Python float
                'is_match': bool(best_similarity >= threshold),  # Convert numpy bool to Python bool
                'threshold': float(threshold)  # Ensure threshold is also Python float
            }
            
        except Exception as e:
            return {'error': f'Error finding best match: {str(e)}'}
