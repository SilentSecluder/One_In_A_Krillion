-- One In A Krillion : a small visual novel engine for LOVE2D (11.x / 12.x)
--
-- Controls
--   Start menu             : click a button, or Up / Down + Enter
--   Click / Space / Enter : advance text (first press finishes the typewriter)
--   Up / Down + Enter      : choose an option   (or click it, or press 1-9)
--   R                      : play again (on an ending screen)
--   Esc                    : in the story: pause (zoom into the shrimp's eye) / resume;
--                            in Settings: back to the pause menu;
--                            in Endings / Credits: back to the start menu; on the start menu: quit
--   F11                    : toggle fullscreen
--
-- The story is a hand conversion of One_In_A_Krillion_Test.ink (see "Story script" below).
-- Each knot is a list of steps, run in order:
--   "Name: text"        a line spoken by Name (Name shows on the top line of the bar)
--   "[text]"            a narration / sound line with no speaker
--   bg("File")          fade the background to black, swap it, fade back in (sprites unload)
--   move / zoom / fadeIn / together(...)   sprite animations; the story waits for them
--   choice{ ... }       choice buttons; each option has its own steps and where it goes next
-- A knot (or option) with no `next_knot` ends the story.

local utf8 = require("utf8")

-- The game is drawn at 256x128 "game pixels". The window opens at START_SCALE and is
-- resizable: when it is resized, maximised or made fullscreen (F11), everything is
-- scaled up or down to fit, keeping the 2:1 shape with black bars filling any leftover space.
local GAME_W, GAME_H  = 256, 128
local START_SCALE     = 4
local INTEGER_SCALING = false   -- true = only whole-number scales (crisper pixels, bigger black bars)
local TEXT_SPEED      = 50      -- characters per second

-- Narration bar (256x26), drawn along the bottom of the screen.
-- Rectangles below are in game pixels, relative to the bar's top-left corner.
local BAR_IMAGE   = "assets/UI_Parts/Narration_Bar.png"

-- Mouse cursors (4x6 pixel art). They're enlarged to match the game's current pixel size,
-- and rebuilt whenever the window is resized. Hotspot = the pixel that does the clicking.
local CURSOR_FILES = {
    arrow = "assets/UI_Parts/Mouse_Parts/Mouse.png",            -- normal cursor
    hand  = "assets/UI_Parts/Mouse_Parts/Mouse_Clickable.png",  -- over something clickable
}
local CURSOR_HOTSPOTS = {
    arrow = { x = 0, y = 0 },
    hand  = { x = 1, y = 0 },   -- top tip of the clickable cursor
}
local BAR_TEXT    = { x = 30, y = 4, w = 221, h = 18 }  -- yellow area the story text goes in
local TEXT_COLOR  = { 0.16, 0.13, 0.08 }               -- dark brown, readable on the yellow
local NAME_COLOR  = { 0.45, 0.13, 0.05 }               -- speaker name on the bar's top line

-- Story text and choices use the pixel font (5px letters + 2px line gap), drawn at
-- TEXT_SCALE in game pixels: 0.5 = half size, so letters are 2.5 game pixels tall.
local TEXT_SCALE     = 0.5
local LINE_HEIGHT    = 7                                  -- in font pixels (before TEXT_SCALE)
local LINE_STEP      = LINE_HEIGHT * TEXT_SCALE           -- in game pixels
-- Long story lines are split into pages; each click shows the next page.
local LINES_PER_PAGE = math.floor((BAR_TEXT.h + 2 * TEXT_SCALE) / LINE_STEP)   -- 6 at half size
local CHOICE_BOX = {
    w = 216,          -- button width
    pad_x = 3,        -- space between the button edge and its text
    pad_y = 2,
    gap = 2,          -- space between buttons
    above_bar = 4,    -- space between the last button and the narration bar
}
local CHOICE_COLORS = {
    fill      = { 36 / 255, 42 / 255, 61 / 255, 0.92 },   -- dark navy from the menu art
    text      = { 187 / 255, 227 / 255, 240 / 255 },      -- pale blue from the menu art
    hot_fill  = { 255 / 255, 102 / 255, 0 },              -- orange from the menu art
    hot_text  = { 36 / 255, 42 / 255, 61 / 255 },
}

-- Ending overlay text, also in the pixel font: the title at 2x (10px letters), hint at 1x.
local ENDING_TITLE_SCALE = 2
local ENDING_HINT_SCALE  = 1
local ENDING_COLORS = {
    good    = { 0.6, 1, 0.6 },
    bad     = { 1, 0.45, 0.45 },
    neutral = { 0.75, 0.85, 1 },
}
local ENDING_TITLES = {
    good    = "GOOD ENDING",
    bad     = "BAD ENDING",
    neutral = "NEUTRAL ENDING",
}

-- Shrimp sprite sheet: 64x64 image = 2x2 grid of 32x32 frames (read left-to-right, top-to-bottom)
local SHRIMP_SHEET = "assets/Sprites/Shrimp_Animations/Shrimp_Anim_Cycle.png"
local SHRIMP_FRAME = 32         -- frame size in pixels
local SHRIMP_FPS   = 6          -- animation speed
local SHRIMP_SCALE = 0.7        -- the 26x22 px shrimp drawn smaller to sit in the bar's blue patch
-- Centre of the blue patch (x 0-22, y 3-25), relative to the bar's top-left.
local SHRIMP_POS   = { x = 11.5, y = 14.5 }
-- Middle of the shrimp's drawn pixels inside its 32x32 frame (art spans x 4-29, y 5-26),
-- used as the pivot so the shrimp itself, not the empty frame, is what gets centred.
local SHRIMP_PIVOT = { x = 17, y = 16 }

---------------------------------------------------------------------------
-- Scenes: backgrounds and character sprites
---------------------------------------------------------------------------
local BACKGROUND_DIR = "assets/Backgrounds/Gameplay_Backgrounds/"
local SPRITE_DIR     = "assets/Sprites/"       -- sprites are named by file, without ".png"
local BG_FADE_TIME   = 1     -- seconds to fade the background to black, and again to fade in
local WALK_SPEED     = 65      -- "standard sprite movement", in game pixels per second
local FOLLOW_DELAY   = 0.75    -- seconds between two sprites when one "follows" the other
local ZOOM_TIME      = 1.2     -- seconds for a sprite to zoom in or back out
local SPRITE_BOTTOM  = GAME_H  -- sprites stand with their bottom edge here (behind the bar)
local EDGE_MARGIN    = 2       -- gap left at the screen edge for "left edge" / "right edge"
local BESIDE_GAP     = 3       -- "next to" / "a few pixels away"

-- Where sprites stand, by the centre of their visible pixels (x in game pixels).
-- "left_edge", "right_edge", "off_left" and "off_right" are worked out from each sprite's width.
local STAGE = {
    middle_left  = 76,
    center       = 128,
    middle_right = 180,
}

-- How far sprites zoom when the script says so.
local ZOOMS = {
    chef_face = 2.25,       -- the Chef peering through the glass, close up on her face
    jordan    = 1.35,    -- "zooms in slightly towards his face"
    saoirse   = 1.2,     -- "slightly, just less so than Jordan"
}

-- Point each sprite zooms towards when it zooms on its "face", in pixels inside its image.
-- The current sprites are 64x96 placeholders, so these all guess the upper middle; adjust
-- them once the real art is in. ("middle" zooms use the centre of the visible pixels.)
local DEFAULT_FACE = { x = 32, y = 20 }
local SPRITE_FACES = {
    Chef           = { x = 32, y = 20 },
    Jordan         = { x = 32, y = 20 },
    Saoirse        = { x = 32, y = 20 },
    Shop_Attendant = { x = 32, y = 20 },
    Worker_1       = { x = 32, y = 20 },
    Worker_2       = { x = 32, y = 20 },
}

---------------------------------------------------------------------------
-- Start menu
---------------------------------------------------------------------------
local MENU_BACKGROUND = "assets/Backgrounds/Mechanics_Backgrounds/Start_Menu_Background.png"
-- The buttons are painted into the background, so these are their positions in it
-- (game pixels), from top to bottom.
local MENU_BUTTONS = {
    { action = "play",    x = 99, y = 44, w = 53, h = 17 },
    { action = "endings", x = 99, y = 62, w = 53, h = 17 },
    { action = "credits", x = 99, y = 80, w = 53, h = 17 },
    { action = "quit",    x = 99, y = 98, w = 53, h = 17 },
}
-- Spinning shrimp: 64x160 sheet = 2 columns x 5 rows of 32x32 frames (10 frames),
-- read left to right, top to bottom.
local SPIN_SHEET    = "assets/Sprites/Shrimp_Animations/Shrimp_Rotate_Anim_Cycle.png"
local SPIN_FRAMES   = 10
local SPIN_FPS      = 7
local SPIN_MIRROR_RIGHT = true   -- flip the right-hand shrimp so both face the buttons
-- Centred halfway between the buttons' edges (x 99 / 151) and the screen edges,
-- and level with the middle of the button stack (y 44-114).
local SPIN_LEFT     = { x = 49.5, y = 79.5 }
local SPIN_RIGHT    = { x = 204,  y = 79.5 }

---------------------------------------------------------------------------
-- Endings screen
---------------------------------------------------------------------------
local ENDINGS_BACKGROUND = "assets/Backgrounds/Mechanics_Backgrounds/Endings_Background.png"
-- Inside of the light-blue box is x 27-227, y 27-99; the painted "ENDINGS" title uses y 30-36.
-- All positions below are in game pixels.
local ENDINGS_LAYOUT = {
    left      = 44,     -- number + ending name start here
    right     = 220,    -- ending type ("GOOD" etc.) is right-aligned to here
    count_y   = 40,     -- "X / Y FOUND" line
    list_y    = 48,     -- first ending
    spacing   = 7,      -- 5px tall letters + 2px gap
}
-- Text colours chosen to read well on the box's light blue (colours from the art where possible).
local ENDINGS_COLORS = {
    text    = { 36 / 255, 42 / 255, 61 / 255 },    -- dark navy
    locked  = { 72 / 255, 111 / 255, 122 / 255 },  -- the box's dark teal, for "???"
    count   = { 82 / 255, 48 / 255, 140 / 255 },   -- purple, same as the title
    good    = { 30 / 255, 110 / 255, 50 / 255 },
    bad     = { 170 / 255, 40 / 255, 30 / 255 },
    neutral = { 82 / 255, 48 / 255, 140 / 255 },
}

---------------------------------------------------------------------------
-- Pixel font, drawn to match the lettering in the menu art: 5px tall capitals,
-- mostly 4px wide, with rounded corners. Lowercase text is shown as capitals.
-- Each glyph is 5 rows of '#' (pixel) and '.' (empty). Add more characters here if needed.
---------------------------------------------------------------------------
local PIXEL_GLYPHS = {
    ["A"] = { ".##.", "#..#", "####", "#..#", "#..#" },
    ["B"] = { "###.", "#..#", "###.", "#..#", "###." },
    ["C"] = { ".##.", "#..#", "#...", "#..#", ".##." },
    ["D"] = { "###.", "#..#", "#..#", "#..#", "###." },
    ["E"] = { "####", "#...", "###.", "#...", "####" },
    ["F"] = { "####", "#...", "###.", "#...", "#..." },
    ["G"] = { ".##.", "#...", "#.##", "#..#", ".##." },
    ["H"] = { "#..#", "#..#", "####", "#..#", "#..#" },
    ["I"] = { "###", ".#.", ".#.", ".#.", "###" },
    ["J"] = { "..##", "...#", "...#", "#..#", ".##." },
    ["K"] = { "#..#", "#.#.", "##..", "#.#.", "#..#" },
    ["L"] = { "#...", "#...", "#...", "#...", "####" },
    ["M"] = { "#...#", "##.##", "#.#.#", "#...#", "#...#" },
    ["N"] = { "#..#", "##.#", "#.##", "#..#", "#..#" },
    ["O"] = { ".##.", "#..#", "#..#", "#..#", ".##." },
    ["P"] = { "###.", "#..#", "###.", "#...", "#..." },
    ["Q"] = { ".##.", "#..#", "#..#", "#.#.", ".#.#" },
    ["R"] = { "###.", "#..#", "###.", "#.#.", "#..#" },
    ["S"] = { ".###", "#...", ".##.", "...#", "###." },
    ["T"] = { "#####", "..#..", "..#..", "..#..", "..#.." },
    ["U"] = { "#..#", "#..#", "#..#", "#..#", ".##." },
    ["V"] = { "#...#", "#...#", "#...#", ".#.#.", "..#.." },
    ["W"] = { "#...#", "#...#", "#.#.#", "##.##", "#...#" },
    ["X"] = { "#..#", "#..#", ".##.", "#..#", "#..#" },
    ["Y"] = { "#...#", ".#.#.", "..#..", "..#..", "..#.." },
    ["Z"] = { "####", "...#", ".##.", "#...", "####" },
    ["0"] = { ".##.", "#.##", "#..#", "##.#", ".##." },
    ["1"] = { ".#.", "##.", ".#.", ".#.", "###" },
    ["2"] = { "###.", "...#", ".##.", "#...", "####" },
    ["3"] = { "###.", "...#", ".##.", "...#", "###." },
    ["4"] = { "#..#", "#..#", "####", "...#", "...#" },
    ["5"] = { "####", "#...", "###.", "...#", "###." },
    ["6"] = { ".##.", "#...", "###.", "#..#", ".##." },
    ["7"] = { "####", "...#", "..#.", ".#..", ".#.." },
    ["8"] = { ".##.", "#..#", ".##.", "#..#", ".##." },
    ["9"] = { ".##.", "#..#", ".###", "...#", ".##." },
    ["."] = { ".", ".", ".", ".", "#" },
    [","] = { ".", ".", ".", "#", "#" },
    ["!"] = { "#", "#", "#", ".", "#" },
    ["?"] = { "###.", "...#", ".##.", "....", ".#.." },
    ["'"] = { "#", "#", ".", ".", "." },
    ['"'] = { "#.#", "#.#", "...", "...", "..." },
    ["-"] = { "...", "...", "###", "...", "..." },
    ["/"] = { "..#", "..#", ".#.", "#..", "#.." },
    [":"] = { ".", "#", ".", "#", "." },
    ["("] = { ".#", "#.", "#.", "#.", ".#" },
    [")"] = { "#.", ".#", ".#", ".#", "#." },
    ["["] = { "##", "#.", "#.", "#.", "##" },
    ["]"] = { "##", ".#", ".#", ".#", "##" },
    ["&"] = { ".#..", "#.#.", ".#.#", "#.#.", ".#.#" },
    ["—"] = { "....", "....", "####", "....", "...." },   -- em dash
    [" "] = { "...", "...", "...", "...", "..." },
}
local PIXEL_GLYPH_ORDER = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!?'\"-/:()[]&—"

-- Endings listed on the Endings screen: { knot = "KnotName", name = "Ending name" }.
-- Empty for now; every ending in the new story counts as neutral.
local ENDINGS_LIST = {}
local SAVE_FILE = "endings.txt"   -- saved in LOVE's save folder, so it survives restarts

-- Credits screen: everything is painted into this image.
local CREDITS_BACKGROUND = "assets/Backgrounds/Mechanics_Backgrounds/Credits_Background.png"
-- The orange back arrow in the bottom-left corner of the Credits and Endings art
-- (drawn pixels x 2-22, y 108-125), in game pixels, with a 1px margin so it's easy to click.
local BACK_ARROW = { x = 1, y = 107, w = 23, h = 20 }

---------------------------------------------------------------------------
-- Pause (Esc during the story)
---------------------------------------------------------------------------
-- Esc freezes the bar's shrimp on its first frame, then zooms into its black eye for
-- PAUSE_ZOOM_TIME seconds. The pause menu then appears over the black.
local PAUSE_BACKGROUND = "assets/Backgrounds/Mechanics_Backgrounds/Pause_Menu_Background.png"
local PAUSE_ZOOM_TIME  = 2        -- seconds (also used for zooming back out on resume)
local PAUSE_MAX_ZOOM   = 400      -- at this zoom the eye's black pixels fill the screen
-- Centre of the black eye in frame 1 of Shrimp_Anim_Cycle.png (eye pixels x 22-24, y 10-11).
local SHRIMP_EYE       = { x = 23.5, y = 11 }
-- "MAIN MENU" (drawn x 107-148, y 40-44) and "SETTINGS" (x 109-148, y 54-58) in the pause
-- art, with a small margin so they're easy to click.
local PAUSE_BUTTONS = {
    { action = "main_menu", x = 104, y = 38, w = 48, h = 9 },
    { action = "settings",  x = 104, y = 52, w = 48, h = 9 },
}
local SETTINGS_COLOR = { 84 / 255, 106 / 255, 145 / 255 }   -- blank settings page (menu blue)

---------------------------------------------------------------------------
-- Story script helpers (used by the story below)
---------------------------------------------------------------------------
-- Switch background. `place` = sprites already standing there once it fades in,
-- e.g. { { "Shop_Attendant", "left_edge" } }.
local function bg(name, place)
    return { kind = "bg", name = name, place = place or {} }
end

-- Walk a sprite to `to`: "off_left", "left_edge", "middle_left", "center", "middle_right",
-- "right_edge", "off_right", a number (x of its centre), or { beside = "Name", side = "left" |
-- "right", gap = pixels }. Options:
--   from      = where it appears first (it is loaded there; usually off-screen)
--   speed     = multiple of WALK_SPEED (1.4 = faster, 0.5 = half speed)
--   delay     = seconds to wait before starting (for "follows after")
--   behind    = { names } to pass behind;  front_of = { names } to pass in front of
local function move(sprite, to, opts)
    opts = opts or {}
    return { kind = "move", sprite = sprite, to = to, from = opts.from, speed = opts.speed or 1,
             delay = opts.delay or 0, behind = opts.behind, front_of = opts.front_of }
end

-- Zoom a sprite in (scale > 1) towards its "face" or its "middle"; unzoom returns it to normal.
local function zoom(sprite, scale, focus)
    return { kind = "zoom", sprite = sprite, scale = scale, focus = focus or "face" }
end
local function unzoom(sprite)
    return { kind = "zoom", sprite = sprite, scale = 1 }
end

-- Fade a sprite in at a spot over `time` seconds.
local function fadeIn(sprite, at, time)
    return { kind = "fade", sprite = sprite, at = at, time = time }
end

-- Run several animations at the same time; the story continues when all have finished.
local function together(...)
    return { kind = "group", actions = { ... } }
end

-- Choice buttons. Each option: { text = "...", steps = { ... }, next_knot = "Knot" (optional) }.
local function choice(options)
    return { kind = "choice", options = options }
end

---------------------------------------------------------------------------
-- Story script (from One_In_A_Krillion_Test.ink)
---------------------------------------------------------------------------
local story = {
    start = "HatcheryIntro",
    knots = {
        HatcheryIntro = {
            steps = {
                bg("Hatchery_Background"),
                together(
                    move("Worker_1", "middle_left",  { from = "off_left" }),
                    move("Worker_2", "middle_right", { from = "off_right" })
                ),
                "Worker 1: God, these shrimp look so good. When are they being sold again?",
                "Worker 2: I don't know, in a few days?",
                "Worker 2: And dude, these are live shrimp. How can they possibly look good?",
                "Worker 1: They don't look so different from ceviche shrimp.",
                "Worker 2: ..You're crazy.",
                "Worker 1: Please tell me the difference between these and ceviche.",
                "Worker 2: Dude, they're still ALIVE!",
                "Worker 1: Okay, so they're just a bit raw, what's you're point?",
                "Worker 2: God, I need to quit this job.",
                "Worker 2: Can you just pour their meal in already?",
                "Worker 1: Yeah yeah, already on it.",
                "[A bag is unzipped above the tank.]",
                "Worker 2: Why is it so green, are you sure you grabbed the right stuff?",
                "Worker 1: Of course I did, they have some special meal plan or something, I don't really know.",
                "Worker 2: Whatever. Just hurry up.",
                "[The plattering of small pellets rattles through the hatchery.]",
                "Worker 1: Dangit.. I just got these shoes!",
                "Worker 2: How did you even manage to spill it-",
                "Worker 2: Dude, they're pellets. Just brush them off?",
                "Worker 1: No but they're like green and weird and kind of sticky.",
                "Worker 2: I'm so done with this place.",
                "[Someone walks away from the tank.]",
                move("Worker_2", "right_edge"),
                "Worker 1: Stupid, stupid.",
                "Worker 1: Hey, are you going to make me clean this up all by myself?",
                "Worker 2: Yeah, you spilt it, not me.",
                "Worker 1: But you work here too!",
                "Worker 2: Not with that attitude.",
                "Worker 1: ..What on earth does that mean.",
                "Worker 2: ...Nothing, I'm going to check the tuna storage.",
                move("Worker_2", "off_right"),
                "Worker 1: Yeah okay.",
                "[The sound of sweeping is heard from outside the tank.]",
                "Worker 1: ..What are they feeding you guys, the tank is glowing.",
                "Worker 1: Kind of reminds me of a Chernobyl documentry.",
                "Worker 1: Smells weird too.",
                "Worker 1: Anyways.",
                "[Someone starts whistling and walking away from the tank.]",
                move("Worker_1", "off_right"),
            },
            next_knot = "TransformationScene",
        },

        TransformationScene = {
            -- continues on the hatchery background
            steps = {
                "Narrator: You are a shrimp.",
                "Narrator: Until now, you were just swarming around in a tank.",
                "Narrator: But, for some reason, after eating too many of the new pellets, you've become aware.",
                "Narrator: Perhaps too aware.",
                "Narrator: The shrimp around you, they did not change.",
                "Narrator: It seems, in your gluttony, you have gained a form of consciousness they could never hope to.",
                "Narrator: It is unlikely they hope for anything, though. After all, they're just shrimp.",
                "Narrator: But, you are a very smart shrimp. You will not succumb to the same fate as them.",
                "Narrator: That is, if you want to survive.",
                "Narrator: Do you want to become ceviche?",
                choice{
                    {
                        text = "Yes.",
                        steps = {
                            "[Footsteps sound outside the tank.]",
                            together(
                                move("Worker_2", "middle_left",  { from = "off_right" }),
                                move("Chef",     "middle_right", { from = "off_right", delay = FOLLOW_DELAY })
                            ),
                            "Chef: What's in this tank?",
                            "Worker 2: High quality shrimp, ma'am.",
                            "Chef: What about them is high quality, they seem pretty average for shrimp?",
                            "Worker 2: Well, we supply them with an enriched diet free of growth hormones and unnatural chemicals.",
                            "Chef: That's certainly pretty high quality then. Hm..",
                            "[You can suddenly see the Chef's face against the tank, peering through the glass.]",
                            move("Chef", "center"),
                            zoom("Chef", ZOOMS.chef_face, "face"),
                            "[The Chef's eyes widen when it locks onto you.]",
                            "Chef: That's an all natural shrimp? It's beautiful and perfectly sized. Your hatchery has some astounding specimens.",
                            "Chef: We'll take this batch, unless you already have a buyer?",
                            "Worker 2: Oh perfect! Their original buyer backed out a few days ago, so this is wonderful timing for us.",
                            "Worker 2: Come with me to the front desk, we can get it all sorted out there.",
                            "Chef: Lovely, they will taste delicious for this weekends dinner.",
                            "[The Chef's face disappears from the glass, and the sound of footsteps vanishes off in the distance.]",
                            unzoom("Chef"),
                            together(
                                move("Worker_2", "off_right"),
                                move("Chef",     "off_right", { delay = FOLLOW_DELAY })
                            ),
                        },
                        next_knot = "SushiParlor",
                    },
                    {
                        text = "No.",
                        steps = {
                            "[Footsteps sound outside the tank.]",
                            -- the ink gives no stopping spots here, so they mirror the "Yes" path
                            together(
                                move("Worker_2", "middle_right", { from = "off_left" }),
                                move("Chef",     "middle_left",  { from = "off_left", delay = FOLLOW_DELAY })
                            ),
                            "Chef: What's in this tank?",
                            "Worker 2: High quality shrimp, ma'am.",
                            "Chef: What about them is high quality, they seem pretty average for shrimp?",
                            "Worker 2: Well, we supply them with an enriched diet free of growth hormones and unnatural chemicals.",
                            "Chef: That's certainly pretty high quality then. Hm..",
                            "[You can suddenly see the Chef's face against the tank, peering through the glass.]",
                            move("Chef", "center"),
                            zoom("Chef", ZOOMS.chef_face, "face"),
                            "Chef: I don't know, they're not too special to me. Can I see your other stock?",
                            "Worker 2: Sure, follow me.",
                            "[The Chef's face disappears from the glass, and the sound of footsteps vanishes off in the distance.]",
                            unzoom("Chef"),
                            together(
                                move("Worker_2", "off_right"),
                                move("Chef",     "off_right", { delay = FOLLOW_DELAY })
                            ),
                        },
                        next_knot = "FeedStore",
                    },
                },
            },
        },

        SushiParlor = {
            steps = {
                bg("SushiParlor_Background"),
                move("Chef", "middle_left", { from = "off_left" }),
                "Chef: Oh! The shrimp are here.",
                "[You find yourself in a new tank, though you're not exactly sure where.]",
                "Chef: Wheres that boy, I need these shrimp wheeled inside?",
                "Jordan: ...",
                "Chef: BOY! GET OVER HERE!",
                move("Jordan", "middle_right", { from = "off_right", speed = 1.4 }),
                "Jordan: I'm here chef, where do you want them?",
                "Chef: Place them in the walk-in freezer for now.",
                "Jordan: Yes chef.",
                move("Jordan", { beside = "Chef", side = "right" }),
                "[The tank suddenly shakes as you're pushed into a different room.]",
                together(
                    move("Jordan", "right_edge", { speed = 0.5 }),
                    move("Chef",   "off_left",   { speed = 0.5 })
                ),
                "Jordan: Great.. Now I need to go out and get some other seafood for the main course.",
                "[Footsteps move away from the tank, leaving you all alone.]",
                move("Jordan", "off_left"),
                "Narrator: Well, this is interesting.",
                "Narrator: It seems you might become ceviche after all.",
                "Narrator: Are you satisfied with this ending?",
                choice{
                    {
                        text = "Yes.",
                        steps = {
                            "Narrator: You're quite an odd fellow, little shrimp.",
                            "Narrator: Perhaps you should get to know your shrimp friends a bit better before you all become food.",
                            "Narrator: Or, you don't have to. I don't control the shrimp.",
                            "[It's getting pretty cold in the tank.]",
                            "Narrator: You're probably going to fall asleep soon.",
                            "Narrator: Have a nice nap, little shrimp.",
                            "[You fall asleep in the tank.]",
                            together(
                                move("Chef",   "middle_right", { from = "off_left" }),
                                move("Jordan", "middle_left",  { from = "off_left", delay = FOLLOW_DELAY })
                            ),
                            "Chef: Alright, the shrimp are ready to be prepared.. Give me that big one for the main plate.",
                            "Jordan: Yes chef.",
                            "Chef: And, done. This will make a perfect meal.",
                        },
                        -- no next_knot: the story ends here
                    },
                    {
                        text = "No.",
                        steps = {
                            "Narrator: It won't change much at this rate, I fear.",
                            "Narrator: ...Wait, what are you doing?",
                            "Narrator: Swimming out of the tank? Will you even make it?",
                            "[There's a wet slap of something hitting the ground.]",
                            "Narrator: ..Well I'll be damned.",
                            "Narrator: There's a storm drain to your right, make a run for it.",
                            "[The sound of rapid scurrying across the floor echoes through the freezer.]",
                            "[There's a splash as you fall into the drain.]",
                        },
                        next_knot = "Ocean",
                    },
                },
            },
        },

        Ocean = {
            steps = {
                bg("Ocean_Background"),
                "Narrator: How did you even do this..",
                "Narrator: Well, you're in the ocean now.",
                "Narrator: Where do you plan to go?",
                choice{
                    { text = "Into the open sea.", next_knot = "OpenSea" },
                },
            },
        },

        OpenSea = {
            -- continues on the ocean background
            steps = {
                "Narrator: Okay then, you hop into a current above you, and you'll be there.",
                "Narrator: ..It might be a bit of a ride, though.",
                "Narrator: I hope you can dodge fish.",
                "Narrator: Oh my, look ahead!",
                fadeIn("Swarm", "center", 1.5),
                "[You see a massive swarm of shrimp and krill alike out in the distance.]",
                "Narrator: Those are wild shrimp, do you want to join them?",
            },
            -- no next_knot: the story ends here (for now)
        },

        FeedStore = {
            steps = {
                bg("FeedStore_Background", { { "Shop_Attendant", "left_edge" } }),
                "Narrator: At some point, you must've taken quite the nap.",
                "Narrator: You're not in the hatchery anymore.",
                "[A bell dings loudly in the distance.]",
                move("Jordan", "middle_right", { from = "off_right" }),
                "Shop Attendant: Welcome in!",
                "Jordan: ...",
                "Shop Attendant: ...",
                "Jordan: ...",
                "Jordan: Do you have anything that can be turned into seafood pretty quickly?",
                "Shop Attendant: Well.. um.",
                "Shop Attendant: Most of our fish aren't very uh.. edible.",
                "Shop Attendant: Oh! There's our shrimp though, back there.",
                "Jordan: ...",
                move("Jordan", "center"),
                zoom("Jordan", ZOOMS.jordan, "face"),
                "[Someone loudly walks over to the tank.]",
                "Jordan: That will do.",
                "[The bell dings again.]",
                move("Saoirse", "right_edge", { from = "off_right" }),
                "Shop Attendant: Great.. Welcome in!",
                "Saoirse: ...Thanks for having me.",
                "Shop Attendant: Always! Is there anything I can help you with?",
                move("Saoirse", { beside = "Shop_Attendant", side = "right" }, { behind = { "Jordan" } }),
                "Saoirse: Um.. Yes please. I need a shrimp for an art piece- I promise it's not weird or anything, I was just told that shrimp are good subjects and it'd be great practice and-",
                "Shop Attendant: Don't worry a thing about it, we just got a fresh supply back there by the well-dressed gentleman.",
                "Saoirse: Oh uhm.. Thank you.",
                move("Shop_Attendant", "middle_right", { behind = { "Jordan", "Saoirse" } }),
                move("Saoirse", "left_edge"),
                zoom("Saoirse", ZOOMS.saoirse, "face"),
                "[A very quiet set of footsteps makes their way towards the tank.]",
                "Jordan: ...",
                "Saoirse: ...",
                "Saoirse: Um.. Are you getting some shrimp?",
                "Jordan: ...",
                "Saoirse: ...",
                "Jordan: Yes, my boss needs a lot for a company event.",
                "Saoirse: Oh.. all of them?",
                "Jordan: Most likely.",
                "Saoirse: ...",
                "Jordan: ...",
                "Jordan: Why, do you need some?",
                "Saoirse: Well um, just one- for drawing practice.",
                "Jordan: Hm.",
                "Narrator: This is getting painful to listen to.",
                choice{
                    {
                        text = "Make yourself visible.",
                        steps = {
                            "Saoirse: Oh my, that one is beautiful.",
                            "Jordan: ...It looks unhealthy.",
                            "Saoirse: ...",
                            "Saoirse: Then it just needs some support!",
                            "Jordan: ...",
                            "Jordan: If you really need a shrimp, that one is all yours.",
                            "Saoirse: Are you sure? Don't you need all the shrimp you can get for the event?",
                            "Jordan: The head chef will throw me out if I hand him that shrimp, it's yours.",
                            "Saoirse: Oh, thank you! I'm sure you'll do great with your work.",
                            "Jordan: ...",
                            unzoom("Saoirse"),
                            "[Footsteps start to quickly move away.]",
                            "Jordan: I hope your art goes well.",
                            move("Saoirse", { beside = "Shop_Attendant", side = "left" }, { behind = { "Jordan" } }),
                            "Shop Attendant: Oh, Saoirse! Find what you need?",
                            "Saoirse: Yes, there's this beautiful shrimp in there that would be wonderful to paint.",
                            "Shop Attendant: Well that's amazing! I'll get it out and then it's all yours.",
                            "Saoirse: Amazing, thanks so much, I hope I'm not being a problem by always having you get them for me.",
                            move("Shop_Attendant", "middle_left", { behind = { "Jordan", "Saoirse" } }),
                            zoom("Shop_Attendant", ZOOMS.jordan, "middle"),
                            "Shop Attendant: Not a problem for my favorite customer!",
                            "Saoirse: Guh.",
                            "[You are suddenly pulled out of the tank by a net, then placed into a plastic bag.]",
                            unzoom("Shop_Attendant"),
                            move("Shop_Attendant", "right_edge", { behind = { "Jordan", "Saoirse" } }),
                            "Shop Attendant: Okay, five dollars, fourteen cents and it's all yours.",
                            "[The sound of loose coins hits the counter.]",
                            "Shop Attendant: Perfect, you're all set. Have a nice day!",
                            "Saoirse: Thanks, you too!",
                        },
                        next_knot = "StreetsSaoirse",
                    },
                    {
                        text = "Stay in the corner of the tank.",
                        steps = {
                            "Saoirse: ...",
                            "Jordan: Hey, Shopkeep?",
                            "Shop Attendant: Yes?",
                            "Jordan: I'd like the full stock.",
                            "Shop Attendant: Ah.. Alright. Give me a moment.",
                            "Saoirse: ...Mm",
                            unzoom("Saoirse"),
                            move("Saoirse", "off_right", { behind = { "Jordan" }, front_of = { "Shop_Attendant" } }),
                            "[Someone quietly walks away from the tank, a bell ringing in the distance.]",
                            "Shop Attendant: Alright. I'm going to have to take a few minutes to drain the tank and make sure I get all the shrimp.",
                            move("Shop_Attendant", "middle_left", { behind = { "Jordan" } }),
                            zoom("Shop_Attendant", ZOOMS.jordan, "middle"),
                            "[A tube is suddenly placed before you, yanking you up into its current.]",
                            "Shop Attendant: There they go.",
                            "Jordan: ...",
                            "[You're dropped into a giant bucket, many of your shrimp brethren falling behind you.]",
                            "Jordan: How long exactly will this take?",
                            "Shop Attendant: Just a minute or two longer, I promise.",
                            "Jordan: ...",
                            "[The machine-powered current suddenly stops.]",
                            "Shop Attendant: And done. This bucket is yours the second you pay...",
                            "Shop Attendant: Two-Hundred-seventy-four dollars and thirty-seven cents.",
                            "Jordan: ...Pricy.",
                            "Shop Attendant: They're high-quality shrimp.",
                            "Jordan: Right.",
                            together(unzoom("Jordan"), unzoom("Shop_Attendant")),
                            together(
                                move("Jordan", "right_edge"),
                                move("Shop_Attendant", { beside = "Jordan", side = "left" }, { delay = FOLLOW_DELAY })
                            ),
                            "[The sound of plastic tapping electronics echoes outside.]",
                            "Shop Attendant: ..All set. Have a nice day, sir.",
                            "Jordan: Thanks.",
                        },
                        next_knot = "StreetsJordan",
                    },
                    {
                        text = "Cause a scene.",
                        steps = {
                            "[You start swarming very fast.]",
                            "Saoirse: Hey uh..",
                            "Shop Attendant: Whats up?",
                            "Saoirse: ...",
                            "Jordan: ..Your shrimp. They're fast.",
                            "Shop Attendant: Yes, is that a problem?",
                            "[The sound of metal slamming against wood is heard.]",
                            "Jordan: The tank is shaking.",
                            move("Shop_Attendant", "middle_right"),
                            zoom("Shop_Attendant", ZOOMS.jordan, "middle"),
                            "[Someone walks over, two hands placed on the tank suddenly holding it in place.]",
                            "Shop Attendant: Well, that's a new issue.",
                            "Saoirse: ...",
                            "Saoirse: I'm going to walk down to the other store.",
                            "Jordan: I think I'll be following you.",
                            "Shop Attendant: That uh.. God- might be for the best.",
                            together(unzoom("Jordan"), unzoom("Saoirse")),
                            together(
                                move("Saoirse", "off_right"),
                                move("Jordan",  "off_right", { delay = FOLLOW_DELAY })
                            ),
                            "[Two sets of footsteps move away from the tank, the bell dings in the distance.]",
                            "Shop Attendant: Ridiculous, you shrimp suck.",
                            "Shop Attendant: ..Oh, but that big one is cool.",
                        },
                        next_knot = "ShopAttendantCounter",
                    },
                },
            },
        },

        -- These three are still placeholders in the ink, so they just load their
        -- background and end.
        ShopAttendantCounter = {
            steps = { bg("ShopAttendantCounter_Background") },
        },
        StreetsJordan = {
            steps = { bg("Streets_Background") },
        },
        StreetsSaoirse = {
            steps = { bg("Streets_Background") },
        },
    },
}

---------------------------------------------------------------------------
-- Engine state
---------------------------------------------------------------------------
local fonts  = {}
local state  = {}

local shrimp = { image = nil, quads = {} }
local bar    = { image = nil, y = 0 }          -- y = bar's top edge in game pixels
local view   = { scale = START_SCALE, ox = 0, oy = 0 }   -- current scale + letterbox offset

local screen   = "menu"        -- "menu" | "game" | "endings" | "credits"
local clock    = 0             -- seconds since launch, drives all animations
local menu     = { background = nil, selected = 1 }
local spin     = { image = nil, quads = {} }
-- phase: nil (playing) | "zoom_in" | "menu" | "settings" | "zoom_out";  t = zoom progress in seconds
local pause    = { phase = nil, t = 0, selected = 1, background = nil }
local achieved = {}            -- [knotName] = true for endings the player has reached

-- What's on stage: only the current background and on-screen sprites are kept loaded.
local scene = { bg = nil, bgName = nil, sprites = {}, tweens = {}, fade = nil, nextLayer = 0 }

local gotoKnot -- forward declaration

-- Cut a sprite sheet into frame quads, left to right, then top to bottom.
local function sliceSheet(image, frame)
    local quads = {}
    local sw, sh = image:getDimensions()
    for row = 0, sh / frame - 1 do
        for col = 0, sw / frame - 1 do
            table.insert(quads, love.graphics.newQuad(col * frame, row * frame, frame, frame, sw, sh))
        end
    end
    return quads
end

-- Turn PIXEL_GLYPHS into a LOVE image font. Image fonts are one strip of glyphs, each
-- separated by a column of a "spacer" colour (the colour of the very first pixel).
local function buildPixelFont()
    local chars = {}                                     -- UTF-8 aware, for the em dash
    for _, code in utf8.codes(PIXEL_GLYPH_ORDER) do table.insert(chars, utf8.char(code)) end

    local width = 1
    for _, ch in ipairs(chars) do
        width = width + #PIXEL_GLYPHS[ch][1] + 1
    end
    local data = love.image.newImageData(width, 5)       -- starts fully transparent
    local function spacer(x)
        for y = 0, 4 do data:setPixel(x, y, 1, 0, 1, 1) end
    end

    spacer(0)
    local x = 1
    for _, ch in ipairs(chars) do
        local rows = PIXEL_GLYPHS[ch]
        for y, row in ipairs(rows) do
            for cx = 1, #row do
                if row:sub(cx, cx) == "#" then data:setPixel(x + cx - 1, y - 1, 1, 1, 1, 1) end
            end
        end
        x = x + #rows[1]
        spacer(x)
        x = x + 1
    end

    local font = love.graphics.newImageFont(data, PIXEL_GLYPH_ORDER, 1)   -- 1px between letters
    font:setFilter("nearest", "nearest")
    return font
end

local function loadEndings()
    if not love.filesystem.getInfo(SAVE_FILE) then return end
    for name in love.filesystem.lines(SAVE_FILE) do
        if name ~= "" then achieved[name] = true end
    end
end

local function saveEnding(knotName)
    if achieved[knotName] then return end
    achieved[knotName] = true
    local names = {}
    for name in pairs(achieved) do table.insert(names, name) end
    love.filesystem.write(SAVE_FILE, table.concat(names, "\n"))
end

-- Make text safe for the pixel font: capitals only, and drop any character it has no glyph for.
local function pixelText(text)
    local out = {}
    for _, code in utf8.codes(text:upper()) do
        local ch = utf8.char(code)
        if PIXEL_GLYPHS[ch] then table.insert(out, ch) end
    end
    return table.concat(out)
end

---------------------------------------------------------------------------
-- Custom mouse cursors
---------------------------------------------------------------------------
local cursors = { source = {}, built = {}, size = 0, kind = "arrow" }

local function hasVisiblePixels(data)
    for y = 0, data:getHeight() - 1 do
        for x = 0, data:getWidth() - 1 do
            local _, _, _, a = data:getPixel(x, y)
            if a > 0 then return true end
        end
    end
    return false
end

-- Load the cursor images. A missing or fully transparent image falls back to the
-- system cursor, so the mouse never becomes invisible.
local function loadCursors()
    for kind, path in pairs(CURSOR_FILES) do
        if love.filesystem.getInfo(path) then
            local data = love.image.newImageData(path)
            if hasVisiblePixels(data) then cursors.source[kind] = data end
        end
    end
end

-- Show the normal ("arrow") or clickable ("hand") cursor.
local function setCursorKind(kind)
    cursors.kind = kind or "arrow"
    local c = cursors.built[cursors.kind]
    if c then
        love.mouse.setCursor(c)
    elseif cursors.kind == "hand" then
        love.mouse.setCursor(love.mouse.getSystemCursor("hand"))
    else
        love.mouse.setCursor()
    end
end

-- Rebuild the cursors at the current pixel size (whole-number enlargement keeps them crisp).
local function refreshCursors()
    local k = math.max(1, math.floor(view.scale + 0.5))
    if k == cursors.size then return end
    cursors.size = k
    for kind, src in pairs(cursors.source) do
        local big = love.image.newImageData(src:getWidth() * k, src:getHeight() * k)
        big:mapPixel(function(x, y)
            return src:getPixel(math.floor(x / k), math.floor(y / k))
        end)
        local hs = CURSOR_HOTSPOTS[kind]
        cursors.built[kind] = love.mouse.newCursor(big, hs.x * k, hs.y * k)
    end
    setCursorKind(cursors.kind)
end

-- Work out the scale and black-bar offsets for a window of size w x h.
-- (Pixel-font text is laid out in game pixels, so it never needs re-wrapping.)
local function updateLayout(w, h)
    local s = math.min(w / GAME_W, h / GAME_H)
    if INTEGER_SCALING and s >= 1 then s = math.floor(s) end
    view.scale = s
    view.ox = math.floor((w - GAME_W * s) / 2)
    view.oy = math.floor((h - GAME_H * s) / 2)
    refreshCursors()
end

---------------------------------------------------------------------------
-- Sprites
---------------------------------------------------------------------------
-- Columns / rows of the image that actually have pixels (so placement uses the visible art).
local function contentBounds(data)
    local w, h = data:getWidth(), data:getHeight()
    local cl, cr, ct, cb = w, -1, h, -1
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local _, _, _, a = data:getPixel(x, y)
            if a > 0 then
                if x < cl then cl = x end
                if x > cr then cr = x end
                if y < ct then ct = y end
                if y > cb then cb = y end
            end
        end
    end
    if cr < 0 then return 0, w - 1, 0, h - 1 end      -- empty image: use the whole frame
    return cl, cr, ct, cb
end

local function loadSprite(name)
    local sp = scene.sprites[name]
    if sp then return sp end
    local data = love.image.newImageData(SPRITE_DIR .. name .. ".png")
    local cl, cr, ct, cb = contentBounds(data)
    local image = love.graphics.newImage(data)
    data:release()
    scene.nextLayer = scene.nextLayer + 1
    sp = {
        name = name, image = image, w = image:getWidth(), h = image:getHeight(),
        cl = cl, cr = cr, ct = ct, cb = cb,
        x = 0, y = SPRITE_BOTTOM - image:getHeight(),   -- x / y = top-left of the image
        scale = 1, alpha = 1, layer = scene.nextLayer,
        fx = 0, fy = 0,                                 -- point it zooms towards
    }
    scene.sprites[name] = sp
    return sp
end

local function unloadSprite(name)
    local sp = scene.sprites[name]
    if not sp then return end
    sp.image:release()
    scene.sprites[name] = nil
    for i = #scene.tweens, 1, -1 do
        if scene.tweens[i].sp == sp then table.remove(scene.tweens, i) end
    end
end

local function unloadAllSprites()
    for name in pairs(scene.sprites) do unloadSprite(name) end
end

-- Unload everything on stage (used when the story starts or the player leaves it).
local function clearScene()
    unloadAllSprites()
    if scene.bg then scene.bg:release() end
    scene.bg, scene.bgName, scene.fade = nil, nil, nil
    scene.tweens, scene.nextLayer = {}, 0
end

-- Where a sprite's image (top-left x) must be for it to stand at `to`.
local function targetX(sp, to)
    local half = (sp.cr - sp.cl + 1) / 2
    if type(to) == "table" then
        local other = scene.sprites[to.beside]
        if not other then return sp.x end
        local ox = other.destX or other.x                -- if it's walking, use where it's going
        local gap = to.gap or BESIDE_GAP
        if to.side == "left" then
            return ox + other.cl - gap - (sp.cr + 1)
        end
        return ox + other.cr + 1 + gap - sp.cl
    elseif type(to) == "number" then
        return to - sp.cl - half
    elseif to == "off_left" then
        return -(sp.cr + 1) - 1
    elseif to == "off_right" then
        return GAME_W + 1 - sp.cl
    elseif to == "left_edge" then
        return EDGE_MARGIN - sp.cl
    elseif to == "right_edge" then
        return GAME_W - EDGE_MARGIN - (sp.cr + 1)
    end
    return (STAGE[to] or GAME_W / 2) - sp.cl - half
end

local function isOffScreen(sp)
    return sp.x + sp.cr + 1 <= 0 or sp.x + sp.cl >= GAME_W
end

local function focusPoint(sp, which)
    if which == "middle" then
        return (sp.cl + sp.cr + 1) / 2, (sp.ct + sp.cb + 1) / 2
    end
    local f = SPRITE_FACES[sp.name] or DEFAULT_FACE
    return f.x, f.y
end

-- Put a sprite behind and/or in front of others (lower layers are drawn first).
local function setLayer(sp, behind, front_of)
    local function pick(list, better)
        local v
        for _, n in ipairs(list or {}) do
            local o = scene.sprites[n]
            if o and o ~= sp then v = v and better(v, o.layer) or o.layer end
        end
        return v
    end
    local hi = pick(behind, math.min)
    local lo = pick(front_of, math.max)
    if hi and lo then
        sp.layer = (hi + lo) / 2
    elseif hi then
        sp.layer = hi - 0.5
    elseif lo then
        sp.layer = lo + 0.5
    end
end

-- Start one animation from the script.
local function startAction(a)
    local sp
    if a.kind == "move" then
        sp = loadSprite(a.sprite)
        if a.from then sp.x = targetX(sp, a.from) end
    elseif a.kind == "fade" then
        sp = loadSprite(a.sprite)
        sp.x = targetX(sp, a.at)
        sp.alpha = 0
    else
        sp = scene.sprites[a.sprite]
        if not sp then return end                       -- nothing to zoom
    end
    table.insert(scene.tweens, { a = a, sp = sp, delay = a.delay or 0, started = false, t = 0 })
end

local function beginTween(tw)
    local a, sp = tw.a, tw.sp
    tw.started = true
    if a.kind == "move" then
        tw.from = sp.x
        sp.destX = targetX(sp, a.to)
        tw.to = sp.destX
        setLayer(sp, a.behind, a.front_of)
        tw.dur = math.abs(tw.to - tw.from) / (WALK_SPEED * a.speed)
    elseif a.kind == "zoom" then
        if a.scale ~= 1 then sp.fx, sp.fy = focusPoint(sp, a.focus) end
        tw.from, tw.to, tw.dur = sp.scale, a.scale, ZOOM_TIME
    elseif a.kind == "fade" then
        tw.from, tw.to, tw.dur = 0, 1, a.time
    end
end

local function updateTweens(dt)
    local gone = {}
    for i = #scene.tweens, 1, -1 do
        local tw = scene.tweens[i]
        if tw.delay > 0 then
            tw.delay = tw.delay - dt
        else
            if not tw.started then beginTween(tw) end
            tw.t = tw.t + dt
            local p = (tw.dur > 0) and math.min(1, tw.t / tw.dur) or 1
            local kind, sp = tw.a.kind, tw.sp
            if kind == "move" then
                sp.x = tw.from + (tw.to - tw.from) * p
            elseif kind == "zoom" then
                local e = p * p * (3 - 2 * p)           -- ease in and out
                sp.scale = tw.from + (tw.to - tw.from) * e
            elseif kind == "fade" then
                sp.alpha = p
            end
            if p >= 1 then
                table.remove(scene.tweens, i)
                if kind == "move" then
                    sp.destX = nil
                    if isOffScreen(sp) then table.insert(gone, sp.name) end
                end
            end
        end
    end
    for _, name in ipairs(gone) do unloadSprite(name) end   -- walked off-screen: unload it
end

---------------------------------------------------------------------------
-- Backgrounds (fade to black, swap, fade back in; the fade covers only the background)
---------------------------------------------------------------------------
local function swapBackground(step)
    if scene.bg then scene.bg:release() end            -- unload the old background
    scene.bg = love.graphics.newImage(BACKGROUND_DIR .. step.name .. ".png")
    scene.bgName = step.name
    unloadAllSprites()                                 -- sprites unload when backgrounds switch
    for _, p in ipairs(step.place) do
        local sp = loadSprite(p[1])
        sp.x = targetX(sp, p[2])
    end
end

local function startBackground(step)
    if scene.bg then
        scene.fade = { step = step, phase = "out", t = 0 }
    else
        swapBackground(step)                           -- first background just fades in from black
        scene.fade = { step = step, phase = "in", t = 0 }
    end
end

local function updateFade(dt)
    local f = scene.fade
    if not f then return end
    f.t = f.t + dt
    if f.t >= BG_FADE_TIME then
        if f.phase == "out" then
            swapBackground(f.step)
            f.phase, f.t = "in", 0
        else
            scene.fade = nil
        end
    end
end

---------------------------------------------------------------------------
-- Story runner
---------------------------------------------------------------------------
-- Show one page of the current line.
local function showPage(n)
    state.page = n
    state.wrapped = state.pages[n]
    state.textLen = 0
    for _, l in ipairs(state.wrapped) do state.textLen = state.textLen + utf8.len(l) end
    state.shown = 0
end

-- "Name: text" -> speaker + text; anything else (like "[...]") has no speaker.
local function parseLine(line)
    local name, text = line:match("^([%w ]+):%s*(.*)$")
    if name and #name <= 24 then return name, text end
    return nil, line
end

-- Wrap the full line once (so words don't jump while typing out), then split it into pages.
-- With a speaker, the top line of the bar holds the name, leaving one line fewer for text.
local function showLine(line)
    local name, text = parseLine(line)
    state.speaker = name and pixelText(name .. ":") or nil
    local perPage = name and (LINES_PER_PAGE - 1) or LINES_PER_PAGE
    local _, wrapped = fonts.pixel:getWrap(pixelText(text), BAR_TEXT.w / TEXT_SCALE)
    state.pages = {}
    for i, l in ipairs(wrapped) do
        local p = math.floor((i - 1) / perPage) + 1
        state.pages[p] = state.pages[p] or {}
        table.insert(state.pages[p], l)
    end
    if #state.pages == 0 then state.pages[1] = {} end
    showPage(1)
    state.mode = "text"
end

local function lineComplete()
    return state.shown >= state.textLen
end

local function endStory()
    state.mode = "end"
    state.ending = "neutral"                           -- every ending is neutral for now
    saveEnding(state.knotName)
end

-- Run the next step of the current knot (or choice option).
local function nextStep()
    state.index = state.index + 1
    local step = state.steps[state.index]
    if step == nil then
        if state.after then gotoKnot(state.after) else endStory() end
        return
    end
    if type(step) == "string" then
        showLine(step)
    elseif step.kind == "choice" then
        state.choices, state.selected, state.mode = step.options, 1, "choice"
    elseif step.kind == "bg" then
        startBackground(step)
        state.mode = "busy"
    elseif step.kind == "group" then
        for _, a in ipairs(step.actions) do startAction(a) end
        state.mode = "busy"
    else
        startAction(step)
        state.mode = "busy"
    end
end

local function runSteps(steps, after)
    state.steps, state.index, state.after = steps or {}, 0, after
    nextStep()
end

gotoKnot = function(name)
    local knot = story.knots[name]
    assert(knot, "Unknown knot: " .. tostring(name))
    state.knotName = name
    runSteps(knot.steps, knot.next_knot)
end

local function advance()
    if state.mode ~= "text" then return end
    if not lineComplete() then
        state.shown = state.textLen                    -- skip typewriter
    elseif state.page < #state.pages then
        showPage(state.page + 1)                       -- more of this line to show
    else
        nextStep()
    end
end

local function pickChoice(i)
    local option = state.choices[i]
    if not option then return end
    state.choices = {}
    runSteps(option.steps, option.next_knot)
end

local function restart()
    clearScene()
    state = { choices = {}, selected = 1, pages = { {} }, page = 1, wrapped = {},
              textLen = 0, shown = 0, mode = "busy", steps = {}, index = 0 }
    screen = "game"
    pause.phase, pause.t = nil, 0
    gotoKnot(story.start)
end

-- Choice buttons in game pixels: each one is as tall as its wrapped text needs,
-- and they stack upwards from just above the narration bar.
local function choiceRects()
    local B = CHOICE_BOX
    local rects, heights, total = {}, {}, 0
    for i, c in ipairs(state.choices) do
        local _, lines = fonts.pixel:getWrap(pixelText(i .. ". " .. c.text),
            (B.w - B.pad_x * 2) / TEXT_SCALE)
        local h = (#lines * LINE_HEIGHT - 2) * TEXT_SCALE + B.pad_y * 2
        rects[i] = { lines = lines }
        heights[i] = h
        total = total + h + (i > 1 and B.gap or 0)
    end
    local x = math.floor((GAME_W - B.w) / 2)
    local y = bar.y - B.above_bar - total
    for i, r in ipairs(rects) do
        r.x, r.y, r.w, r.h = x, y, B.w, heights[i]
        y = y + heights[i] + B.gap
    end
    return rects
end

local function hit(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- Convert a window position to game pixels (for clicking on things in the art).
local function toGame(x, y)
    return (x - view.ox) / view.scale, (y - view.oy) / view.scale
end

local function menuButtonAt(x, y)
    local gx, gy = toGame(x, y)
    for i, b in ipairs(MENU_BUTTONS) do
        if hit(b, gx, gy) then return i end
    end
end

local function goToMenu()
    screen = "menu"
    pause.phase, pause.t = nil, 0
    clearScene()                                       -- unload the story's art
    setCursorKind("arrow")
end

local function pauseButtonAt(x, y)
    local gx, gy = toGame(x, y)
    for i, b in ipairs(PAUSE_BUTTONS) do
        if hit(b, gx, gy) then return i end
    end
end

local function startPause()
    pause.phase, pause.t, pause.selected = "zoom_in", 0, 1
    setCursorKind("arrow")
end

local function resumeFromPause()
    pause.phase, pause.t = "zoom_out", PAUSE_ZOOM_TIME   -- plays the zoom backwards
    setCursorKind("arrow")
end

local function activatePauseButton(i)
    local action = PAUSE_BUTTONS[i].action
    setCursorKind("arrow")
    if action == "main_menu" then
        goToMenu()
    elseif action == "settings" then
        pause.phase = "settings"
    end
end

local function activateMenuButton(i)
    local action = MENU_BUTTONS[i].action
    setCursorKind("arrow")
    if action == "play" then
        restart()
    elseif action == "quit" then
        love.event.quit()
    else
        screen = action                            -- "endings" or "credits"
    end
end

---------------------------------------------------------------------------
-- LOVE callbacks
---------------------------------------------------------------------------
function love.load()
    love.window.setMode(GAME_W * START_SCALE, GAME_H * START_SCALE,
        { resizable = true, vsync = 1, minwidth = GAME_W, minheight = GAME_H })
    love.window.setTitle("One In A Krillion")
    -- Nearest filtering keeps scaled-up pixel art crisp.
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Narration bar sits on the bottom edge of the game area.
    bar.image = love.graphics.newImage(BAR_IMAGE)
    bar.y = GAME_H - bar.image:getHeight()
    loadCursors()
    updateLayout(love.graphics.getDimensions())     -- also builds the cursors at this size

    -- Slice the sprite sheets into frames
    shrimp.image = love.graphics.newImage(SHRIMP_SHEET)
    shrimp.quads = sliceSheet(shrimp.image, SHRIMP_FRAME)
    spin.image   = love.graphics.newImage(SPIN_SHEET)
    spin.quads   = sliceSheet(spin.image, SHRIMP_FRAME)
    for i = #spin.quads, SPIN_FRAMES + 1, -1 do spin.quads[i] = nil end   -- ignore unused cells
    menu.background = love.graphics.newImage(MENU_BACKGROUND)
    menu.credits    = love.graphics.newImage(CREDITS_BACKGROUND)
    menu.endings    = love.graphics.newImage(ENDINGS_BACKGROUND)
    pause.background = love.graphics.newImage(PAUSE_BACKGROUND)
    fonts.pixel     = buildPixelFont()

    -- Saved endings live in LOVE's save folder (%APPDATA%\LOVE\one_in_a_krillion on Windows)
    love.filesystem.setIdentity("one_in_a_krillion")
    loadEndings()

    screen = "menu"
end

-- Called by LOVE whenever the window is resized or maximised.
function love.resize(w, h)
    updateLayout(w, h)
end

function love.update(dt)
    clock = clock + dt

    -- pause zoom animation
    if pause.phase == "zoom_in" then
        pause.t = math.min(PAUSE_ZOOM_TIME, pause.t + dt)
        if pause.t >= PAUSE_ZOOM_TIME then pause.phase = "menu" end
    elseif pause.phase == "zoom_out" then
        pause.t = math.max(0, pause.t - dt)
        if pause.t <= 0 then pause.phase = nil end
    end

    -- the story (everything here is frozen while paused)
    if screen == "game" and not pause.phase then
        updateFade(dt)
        updateTweens(dt)
        if state.mode == "text" and not lineComplete() then
            state.shown = math.min(state.textLen, state.shown + TEXT_SPEED * dt)
        elseif state.mode == "busy" and not scene.fade and #scene.tweens == 0 then
            nextStep()                                 -- animations finished: carry on
        end
    end
end

-- Where the bar shrimp's black eye is on screen, in game pixels.
local function eyePosition()
    return SHRIMP_POS.x + (SHRIMP_EYE.x - SHRIMP_PIVOT.x) * SHRIMP_SCALE,
           bar.y + SHRIMP_POS.y + (SHRIMP_EYE.y - SHRIMP_PIVOT.y) * SHRIMP_SCALE
end

local function isZooming()
    return pause.phase == "zoom_in" or pause.phase == "zoom_out"
end

-- Move into game-pixel space: everything drawn after this is in 256x128 coordinates.
-- While pausing, this also applies the zoom: the eye glides to the centre of the screen
-- as the zoom grows from 1x to PAUSE_MAX_ZOOM (smoothly eased, exponential so it feels even).
local function pushGameSpace()
    love.graphics.push()
    love.graphics.translate(view.ox, view.oy)
    love.graphics.scale(view.scale)
    if isZooming() then
        local p = pause.t / PAUSE_ZOOM_TIME
        local e = p * p * (3 - 2 * p)                     -- smoothstep ease in/out
        local z = PAUSE_MAX_ZOOM ^ e
        local ex, ey = eyePosition()
        love.graphics.translate(ex + (GAME_W / 2 - ex) * e, ey + (GAME_H / 2 - ey) * e)
        love.graphics.scale(z)
        love.graphics.translate(-ex, -ey)
    end
end

-- Background (with its fade-to-black), then the sprites in layer order. All of it is
-- drawn before the narration bar, so sprites stand behind the bar.
local function drawScene()
    pushGameSpace()
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, 0, GAME_W, GAME_H)
    if scene.bg then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(scene.bg, 0, 0)
    end
    local f = scene.fade
    if f then
        local p = math.min(1, f.t / BG_FADE_TIME)
        love.graphics.setColor(0, 0, 0, f.phase == "out" and p or (1 - p))
        love.graphics.rectangle("fill", 0, 0, GAME_W, GAME_H)
    end

    local list = {}
    for _, sp in pairs(scene.sprites) do table.insert(list, sp) end
    table.sort(list, function(a, b)
        if a.layer ~= b.layer then return a.layer < b.layer end
        return a.name < b.name
    end)
    for _, sp in ipairs(list) do
        love.graphics.setColor(1, 1, 1, sp.alpha)
        love.graphics.draw(sp.image, math.floor(sp.x + 0.5) + sp.fx, sp.y + sp.fy, 0,
            sp.scale, sp.scale, sp.fx, sp.fy)
    end
    love.graphics.pop()
end

-- Narration bar along the bottom, with the animated shrimp in its blue patch.
local function drawBar()
    pushGameSpace()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(bar.image, 0, bar.y)
    local frame = math.floor(clock * SHRIMP_FPS) % #shrimp.quads + 1
    if pause.phase then frame = 1 end              -- frozen on its first frame while paused
    love.graphics.draw(shrimp.image, shrimp.quads[frame],
        SHRIMP_POS.x, bar.y + SHRIMP_POS.y, 0,
        SHRIMP_SCALE, SHRIMP_SCALE, SHRIMP_PIVOT.x, SHRIMP_PIVOT.y)
    love.graphics.pop()
end

-- Story text inside the bar's yellow area: the speaker's name stays on the top line,
-- and their words type out on the lines below it.
local function drawText()
    if not state.wrapped then return end
    pushGameSpace()
    love.graphics.setFont(fonts.pixel)
    local x  = BAR_TEXT.x
    local y0 = bar.y + BAR_TEXT.y + 0.5
    local first = 0
    if state.speaker then
        love.graphics.setColor(NAME_COLOR)
        love.graphics.print(state.speaker, x, y0, 0, TEXT_SCALE, TEXT_SCALE)
        first = 1
    end

    -- typewriter: print wrapped lines up to `shown` characters
    love.graphics.setColor(TEXT_COLOR)
    local remaining = math.floor(state.shown)
    for i, line in ipairs(state.wrapped) do
        if remaining <= 0 then break end
        local len = utf8.len(line)
        local visible = line
        if remaining < len then
            visible = line:sub(1, utf8.offset(line, remaining + 1) - 1)
        end
        love.graphics.print(visible, x, y0 + (i - 1 + first) * LINE_STEP, 0, TEXT_SCALE, TEXT_SCALE)
        remaining = remaining - len
    end

    -- blinking "continue" arrow in the bar's bottom-right corner
    if state.mode == "text" and lineComplete() and math.floor(clock * 2) % 2 == 0 then
        local ax = BAR_TEXT.x + BAR_TEXT.w - 5
        local ay = bar.y + BAR_TEXT.y + BAR_TEXT.h - 3
        love.graphics.polygon("fill", ax, ay, ax + 5, ay, ax + 2.5, ay + 2.5)
    end
    love.graphics.pop()
end

local function drawChoices()
    pushGameSpace()
    love.graphics.setFont(fonts.pixel)
    local C = CHOICE_COLORS
    for i, r in ipairs(choiceRects()) do
        local hot = (i == state.selected)
        love.graphics.setColor(hot and C.hot_fill or C.fill)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
        love.graphics.setColor(hot and C.hot_text or C.text)
        for li, line in ipairs(r.lines) do
            love.graphics.printf(line, r.x + CHOICE_BOX.pad_x,
                r.y + CHOICE_BOX.pad_y + (li - 1) * LINE_STEP,
                (r.w - CHOICE_BOX.pad_x * 2) / TEXT_SCALE, "center", 0, TEXT_SCALE, TEXT_SCALE)
        end
    end
    love.graphics.pop()
end

-- Ending overlay over the area above the narration bar, in game pixels with the pixel font.
local function drawEnding()
    pushGameSpace()
    local top = bar.y
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, GAME_W, top)
    love.graphics.setFont(fonts.pixel)

    local ts, hs = ENDING_TITLE_SCALE, ENDING_HINT_SCALE
    local titleY = math.floor(top / 2) - 5 * ts - 2
    love.graphics.setColor(ENDING_COLORS[state.ending])
    love.graphics.printf(ENDING_TITLES[state.ending], 0, titleY, GAME_W / ts, "center", 0, ts, ts)

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.printf("CLICK TO RETURN TO THE MENU - R TO PLAY AGAIN", 0, math.floor(top / 2) + 3,
        GAME_W / hs, "center", 0, hs, hs)
    love.graphics.pop()
end

---------------------------------------------------------------------------
-- Start menu, Endings and Credits screens
---------------------------------------------------------------------------
local function drawSpinShrimp(pos, mirror)
    local frame = math.floor(clock * SPIN_FPS) % #spin.quads + 1
    local sx = mirror and -1 or 1
    love.graphics.draw(spin.image, spin.quads[frame], pos.x, pos.y, 0, sx, 1,
        SHRIMP_PIVOT.x, SHRIMP_PIVOT.y)
end

local function drawMenu()
    pushGameSpace()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(menu.background, 0, 0)

    love.graphics.setColor(1, 1, 1)
    drawSpinShrimp(SPIN_LEFT, false)
    drawSpinShrimp(SPIN_RIGHT, SPIN_MIRROR_RIGHT)
    love.graphics.pop()
end

-- Drawn in game pixels with the pixel font, so the text scales exactly like the art.
-- With ENDINGS_LIST empty, only the background shows.
local function drawEndingsList()
    pushGameSpace()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(menu.endings, 0, 0)

    if #ENDINGS_LIST > 0 then
        local L, C = ENDINGS_LAYOUT, ENDINGS_COLORS
        love.graphics.setFont(fonts.pixel)

        local found = 0
        for _, e in ipairs(ENDINGS_LIST) do
            if achieved[e.knot] then found = found + 1 end
        end
        love.graphics.setColor(C.count)
        love.graphics.printf(found .. " / " .. #ENDINGS_LIST .. " FOUND", L.left, L.count_y,
            L.right - L.left, "center")

        for i, e in ipairs(ENDINGS_LIST) do
            local y = L.list_y + (i - 1) * L.spacing
            if achieved[e.knot] then
                local kind = e.kind or "neutral"
                love.graphics.setColor(C.text)
                love.graphics.print((i .. ". " .. e.name):upper(), L.left, y)
                love.graphics.setColor(C[kind])
                love.graphics.printf(kind:upper(), L.left, y, L.right - L.left, "right")
            else
                love.graphics.setColor(C.locked)
                love.graphics.print(i .. ". ???", L.left, y)
            end
        end
    end
    love.graphics.pop()
end

local function drawCredits()
    pushGameSpace()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(menu.credits, 0, 0)
    love.graphics.pop()
end

local function overBackArrow(x, y)
    local gx, gy = toGame(x, y)
    return hit(BACK_ARROW, gx, gy)
end

-- Pause menu art over the black (its transparent areas let the black show through).
local function drawPauseMenu()
    pushGameSpace()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(pause.background, 0, 0)
    love.graphics.pop()
end

-- Settings: blank for now.
local function drawSettings()
    pushGameSpace()
    love.graphics.setColor(SETTINGS_COLOR)
    love.graphics.rectangle("fill", 0, 0, GAME_W, GAME_H)
    love.graphics.pop()
end

local function drawStory()
    drawScene()
    if state.mode == "choice" then drawChoices() end
    if state.mode == "end" then drawEnding() end
    drawBar()
    drawText()
end

function love.draw()
    love.graphics.clear(0, 0, 0)                   -- black bars around the game area
    if screen == "menu" then
        drawMenu()
    elseif screen == "endings" then
        drawEndingsList()
    elseif screen == "credits" then
        drawCredits()
    elseif pause.phase == "menu" then
        drawPauseMenu()
    elseif pause.phase == "settings" then
        drawSettings()
    else
        -- keep the picture (zoomed sprites, the pause zoom) inside the game area,
        -- not over the black side bars
        local s = view.scale
        love.graphics.setScissor(view.ox, view.oy, math.ceil(GAME_W * s), math.ceil(GAME_H * s))
        drawStory()
        love.graphics.setScissor()
    end
end

function love.mousemoved(x, y)
    if screen == "menu" then
        local i = menuButtonAt(x, y)
        if i then menu.selected = i end
        setCursorKind(i and "hand" or "arrow")
    elseif screen == "credits" or screen == "endings" then
        setCursorKind(overBackArrow(x, y) and "hand" or "arrow")
    elseif screen == "game" and pause.phase then
        if pause.phase == "menu" then
            local i = pauseButtonAt(x, y)
            if i then pause.selected = i end
            setCursorKind(i and "hand" or "arrow")
        end
    elseif screen == "game" and state.mode == "choice" then
        local gx, gy = toGame(x, y)
        for i, r in ipairs(choiceRects()) do
            if hit(r, gx, gy) then state.selected = i end
        end
    end
end

function love.mousepressed(x, y, button)
    if button ~= 1 then return end
    if screen == "menu" then
        local i = menuButtonAt(x, y)
        if i then activateMenuButton(i) end
    elseif screen == "credits" or screen == "endings" then
        if overBackArrow(x, y) then goToMenu() end     -- only the arrow goes back
    elseif pause.phase then
        if pause.phase == "menu" then                  -- clicks do nothing while zooming
            local i = pauseButtonAt(x, y)
            if i then activatePauseButton(i) end
        end
    elseif state.mode == "text" then
        advance()
    elseif state.mode == "choice" then
        local gx, gy = toGame(x, y)
        for i, r in ipairs(choiceRects()) do
            if hit(r, gx, gy) then pickChoice(i) return end
        end
    elseif state.mode == "end" then
        goToMenu()
    end
    -- (clicks while sprites are moving or the background is fading are ignored)
end

function love.keypressed(key)
    if key == "f11" then
        love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
        updateLayout(love.graphics.getDimensions())
        return
    end
    local confirm = (key == "space" or key == "return" or key == "kpenter")

    if screen == "menu" then
        local n = #MENU_BUTTONS
        if key == "escape" then
            love.event.quit()
        elseif key == "up" then
            menu.selected = (menu.selected - 2) % n + 1
        elseif key == "down" then
            menu.selected = menu.selected % n + 1
        elseif confirm then
            activateMenuButton(menu.selected)
        end
        return
    end
    if screen == "endings" or screen == "credits" then
        if key == "escape" or confirm then goToMenu() end   -- keyboard shortcut for the arrow
        return
    end
    -- From here on we're in the story. Esc pauses / resumes / backs out of Settings.
    if pause.phase == "menu" then
        local n = #PAUSE_BUTTONS
        if key == "escape" then
            resumeFromPause()
        elseif key == "up" then
            pause.selected = (pause.selected - 2) % n + 1
        elseif key == "down" then
            pause.selected = pause.selected % n + 1
        elseif confirm then
            activatePauseButton(pause.selected)
        end
        return
    elseif pause.phase == "settings" then
        if key == "escape" then pause.phase = "menu" end
        return
    elseif pause.phase then
        return                                     -- ignore keys mid-zoom
    end
    if key == "escape" then startPause() return end

    if state.mode == "text" then
        if confirm then advance() end
    elseif state.mode == "choice" then
        local n = #state.choices
        if key == "up" then
            state.selected = (state.selected - 2) % n + 1
        elseif key == "down" then
            state.selected = state.selected % n + 1
        elseif confirm then
            pickChoice(state.selected)
        else
            local num = tonumber(key)
            if num and num >= 1 and num <= n then pickChoice(num) end
        end
    elseif state.mode == "end" then
        if key == "r" then restart() elseif confirm then goToMenu() end
    end
end
