"""
Test Recognition Model (OCR)
=============================

Script untuk testing model pengenalan karakter plat nomor.
Run: python test_recognition.py --image path/to/cropped_plate.jpg
"""

import argparse
import cv2
import numpy as np
from pathlib import Path
import time

try:
    from ultralytics import YOLO
    USE_ULTRALYTICS = True
except ImportError:
    print("Installing ultralytics...")
    import subprocess
    subprocess.run(["pip", "install", "ultralytics"], check=True)
    from ultralytics import YOLO
    USE_ULTRALYTICS = True


# Default Indonesian plate character classes
DEFAULT_CLASSES = [str(i) for i in range(10)] + [chr(i) for i in range(ord('A'), ord('Z')+1)]


def load_classes(classes_file='models/recognition/classes.names'):
    """Load class names from file"""
    classes_path = Path(classes_file)
    if classes_path.exists():
        with open(classes_path, 'r') as f:
            return [line.strip() for line in f.readlines()]
    return DEFAULT_CLASSES


def reconstruct_plate_text(results, class_names, img_width):
    """
    Reconstruct license plate text from character detections.
    Sort characters left to right based on x-coordinate.
    """
    boxes = results[0].boxes
    
    if len(boxes) == 0:
        return "", 0.0, []
    
    # Extract detections
    detections = []
    for box in boxes:
        x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
        conf = float(box.conf[0])
        cls = int(box.cls[0])
        x_center = (x1 + x2) / 2
        detections.append({
            'x_center': x_center,
            'class_id': cls,
            'char': class_names[cls] if cls < len(class_names) else str(cls),
            'confidence': conf,
            'bbox': [float(x1), float(y1), float(x2), float(y2)]
        })
    
    # Sort by x-coordinate (left to right)
    detections.sort(key=lambda x: x['x_center'])
    
    # Build text
    plate_text = ''.join([d['char'] for d in detections])
    avg_confidence = np.mean([d['confidence'] for d in detections])
    
    return plate_text, float(avg_confidence), detections


def test_recognition(image_path, model_path='models/recognition/license_plate_recognition.pt',
                     classes_file='models/recognition/classes.names',
                     conf_threshold=0.25, save_result=True):
    """
    Test license plate character recognition on a cropped plate image
    
    Args:
        image_path: Path to cropped plate image
        model_path: Path to recognition model
        classes_file: Path to class names file
        conf_threshold: Confidence threshold for character detection
        save_result: Whether to save annotated result
    """
    
    # Load model and classes
    print(f"📦 Loading recognition model from: {model_path}")
    model = YOLO(model_path)
    
    class_names = load_classes(classes_file)
    print(f"📝 Loaded {len(class_names)} character classes")
    
    # Load image
    print(f"📸 Loading plate image: {image_path}")
    img = cv2.imread(str(image_path))
    if img is None:
        print(f"❌ Failed to load image: {image_path}")
        return None
    
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    img_h, img_w = img.shape[:2]
    
    # Run OCR
    print(f"🔍 Running character recognition...")
    start_time = time.time()
    results = model(img_rgb, conf=conf_threshold, verbose=False)
    inference_time = (time.time() - start_time) * 1000
    
    # Reconstruct plate text
    plate_text, avg_conf, detections = reconstruct_plate_text(results, class_names, img_w)
    
    print(f"\n{'='*60}")
    print(f"✅ OCR RESULTS")
    print(f"{'='*60}")
    print(f"📋 Plate Text: \"{plate_text}\"")
    print(f"🎯 Confidence: {avg_conf:.3f} ({avg_conf*100:.1f}%)")
    print(f"🔢 Characters detected: {len(detections)}")
    print(f"⚡ Inference time: {inference_time:.2f} ms")
    print(f"📊 FPS: {1000/inference_time:.2f}")
    
    if len(detections) > 0:
        print(f"\n📝 Character Details (left to right):")
        for i, det in enumerate(detections):
            print(f"  {i+1}. '{det['char']}' - conf: {det['confidence']:.3f}")
        
        # Visualize
        annotated = results[0].plot()
        annotated_bgr = cv2.cvtColor(annotated, cv2.COLOR_RGB2BGR)
        
        # Add plate text overlay
        text_size = cv2.getTextSize(plate_text, cv2.FONT_HERSHEY_BOLD, 1.5, 3)[0]
        cv2.rectangle(annotated_bgr, (5, 5), (text_size[0] + 15, text_size[1] + 20), (0, 255, 0), -1)
        cv2.putText(annotated_bgr, plate_text, (10, text_size[1] + 10), 
                   cv2.FONT_HERSHEY_BOLD, 1.5, (0, 0, 0), 3)
        
        if save_result:
            output_path = Path(image_path).parent / f"{Path(image_path).stem}_ocr.jpg"
            cv2.imwrite(str(output_path), annotated_bgr)
            print(f"\n💾 Result saved to: {output_path}")
        
        # Display (optional)
        try:
            cv2.imshow(f'OCR Result: {plate_text}', annotated_bgr)
            print("\nPress any key to close window...")
            cv2.waitKey(0)
            cv2.destroyAllWindows()
        except:
            print("(Display not available - result saved to file)")
        
        return plate_text, avg_conf, detections
    else:
        print("\n⚠️  No characters detected")
        return "", 0.0, []


def main():
    parser = argparse.ArgumentParser(description='Test License Plate Recognition Model')
    parser.add_argument('--image', type=str, required=True, help='Path to cropped plate image')
    parser.add_argument('--model', type=str, default='models/recognition/license_plate_recognition.pt',
                       help='Path to recognition model')
    parser.add_argument('--classes', type=str, default='models/recognition/classes.names',
                       help='Path to class names file')
    parser.add_argument('--conf', type=float, default=0.25, help='Confidence threshold')
    
    args = parser.parse_args()
    
    test_recognition(args.image, args.model, args.classes, args.conf)


if __name__ == '__main__':
    main()
