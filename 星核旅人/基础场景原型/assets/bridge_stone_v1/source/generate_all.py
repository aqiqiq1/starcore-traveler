"""Rebuild atlas, examples, sheet, manifest, then run structural checks."""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
for s in ("generate_atlas.py", "build_examples.py", "generate_contact_sheet.py",
          "generate_manifest.py", "validate_outputs.py"):
    print("==", s)
    subprocess.check_call([sys.executable, os.path.join(HERE, s)], cwd=HERE)
print("all done")
