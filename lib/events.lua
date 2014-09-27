local Prototype = require 'prototype'

EventEmitter = Prototype:fork()

function EventEmitter:init()
    self._events = {}
end

function EventEmitter:on(event, listener)
    self:emit('newListener', event, listener)
    if not self._events[event] then
        self._events[event] = listener
    elseif type(self._events[event]) == 'function' then
        self._events[event] = { self._events[event], listener }
    else
        table.insert(self._events[event], listener)
    end
    return self
end

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

function EventEmitter:removeAllListeners(event)
    if event then
        self._events[event] = nil
    else
        self._events = {}
    end
    return self
end

return EventEmitter
