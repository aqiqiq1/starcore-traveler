class_name CompactLevelHeader
extends HudObjective

## Deprecated compatibility wrapper.  The formal HUDs now use HudObjective
## directly, which owns the approved one-line chapter/objective row and the
## shared 20x20 phase icon.  Old callers/tests that still create
## CompactLevelHeader keep working through this thin mapping.
##
## configure(title, subtitle) maps to (chapter, objective); the old
## "辉相 / 澜相" word label no longer exists anywhere in the tree.


func configure(title_text: String, subtitle_text: String, font: Font = null) -> void:
	super.configure(title_text, subtitle_text, font)
