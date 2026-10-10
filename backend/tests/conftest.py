import os
import sys
from pathlib import Path

os.environ["SAJAG_MOCK"] = "1"  # tests never call the real model
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
