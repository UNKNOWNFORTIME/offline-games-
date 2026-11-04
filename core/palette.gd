class_name Palette
extends RefCounted
## Single source of truth for every color in the game (GAME_SPEC 5.2).

const PLAYER: Color = Color("#2F80FF")
const PLAYER_LIGHT: Color = Color("#7DB7FF")
const ENEMY: Color = Color("#FF3B3B")
const ENEMY_LIGHT: Color = Color("#FF8A80")
const GOLD: Color = Color("#FFC531")
const GOLD_SHADOW: Color = Color("#E09A00")
const TRACK: Color = Color("#D9D4CC")
const METAL: Color = Color("#8C96A3")
const GRASS: Color = Color("#5DBB63")
const FOREST: Color = Color("#2E5E3A")
const SKY_TOP: Color = Color("#6EC6FF")
const SKY_HORIZON: Color = Color("#DFF3FF")
const FOG_CITY: Color = Color("#B8C4D6")
const UI_DARK: Color = Color("#1B1F2A")
const UI_ACCENT: Color = Color("#36D399")

# Derived helpers (not in the spec table, but built from it).
const WHITE: Color = Color(1, 1, 1, 1)
const SKIN: Color = Color("#FFD2A6")
const WATER_DEEP: Color = Color("#2A8FD8")
const WATER_SHALLOW: Color = Color("#5CC8F0")
const UI_DARK_SOFT: Color = Color("#2A3142")
const UI_MUTED: Color = Color("#7A8396")


## Darker, slightly blue-shifted version of a color. Used for toon shadows
## and for the "pressable" bottom edge of buttons.
static func shade(c: Color, amount: float = 0.35) -> Color:
	var d: Color = c.darkened(amount)
	return d.lerp(Color(0.16, 0.2, 0.42), amount * 0.35)


static func lighten(c: Color, amount: float = 0.25) -> Color:
	return c.lightened(amount)
