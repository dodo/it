local Prototype = require 'prototype'
local doc = require 'util.doc'

local EventEmitter = Prototype:fork()

function EventEmitter:init()
    self._events = {}
end
doc.info(EventEmitter.init, 'events:init', '(  )')

function EventEmitter:on(event, listener)
    self:emit('newListener', event, listener)
    if not self._events[event] then
        self._events[event] = listener
    elseif type(self._events[event]) == 'function' then
        self._events[event] = { self._events[event], listener, length = 2 }
    else
        table.insert(self._events[event], listener)
        self._events[event].length = self._events[event].length + 1
    end
    return self
end
doc.info(EventEmitter.on, 'events:on', '( event, listener )')

function EventEmitter:once(event, handler)
    if not self._events[event] then
        self._events[event] = { length = 0 }
    elseif type(self._events[event]) == 'function' then
        self._events[event] = { self._events[event], length = 1 }
    end
    return self:on(event, setmetatable({
        emitter = self,
        handler = handler,
    }, {
        __call = function (t, ...)
            t.handler(...)
            t.emitter:off(t.handler)
        end,
    }))
end
doc.info(EventEmitter.once, 'events:once', '( event, listener )')

function EventEmitter:off(event, handler)
    local listeners = self._events and self._events[event]
    if not listeners then return false end
    if type(listeners) == 'function' then
        if listeners == handler then
            self._events[event] = nil
            return true
        end
    else
        for i, listener in ipairs(listeners) do
            if listener == handler or
               (type(listener) == 'table' and listener.handler == handler) then
                if listeners.length == 1 then
                    self._events[event] = nil
                else
                    table.remove(listeners, i)
                    listeners.length = listeners.length - 1
                end
                return true
            end
        end
    end
    return false
end
doc.info(EventEmitter.off, 'events:off', '( event, listener )')

function EventEmitter:emit(event, ...)
    if event == "error" and self._events and not self._events.error then
        error(...)
        return false
    end
    if not self._events then return false end
    local handler = self._events[event]
    if not handler then return false end
    if type(handler) == 'function' then
        handler(...)
    else
        for _, listener in ipairs(handler) do
            listener(...)
        end
    end
    return true
end
doc.info(EventEmitter.emit, 'events:emit', '( event[, ...] )')

function EventEmitter:listeners(event)
    local handler = self._events[event]
    if type(handler) == 'function' then
        return { handler, length = 1 }
    else
        return handler -- already a list
    end
end
doc.info(EventEmitter.listeners, 'events:listeners', '( event )')

function EventEmitter:removeAllListeners(event)
    if event then
        self._events[event] = nil
    else
        self._events = {}
    end
    return self
end
doc.info(EventEmitter.removeAllListeners, 'events:removeAllListeners', '( [ event ] )')

return EventEmitter
