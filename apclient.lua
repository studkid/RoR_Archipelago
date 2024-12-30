require("staticvars")

local server = ""
local slot = ""
local password = ""
local connectionMessage = "Connecting..."
local messageQueue = {}
local sendMsgQueue = {}
local itemQueue = {}
local initialSetup = true
local deathLink = false

local itemsCollected = {}
local itemsBuffer = {}
local locationsMissing = {}

local game_name = "Risk of Rain"
local items_handling = 7
local message_format = AP.RenderFormat.TEXT
local ap = nil

local playerInst = nil
local common = nil
local uncommon = nil
local rare = nil
local equipment = nil
local boss = nil

local connected = false
local runStarted = false
local skipItemSend = false
local slotData = nil

local combatQueue = 0
local scale = 0
local expQueue = 0
local pickupStep = 0
local pickupStepOveride = -1
local teleFrags = 0

local unlockedMaps = {}
local unlockedStages = {1, 6}
local progStage = 2
local lastStage = -1
local portalSpawned = false
local portalToggle = false

local portalStages = nil
local stageIndex = 0
local player = nil

local mapSetup = false

-----------------------------------------------------------------------
-- AP Client Handling                                                --
-----------------------------------------------------------------------
function connect(server, slot, password)
    function on_socket_connected()
        print("Socket connected")
        if debug then log("Socket connected") end
    end

    function on_socket_error(msg)
        print("Socket error: " .. msg)
        if debug then log("Socket error: " .. msg) end
        connectionMessage = "&r&Socket error: " .. msg .. "&!&"
    end

    function on_socket_disconnected()
        print("Socket disconnected")
        if debug then print("Socket disconnected") end
        connectionMessage = "&r&Socket disconnected!&!&"
        connected = false
        skipItemSend = true
        itemsCollected = {}
    end

    function on_room_info()
        print("Room info")
        ap:ConnectSlot(slot, password, items_handling, {"Lua-APClientPP"}, {0, 5, 0})
    end

    function on_slot_connected(data)
        print("Slot connected")
        if debug then print(data) end
        if debug then log("Slot connecting...") end
        connectionMessage = "&g&Slot connected!&!&"
        slotData = data
        
        curPlayerSlot = ap:get_player_number()
        connected = true

        if data.grouping == 0 then
            locationsMissing = ap.missing_locations
        elseif data.grouping == 2 then
            mapSetup = true
        end

        if pickupStepOveride == -1 then
            pickupStepOveride = data.itemPickupStep
        end

        if deathLink == true then
            ap:ConnectUpdate(nil, { "Lua-APClientPP", "DeathLink" })
        end
        if debug then log("Slot connected") end
    end

    function on_slot_refused(reasons)
        print("Slot refused: " .. table.concat(reasons, ", "))
        if debug then print("Slot refused: " .. table.concat(reasons, ", ")) end
        connectionMessage = "&r&Slot Refused!  Check Console!&!&"
    end

    function on_items_received(items)
        if debug then print("Sending Items") end
        if(skipItemSend) then
            return
        end

        for _, item in ipairs(items) do 
            if initialSetup and (item.item == 250202 or item.item == 250203) then
            elseif item.item < 250300 then
                table.insert(itemsBuffer, 1, item)
            elseif item.item < 250400 then
                if item.item == 250302 then
                    table.insert(unlockedStages, 2)
                elseif item.item == 250303 then
                    table.insert(unlockedStages, 3)
                elseif item.item == 250304 then
                    table.insert(unlockedStages, 4)
                elseif item.item == 250305 then
                    table.insert(unlockedStages, 5)
                elseif item.item == 250306 then
                    table.insert(unlockedStages, progStage)
                    progStage = progStage + 1
                end
                if runStarted == true and slotData.grouping ~= 0 then
                    refreshOverride()
                end
            else
                table.insert(unlockedMaps, ap:get_item_name(item.item))
                if runStarted == true and slotData.grouping ~= 0 then
                    refreshOverride()
                end
            end
        end
        skipItemSend = false
        initialSetup = false
    end

    function on_location_info(items)
        print("Locations scouted: ")
        for _, item in ipairs(items) do
            print(item)
        end
    end

    function on_location_checked(locations)
        print("Locations checked: " .. table.concat(locations, ", "))
    end

    function on_data_package_changed(data_package)
        print("Data package changed: ")
        print(data_package)
    end

    function on_print(msg)
        print(msg)
        if debug then log(msg) end
        table.insert(messageQueue, msg)
    end

    function on_print_json(msg, extra)
        local newMsg = "" 
        if debug then log(ap:render_json(msg)) end
        print(ap:render_json(msg, message_format))
        
        if extra["type"] == "ItemSend" then
            table.insert(sendMsgQueue, msg)
        else
            newMsg = ap:render_json(msg, message_format):gsub("&", "and")
            table.insert(messageQueue, newMsg)
        end
    end

    function on_bounced(bounce)
        print("Bounced:")
        print(bounce)
        print("Retrieved:")    
    end

    function on_retrieved(map, keys, extra)
        print("Retrieved:")
        -- since lua tables won't contain nil values, we can use keys array
        for _, key in ipairs(keys) do
            print("  " .. key .. ": " .. tostring(map[key]))
        end
        -- extra will include extra fields from Get
        print("Extra:")
        for key, value in pairs(extra) do
            print("  " .. key .. ": " .. tostring(value))
        end
        -- both keys and extra are optional
    end

    function on_set_reply(message)
        print("Set Reply:")
    end


    local uuid = ""
    local ran, msg = pcall(AP, uuid, game_name, server)
    if not ran then
        log("Connection failed\n" .. msg)
        ap = nil
    else
        ap = msg
    end
    

    ap:set_socket_connected_handler(on_socket_connected)
    ap:set_socket_error_handler(on_socket_error)
    ap:set_socket_disconnected_handler(on_socket_disconnected)
    ap:set_room_info_handler(on_room_info)
    ap:set_slot_connected_handler(on_slot_connected)
    ap:set_slot_refused_handler(on_slot_refused)
    ap:set_items_received_handler(on_items_received)
    ap:set_location_info_handler(on_location_info)
    ap:set_location_checked_handler(on_location_checked)
    ap:set_data_package_changed_handler(on_data_package_changed)
    ap:set_print_handler(on_print)
    ap:set_print_json_handler(on_print_json)
    ap:set_bounced_handler(on_bounced)
    ap:set_retrieved_handler(on_retrieved)
    ap:set_set_reply_handler(on_set_reply)
end

-----------------------------------------------------------------------
-- Game Callbacks                                                    --
-----------------------------------------------------------------------

-- Runs on initial game load
callback.register("onLoad", function(item)
    getItemPools(ItemPool.findAll()) 

    local flags = modloader.getFlags()
    for _, flag in ipairs(flags) do
        if string.find(flag, "ap_server_") then
            local s = string.gsub(flag, "ap_server_", "")
            if type(s) == "string" then
                server = s
            end

        elseif string.find(flag, "ap_slot_") then
            local s = string.gsub(flag, "ap_slot_", "")
            if type(s) == "string" then
                slot = s
            end

        elseif string.find(flag, "ap_password_") then
            local s = string.gsub(flag, "ap_password_", "")
            if type(s) == "string" then
                password = s
            end

        elseif string.find(flag, "ap_pickup_") then
            local s = string.gsub(flag, "ap_pickup_", "")
            local i = tonumber(s)
            if i ~= nil then
                pickupStepOveride = i
            end

        elseif string.find(flag, "ap_deathlink") then
            deathLink = true
        end
        
    end

    if debug then log("\n##########################################\nAP Client Connecting\n##########################################\n") end
    -- if debug then log("connect(" .. server .. ", " .. slot .. ", " .. password .. ")") end
    
    local ran, errorMsg = pcall(connect, server, slot, password)
    if not ran then
        error("Connection failed\n" .. errorMsg)
    end
end)

-- Runs poll() every game tick
callback.register("globalStep", function(room)
    if ap and room:getName() ~= "Logo" and room:getName() ~= "Cutscene1" then
        suc, err = pcall(function () ap:poll() end)
        if err then log("pcall: "..err) end
    end

    if mapSetup then
        for _, loc in ipairs(ap.missing_locations) do
            name = ap:get_location_name(loc)
            map = string.match(name, "(.*):")
            table.insert(mapgroup[map], 1, loc)
        end
        mapSetup = false
    end
end)

-- Save the player instance to a local variable
callback.register("onPlayerInit", function(playerInstance)
    if slotData.grouping ~= 0 then
        return
    end

    playerInst = playerInstance
    local playerData = playerInstance:getData()
    playerData.overrideStage = refreshOverride()
end)

-- Give player collected items between runs
callback.register("onPlayerDraw", function(playerInstance)
    if not runStarted and connected then
        for _, item in ipairs(itemsCollected) do 
            giveItem(item)
        end

        runStarted = true
    end
end)

-- Gives exp if reward exp exceeds needed for level up
callback.register("onPlayerLevelUp", function(player)
    local pAcc = playerInst:getAccessor()

    if expQueue > 0 then
        pAcc.expr = expQueue
        expQueue = expQueue - pAcc.maxexp
    end
end)

-- Stage Override
callback.register("onPlayerStep", function(player)
    if slotData.grouping ~= 0 then
        return
    end

    local playerData = player:getData()
    local teleporter = Object.find("Teleporter"):find(1)

    if teleporter ~= nil and misc.hud:get("gold") > 0 and teleporter:get("active") == 5 then
        teleporter:set("active", 4)
    end

    if slotData ~= 0 and teleporter ~= nil and teleporter:get("active") == 4 and playerData.overrideStage ~= nil then
        playerData.teleport = 1
    end 

    if playerData.teleport == 1 then
        if misc.HUD:get("gold") == 0 then
			teleporter:set("active", 5)
			if not Object.find("EfExp"):find(1) then
				Stage.transport(playerData.overrideStage)
                playerData.teleport = 0
			end
		end
    end
end)

callback.register("onPlayerDeath", function()
    if not deathLink then return end

    ap:Bounce({
        cause = slot .. " has died.",
        source = slot,
    }, nil, nil, {"DeathLink"})
end)

callback.register("onStep", function()
    local teleInst = Object.find("Teleporter"):find(1)

    -- Combat Trap Handler
    if misc.director:getAlarm(1) > 1 and combatQueue > 0 then
        misc.director:setAlarm(1, 1)
        combatQueue = combatQueue - 1
    end

    -- Item Handler
    if next(itemsBuffer) ~= nil then
        local item = table.remove(itemsBuffer)
        if item.item ~= 250006 then
            giveItem(item)
            table.insert(itemsCollected, item)
        else
            teleFrags = teleFrags + 1
            table.insert(itemQueue, "Teleporter Fragment")
            if teleInst ~= null and canEnterFinalStage() then
                teleInst:set("epic", 1)
            end
        end
    end

    -- Map Selection
    if slotData.grouping ~= 0 and teleInst ~= nil and teleInst:get("active") == 3 then
        local nextStages = skipStage(getStageProg(Stage.getCurrentStage()))
        portalStages = nextStages

        for _, p in ipairs(Object.find("P", "vanilla"):findAllRectangle(teleInst.x - 25, teleInst.y - 20, teleInst.x + 25, teleInst.y + 14)) do
            player = p
            playerData = player:getData()

            if player:isValid() and player:get("ropeUp") == 0 and player:get("ropeDown") == 0 then
                playerData.buttonHeld = 0
            elseif player:isValid() and player:get("ropeUp") == 1 and playerData.buttonHeld == 0 then
                playerData.buttonHeld = 1
                stageIndex = math.fmod(stageIndex + 1, #portalStages + 1)
                if stageIndex > 0 then
                    player:getData().overrideStage = portalStages[stageIndex]
                else
                    refreshOverride()
                end
            elseif player:isValid() and player:get("ropeDown") == 1 and playerData.buttonHeld == 0 then
                playerData.buttonHeld = 1
                stageIndex = math.fmod(stageIndex + #portalStages, #portalStages + 1)
                if stageIndex > 0 then
                    player:getData().overrideStage = portalStages[stageIndex]
                else
                    refreshOverride()
                end
            end
        end
    end
end)

-- Location checker
-- TODO Add alternative "onItemPickup" callback when starstorm is used?
callback.register("onItemInit", function(itemInst)
    local item = itemInst:getItem()
    local map = Stage.getCurrentStage():getName()

    if connected and not item.isUseItem then
        if slotData.grouping == 0 and #locationsMissing ~= 0 then
            locationsChecked = {}

            if pickupStepOveride == pickupStep then
                table.insert(locationsChecked, ap.missing_locations[1])
                ap:LocationChecks(locationsChecked)
                itemInst:destroy()
                pickupStep = 0
            else 
                pickupStep = pickupStep + 1
            end
        elseif map ~= "Risk of Rain" and #mapgroup[map] ~= 0 then
            locationsChecked = {}
            map = Stage.getCurrentStage():getName()

            if pickupStepOveride == pickupStep then
                table.insert(locationsChecked, table.remove(mapgroup[map]))
                ap:LocationChecks(locationsChecked)
                itemInst:destroy()
                pickupStep = 0
            else
                pickupStep = pickupStep + 1
            end
        end
    end
end) 

-- Check when providence dies
callback.register("onNPCDeath", function(npc)
    if slotData.requiredFrags > teleFrags then
        return
    end

    local killed = npc:getObject()
    if killed:getName() == "Boss3" then
        ap:StatusUpdate(30)
    end
end)

-- Tracks when a current run ends
callback.register("onGameEnd", function()
    runStarted = false
    playerInst = nil
    lastStage = -1
end)

-- Run stage skip for frag hunt/non universal grouping
callback.register("onStageEntry", function()
    local stage = Stage.getCurrentStage()
    local teleObj = Object.find("Teleporter", "vanilla")
    local teleInst = teleObj:find(1)
    stageIndex = 0
    portalSpawned = false

    -- Lock final stage
    if teleInst ~= nil and canEnterFinalStage()  then
        teleInst:set("epic", 1)
    elseif teleInst ~= nil then
        teleInst:set("epic", 0)
    end

    -- Find next stage
    if slotData.grouping ~= 0 then
        refreshOverride()
    end

    -- New Run check
    if arrayContains(unlockedMaps, stage:getName()) == nil and lastStage == -1 and slotData.grouping == 2 then
        local nextStages = skipStage(0)
        Stage.transport(nextStages[math.random(#nextStages)])
        misc.director:set("enemy_buff", misc.director:get("enemy_buff") - 0.45)
        misc.director:set("stages_passed", misc.director:get("stages_passed") - 1)
    end

    lastStage = getStageProg(Stage.getCurrentStage())
end)

-----------------------------------------------------------------------
-- HUD Elements                                                      --
-----------------------------------------------------------------------

local msgTimer = 500
local itemTimer = 60

-- Draw connection status
local drawConnected = function()
    local w, h = graphics.getGameResolution()
    graphics.printColor(connectionMessage, 10, h-15)
end

-- Draws connection status on menu
callback.register("globalRoomStart", function(room)
    local roomName = room:getName()
    local title = {"Start", "Select", "SelectCoop"}

    if arrayContains(title, roomName) ~= nil then
        graphics.bindDepth(-9999, drawConnected)
    end
end) 

-- Draws in game UI
callback.register("onPlayerHUDDraw", function(player, hudX, hudY)
    local w, h = graphics.getGameResolution()
    graphics.printColor(connectionMessage, 10, h-15)

    -- "Chat" window
    for i, msg in ipairs(sendMsgQueue) do
        table.insert(messageQueue, parseJson(msg))
        table.remove(sendMsgQueue, 1)
    end

    for i, msg in pairs(messageQueue) do
        if i < 6 then
            graphics.color(Color.fromRGB(192, 192, 192))
            graphics.printColor(msg, 10, 25 + (10 * i), graphics.FONT_SMALL)
        else
            table.remove(messageQueue, 1)
            msgTimer = 500
        end
    end

    if next(messageQueue) ~= nil then
        msgTimer = msgTimer - 1

        if msgTimer < 1 then 
            table.remove(messageQueue, 1)
            msgTimer = 500
        end
    end

    -- Goal read out
    local goalString = ""
    local stage = Stage.getCurrentStage()

    if slotData.grouping == 0 then
        goalString = goalString .. (slotData.totalLocations - #locationsMissing) .. "/" .. slotData.totalLocations .. " Checks Remaining.  "
    elseif slotData.grouping == 2 and stage:getName() ~= "Risk of Rain" then
        goalString = goalString .. (slotData.totalLocations - #mapgroup[stage:getName()]) .. "/" .. slotData.totalLocations .. " Checks Remaining.  "
    end

    if(pickupStepOveride > 0) then
        goalString = goalString .. "Step Progression: " .. pickupStep .. "/" .. pickupStepOveride.. "  "
    end

    if slotData.requiredFrags > 0 then
        goalString = goalString .. teleFrags .. "/" .. slotData.requiredFrags .. " Fragments Remaining.  "
    end

    graphics.color(Color.fromRGB(192, 192, 192))
    graphics.print(goalString, w/2, h-15, graphics.FONT_DEFAULT, graphics.ALIGN_MIDDLE)

    -- Tab Menu
    if input.checkKeyboard("tab") == input.HELD then
        local offset = 0
        for i, maps in ipairs(Stage.progression) do
            stageColor(i)
            graphics.print("----- Stage " .. i, w - 100, 10 + (10 * (i + offset)), graphics.FONT_SMALL, graphics.ALIGN_RIGHT)
            for _, map in ipairs(maps:toTable()) do
                offset = offset + 1
                mapColor(map:getName())
                if mapgroup[map:getName()] ~= nil then
                    graphics.print(map:getName() .. ": " .. (slotData.totalLocations -  #mapgroup[map:getName()]) .. "/" .. slotData.totalLocations, w - 100, 10 + (10 * (i + offset)), graphics.FONT_SMALL, graphics.ALIGN_RIGHT)
                elseif map:getName() == "Risk of Rain" then
                    graphics.print(map:getName(), w - 100, 10 + (10 * (i + offset)), graphics.FONT_SMALL, graphics.ALIGN_RIGHT)
                else
                    offset = offset - 1
                end
            end
        end
    end
end)

function stageColor(stage)
    if arrayContains(unlockedStages, stage) ~= nil then
        graphics.color(Color.fromHex(0x14ee00))
    else
        graphics.color(Color.fromHex(0xfd0000))
    end
end

function mapColor(map)
    if arrayContains(unlockedMaps, map) ~= nil then
        graphics.color(Color.fromHex(0x14ee00))
    else
        graphics.color(Color.fromHex(0xfd0000))
    end
end

callback.register("onPlayerDrawAbove", function(player)
    if #itemQueue > 0 then
        graphics.color(Color.fromRGB(192, 192, 192))

        if itemTimer < 16 then
            graphics.alpha(itemTimer / 10)
        end

        graphics.print(itemQueue[1], player.x, player.y - 20 - (30 - itemTimer/2), graphics.FONT_LARGE, graphics.ALIGN_MIDDLE)

        if itemTimer < 1 then
            table.remove(itemQueue, 1)
            itemTimer = 60
        end

        itemTimer = itemTimer - .5
        graphics.alpha(1)
    end
end)

-- Print Teleporter warp text
callback.register("onDraw", function()
    local teleInst = Object.find("Teleporter"):find(1)
    if slotData.grouping == 2 and teleInst ~= nil and teleInst:get("active") == 3 and Object.find("P", "vanilla"):findRectangle(teleInst.x - 25, teleInst.y - 20, teleInst.x + 25, teleInst.y + 14) and player ~= nil then
        local upKeyStr = "Up"
        local downKeyStr = "Down"
        if player and player:isValid() then
            upKeyStr = input.getControlString("up", player)
            downKeyStr = input.getControlString("down", player)
        end

        local name = "Random Stage"
        if stageIndex > 0 then
            name = portalStages[stageIndex]:getName()
        end
        local destText = "Current Destination: &r&" .. name .. "&!&"
        local text = ""
        local pp = not net.online or player == net.localPlayer
        if input.getPlayerGamepad(player) and pp then
            text = "Press '" .. upKeyStr .. "'/'" .. downKeyStr .. "' to change destination"
        else
            text = "Press " .. "&y&'" .. upKeyStr .. "'&!&" .. "/" .. "&y&'" .. downKeyStr .. "'&!&" .. " to change destination"
        end

        graphics.color(Color.WHITE)
        graphics.printColor(destText, teleInst.x - (graphics.textWidth("Current Destination: " .. name, graphics.FONT_DEFAULT) / 2), teleInst.y + 20)
        graphics.printColor(text, teleInst.x - (graphics.textWidth("Press '" .. upKeyStr .. "'/'" .. downKeyStr .. "' to change destination", graphics.FONT_DEFAULT) / 2), teleInst.y + 30)
    end
end)

-----------------------------------------------------------------------
-- Helper functions                                                  --
-----------------------------------------------------------------------

-- Checks array for value
-- TODO Convert existing arrays to lists instead and use it's contains function instead
function arrayContains(tab, val)
    for i, value in ipairs(tab) do
        if value == val then
            return i
        end
    end
    return nil
end

function canEnterFinalStage()
    return slotData.requiredFrags <= teleFrags and (slotData.grouping == 0 or arrayContains(unlockedMaps, "Risk of Rain") ~= nil) and (slotData.stageFiveTp == 0 or getStageProg(Stage.getCurrentStage()) == 5)
end

-- Registers every necessary itemPool
function getItemPools(itemPools) 
    for i, pool in pairs(itemPools) do
        if pool:getName() == "common" then
			common = pool
		end

		if pool:getName() == "uncommon" then
			uncommon = pool
		end

		if pool:getName() == "rare" then
			rare = pool
		end

		if pool:getName() == "use" then
			equipment = pool
		end
    end

    boss = ItemPool.new("boss")
    
    boss:add(Item.find("ifrit's horn"))
    boss:add(Item.find("Colossal Knurl"))
    boss:add(Item.find("Nematocyst Nozzle"))
    boss:add(Item.find("Burning Witness"))
    boss:add(Item.find("Legendary Spark"))
    boss:add(Item.find("Imp Overlord's Tentacle"))
end

-- Check stage progression
function getStageProg(stage)
    for i = 1, 6 do
		if Stage.progression[i]:contains(stage) then
			return i
		end
	end
end

-- Add Message
function addMessage(msg)
    if not msg then
        return
    end

    if type(msg) == "table" then
        return
    else
        table.insert(messageQueue, msg)
    end
end

-- Json Parse
function parseJson(msg)
    newMsg = ""
    for _, str in ipairs(msg) do
        if str.type == "player_id" then -- Player ID Color
            local pName = ap:get_player_alias(str.text):gsub("&", "and")
            if str.text == curPlayerSlot then
                newMsg = newMsg .. "&p&"
            else
                newMsg = newMsg .. "&y&"
            end
            newMsg = newMsg .. pName .. "&!&"
            
        elseif str.type == "item_id" then -- Item ID Color
            local itemName = ap:get_item_name(str.text):gsub("&", "and")
            if str.flags == 4 then
                newMsg = newMsg .. "&r&"
            elseif str.flags == 1 then
                newMsg = newMsg .. "&g&"
            else
                newMsg = newMsg .. "&b&"
            end
            newMsg = newMsg .. itemName .. "&!&"

        elseif str.type == "location_id" then -- Location ID Color
            newMsg = newMsg .. "&g&" .. ap:get_location_name(str.text):gsub("&", "and")
        else
            newMsg = newMsg .. str.text
        end
    end
    return (newMsg)
end

-- Give Item
function giveItem(item)
    if item.item == nil then
        return
    end

    itemSent = nil
    itemSfx = Sound.find("pickup")

    -- Items
    if item.item == 250001 then -- Common Item
        itemSent = common:roll()
        playerInst:giveItem(itemSent)
        itemSfx:play()
    elseif item.item == 250002 then -- Uncommon Item
        itemSent = uncommon:roll()
        playerInst:giveItem(itemSent)
        itemSfx:play()
    elseif item.item == 250003 then -- Rare Item
        itemSent = rare:roll()
        playerInst:giveItem(itemSent)
        itemSfx:play()
    elseif item.item == 250004 then -- Boss Item
        bossItem = boss:roll()

        if bossItem.isUseItem then
            bossItem:create(playerInst.x, playerInst.y)
        else 
            playerInst:giveItem(bossItem)
        end
    elseif item.item == 250005 then -- Equipment
        equipment:roll():create(playerInst.x, playerInst.y)
    
    -- Fillers
    elseif item.item == 250101 then -- Money
        misc.hud:set("gold", misc.hud:get("gold") + (100 * Difficulty.getScaling(cost)))
        local coins = Sound.find("coin")
        coins:play()
    elseif item.item == 250102 then -- Experience
        local pAcc = playerInst:getAccessor()
        expGiven = 1000
        if expGiven > pAcc.maxexp then
            pAcc.expr = pAcc.maxexp
            expQueue = expGiven - pAcc.maxexp
        end

    -- Traps
    elseif item.item == 250201 then -- Time Warp
        misc.hud:set("minute", misc.hud:get("minute") + 1)
        misc.director:set("enemy_buff", misc.director:get("enemy_buff") + (Difficulty.getActive().scale * 1))
    elseif item.item == 250202 and runStarted then -- Combat
        combatQueue = combatQueue + 5
    elseif item.item == 250203 and runStarted then -- Meteor
        playerInst:activateUseItem(true, Item.find("Glowing Meteorite"))
        playerInst:activateUseItem(true, Item.find("Glowing Meteorite"))
        playerInst:activateUseItem(true, Item.find("Glowing Meteorite"))
        playerInst:activateUseItem(true, Item.find("Glowing Meteorite"))
        playerInst:activateUseItem(true, Item.find("Glowing Meteorite"))
    end

    if itemSent ~= nil then
        table.insert(itemQueue, itemSent:getName())
    end
end

-- Skips current stage to next unlocked stage
function skipStage(stageProg)
    local nextProg = math.fmod(stageProg, 5) + 1

    while arrayContains(unlockedStages, nextProg) == nil do
        nextProg = math.fmod(nextProg, 5) + 1
    end

    local stageTab = Stage.progression[nextProg]
    return getStagesUnlocked(stageTab:toTable(), stageProg)
end

-- Checks if stages are unlocked for the given progression level
function getStagesUnlocked(progression, stageProg)
    local newProgression = {}
    for _, map in ipairs(progression) do
        if arrayContains(unlockedMaps, map:getName()) ~= nil then
            table.insert(newProgression, map)
        end
    end

    if #newProgression == 0 then
        if slotData.strictStageProg == 0 then
            local nextProg = math.fmod(stageProg, 5) + 1

            while arrayContains(unlockedStages, nextProg) == nil do
                nextProg = math.fmod(nextProg, 5) + 1
            end

            newProgression = getStagesUnlocked(Stage.progression[nextProg]:toTable(), nextProg)
        else
            newProgression = getStagesUnlocked(Stage.progression[1]:toTable(), stageProg)
        end
    end

    return newProgression
end

function refreshOverride()
    stage = Stage.getCurrentStage()
    for _, player in ipairs(misc.players) do
        local playerData = player:getData()
        local nextStages = skipStage(getStageProg(stage))
        if debug then print(nextStages) end
        playerData.overrideStage = nextStages[math.random(#nextStages)]
    end 
end