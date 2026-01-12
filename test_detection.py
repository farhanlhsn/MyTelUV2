"""
Test Detection Model
=====================

Script untuk testing model deteksi plat nomor.
Run: python test_detection.py --image path/to/image.jpg
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


def test_detection(image_path, model_path='models/detection/license_plate_detection.pt', 
                   conf_threshold=0.5, save_result=True):
    """
    Test license plate detection on an image
    
    Args:
        image_path: Path to input image
        model_path: Path to detection model (.pt or .onnx)
        conf_threshold: Confidence threshold for detections
        save_result: Whether to save annotated result
    """
    
    # Load model
    print(f"📦 Loading detection model from: {model_path}")
    model = YOLO(model_path)
    
    # Load image
    print(f"📸 Loading image: {image_path}")
    img = cv2.imread(str(image_path))
    if img is None:
        print(f"❌ Failed to load image: {image_path}")
        return None
    
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    
    # Run detection
    print(f"🔍 Running detection...")
    start_time = time.time()
    results = model(img_rgb, conf=conf_threshold)
    inference_time = (time.time() - start_time) * 1000
    
    # Get results
    detections = results[0].boxes
    num_detections = len(detections)
    
    print(f"\n{'='*60}")
    print(f"✅ DETECTION RESULTS")
    print(f"{'='*60}")
    print(f"Detections found: {num_detections}")
    print(f"Inference time: {inference_time:.2f} ms")
    print(f"FPS: {1000/inference_time:.2f}")
    
    if num_detections > 0:
        print(f"\n📋 Detection Details:")
        for i, box in enumerate(detections):
            x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
            conf = float(box.conf[0])
            print(f"  Plate {i+1}: bbox=[{x1:.0f}, {y1:.0f}, {x2:.0f}, {y2:.0f}], conf={conf:.3f}")
        
        # Visualize
        annotated = results[0].plot()
        annotated_bgr = cv2.cvtColor(annotated, cv2.COLOR_RGB2BGR)
        
        if save_result:
            output_path = Path(image_path).parent / f"{Path(image_path).stem}_detection.jpg"
            cv2.imwrite(str(output_path), annotated_bgr)
            print(f"\n💾 Result saved to: {output_path}")
        
        # Display (optional - comment out if running headless)
        try:
            cv2.imshow('Detection Result', annotated_bgr)
            print("\nPress any key to close window...")
            cv2.waitKey(0)
            cv2.destroyAllWindows()
        except:
            print("(Display not available - result saved to file)")
        
        return results
    else:
        print("\n⚠️  No license plates detected")
        return None


def test_detection_onnx(image_path, model_path='models/detection/license_plate_detection.onnx',
                        conf_threshold=0.5):
    """Test using ONNX model (faster, for edge devices)"""
    
    try:
        import onnxruntime as ort
    except ImportError:
        print("Installing onnxruntime...")
        import subprocess
        subprocess.run(["pip", "install", "onnxruntime"], check=True)
        import onnxruntime as ort
    
    print(f"📦 Loading ONNX model: {model_path}")
    session = ort.InferenceSession(str(model_path))
    
    # Load and preprocess image
    img = cv2.imread(str(image_path))
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    
    # Resize and normalize
    img_resized = cv2.resize(img_rgb, (640, 640))
    img_input = img_resized.transpose(2, 0, 1)  # HWC to CHW
    img_input = np.expand_dims(img_input, 0).astype(np.float32) / 255.0
    
    # Run inference
    print("🔍 Running ONNX inference...")
    start_time = time.time()
    input_name = session.get_inputs()[0].name
    outputs = session.run(None, {input_name: img_input})
    inference_time = (time.time() - start_time) * 1000
    
    print(f"\n{'='*60}")
    print(f"✅ ONNX INFERENCE RESULTS")
    print(f"{'='*60}")
    print(f"Inference time: {inference_time:.2f} ms")
    print(f"FPS: {1000/inference_time:.2f}")
    print(f"Output shape: {outputs[0].shape}")
    print(f"\n✓ ONNX model working! Ready for Raspberry Pi deployment.")
    
    return outputs


def main():
    parser = argparse.ArgumentParser(description='Test License Plate Detection Model')
    parser.add_argument('--image', type=str, required=True, help='Path to test image')
    parser.add_argument('--model', type=str, default='models/detection/license_plate_detection.pt',
                       help='Path to model file (.pt or .onnx)')
    parser.add_argument('--conf', type=float, default=0.5, help='Confidence threshold')
    parser.add_argument('--onnx', action='store_true', help='Use ONNX inference (faster)')
    
    args = parser.parse_args()
    
    if args.onnx or args.model.endswith('.onnx'):
        test_detection_onnx(args.image, args.model, args.conf)
    else:
        test_detection(args.image, args.model, args.conf)


if __name__ == '__main__':
    main()
