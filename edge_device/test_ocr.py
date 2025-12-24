import cv2
import numpy as np
import sys
from pathlib import Path

def preprocess_plate_for_ocr(plate_img):
    """Enhanced preprocessing for better OCR accuracy"""
    # 1. Resize to larger size if needed (OCR needs good resolution)
    height, width = plate_img.shape[:2]
    if height < 64:
        scale = 64 / height
        new_width = int(width * scale)
        plate_img = cv2.resize(plate_img, (new_width, 64), interpolation=cv2.INTER_CUBIC)
        print(f"Resized plate to {new_width}x64 for OCR")
    
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
    
    return result, gray, binary, denoised, sharpened

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 test_ocr.py <path_to_test_image>")
        print("\nExample: python3 test_ocr.py detections/20241224_033239_B1234XYZ.jpg")
        sys.exit(1)
    
    image_path = sys.argv[1]
    
    # Load image
    img = cv2.imread(image_path)
    if img is None:
        print(f"Error: Could not load image from {image_path}")
        sys.exit(1)
    
    print(f"Loaded image: {image_path}")
    print(f"Original size: {img.shape[1]}x{img.shape[0]}")
    
    # Process image
    result, gray, binary, denoised, sharpened = preprocess_plate_for_ocr(img)
    
    print(f"Processed size: {result.shape[1]}x{result.shape[0]}")
    
    # Create output directory
    output_dir = Path("test_output")
    output_dir.mkdir(exist_ok=True)
    
    # Save all stages
    base_name = Path(image_path).stem
    cv2.imwrite(str(output_dir / f"{base_name}_1_original.jpg"), img)
    cv2.imwrite(str(output_dir / f"{base_name}_2_grayscale.jpg"), gray)
    cv2.imwrite(str(output_dir / f"{base_name}_3_binary.jpg"), binary)
    cv2.imwrite(str(output_dir / f"{base_name}_4_denoised.jpg"), denoised)
    cv2.imwrite(str(output_dir / f"{base_name}_5_sharpened.jpg"), sharpened)
    cv2.imwrite(str(output_dir / f"{base_name}_6_final.jpg"), result)
    
    print(f"\n✅ Saved all preprocessing stages to: {output_dir}/")
    print("Files saved:")
    print(f"  1. {base_name}_1_original.jpg")
    print(f"  2. {base_name}_2_grayscale.jpg")
    print(f"  3. {base_name}_3_binary.jpg")
    print(f"  4. {base_name}_4_denoised.jpg")
    print(f"  5. {base_name}_5_sharpened.jpg")
    print(f"  6. {base_name}_6_final.jpg (sent to OCR)")
    
    print("\n💡 You can now visually compare these to see the preprocessing improvements!")

if __name__ == '__main__':
    main()
