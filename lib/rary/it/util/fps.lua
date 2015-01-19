-- https://github.com/mrdoob/stats.js/blob/master/src/Stats.js
local EventEmitter = require 'events'
local round = require('util.misc').round
local doc = require 'util.doc'


local Fps = EventEmitter:fork()


function Fps:init()
    self.prototype.init(self)
    self.accuracy = 6 -- os.clock max accuracy
    self.frames = 0
    self.value = 0
    self:start()
    self.prev_time = self.start_time
end
doc.info(Fps.init, 'fps:init', '(  )')

function Fps:start()
    self.running = true
    self.start_time = os.clock()
    self:emit('start')
end
doc.info(Fps.start, 'fps:start', '(  )')

function Fps:stop()
    self.running = false
    self:emit('stop')
end
doc.info(Fps.stop, 'fps:stop', '(  )')

function Fps:update()
    if not self.running then return end
    local time = os.clock()
    self.frames = self.frames + 1
    if time > self.prev_time + 0.001 then
        self.value = round(
            (self.frames / 100) / (time - self.prev_time),
            self.accuracy
        )
        self:emit('update', self.value)
        self.prev_time = time
        self.frames = 0
    end
    self.start_time = time
    return time
end
doc.info(Fps.update, 'fps:update', '(  )')


return Fps
