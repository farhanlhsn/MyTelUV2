"""
License Plate Detector for Raspberry Pi 2
==========================================

This script runs on Raspberry Pi 2 to:
1. Capture images from camera
2. Detect license plates using lightweight YOLO model
3. Send detected plates to server for OCR recognition
4. Log parking entry

Optimized for Raspberry Pi 2 (ARMv7, 1GB RAM)
"""

import cv2
import numpy as np
import requests
import time
import yaml
import argparse
from pathlib import Path
from datetime import datetime
import logging

try:
    import onnxruntime as ort
except ImportError:
    print("ONNX Runtime not available, trying OpenCV DNN...")
    ort = None


class PlateDetector:
    def __init__(self, config_path='config.yaml'):
        """Initialize plate detector with configuration"""
        # Load configuration
        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)
        
        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
        
        # Load model
        model_path = self.config['model']['path']
        self.img_size = self.config['model']['img_size']
        self.conf_threshold = self.config['model']['confidence_threshold']
        
        self.logger.info(f"Loading detection model from {model_path}")
        
        if model_path.endswith('.onnx') and ort is not None:
            self.session = ort.InferenceSession(model_path)
            self.input_name = self.session.get_inputs()[0].name
            self.use_onnx = True
            self.logger.info("Using ONNX Runtime")
        else:
            # Fallback to OpenCV DNN
            self.net = cv2.dnn.readNet(model_path)
            self.use_onnx = False
            self.logger.info("Using OpenCV DNN")
        
        # Server configuration
        self.server_url = self.config['server']['url']
        self.server_timeout = self.config['server']['timeout']
        
        # Camera configuration
        self.camera_index = self.config['camera']['index']
        self.camera_width = self.config['camera']['width']
        self.camera_height = self.config['camera']['height']
        
        self.logger.info("PlateDetector initialized successfully")
    
    def letterbox(self, img, new_shape=(640, 640)):
        """Resize and pad image while maintaining aspect ratio"""
        shape = img.shape[:2]  # current shape [height, width]
        
        # Scale ratio
        r = min(new_shape[0] / shape[0], new_shape[1] / shape[1])
        
        # Compute padding
        new_unpad = int(round(shape[1] * r)), int(round(shape[0] * r))
        dw, dh = new_shape[1] - new_unpad[0], new_shape[0] - new_unpad[1]
        dw /= 2
        dh /= 2
        
        if shape[::-1] != new_unpad:
            img = cv2.resize(img, new_unpad, interpolation=cv2.INTER_LINEAR)
        
        top, bottom = int(round(dh - 0.1)), int(round(dh + 0.1))
        left, right = int(round(dw - 0.1)), int(round(dw + 0.1))
        img = cv2.copyMakeBorder(img, top, bottom, left, right, 
                                cv2.BORDER_CONSTANT, value=(114, 114, 114))
        
        return img, r, (dw, dh)
    
    def preprocess(self, img):
        """Preprocess image for inference"""
        # Letterbox resize
        img_resized, ratio, (dw, dh) = self.letterbox(img, (self.img_size, self.img_size))
        
        # Normalize and transpose
        img_input = img_resized.transpose(2, 0, 1)  # HWC to CHW
        img_input = np.expand_dims(img_input, 0)  # Add batch dimension
        img_input = img_input.astype(np.float32) / 255.0
        
        return img_input, ratio, (dw, dh)
    
    def postprocess(self, outputs, img_shape, ratio, pad):
        """Postprocess model outputs to get bounding boxes"""
        if self.use_onnx:
            # ONNX output format
            outputs = outputs[0]
        
        # YOLOv5/v8 output format: [batch, num_detections, 85]
        # where 85 = x, y, w, h, conf, class_probs...
        
        # For simplicity, using direct output parsing
        # Adjust based on actual model output
        detections = []
        
        if len(outputs.shape) == 3:
            outputs = outputs[0]  # Remove batch dimension
        
        # Parse detections
        for detection in outputs:
            if len(detection) >= 5:
                conf = detection[4]
                if conf > self.conf_threshold:
                    x_center, y_center, width, height = detection[:4]
                    
                    # Convert from normalized to pixel coordinates
                    # Account for letterbox padding
                    x1 = (x_center - width / 2 - pad[0]) / ratio
                    y1 = (y_center - height / 2 - pad[1]) / ratio
                    x2 = (x_center + width / 2 - pad[0]) / ratio
                    y2 = (y_center + height / 2 - pad[1]) / ratio
                    
                    detections.append({
                        'bbox': [int(x1), int(y1), int(x2), int(y2)],
                        'confidence': float(conf)
                    })
        
        return detections
    
    def detect(self, img):
        """Detect license plates in image"""
        # Preprocess
        img_input, ratio, pad = self.preprocess(img)
        
        # Inference
        if self.use_onnx:
            outputs = self.session.run(None, {self.input_name: img_input})
        else:
            self.net.setInput(img_input)
            outputs = self.net.forward()
        
        # Postprocess
        detections = self.postprocess(outputs, img.shape, ratio, pad)
        
        return detections
    
    def is_valid_plate_detection(self, bbox):
        """Validate detection based on aspect ratio and size"""
        x1, y1, x2, y2 = bbox
        width = x2 - x1
        height = y2 - y1
        
        if height <= 0 or width <= 0:
            return False
        
        aspect_ratio = width / height
        
        # Indonesian license plates typically have aspect ratio 4:1 to 6:1
        # Filter out obviously wrong detections
        if aspect_ratio < 3.5 or aspect_ratio > 7.0:
            self.logger.debug(f"Rejected detection: aspect ratio {aspect_ratio:.2f}")
            return False
        
        # Minimum size check
        if width < 50 or height < 10:
            self.logger.debug(f"Rejected detection: too small ({width}x{height})")
            return False
        
        return True
    
    def crop_plate(self, img, bbox):
        """Crop license plate region from image with enhanced padding"""
        x1, y1, x2, y2 = bbox
        h, w = img.shape[:2]
        
        # Increased padding (10-15%) for better OCR
        pad_x = int((x2 - x1) * 0.15)
        pad_y = int((y2 - y1) * 0.15)
        
        x1 = max(0, x1 - pad_x)
        y1 = max(0, y1 - pad_y)
        x2 = min(w, x2 + pad_x)
        y2 = min(h, y2 + pad_y)
        
        cropped = img[y1:y2, x1:x2]
        
        # Ensure minimum size for OCR readability
        if cropped.shape[0] < 32 or cropped.shape[1] < 100:
            # Scale up to minimum readable size
            scale = max(32 / cropped.shape[0], 100 / cropped.shape[1])
            new_w = int(cropped.shape[1] * scale)
            new_h = int(cropped.shape[0] * scale)
            cropped = cv2.resize(cropped, (new_w, new_h), interpolation=cv2.INTER_CUBIC)
            self.logger.debug(f"Upscaled plate image to {new_w}x{new_h}")
        
        return cropped
    
    def preprocess_plate_for_ocr(self, plate_img):
        """Enhanced preprocessing for better OCR accuracy"""
        # 1. Resize to larger size if needed (OCR needs good resolution)
        height, width = plate_img.shape[:2]
        if height < 64:
            scale = 64 / height
            new_width = int(width * scale)
            plate_img = cv2.resize(plate_img, (new_width, 64), interpolation=cv2.INTER_CUBIC)
            self.logger.debug(f"Resized plate to {new_width}x64 for OCR")
        
        # 2. Convert to grayscale
        gray = cv2.cvtColor(plate_img, cv2.COLOR_BGR2GRAY)
        
        # 3. Adaptive thresholding for handling uneven lighting
        binary = cv2.adaptiveThreshold(
            gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY, 11, 2
        )
        
        # 4. Denoise
        denoised = cv2.fastNlMeansDenoising(binary, None, 10, 7, 21)
        
        # 5. Sharpen to enhance character edges
        kernel = np.array([[-1, -1, -1], [-1, 9, -1], [-1, -1, -1]])
        sharpened = cv2.filter2D(denoised, -1, kernel)
        
        # 6. Convert back to BGR for model compatibility
        result = cv2.cvtColor(sharpened, cv2.COLOR_GRAY2BGR)
        
        return result
    
    def send_to_server(self, plate_img):
        """Send plate image to server for OCR recognition"""
        try:
            # Encode image as JPEG with high quality
            encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), 95]
            _, img_encoded = cv2.imencode('.jpg', plate_img, encode_param)
            
            # Send to server with lower confidence threshold
            files = {'image': ('plate.jpg', img_encoded.tobytes(), 'image/jpeg')}
            response = requests.post(
                f"{self.server_url}/api/recognize-plate?confidence=0.15",
                files=files,
                timeout=self.server_timeout
            )
            
            if response.status_code == 200:
                result = response.json()
                return result
            else:
                self.logger.error(f"Server error: {response.status_code}")
                return None
                
        except Exception as e:
            self.logger.error(f"Error sending to server: {e}")
            return None
    
    def process_frame(self, frame, save_dir=None):
        """Process a single frame"""
        start_time = time.time()
        
        # Detect plates
        detections = self.detect(frame)
        
        detect_time = time.time() - start_time
        
        results = []
        
        for idx, detection in enumerate(detections):
            bbox = detection['bbox']
            conf = detection['confidence']
            
            # Validate detection
            if not self.is_valid_plate_detection(bbox):
                self.logger.debug("Skipping invalid plate detection")
                continue
            
            # Crop plate
            plate_img = self.crop_plate(frame, bbox)
            
            # Preprocess for OCR
            plate_img_preprocessed = self.preprocess_plate_for_ocr(plate_img)
            
            # Save debug images if enabled
            if save_dir and self.config.get('debug', {}).get('save_images', False):
                debug_dir = Path(save_dir) / 'debug'
                debug_dir.mkdir(parents=True, exist_ok=True)
                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
                cv2.imwrite(str(debug_dir / f"{timestamp}_original.jpg"), plate_img)
                cv2.imwrite(str(debug_dir / f"{timestamp}_preprocessed.jpg"), plate_img_preprocessed)
            
            # Send to server for OCR
            ocr_result = self.send_to_server(plate_img_preprocessed)
            
            if ocr_result:
                plate_text = ocr_result.get('plate_text', '')
                ocr_confidence = ocr_result.get('confidence', 0.0)
                
                self.logger.info(
                    f"Detected plate: {plate_text} "
                    f"(det_conf: {conf:.2f}, ocr_conf: {ocr_confidence:.2f})"
                )
                
                # Save if requested
                if save_dir:
                    save_path = Path(save_dir)
                    save_path.mkdir(parents=True, exist_ok=True)
                    
                    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                    filename = f"{timestamp}_{plate_text.replace(' ', '_')}.jpg"
                    cv2.imwrite(str(save_path / filename), plate_img)
                
                results.append({
                    'bbox': bbox,
                    'plate_text': plate_text,
                    'detection_confidence': conf,
                    'ocr_confidence': ocr_confidence,
                    'detection_time': detect_time
                })
        
        return results
    
    def run_camera(self, save_dir='detections'):
        """Run continuous detection from camera"""
        self.logger.info("Starting camera capture...")
        
        cap = cv2.VideoCapture(self.camera_index)
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, self.camera_width)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, self.camera_height)
        
        if not cap.isOpened():
            self.logger.error("Failed to open camera")
            return
        
        self.logger.info("Camera opened successfully. Press 'q' to quit.")
        
        frame_count = 0
        
        try:
            while True:
                ret, frame = cap.read()
                if not ret:
                    self.logger.warning("Failed to read frame")
                    continue
                
                frame_count += 1
                
                # Process every N frames to reduce load
                if frame_count % self.config['camera']['process_every_n_frames'] == 0:
                    results = self.process_frame(frame, save_dir)
                    
                    # Draw results on frame
                    for result in results:
                        bbox = result['bbox']
                        text = result['plate_text']
                        
                        cv2.rectangle(frame, (bbox[0], bbox[1]), (bbox[2], bbox[3]), 
                                    (0, 255, 0), 2)
                        cv2.putText(frame, text, (bbox[0], bbox[1]-10),
                                  cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 0), 2)
                
                # Display frame (optional, disable on headless Raspberry Pi)
                if self.config['camera'].get('show_preview', False):
                    cv2.imshow('License Plate Detection', frame)
                    
                    if cv2.waitKey(1) & 0xFF == ord('q'):
                        break
        
        finally:
            cap.release()
            cv2.destroyAllWindows()
            self.logger.info("Camera capture stopped")


def main():
    parser = argparse.ArgumentParser(description='License Plate Detector for Raspberry Pi')
    parser.add_argument('--config', type=str, default='config.yaml',
                       help='Path to configuration file')
    parser.add_argument('--test-image', type=str, help='Test on single image instead of camera')
    parser.add_argument('--save-dir', type=str, default='detections',
                       help='Directory to save detected plates')
    
    args = parser.parse_args()
    
    # Initialize detector
    detector = PlateDetector(args.config)
    
    if args.test_image:
        # Test mode
        img = cv2.imread(args.test_image)
        if img is None:
            print(f"Failed to load image: {args.test_image}")
            return
        
        print("Processing test image...")
        results = detector.process_frame(img, args.save_dir)
        
        print(f"\nDetected {len(results)} plate(s):")
        for i, result in enumerate(results):
            print(f"  {i+1}. {result['plate_text']} "
                  f"(conf: {result['detection_confidence']:.2f})")
        
        # Display result
        for result in results:
            bbox = result['bbox']
            text = result['plate_text']
            cv2.rectangle(img, (bbox[0], bbox[1]), (bbox[2], bbox[3]), 
                        (0, 255, 0), 2)
            cv2.putText(img, text, (bbox[0], bbox[1]-10),
                      cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 0), 2)
        
        cv2.imshow('Result', img)
        cv2.waitKey(0)
        cv2.destroyAllWindows()
    else:
        # Live camera mode
        detector.run_camera(args.save_dir)


if __name__ == '__main__':
    main()
