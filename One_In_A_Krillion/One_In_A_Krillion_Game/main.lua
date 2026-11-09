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
-- The story below is a hand conversion of One_In_A_Krillion.ink.
-- Each "knot" has:
--   lines    = list of strings shown one at a time
--   choices  = list of { text, target, after = {lines}, requires = "KnotName" }
--              (choices are once-only like ink's "*"; `requires` = ink's {KnotName})
--   divert   = knot to jump to when lines finish (if no choices)
--   ending   = "good" | "bad" | "neutral"
--   scene    = key into SCENES (background colour / optional image)

local utf8 = require("utf8")

-- The game is drawn at 256x128 "game pixels". The window opens at 3x (768x384) and is
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
local BAR_TEXT    = { x = 29, y = 4, w = 222, h = 21 }  -- yellow area the story text goes in
local TEXT_COLOR  = { 0.16, 0.13, 0.08 }               -- dark brown, readable on the yellow

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

-- Shrimp sprite sheet: 64x64 image = 2x2 grid of 32x32 frames (read left-to-right, top-to-bottom)
local SHRIMP_SHEET = "assets/Sprites/Shrimp_Animations/Shrimp_Anim_Cycle.png"
local SHRIMP_FRAME = 32         -- frame size in pixels
local SHRIMP_FPS   = 6          -- animation speed
local SHRIMP_SCALE = 0.7        -- half size: the 26x22 px shrimp becomes 13x11
-- Centre of the blue patch (x 0-22, y 3-25), relative to the bar's top-left.
local SHRIMP_POS   = { x = 11.5, y = 14.5 }
-- Middle of the shrimp's drawn pixels inside its 32x32 frame (art spans x 4-29, y 5-26),
-- used as the pivot so the shrimp itself, not the empty frame, is what gets centred.
local SHRIMP_PIVOT = { x = 17, y = 16 }

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
    count_y   = 40,     -- "X / 7 FOUND" line
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
    ["&"] = { ".#..", "#.#.", ".#.#", "#.#.", ".#.#" },
    ["—"] = { "....", "....", "####", "....", "...." },   -- em dash
    [" "] = { "...", "...", "...", "...", "..." },
}
local PIXEL_GLYPH_ORDER = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!?'\"-/:()&—"

-- Every ending in the story, in the order the Endings screen lists them.
local ENDINGS_LIST = {
    { knot = "Saoirse121",  name = "A Shrimple Life" },
    { knot = "Saoirse1201", name = "..Not Healthy" },
    { knot = "Jordan111",   name = "One Rich Shrimp" },
    { knot = "Jordan102",   name = "Dog Food" },
    { knot = "Jordan1011",  name = "Pleasant Nap" },
    { knot = "Whale1",      name = "...Well, That Was Fast" },
    { knot = "Whale2",      name = "Convenient Snack" },
}
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
-- Scenes (swap `image` for a real file path, e.g. "assets/feedstore.png")
---------------------------------------------------------------------------
local SCENES = {
    feedstore = { color = {0.14, 0.32, 0.37}, image = nil },
    saoirse   = { color = {0.38, 0.26, 0.40}, image = nil },
    jordan    = { color = {0.27, 0.29, 0.36}, image = nil },
    ocean     = { color = {0.05, 0.17, 0.35}, image = nil },
}

---------------------------------------------------------------------------
-- Story data
---------------------------------------------------------------------------
local story = {
    start = "Intro",
    knots = {
        Intro = {
            scene = "feedstore",
            lines = {
                [[You are a shrimp.]],
                [[You are a very smart shrimp.]],
                [[From the ashes of the local feed store you rose, a genius crustacean ready to take on the world.]],
                [[But you have no human body, you can make no financial decisions on your own.]],
                [[You must pick a body—er, owner, to succeed.]],
            },
            divert = "Human",
        },

        Human = {
            scene = "feedstore",
            lines = {
                [[Two beings stand before you: A man, well-groomed and smug, playing with the cuffs of his suit—and a woman, short statured and easily intimidated, refusing eye-contact with even you.]],
                [[They both wear convenient name-tags, the smug one reading to your shrimpish eyes as "Jorqan", whereas the short one reads as "Sassi". These are definitely not their names.]],
            },
            choices = {
                { text = [[Lean towards "Jorqan".]], target = "Jordan" },
                { text = [[Lean towards "Sassi".]], target = "Saoirse" },
                { text = [[Crawl back into your tank cave.]], target = "Whale1" },
            },
        },

        -- Saoirse arc --------------------------------------------------------
        Saoirse = {
            scene = "saoirse",
            lines = {
                [[The shorter one offers you a tiny smile, while the smug guy saunters away, mildly annoyed at the shrimp, but also glaring at the attendant as if the shrimp not loving him was their fault. Whatever dude.]],
                [[You're gently scooped into a bag—just you, nobody else—then paid for and taken on a slow walk down the street, just you in your giant bag, and "Sassi". She's humming this low, stuttery song, it sounds almost like a lullaby, soothing and soft, but scared in her voice. Poor girl, what is a shrimp possibly going to do with her?]],
                [[Eventually, you're taken into her sublet home, a small studio room filled with various crafts of many kinds, clay pottery, easels covered in paint, knitted cloth lying half-complete on the floor. It's a mess, but it's hers. And yours too, apparently.]],
                [["Sassi" places you into a glass vase filled with lukewarm water, of which has a surprisingly large amount of room in it to swim around. You have quite a hard time getting to the top of the vase, it's tall, slick shape making it near impossible to grab ahold of the rim. Perhaps you should simply observe, a smart shrimp knows better than to make a mess before understanding a situation, right?]],
                [[You hear "Sassi" mumbling something across the room, and upon sticking your shrimp ear-holes out of the top of the vase, you find her complaining of the four dollars in her bank account, praying that her latest art won't fall through.]],
                [[You're a shrimp, you don't understand art, but you do recognize that you're being stared at in an almost analytical way, so you should probably stop peering out the top of the vase like some shrimp deity.]],
            },
            choices = {
                { text = [[Be a normal shrimp.]], target = "Saoirse100" },
                { text = [[Keep trying to listen.]], target = "Whale2",
                  after = { [["Sassi" freaks out at your weird shrimp behavior, immediately flushing you down the sink.]] } },
            },
        },

        Saoirse100 = {
            scene = "saoirse",
            lines = {
                [[You swim back down into the vase, then start mimicking standard swarming behavior, spinning in reckless circles up and down and along the tank. "Sassi" seems to appreciate this, sketching on her easel excitedly. It's an hour or two, but eventually she stands up and walks away, likely to make herself food. Now is the time to be a smart shrimp.]],
                [[You climb out of your vase very carefully, setting up a way to get back in by moving small clay sculptures to make a giant path back up. Then, you move to her horrible computer setup, scrolling through, who you now know as Saoirse's terrible finances. She is very very broke, surviving on a thread, and it's highly unlikely she'll make next months rent.]],
                [[As a genius shrimp, you have two choices:]],
            },
            choices = {
                { text = [[Write a note about selling prints of Saoirse's art.]], target = "Saoirse101" },
                { text = [[Commit Tax Evasion on her current sales.]], target = "Saoirse120" },
                { text = [[COMMIT TAX EVASION!!!!]], target = "Saoirse120", requires = "Saoirse101",
                  after = { [[We appreciate excited shrimps but calm down it's just some money.]] } },
            },
        },

        Saoirse101 = {
            scene = "saoirse",
            lines = {
                [[After climbing back into your tank, Saoirse sees the note, finds it cryptic, and immediately throws it in the trash like it is tainted. So much for that.]],
                [[Eventually, she finishes her pretty shrimp painting, one you must admire for its beauty, and releases you into the ocean, much to your despair. You're very quickly eaten by a giant fish.]],
                [[But you're a genius shrimp, lets start over, shall we?]],
            },
            choices = {
                { text = [[Go back in time.]], target = "Saoirse100" },
                { text = [[Succumb to the shrimp life-cycle.]], target = "Jordan1011" },
            },
        },

        Saoirse120 = {
            scene = "saoirse",
            lines = {
                [[You do a little movement around and hacking in bank systems (how does a shrimp even do that?) and suddenly, Saoirse can make rent, and she has some money to spare. You really are a smart shrimp.]],
                [[Somehow, Saoirse doesn't question this change, instead taking it as a sign to keep making good art. But you have to justify where this money came from before tax season hits.]],
                [[What do you do?]],
            },
            choices = {
                { text = [[Forge statements from an international transaction.]], target = "Saoirse121" },
                { text = [[Don't file Saoirse's taxes this year.]], target = "Saoirse1201",
                  after = { [[You intercept Saoirse's taxes before she can send them off with the mail, and somehow, she doesn't notice.]] } },
                { text = [[Hope the government doesn't notice.]], target = "Saoirse1201",
                  after = { [[So they saw the sudden increase in money without a transaction history..]] } },
            },
        },

        Saoirse121 = {
            scene = "saoirse", ending = "good",
            lines = {
                [[It works! They don't notice a thing, and Saoirse is starting to make it big in the art world. She featured in a gallery shortly after tax season, and met some people who bought a lot of her pieces. Now, you don't even have to commit tax evasion for her, she's taking good care of you all on her own, and calls you her lucky shrimp all the time, whatever that means.]],
                [[This is the good life for a shrimp, you did a good job.]],
                [[You truly are one in a krillion.]],
            },
        },

        Saoirse1201 = {
            scene = "saoirse", ending = "bad",
            lines = {
                [[Saoirse's sublet gets raided, and unfortunately, in the crossfire, some clay dust is thrown haphazardly into your vase-tank. This was far too much for you to survive in, and suddenly, you are dead. Maybe this isn't how you commit tax evasion.]],
            },
        },

        -- Jordan arc ---------------------------------------------------------
        Jordan = {
            scene = "jordan",
            lines = {
                [["Jorqan" smuggly takes charge and calls the very tired attendant over, where you are scooped out of your container with your brethren, and dropped into a bag of water. Before you know it, your soul has been paid for and tossed into a cooler in the back of a pricy BMW.]],
                [[You and your fellow (much stupider, mind you) shrimp are taken to some absurdly tall high-rise building 30 minutes downtown, then hauled through a back entrance and handed to someone that looks chef-adjacent. As a shrimp, you don't speak english, nor can you understand it while underwater—but you can guess, by the very pointed middle finger the chef-like human throws "Jorqan"s way, that you are not the correct shrimp he wanted.]],
                [[A very annoyed "Jorqan" trudges back to his ridiculous car, glancing at the bag as if contemplating what to do. He then spots a storm drain at the edge of the dreary parking garage, slowly moving over towards it like a man on a weary mission.]],
            },
            choices = {
                { text = [[Plead pitifully up towards "Jorqan" for your life.]], target = "Jordan100" },
                { text = [[Enjoy the internal debate happening before you.]], target = "Whale2" },
            },
        },

        Jordan100 = {
            scene = "jordan",
            lines = {
                [["Jorqan" sighs, loudly, hauling his shrimp friends with him. Because the rest of the shrimp aren't the brightest shrimp in the bioluminescent shrimp family, they tore a hole in the top of the bag and leapt for freedom towards the storm drain. Only like.. half of them made it.]],
                [[It is simply you and "Jorqan" now, and judging by the open banking apps on his phone indicating several maxed out credit cards, you'll have a lot of work to do.]],
                [[Eventually, you make it back to "Jorqan"s house, where he dumps you half-heartedly into an empty fish-bowl next to his desk, immediately leaving to go back to his terrible 9-5 job downtown. Luckily for you, his laptop is on, and you are a very smart shrimp.]],
                [[Ensuring "Jorqan" is gone, you climb out of your bowl and set up a very careful pencil system and thick notebook-paper leaning against the tank, allowing you to climb back in at a moments notice, before sitting yourself down in front of his horrible finances. Student-loans, terrible credit, near-empty bank account, this man is a mess.]],
                [[As a shrimp, you have two choices:]],
            },
            choices = {
                { text = [[Commit Tax Evasion.]], target = "Jordan110" },
                { text = [[Do nothing.]], target = "Jordan101" },
                { text = [[COMMIT TAX EVASION!!!]], target = "Jordan110", requires = "Jordan101",
                  after = { [[You're a little excited, God.]] } },
            },
        },

        Jordan110 = {
            scene = "jordan",
            lines = {
                [[As a genius shrimp, you are incredibly good at hiding money from your government. An offshore account here, a physical asset there, and suddenly the man you now know as Jordan disappears from government oversight.]],
                [[But wait, tax season is coming up, and you have to find a way to justify Jordan's expenses to reduce government suspicion. What will you do?]],
            },
            choices = {
                { text = [[Create a fake business to route Jordan's finances through.]], target = "Jordan111" },
                { text = [[Don't file Jordan's taxes this year.]], target = "Jordan102",
                  after = { [[You intercept Jordan's taxes before he can send them off with the mail, and somehow, he doesn't notice.]] } },
                { text = [[Hope and pray the government doesn't catch on.]], target = "Jordan102",
                  after = { [[So they saw the transactions into offshore accounts...]] } },
            },
        },

        Jordan111 = {
            scene = "jordan", ending = "good",
            lines = {
                [[Now you're playing smart. They don't suspect a thing, and in fact, you can route even more money through here and use it for yourself if you sign Jordan up for an online bank he doesn't know about. You're such a smart shrimp.]],
                [[Somehow, Jordan is becoming very financially sound, he's calling you his "Good luck shrimp", or something. All that really matters is you've gotten a bigger tank you're having a very easy time climbing out of, and a new beta-fish friend who keeps trying to eat you. It's not working, you're nearly the same size after all, but it's still mildly annoying.]],
                [[In pursuit of final shrimp happiness, you've ordered yourself premium shrimp food, which Jordan has been feeding you in confused bewilderment. The beta-fish has begun leaving you alone, so that's something to be happy about.]],
                [[Maybe this is the life you were meant to live, free from the swarming cycle of the ocean, no longer destined to be consumed by a big whale.]],
                [[You truly are one in a krillion.]],
            },
        },

        Jordan102 = {
            scene = "jordan", ending = "bad",
            lines = {
                [[The government caught on to what "Jordan" has been doing, and now he is under investigation. As a shrimp, there is nothing you can do about the police swarming your home and taking note of everything around you. While doing a deep search with drug-sniffing dogs, one of the animals ate you out of the bowl. There goes that, I guess.]],
            },
        },

        Jordan101 = {
            scene = "jordan",
            lines = {
                [[Probably not the smartest idea to get involved with government finances, right? Climbing back into your tank, you get to live out the rest of your days watching the man you now know as Jordan lose his job, go bankrupt, then move back in with his parents.]],
                [[As you sink to the bottom of your bowl, unclean and filled with disgusting substrate, you watch this man revert back to a reddit mod in his parents basement, masters degree gone to waste.]],
                [[It was a brief year under his care, but you almost regret it, don't you? Maybe you should have commited tax evasion.]],
                [[...I mean, you can still change this. Just go back a line and try again, you're a genius shrimp, after all.]],
            },
            choices = {
                { text = [[Go back in time.]], target = "Jordan100" },
                { text = [[Succumb to the shrimp life-cycle.]], target = "Jordan1011" },
            },
        },

        Jordan1011 = {
            scene = "ocean", ending = "neutral",
            lines = {
                [[..Yeah okay, have a good sleep shrimp, you are NOT one in a krillion.]],
            },
        },

        -- Whale endings ------------------------------------------------------
        Whale1 = {
            scene = "ocean", ending = "neutral",
            lines = {
                [[Both walk away, deciding to try their luck with other feed shops, much to the attendant's disappointment.]],
                [[As per feed store protocol, you were later dumped illegally back into the ocean.]],
                [[Then you started swarming.]],
                [[Then you were eaten by a whale.]],
                [[Congrats?]],
            },
        },

        Whale2 = {
            scene = "ocean", ending = "neutral",
            lines = {
                [[You were dumped illegally back into the ocean.]],
                [[Then you started swarming.]],
                [[Then you were eaten by a whale.]],
                [[Congrats?]],
            },
        },
    },
}

local ENDING_TITLES = {
    good    = "GOOD ENDING",
    bad     = "BAD ENDING",
    neutral = "NEUTRAL ENDING",
}

---------------------------------------------------------------------------
-- Engine state
---------------------------------------------------------------------------
local fonts  = {}
local images = {}
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

local function getImage(path)
    if not path then return nil end
    if images[path] == nil then
        images[path] = love.filesystem.getInfo(path) and love.graphics.newImage(path) or false
    end
    return images[path] or nil
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

-- Show one page (up to LINES_PER_PAGE wrapped lines) of the current story line.
local function showPage(n)
    state.page = n
    state.wrapped = state.pages[n]
    state.textLen = 0
    for _, l in ipairs(state.wrapped) do state.textLen = state.textLen + utf8.len(l) end
    state.shown = 0
end

-- Wrap the full line once (so words don't jump while typing out), then split it into pages.
local function startLine()
    local text = pixelText(state.lines[state.lineIndex])
    local _, wrapped = fonts.pixel:getWrap(text, BAR_TEXT.w / TEXT_SCALE)   -- width in font pixels
    state.pages = {}
    for i, line in ipairs(wrapped) do
        local p = math.floor((i - 1) / LINES_PER_PAGE) + 1
        state.pages[p] = state.pages[p] or {}
        table.insert(state.pages[p], line)
    end
    if #state.pages == 0 then state.pages[1] = {} end
    showPage(1)
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

local function setLines(lines, onFinish)
    state.lines, state.lineIndex, state.onFinish = lines, 1, onFinish
    if #lines == 0 then onFinish() else startLine() end
end

local function lineComplete()
    return state.shown >= state.textLen
end

local function buildChoices()
    state.choices = {}
    for i, c in ipairs(state.knot.choices) do
        local id = state.knotName .. ":" .. i
        if not state.used[id] and (not c.requires or state.visited[c.requires]) then
            table.insert(state.choices, { text = c.text, target = c.target, after = c.after, id = id })
        end
    end
    state.selected = 1
    state.mode = "choice"
end

local function finishKnot()
    local knot = state.knot
    if knot.choices then
        buildChoices()
        if #state.choices == 0 then          -- ran out of options: treat as an ending
            state.ending, state.mode = "neutral", "end"
        end
    elseif knot.divert then
        gotoKnot(knot.divert)
    else
        state.ending = knot.ending or "neutral"
        state.mode = "end"
        saveEnding(state.knotName)
    end
end

gotoKnot = function(name)
    local knot = story.knots[name]
    assert(knot, "Unknown knot: " .. tostring(name))
    state.knotName, state.knot = name, knot
    state.visited[name] = true
    state.mode = "text"
    setLines(knot.lines, finishKnot)
end

local function nextLine()
    if state.page < #state.pages then          -- more of this line to show
        showPage(state.page + 1)
        return
    end
    state.lineIndex = state.lineIndex + 1
    if state.lineIndex > #state.lines then
        state.lineIndex = #state.lines       -- keep last line on screen
        state.onFinish()
    else
        startLine()
    end
end

local function advance()
    if state.mode ~= "text" then return end
    if not lineComplete() then
        state.shown = state.textLen          -- skip typewriter
    else
        nextLine()
    end
end

local function pickChoice(i)
    local c = state.choices[i]
    if not c then return end
    state.used[c.id] = true
    state.mode = "text"
    if c.after then
        setLines(c.after, function() gotoKnot(c.target) end)
    else
        gotoKnot(c.target)
    end
end

local function restart()
    state = { visited = {}, used = {}, choices = {}, selected = 1 }
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
    -- Nearest filtering keeps scaled-up pixel art crisp; fonts set their own smooth filter.
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

    -- typewriter (frozen while paused)
    if screen == "game" and not pause.phase and state.mode == "text" and not lineComplete() then
        state.shown = math.min(state.textLen, state.shown + TEXT_SPEED * dt)
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

local function drawPixelArt()
    pushGameSpace()

    -- background: scene image if it has one, otherwise a flat colour
    local scene = SCENES[state.knot.scene] or SCENES.feedstore
    local img = getImage(scene.image)
    if img then
        local s = math.max(GAME_W / img:getWidth(), GAME_H / img:getHeight())
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(img, GAME_W / 2, GAME_H / 2, 0, s, s, img:getWidth() / 2, img:getHeight() / 2)
    else
        love.graphics.setColor(scene.color)
        love.graphics.rectangle("fill", 0, 0, GAME_W, GAME_H)
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

-- Story text, drawn in game pixels with the pixel font inside the bar's yellow area.
local function drawText()
    pushGameSpace()
    love.graphics.setFont(fonts.pixel)
    love.graphics.setColor(TEXT_COLOR)

    -- typewriter: print wrapped lines up to `shown` characters
    local remaining = math.floor(state.shown)
    local block = (#state.wrapped * LINE_HEIGHT - 2) * TEXT_SCALE
    local x  = BAR_TEXT.x
    local y0 = bar.y + BAR_TEXT.y + math.floor((BAR_TEXT.h - block) / 2 / TEXT_SCALE) * TEXT_SCALE
    for i, line in ipairs(state.wrapped) do
        if remaining <= 0 then break end
        local len = utf8.len(line)
        local visible = line
        if remaining < len then
            visible = line:sub(1, utf8.offset(line, remaining + 1) - 1)
        end
        love.graphics.print(visible, x, y0 + (i - 1) * LINE_STEP, 0, TEXT_SCALE, TEXT_SCALE)
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
local function drawEndingsList()
    pushGameSpace()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(menu.endings, 0, 0)

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
            local kind = story.knots[e.knot].ending
            love.graphics.setColor(C.text)
            love.graphics.print((i .. ". " .. e.name):upper(), L.left, y)
            love.graphics.setColor(C[kind])
            love.graphics.printf(kind:upper(), L.left, y, L.right - L.left, "right")
        else
            love.graphics.setColor(C.locked)
            love.graphics.print(i .. ". ???", L.left, y)
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
    drawPixelArt()
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
    elseif isZooming() then
        -- keep the zoomed picture inside the game area, not over the black side bars
        local s = view.scale
        love.graphics.setScissor(view.ox, view.oy, math.ceil(GAME_W * s), math.ceil(GAME_H * s))
        drawStory()
        love.graphics.setScissor()
    else
        drawStory()
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
        if key == "space" or key == "return" or key == "kpenter" then advance() end
    elseif state.mode == "choice" then
        local n = #state.choices
        if key == "up" then
            state.selected = (state.selected - 2) % n + 1
        elseif key == "down" then
            state.selected = state.selected % n + 1
        elseif key == "space" or key == "return" or key == "kpenter" then
            pickChoice(state.selected)
        else
            local num = tonumber(key)
            if num and num >= 1 and num <= n then pickChoice(num) end
        end
    elseif state.mode == "end" then
        if key == "r" then restart() elseif confirm then goToMenu() end
    end
end
