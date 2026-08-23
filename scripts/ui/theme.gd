extends RefCounted
class_name GrindTheme
## theme.gd — HUD visual system, single source (BRIEF "Visual system").
## Exact floats; styling asserts read these values. Bebas Neue only.

const FONT_PATH := "res://assets/ui/fonts/BebasNeue-Regular.ttf"

const INK := Color(0.078431, 0.062745, 0.054902)      # #14100e
const PAPER := Color(0.960784, 0.917647, 0.847059)    # #f5ead8
const ACCENT := Color(0.941176, 0.647059, 0.117647)   # #f0a51e

const SHADOW_OFFSET := Vector2(5, 5)
const SHADOW_SIZE := 6
const CHIP_SHADOW_OFFSET := Vector2(3, 3)

static var _font: FontFile = null

static func font() -> FontFile:
	if _font == null:
		_font = load(FONT_PATH)
	return _font

static func wordmark_settings() -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = font()
	ls.font_size = 140
	ls.font_color = PAPER
	ls.shadow_color = INK
	ls.shadow_offset = SHADOW_OFFSET
	ls.shadow_size = SHADOW_SIZE
	return ls

static func chip_settings() -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = font()
	ls.font_size = 30
	ls.font_color = INK
	ls.shadow_color = PAPER
	ls.shadow_offset = CHIP_SHADOW_OFFSET
	ls.shadow_size = 3
	return ls

static func combo_settings() -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = font()
	ls.font_size = 64
	ls.font_color = Color(1, 1, 1)
	ls.shadow_color = INK
	ls.shadow_offset = CHIP_SHADOW_OFFSET
	ls.shadow_size = 4
	return ls
