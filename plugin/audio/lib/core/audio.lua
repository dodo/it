local ffi = require 'ffi'
local util = require 'util'
local cface = require 'cface'
local Metatype = require 'metatype'
local doc = require 'util.doc'


local define
do local header
    _, header, define = cface(_it.plugin.audio.libdir .. "openal.h")
end


local Audio = require('events'):fork()
Audio.type = Metatype:struct("it_audios", {
    "int refc";
    "ALCdevice *device";
    "ALCcontext *context";
    "ALuint *sources";
    "int nsource";
})

Audio.type:load('libaudio.so', {
    init = [[void it_inits_audio(it_audios* audio,
                                 const ALCchar *devicename,
                                 const ALCint* attrlist,
                                 int nsource)]];
    __gc = [[void it_frees_audio(it_audios* audio)]];
})


Audio.LIB = 'libopenal'
Audio.C = Metatype:fork():lib(Audio.LIB, 'al'):new()
Audio.ctype = {
    device = Metatype:use(Audio.LIB, nil, 'ALCdevice', 'CloseDevice'),
    context = Metatype:use(Audio.LIB, nil, 'ALCcontext', 'DestroyContext'),
}
do local   type
    for _, type in pairs(Audio.ctype) do
        type.metatype.prefix = 'alc'
    end
end


function Audio:init(devicename, opts)
    self.prototype.init(self)
    opts = opts or {}
    opts.sources = opts.sources or 1
    self.native = self.type:create(nil, devicename, opts.attrs, opts.sources)
end
doc.info(Audio.init,
        'audio:init',
        '( [devicename], opts={ sources=1[, attrs] } )')


return Audio
