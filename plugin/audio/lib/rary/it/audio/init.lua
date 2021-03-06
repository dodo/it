local ffi = require 'ffi'
local util = require 'util'
local cdef = require 'cdef'
local cface = require 'cface'
local Metatype = require 'metatype'
local doc = require 'util.doc'


local submodules = util.lazysubmodules('audio', {'buffer'})

local Audio = require('events'):fork(submodules)


cdef({
    constants = 'AL*',
    typedefs  = 'AL*',
    functions = 'al*',
    verbose   = process.verbose,
})

Audio.define = {}
for stmt in cdef({ find=true, constants='AL*' }) do
    if stmt.kind == 'MacroDefinition' then
        Audio.define[stmt.name] = tonumber(stmt.extent)
    end
end


Audio.type = Metatype:struct("it_audios", cdef)

Audio.type:load(_it.api('audio'), {
    __ref = 'it_refs',
    __unref = 'it_unrefs',
    __ac = 'it_allocs_audio',
    __init = 'it_inits_audio',
    __gc = 'it_frees_audio',
}, cdef)


Audio.LIB = 'libopenal'
Audio.C = Metatype:fork():lib(Audio.LIB, 'al'):new()
Audio.Buffer = require('audio.buffer')
Audio.Buffer.Audio = Audio -- prevent circular dependency
-- Audio.ctype = {
-- --     device = Metatype:use(Audio.LIB, nil, 'ALCdevice', 'CloseDevice'),
-- --     context = Metatype:use(Audio.LIB, nil, 'ALCcontext', 'DestroyContext'),
-- }
-- do local   type
--     for _, type in pairs(Audio.ctype) do
--         type.metatype.prefix = 'alc'
--     end
-- end


function Audio:__new(devicename, opts)
    self.prototype.__new(self)
    opts = opts or {}
    opts.sources = opts.sources or 1
    self.native = self.type:create(
        nil, -- no pointers here because there is only one context per process
        devicename,
        opts.attrs,
        opts.sources
    )
end
doc.info(Audio.__new,
        'Audio:new',
        '( [devicename], ' ..
        'opts={ sources=1[, attrs] } )')

function Audio:source(i, state)
    if type(i) ~= 'number' then
        i, state = nil, i
    end
    if state then
        local value = ffi.new("ALint[?]", 1)
        local src = self.native.sources[i or 0]
        state = string.upper(state):gsub('%s', '_')
        state = Audio.define["AL_" .. state]
        Audio.C.GetSourcei(src, state, value)
        return value[0]
    end
end

function Audio:push(i, buffers, num_buffers)
    if type(i) ~= 'number' then
        i, buffers, num_buffers = nil, i, buffers
    end
    if buffers.id and buffers.number then
        -- we got a Audio.Buffer
        num_buffers = buffers.number
        buffers = buffers.id
    end
    if num_buffers and buffers then
        local src = self.native.sources[i or 0]
        -- this will trigger the source to be in AL_STREAMING state
        Audio.C.SourceQueueBuffers(src, num_buffers, buffers)
    end
end
doc.info(Audio.push, 'audio:push', '( [i=0], buffers[, num_buffers] )')

function Audio:pop(i, buffers, num_buffers)
    if type(i) ~= 'number' then
        i, buffers, num_buffers = nil, i, buffers
    end
    if buffers.id and buffers.number then
        -- we got a Audio.Buffer
        num_buffers = buffers.number
        buffers = buffers.id
    end
    if num_buffers and buffers then
        local src = self.native.sources[i or 0]
        Audio.C.SourceUnqueueBuffers(src, num_buffers, buffers)
    end
end
doc.info(Audio.pop, 'audio:pop', '( [i=0], buffers[, num_buffers] )')


function Audio:play(i)
    local src = self.native.sources[i or 0]
    Audio.C.SourcePlay(src)
end
doc.info(Audio.play, 'audio:play', '( i=0 )')

function Audio:Pause(i)
    local src = self.native.sources[i or 0]
    Audio.C.SourcePause(src)
end
doc.info(Audio.pause, 'audio:pause', '( i=0 )')

function Audio:stop(i)
    local src = self.native.sources[i or 0]
    Audio.C.SourceStop(src)
end
doc.info(Audio.stop, 'audio:stop', '( i=0 )')

function Audio:rewind(i)
    local src = self.native.sources[i or 0]
    Audio.C.SourceRewind(src)
end
doc.info(Audio.rewind, 'audio:rewind', '( i=0 )')


return Audio
