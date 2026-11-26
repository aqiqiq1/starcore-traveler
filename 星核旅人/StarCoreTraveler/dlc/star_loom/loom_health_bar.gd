class_name LoomHealthBar
extends PlayerHealthBar

## Kept as a named subclass so the loom HUD/test references stay stable.
## It inherits the shared red segmented bar (creator decision: one bar style
## across every combat level).  The run's life COUNT is the heart row in the
## top HUD; this control is only the health VALUE.
