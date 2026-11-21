extends Object
class_name OopaColors
## Central design tokens for the Godot application. Keep legacy aliases below
## while screens migrate to the semantic palette.

const MIDNIGHT_NAVY := Color("#101827")
const DEEP_SLATE := Color("#19263a")
const GRAPHITE_BLUE := Color("#26364d")
const COOL_MIST := Color("#e9eef5")
const CLEAN_WHITE := Color("#ffffff")
const SCIENTIFIC_TEAL := Color("#16b8a6")
const INSTRUMENT_BLUE := Color("#3b82f6")
const SIGNAL_AMBER := Color("#f2a84a")
const STATUS_SUCCESS := Color("#16856f")
const STATUS_ERROR := Color("#c44545")
const STATUS_INFO := INSTRUMENT_BLUE

const SPACE_1 := 4
const SPACE_2 := 8
const SPACE_3 := 12
const SPACE_4 := 16
const SPACE_5 := 24
const SPACE_6 := 32
const SPACE_7 := 48
const RADIUS_SM := 6
const RADIUS_MD := 10
const RADIUS_LG := 14
const RADIUS_XL := 20
const BORDER_WIDTH := 1
const PAGE_MARGIN := 32
const SIDEBAR_WIDTH := 320
const HEADER_HEIGHT := 64

const TYPE_DISPLAY := 36
const TYPE_PAGE := 28
const TYPE_SECTION := 20
const TYPE_BODY := 14
const TYPE_SECONDARY := 12
const TYPE_LABEL := 11
const TYPE_READOUT := 24

## Legacy brand tokens retained for existing scenes and scripts.

const RED := Color("#b22222")           ## --red
const RED_BRIGHT := Color("#e12b2b")    ## --red-bright
const RED_DARK := Color("#741717")      ## --red-dark
const BLACK := Color("#101010")         ## --black
const INK := Color("#1b1b1b")           ## --ink
const MUTED := Color("#666666")         ## --muted
const MUTED_SOFT := Color("#696969")
const WHITE := Color("#ffffff")
const OFF := Color("#f7f6f4")           ## --off / --off-white
const LINE := Color("#e7e3e0")          ## --line
const LINE_SOFT := Color("#ded8d5")
const BG_PAGE := Color("#faf9f8")
const BG_STAGE := Color("#161616")      ## .stage canvas frame
const BG_HEADER := Color(1, 1, 1, 0.96)
const TAG_BG := Color("#fff0ef")
const STAT_LAW_BG := Color("#fbe5e5")
const HOLD_NOTE := Color("#bdbdbd")
const STATUS_WARN := Color("#f0b34a")

## Aliases used elsewhere in the project
const FIREBRICK := RED
const FIREBRICK_HOVER := Color("#c92828")
const FIREBRICK_DEEP := RED_DARK
const BG_DARK := Color("#080808")
