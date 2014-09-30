process = require('events'):new()

-- call c to pump moar values into lua state
_it.boots(process)


-- print(require('util').dump(process.argv))

if #process.argv == 0 then
    print "no repl, no script file."
    process.exit(1)
else
    process.shutdown = true
    dofile(process.argv[1])
    -- TODO test if something happened
    if process.shutdown then
        process.exit() -- normally
    end
end
