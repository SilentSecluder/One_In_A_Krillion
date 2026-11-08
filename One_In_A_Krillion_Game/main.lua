-- One In A Krillion : a small visual novel engine for LOVE2D (11.x / 12.x)
--
-- Controls
--   Click / Space / Enter : advance text (first press finishes the typewriter)
--   Up / Down + Enter      : choose an option   (or click it, or press 1-9)
--   R                      : restart (on an ending screen)
--   Esc                    : quit
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

local W, H          = 1280, 720
local TEXT_SPEED    = 50       -- characters per second
local BOX_MARGIN    = 40
local BOX_HEIGHT    = 220
local BOX_PADDING   = 24

-- Shrimp sprite sheet: 64x64 image = 2x2 grid of 32x32 frames (read left-to-right, top-to-bottom)
local SHRIMP_SHEET  = "assets/Shrimp_Animations/Shrimp_Anim_Cycle.png"
local SHRIMP_FRAME  = 32       -- frame size in pixels
local SHRIMP_FPS    = 6        -- animation speed
local SHRIMP_SCALE  = 4        -- 32px drawn at 128px on screen
local SHRIMP_MARGIN = 16       -- gap from the screen's left/bottom edge

---------------------------------------------------------------------------
-- Scenes (swap `image` for a real file path, e.g. "assets/feedstore.png")
---------------------------------------------------------------------------
local SCENES = {
    feedstore = { top = {0.20, 0.45, 0.50}, bottom = {0.08, 0.20, 0.25}, image = nil },
    saoirse   = { top = {0.55, 0.38, 0.55}, bottom = {0.22, 0.14, 0.26}, image = nil },
    jordan    = { top = {0.40, 0.44, 0.52}, bottom = {0.14, 0.15, 0.20}, image = nil },
    ocean     = { top = {0.08, 0.30, 0.55}, bottom = {0.01, 0.05, 0.15}, image = nil },
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
local bubbles = {}

-- The text box starts to the right of the shrimp so the two don't overlap.
local boxX       = SHRIMP_MARGIN * 2 + SHRIMP_FRAME * SHRIMP_SCALE
local boxY       = H - BOX_HEIGHT - BOX_MARGIN
local boxW       = W - boxX - BOX_MARGIN
local shrimp     = { image = nil, quads = {} }
local textW      = boxW - BOX_PADDING * 2

local gotoKnot -- forward declaration

local function getImage(path)
    if not path then return nil end
    if images[path] == nil then
        images[path] = love.filesystem.getInfo(path) and love.graphics.newImage(path) or false
    end
    return images[path] or nil
end

-- Wrap the full line once, so words don't jump lines while typing out.
local function startLine()
    local text = state.lines[state.lineIndex]
    local _, wrapped = fonts.body:getWrap(text, textW)
    state.wrapped = wrapped
    state.textLen = 0
    for _, l in ipairs(wrapped) do state.textLen = state.textLen + utf8.len(l) end
    state.shown = 0
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
    state = { visited = {}, used = {}, choices = {}, selected = 1, time = state.time or 0 }
    gotoKnot(story.start)
end

local function choiceRects()
    local rects = {}
    local bw, bh, gap = 820, 54, 14
    local total = #state.choices * bh + (#state.choices - 1) * gap
    local y = boxY - 30 - total
    for i = 1, #state.choices do
        rects[i] = { x = (W - bw) / 2, y = y + (i - 1) * (bh + gap), w = bw, h = bh }
    end
    return rects
end

local function hit(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

---------------------------------------------------------------------------
-- LOVE callbacks
---------------------------------------------------------------------------
function love.load()
    love.window.setMode(W, H, { resizable = false, vsync = 1 })
    love.window.setTitle("One In A Krillion")
    love.graphics.setDefaultFilter("linear", "linear")

    fonts.body   = love.graphics.newFont(22)
    fonts.choice = love.graphics.newFont(21)
    fonts.title  = love.graphics.newFont(48)
    fonts.small  = love.graphics.newFont(16)

    -- Slice the sprite sheet into frames (nearest filter keeps pixel art crisp)
    shrimp.image = love.graphics.newImage(SHRIMP_SHEET)
    shrimp.image:setFilter("nearest", "nearest")
    local sw, sh = shrimp.image:getDimensions()
    for row = 0, sh / SHRIMP_FRAME - 1 do
        for col = 0, sw / SHRIMP_FRAME - 1 do
            table.insert(shrimp.quads, love.graphics.newQuad(
                col * SHRIMP_FRAME, row * SHRIMP_FRAME, SHRIMP_FRAME, SHRIMP_FRAME, sw, sh))
        end
    end

    for i = 1, 25 do
        bubbles[i] = { x = love.math.random(0, W), y = love.math.random(0, H),
                       r = love.math.random(2, 7), s = love.math.random(20, 60) }
    end

    state.time = 0
    restart()
end

function love.update(dt)
    state.time = state.time + dt
    if state.mode == "text" and not lineComplete() then
        state.shown = math.min(state.textLen, state.shown + TEXT_SPEED * dt)
    end
    for _, b in ipairs(bubbles) do
        b.y = b.y - b.s * dt
        if b.y < -10 then b.y, b.x = H + 10, love.math.random(0, W) end
    end
end

local function drawBackground()
    local scene = SCENES[state.knot.scene] or SCENES.feedstore
    local img = getImage(scene.image)
    if img then
        local s = math.max(W / img:getWidth(), H / img:getHeight())
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(img, W / 2, H / 2, 0, s, s, img:getWidth() / 2, img:getHeight() / 2)
    else
        -- simple vertical gradient made of bands
        local bands = 48
        for i = 0, bands - 1 do
            local t = i / (bands - 1)
            love.graphics.setColor(
                scene.top[1] + (scene.bottom[1] - scene.top[1]) * t,
                scene.top[2] + (scene.bottom[2] - scene.top[2]) * t,
                scene.top[3] + (scene.bottom[3] - scene.top[3]) * t)
            love.graphics.rectangle("fill", 0, i * H / bands, W, H / bands + 1)
        end
    end
    love.graphics.setColor(1, 1, 1, 0.18)
    for _, b in ipairs(bubbles) do
        love.graphics.circle("line", b.x + math.sin(state.time * 2 + b.y * 0.02) * 4, b.y, b.r)
    end
end

-- Animated 32px shrimp, fixed in the bottom-left corner of the screen.
local function drawShrimp()
    local frame = math.floor(state.time * SHRIMP_FPS) % #shrimp.quads + 1
    local size  = SHRIMP_FRAME * SHRIMP_SCALE
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(shrimp.image, shrimp.quads[frame],
        SHRIMP_MARGIN, H - SHRIMP_MARGIN - size, 0, SHRIMP_SCALE, SHRIMP_SCALE)
end

local function drawTextBox()
    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", boxX, boxY, boxW, BOX_HEIGHT, 14, 14)
    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.rectangle("line", boxX, boxY, boxW, BOX_HEIGHT, 14, 14)

    -- typewriter: print wrapped lines up to `shown` characters
    love.graphics.setFont(fonts.body)
    love.graphics.setColor(1, 1, 1)
    local remaining = math.floor(state.shown)
    local lh = fonts.body:getHeight() * 1.15
    for i, line in ipairs(state.wrapped) do
        if remaining <= 0 then break end
        local len = utf8.len(line)
        local visible = line
        if remaining < len then
            visible = line:sub(1, utf8.offset(line, remaining + 1) - 1)
        end
        love.graphics.print(visible, boxX + BOX_PADDING, boxY + BOX_PADDING + (i - 1) * lh)
        remaining = remaining - len
    end

    -- "continue" indicator
    if state.mode == "text" and lineComplete() and math.floor(state.time * 2) % 2 == 0 then
        local x, y = boxX + boxW - 34, boxY + BOX_HEIGHT - 28
        love.graphics.polygon("fill", x, y, x + 16, y, x + 8, y + 10)
    end
end

local function drawChoices()
    local mx, my = love.mouse.getPosition()
    love.graphics.setFont(fonts.choice)
    for i, r in ipairs(choiceRects()) do
        local hot = (i == state.selected)
        love.graphics.setColor(hot and 0.95 or 0.10, hot and 0.55 or 0.10, hot and 0.48 or 0.14, 0.92)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 10, 10)
        love.graphics.setColor(1, 1, 1, hot and 1 or 0.4)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 10, 10)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(i .. ".  " .. state.choices[i].text, r.x + 16,
            r.y + (r.h - fonts.choice:getHeight()) / 2, r.w - 32, "center")
    end
end

local function drawEnding()
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, W, boxY - 10)
    love.graphics.setFont(fonts.title)
    local col = ({ good = {0.6, 1, 0.6}, bad = {1, 0.45, 0.45}, neutral = {0.75, 0.85, 1} })[state.ending]
    love.graphics.setColor(col)
    love.graphics.printf(ENDING_TITLES[state.ending], 0, boxY / 2 - 60, W, "center")
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.printf("Click or press R to play again", 0, boxY / 2 + 10, W, "center")
end

function love.draw()
    drawBackground()
    drawTextBox()
    if state.mode == "choice" then drawChoices() end
    if state.mode == "end" then drawEnding() end
    drawShrimp()
end

function love.mousemoved(x, y)
    if state.mode == "choice" then
        for i, r in ipairs(choiceRects()) do
            if hit(r, x, y) then state.selected = i end
        end
    end
end

function love.mousepressed(x, y, button)
    if button ~= 1 then return end
    if state.mode == "text" then
        advance()
    elseif state.mode == "choice" then
        for i, r in ipairs(choiceRects()) do
            if hit(r, x, y) then pickChoice(i) return end
        end
    elseif state.mode == "end" then
        restart()
    end
end

function love.keypressed(key)
    if key == "escape" then love.event.quit() return end

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
        if key == "r" or key == "return" or key == "space" then restart() end
    end
end
