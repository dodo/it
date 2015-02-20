-- https://github.com/mrdoob/stats.js/blob/master/src/Stats.js
local EventEmitter = require 'events'
local round = require('util.misc').round
local doc = require 'util.doc'


local Fps = EventEmitter:fork()
Fps.accuracy = 6 -- os.clock max accuracy
Fps.interval = 1

function Fps:init()
    self.prototype.init(self)
    self.frames = 0
    self.value = 0
    self.delta = 0
    self:start()
    self.prev_time = self.last_time
end
doc.info(Fps.init, 'fps:init', '(  )')

function Fps:start()
    self.running = true
    self.last_time = process.time()
    self:emit('start')
end
doc.info(Fps.start, 'fps:start', '(  )')

function Fps:stop()
    self.running = false
    self:emit('stop')
end
doc.info(Fps.stop, 'fps:stop', '(  )')

function Fps:update(opts)
    if not self.running then return end
    local time = process.time()
    self.frames = self.frames + 1
    if time > self.prev_time + self.interval or (opts and opts.force) then
        self.value = round(
            self.frames / (time - self.prev_time),
            self.accuracy
        )
        self:emit('update', self.value)
        self.prev_time = time
        self.frames = 0
    end
    self.delta = time - self.last_time
    self.last_time = time
    return time
end
doc.info(Fps.update, 'fps:update', '( { force=false } )')


return Fps
