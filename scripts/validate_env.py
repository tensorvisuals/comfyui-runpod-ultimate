#!/usr/bin/env python3
# Validierungsskript für die Docker-Umgebung
# Stellt sicher, dass PyTorch 2.8.0 mit CUDA 12.8 korrekt installiert ist

import sys
import torch

def print_env_info():
    """Gibt Informationen über die Python- und PyTorch-Umgebung aus."""
    print(f"Python Version: {sys.version}")
    print(f"PyTorch Version: {torch.__version__}")
    print(f"CUDA verfügbar: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"CUDA Version: {torch.version.cuda}")
        print(f"cuDNN Version: {torch.backends.cudnn.version()}")
        print(f"Anzahl der GPUs: {torch.cuda.device_count()}")
        for i in range(torch.cuda.device_count()):
            print(f"GPU {i}: {torch.cuda.get_device_name(i)}")

def validate_pytorch_version():
    """Überprüft, ob die PyTorch-Version korrekt ist."""
    version_parts = torch.__version__.split('.')
    # Pad with '0' if patch version is missing
    while len(version_parts) < 3:
        version_parts.append('0')
    major, minor, _ = version_parts[:3]
    if int(major) != 2 or int(minor) != 8:
        print(f"WARNUNG: Erwartete PyTorch 2.8.x, gefunden: {torch.__version__}")
        return False
    print("PyTorch Version ist korrekt!")
    return True

def validate_cuda_version():
    """Überprüft, ob die CUDA-Version korrekt ist."""
    if not torch.cuda.is_available():
        print("WARNUNG: CUDA ist nicht verfügbar!")
        return False
    
    cuda_version = torch.version.cuda
    if not cuda_version.startswith("12.8"):
        print(f"WARNUNG: Erwartete CUDA 12.8, gefunden: {cuda_version}")
        return False
    
    print("CUDA Version ist korrekt!")
    return True

def main():
    """Hauptfunktion zur Validierung der Umgebung."""
    print("=== Umgebungsinformationen ===")
    print_env_info()
    print("\n=== Validierung ===")
    
    pytorch_ok = validate_pytorch_version()
    cuda_ok = validate_cuda_version()
    
    if pytorch_ok and cuda_ok:
        print("\n✅ Alle Prüfungen bestanden! Die Umgebung ist korrekt eingerichtet.")
        return 0
    else:
        print("\n❌ Es wurden Probleme mit der Umgebung festgestellt!")
        return 1

if __name__ == "__main__":
    sys.exit(main())
