
local exports = {}
local console = exports

console.color = {
        default    = "\27[m",
        -- styles
        bold       = "\27[1m",
        underline  = "\27[4m",
        blink      = "\27[5m",
        reverse    = "\27[7m",
        concealed  = "\27[8m",
        -- font colors
        black      = "\27[30m",
        red        = "\27[31m",
        green      = "\27[32m",
        yellow     = "\27[33m",
        blue       = "\27[34m",
        magenta    = "\27[35m",
        cyan       = "\27[36m",
        white      = "\27[37m",
        -- background colors
        on_black   = "\27[40m",
        on_red     = "\27[41m",
        on_green   = "\27[42m",
        on_yellow  = "\27[43m",
        on_blue    = "\27[44m",
        on_magenta = "\27[45m",
        on_cyan    = "\27[46m",
        on_white   = "\27[47m",
}

-- aliases
console.color.reset = console.color.default

return exports
