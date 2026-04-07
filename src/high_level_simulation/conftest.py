import sys
from pathlib import Path

# Ensure the high_level_simulation directory is on sys.path so that
# "from toeplitz_hash import ..." works regardless of the working
# directory pytest is invoked from.
sys.path.insert(0, str(Path(__file__).resolve().parent))
