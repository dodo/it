-- link core lib
package.path = './lib/?.lua;' .. package.path

process = require('events'):new()

-- call c to pump moar values into lua state
__it_boots(process)


-- print(require('util').dump(process.argv))

if #process.argv == 0 then
    print "no repl, no script file."
    process.exit(1)
else
    print(process.argv[1])
--     dofile(process.argv[2])
end
