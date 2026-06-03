#!/usr/bin/env python3
"""
YOLOv8 ONNX Quantization Engine for Edge Devices (Raspberry Pi 2/3/4)
====================================================================

This script automates the process of quantizing standard YOLOv8 ONNX models
into highly-optimized INT8 (Dynamic Quantization) or FP16 (Half-Precision) format.
This reduces the model footprint (~4x smaller for INT8) and improves inference speed
on the Raspberry Pi CPU by up to 2-3x without heavy accuracy degradation.

Dependencies:
    pip install onnx onnxruntime onnxconverter-common

Usage:
    python quantize_model.py --input models/license_plate_detection.onnx --type int8
"""

import os
import sys
import argparse
import time

def check_dependencies():
    """Verify that all required packages for quantization are installed."""
    missing = []
    try:
        import onnx
    except ImportError:
        missing.append("onnx")
        
    try:
        import onnxruntime
    except ImportError:
        missing.append("onnxruntime")
        
    try:
        import onnxconverter_common
    except ImportError:
        missing.append("onnxconverter-common")
        
    if missing:
        print("❌ Error: Missing required python packages for quantization.")
        print(f"Please install them via:\n   pip install {' '.join(missing)}")
        print("\nNote: Quantization is typically performed on a host computer (PC/Laptop) "
              "before deploying the quantized .onnx file to the Raspberry Pi.")
        sys.exit(1)

def quantize_to_int8(input_path, output_path):
    """
    Apply Dynamic INT8 Quantization.
    Ideal for general CPU execution on Raspberry Pi by quantizing activations and weights.
    """
    from onnxruntime.quantization import quantize_dynamic, QuantType
    
    print(f"⚡ Starting Dynamic INT8 Quantization...")
    print(f"   Input:  {input_path} ({os.path.getsize(input_path) / 1024 / 1024:.2f} MB)")
    
    start_time = time.time()
    
    # Run dynamic quantization focusing on linear layers and convolutions where appropriate
    quantize_dynamic(
        model_input=input_path,
        model_output=output_path,
        weight_type=QuantType.QUInt8
    )
    
    elapsed = time.time() - start_time
    print(f"✅ Dynamic INT8 Quantization completed in {elapsed:.2f} seconds!")
    print(f"   Output: {output_path} ({os.path.getsize(output_path) / 1024 / 1024:.2f} MB)")
    print(f"   Size reduction: {(1 - os.path.getsize(output_path)/os.path.getsize(input_path))*100:.1f}%")

def quantize_to_fp16(input_path, output_path):
    """
    Convert model weights to FP16 (Half-precision).
    Ideal for environments with native FP16 execution support or to save disk size with zero accuracy loss.
    """
    import onnx
    from onnxconverter_common import float16
    
    print(f"⚡ Starting FP16 (Half-Precision) Conversion...")
    print(f"   Input:  {input_path} ({os.path.getsize(input_path) / 1024 / 1024:.2f} MB)")
    
    start_time = time.time()
    
    # Load model and convert to float16
    model = onnx.load(input_path)
    model_fp16 = float16.convert_float_to_float16(model, keep_io_types=True)
    onnx.save(model_fp16, output_path)
    
    elapsed = time.time() - start_time
    print(f"✅ FP16 conversion completed in {elapsed:.2f} seconds!")
    print(f"   Output: {output_path} ({os.path.getsize(output_path) / 1024 / 1024:.2f} MB)")
    print(f"   Size reduction: {(1 - os.path.getsize(output_path)/os.path.getsize(input_path))*100:.1f}%")

def main():
    parser = argparse.ArgumentParser(description="YOLOv8 ONNX Quantizer for Raspberry Pi")
    parser.add_argument(
        "--input", 
        type=str, 
        default="models/license_plate_detection.onnx",
        help="Path to the input float32 ONNX model"
    )
    parser.add_argument(
        "--output", 
        type=str, 
        default=None,
        help="Path for the output quantized ONNX model"
    )
    parser.add_argument(
        "--type", 
        type=str, 
        choices=["int8", "fp16"], 
        default="int8",
        help="Quantization type: 'int8' (Dynamic INT8) or 'fp16' (Float16)"
    )
    
    args = parser.parse_args()
    
    # Verify input file exists
    if not os.path.exists(args.input):
        print(f"❌ Error: Input model file not found at: {args.input}")
        print("Please copy your trained license_plate_detection.onnx to the models/ folder first.")
        sys.exit(1)
        
    # Check package dependencies
    check_dependencies()
    
    # Generate default output name if not provided
    if not args.output:
        base, ext = os.path.splitext(args.input)
        args.output = f"{base}_{args.type}{ext}"
        
    # Execute quantization
    if args.type == "int8":
        quantize_to_int8(args.input, args.output)
    elif args.type == "fp16":
        quantize_to_fp16(args.input, args.output)

if __name__ == "__main__":
    main()
