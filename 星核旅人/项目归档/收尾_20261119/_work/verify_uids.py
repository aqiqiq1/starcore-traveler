import csv
import re
from pathlib import Path

R = Path(r"D:\godot game\星核旅人\基础场景原型")
rows = list(csv.DictReader(open(
    r"D:\godot game\星核旅人\项目归档\收尾_20261119\asset_rename_map.csv", encoding="utf-8-sig")))

bad = 0
for r in rows:
    new = r["new_path"].replace("res://", "")
    imp = R / (new + ".import")
    uid = ""
    if imp.exists():
        m = re.search(r'uid="(uid://[^"]+)"', imp.read_text(encoding="utf-8"))
        uid = m.group(1) if m else ""
    ok = uid == r["import_uid_before"]
    if not ok:
        bad += 1
        print("UID MISMATCH", new, r["import_uid_before"], "->", uid)
    print(("OK " if ok else "BAD"), new)
print("mismatch", bad, "of", len(rows))
