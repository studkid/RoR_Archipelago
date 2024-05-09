local stagePortal = Object.base("MapObject", "stagePortal")
stagePortal.sprite = Sprite.load("portal", 1, 15, 20)

portalStages = nil

stagePortal:addCallback("create", function(self)
    local selfData = self:getData()
    self:set("active", 0)
    self:set("myplayer", -4)
    selfData.stage = nil
    selfData.index = 1
    selfData.colBoxMult = 1
end)

stagePortal:addCallback("step", function(self)
    local selfAc = self:getAccessor()
    local selfData = self:getData()

    if selfAc.active == 0 then
        for _, player in ipairs(Object.find("P", "vanilla"):findAllRectangle(self.x - 15 * selfData.colBoxMult, self.y - 20 * selfData.colBoxMult, self.x + 15 * selfData.colBoxMult, self.y + 14 * selfData.colBoxMult)) do
            selfAc.myplayer = player.id
            
            if player:isValid() and player:control("enter") == input.PRESSED then
                local playerData = player:getData()
                playerData.overrideStage = portalStages[selfData.index]
                Object.find("Teleporter", "vanilla"):find(1):set("active", 4)
                selfAc.active = 1
            elseif player:isValid() and player:control("swap") == input.PRESSED then
                selfData.index = math.fmod(selfData.index, #portalStages) + 1
            end
        end
    end
end)

stagePortal:addCallback("draw", function(self)
    local selfAc = self:getAccessor()
    local selfData = self:getData()

    if selfAc.active == 0 then
        if Object.find("P", "vanilla"):findRectangle(self.x - 15 * selfData.colBoxMult, self.y - 20 * selfData.colBoxMult, self.x + 15 * selfData.colBoxMult, self.y + 14 * selfData.colBoxMult) and selfAc.myplayer ~= -4 then
            local player = Object.findInstance(selfAc.myplayer)

            local keyStr = "Activate"
            if player and player:isValid() then
				keyStr = input.getControlString("enter", player)
			end

            local name = portalStages[selfData.index]:getName()
            local text = ""
            local pp = not net.online or player == net.localPlayer
            if input.getPlayerGamepad(player) and pp then
                text = "Press " .. "'" .. keyStr .. "'" .. " to teleport to &y&" .. name
            else
                text = "Press " .. "&y&" .. keyStr .. "&!&" .. " to teleport to &y&" .. name
            end
            graphics.color(Color.WHITE)
            graphics.alpha(1)
            graphics.printColor(text, self.x - 88, self.y - 30)

            if player and player:isValid() then
				keyStr = input.getControlString("swap", player)
			end

            if input.getPlayerGamepad(player) and pp then
                text = "Press " .. "'" .. keyStr .. "'" .. " to change location"
            else
                text = "Press " .. "&r&" .. keyStr .. "&!&" .. " to change location"
            end
            graphics.color(Color.WHITE)
            graphics.alpha(1)
            graphics.printColor(text, self.x - 88, self.y - 40)
        end
    end
end)

return stagePortal