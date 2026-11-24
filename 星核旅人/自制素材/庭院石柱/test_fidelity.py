"""Reproducible V4 geometry, local RGB and deterministic export checks."""
import hashlib
import json
from PIL import Image, ImageChops
import generate_doric_assets as g


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run():
    protected = [g.SOURCE, g.CONCEPT / 'concept_v4.png', g.CONCEPT / 'source_v4.md']
    before = {str(p): sha(p) for p in protected}
    manifest = g.generate()
    outputs = [g.OUT / r['file'] for r in manifest['assets']]
    outputs += [g.OUT / 'manifest.json', g.CONCEPT / 'concept_v5_detail.png']
    first = {str(p): sha(p) for p in outputs}
    g.generate()
    assert first == {str(p): sha(p) for p in outputs}, 'Non-deterministic output'
    assert before == {str(p): sha(p) for p in protected}, 'V4 file changed'
    stats = []
    for record in manifest['assets']:
        kind = record['file'].removeprefix('doric_column_').removesuffix('.png')
        old = g.originals()[kind]
        new = Image.open(g.OUT / record['file']).convert('RGBA')
        assert old.size == new.size == tuple(record['size'])
        assert old.getchannel('A').tobytes() == new.getchannel('A').tobytes()
        assert list(new.getchannel('A').getbbox()) == record['alpha_bbox']
        assert record['foot_anchor'][1] == record['alpha_bbox'][3]
        changed = sum(a[:3] != b[:3] for a, b in zip(old.getdata(), new.getdata()))
        visible = sum(p[3] != 0 for p in old.getdata())
        assert 0 < changed < visible * .25, 'Not a local refinement'
        assert all(a == b for a, b in zip(old.getdata(), new.getdata()) if a[3] == 0)
        stats.append({'file': record['file'], 'size': record['size'],
                      'alpha_bbox': record['alpha_bbox'], 'foot_anchor': record['foot_anchor'],
                      'rgb_changed_pixels': changed, 'visible_pixels': visible,
                      'rgb_changed_percent': round(changed / visible * 100, 2),
                      'alpha_changed_pixels': 0})
    old = Image.open(g.CONCEPT / 'concept_v4.png').convert('RGB')
    new = Image.open(g.CONCEPT / 'concept_v5_detail.png').convert('RGB')
    assert old.size == new.size == (1280, 560)
    # Only the four original asset rectangles may differ in the unchanged scene.
    diff = ImageChops.difference(old, new)
    d = __import__('PIL.ImageDraw', fromlist=['ImageDraw']).Draw(diff)
    for x, y, w, h in [(123, 109, 52, 108), (478, 135, 52, 82),
                       (197, 193, 52, 24), (542, 196, 56, 28)]:
        d.rectangle((x*2, y*2, (x+w)*2-1, (y+h)*2-1), fill=(0, 0, 0))
    assert diff.getbbox() is None, 'Non-column staging changed'
    report = {'result': 'PASS', 'checks': ['exact V4 alpha and dimensions',
              'transparent RGB unchanged', 'local nonzero RGB changes on all four',
              'two-run PNG + manifest SHA256 determinism', 'V4 source files unchanged',
              'preview differences confined to original column rectangles'], 'assets': stats}
    (g.OUT / 'fidelity_report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'result': report['result'], 'assets': stats}, ensure_ascii=False))


if __name__ == '__main__':
    run()
