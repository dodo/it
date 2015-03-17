if _it and require('prostitution').emulate(1) then return end

x = x or 0
y = y or 0
function love.load(arg)
    if arg and arg[#arg] == "-debug" then require("mobdebug").start() end
    x, y = love.window.getDimensions()
    x, y = x / 2, y / 2
end

function love.update(dt)
    x, y = love.mouse.getPosition()
end

p = p or 0
function love.draw()
    love.graphics.print(love.timer.getFPS(), 10, 10)
    love.graphics.print(love.timer.getDelta(), 10, 20)


    love.graphics.print('Hello World!', 234, p)
    p = (p+1) % love.window.getHeight()


    love.graphics.circle('line', x, y, math.abs(30 - (p*1.2)%60))
end
