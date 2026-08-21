-- Enough of Hyprland's Lua config API to run hypr/.config/hypr/*.lua outside
-- Hyprland and write down every bind it declares.
--
-- WHY EXECUTE THE CONFIG INSTEAD OF READING IT. The binds are not a table a
-- regular expression can lift out: the chord is built by concatenation
-- (`mainMod .. " + " .. key`), twenty of them come out of a `for i = 1, 10`
-- loop, and only the first of each ten carries a description. A regex would
-- have to special-case that loop, and would go stale the day the loop is
-- written differently. Running the file gives the same twenty binds Hyprland
-- itself would see, and gaming.lua comes along for free through the
-- `require("gaming")` that is already in there.
--
-- Everything except `hl.bind` is a black hole: any field of `hl` can be
-- indexed, called or used as a method and yields another black hole. That is
-- what lets `hl.dsp.window.close()` and `hl.config({...})` run without this
-- file knowing a single dispatcher name -- so the API can grow without this
-- stub needing a line.

-- The black hole. One object, reused: indexing it, calling it, or calling a
-- method on it all return itself.
local sink = setmetatable({}, {
    __index    = function(t) return t end,
    __call     = function(t) return t end,
    __tostring = function() return "" end,
    __concat   = function() return "" end,
})

local binds = {}

hl = setmetatable({
    -- The one call we care about. Signature as used across the config:
    --   hl.bind(chord, dispatcher, opts?)
    -- `opts.description` is what the cheatsheet reads, and what the parity
    -- check compares against niri's hotkey-overlay-title.
    bind = function(chord, _dispatcher, opts)
        local description = ""
        if type(opts) == "table" and type(opts.description) == "string" then
            description = opts.description
        end
        -- Tab-separated because a description may contain anything else; a
        -- literal tab in one would be a bug of its own.
        binds[#binds + 1] = tostring(chord) .. "\t" .. description
        return sink
    end,

    -- Binds can be taken away as well as added, and a chord removed here must
    -- not be reported as a parity failure against niri.
    unbind = function(chord)
        local wanted = tostring(chord) .. "\t"
        for i = #binds, 1, -1 do
            if binds[i]:sub(1, #wanted) == wanted then table.remove(binds, i) end
        end
        return sink
    end,
}, { __index = function(t) return sink end })

-- The config file is given on the command line. It is loaded with the hypr
-- config directory on package.path so its own `require("gaming")` resolves,
-- exactly as it does under Hyprland.
local target = assert(arg[1], "usage: lua hl-stub.lua <hyprland.lua>")
local dir = target:match("^(.*)/[^/]+$") or "."
package.path = dir .. "/?.lua;" .. package.path

dofile(target)

for _, line in ipairs(binds) do print(line) end
