local server = ""
local slot = ""
local password = ""
local connectionMessage = "Connecting..."
local messageQueue = {}

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

local checks = 0
local combatQueue = 0
local scale = 0
local expQueue = 0
local pickupStep = 0
local teleFrags = 0

-----------------------------------------------------------------------
-- AP Client Handling                                                --
-----------------------------------------------------------------------
function connect(server, slot, password)
    function on_socket_connected()
        print("Socket connected")
    end

    function on_socket_error(msg)
        print("Socket error: " .. msg)
        connectionMessage = "&r&Socket cannot be found!&!&"
    end

    function on_socket_disconnected()
        print("Socket disconnected")
        connectionMessage = "&r&Socket disconnected!&!&"
        connected = false
        skipItemSend = true
        itemsCollected = {}
    end

    function on_room_info()
        print("Room info")
        ap:ConnectSlot(slot, password, items_handling, {"Lua-APClientPP"}, {0, 4, 4})
    end

    function on_slot_connected(data)
        print("Slot connected")
        connectionMessage = "&g&Socket connected!&!&"
        slotData = data
        print(slotData)
        
        curPlayerSlot = ap:get_player_number()
        connected = true

        locationsMissing = ap.missing_locations
    end

    function on_slot_refused(reasons)
        print("Slot refused: " .. table.concat(reasons, ", "))
        connectionMessage = "&r&Slot Refused!  Check Console!&!&"
    end

    function on_items_received(items)
        if(skipItemSend) then
            return
        end

        for _, item in ipairs(items) do 
            table.insert(itemsBuffer, item)
        end
        skipItemSend = false
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
        table.insert(messageQueue, msg)
    end

    function on_print_json(msg, extra)
        print(ap:render_json(msg, message_format))
        table.insert(messageQueue, ap:render_json(msg, message_format))
    end

    function on_bounced(bounce)
        print("Bounced:")
        print(bounce)
    end

    function on_retrieved(map, keys, extra)
        print("Retrieved:")    
    end

    function on_set_reply(message)
        print("Set Reply:")
    end


    local uuid = ""
    ap = AP(uuid, game_name, server);

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
        end
    end
    
	connect(server, slot, password)
end)

-- Runs poll() every game tick
callback.register("globalStep", function(room)
    if ap then
        ap:poll() 
    end
end)

-- Save the player instance to a local variable
callback.register("onPlayerInit", function(playerInstance)
    playerInst = playerInstance
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


callback.register("onStep", function()
    -- Combat Trap Handler
    if misc.director:getAlarm(1) > 1 and combatQueue > 0 then
        misc.director:setAlarm(1, 1)
        combatQueue = combatQueue - 1
    end

    -- Item Handler
    if itemsBuffer[1] ~= nil then
        item = table.remove(itemsBuffer, 1)
        if item.item ~= 250006 then
            giveItem(item)
            table.insert(itemsCollected, item)
        else
            teleFrags = teleFrags + 1
        end
    end
end)

-- Location checker
-- TODO Add alternative "onItemPickup" callback when starstorm is used?
callback.register("onItemInit", function(itemInst)
    item = itemInst:getItem()

    if connected and not item.isUseItem then
        locationsChecked = {}

        if slotData.itemPickupStep == pickupStep then
            table.insert(locationsChecked, ap.missing_locations[1])
            ap:LocationChecks(locationsChecked)
            itemInst:destroy()
            pickupStep = 0
            checks = checks + 1
        else 
            pickupStep = pickupStep + 1
        end
    end
end) 

-- Check when providence dies
callback.register("onNPCDeath", function(npc)
    local killed = npc:getObject()
    if killed:getName() == "Boss3" then
        ap:StatusUpdate(30)
    end
end)

-- Tracks when a current run ends
callback.register("onGameEnd", function()
    runStarted = false
    playerInst = nil
end)

callback.register("onGameStart", function()
    if slotData.requiredFrags > teleFrags then
        Stage.progressionLimit(99999)
    end
end)

callback.register("onStageEntry", function(npc)
	if slotData.requiredFrags > teleFrags then
        Stage.progressionLimit(0)
    end
end)

-----------------------------------------------------------------------
-- HUD Elements                                                      --
-----------------------------------------------------------------------

local msgTimer = 500

-- Draw connection status
local drawConnected = function()
    local w, h = graphics.getGameResolution()
    graphics.printColor(connectionMessage, 10, h-15)
end

-- Draws connection status on menu
callback.register("globalStep", function(room)
    local roomName = room:getName()
    local title = {"Start", "Select", "SelectCoop"}

    if arrayContains(title, roomName) then
        graphics.bindDepth(-9999, drawConnected)
    end
end) 

-- Draws in game UI
callback.register("onPlayerHUDDraw", function(player, hudX, hudY)
    local w, h = graphics.getGameResolution()
    graphics.printColor(connectionMessage, 10, h-15)

    -- "Chat" window
    for i, msg in pairs(messageQueue) do
        if i < 6 then
            -- msg = "Recieved " .. ap:get_item_name(item.item) .. " from &y&" .. ap:get_player_alias(item.player) .. "&!&"
            graphics.print(msg, 10, 25 + (10 * i), graphics.FONT_SMALL)
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
    if slotData.requiredFrags < 1 then
        graphics.print((slotData.totalLocations - #locationsMissing) .. "/" .. slotData.totalLocations .. 
                        " Checks Remaining.  Step Progression: " .. pickupStep .. "/" .. slotData.itemPickupStep, 
                        w/2, h-15, graphics.FONT_DEFAULT, graphics.ALIGN_MIDDLE)
    else
        graphics.print((slotData.totalLocations - #locationsMissing) .. "/" .. slotData.totalLocations .. 
                        " Checks Remaining.  " .. teleFrags .. "/" .. slotData.requiredFrags .. " Fragments Remaining.  " .. 
                        "Step Progression: " .. pickupStep .. "/" .. slotData.itemPickupStep,
                        w/2, h-15, graphics.FONT_DEFAULT, graphics.ALIGN_MIDDLE)
    end
end)

-----------------------------------------------------------------------
-- Helper functions                                                  --
-----------------------------------------------------------------------

-- Checks array for value
function arrayContains(tab, val)
    for _, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
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

function giveItem(item)
    -- Items
    if item.item == 250001 then -- Common Item
        playerInst:giveItem(common:roll())
    elseif item.item == 250002 then -- Uncommon Item
        playerInst:giveItem(uncommon:roll())
    elseif item.item == 250003 then -- Rare Item
        playerInst:giveItem(rare:roll())
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
    elseif item.item == 250102 then -- Experience
        local pAcc = playerInst:getAccessor()
        expGiven = 1000
        if expGiven > pAcc.maxexp then
            pAcc.expr = pAcc.maxexp
            expQueue = expGiven - pAcc.maxexp
        end

    -- Traps
    elseif item.item == 250201 then -- Time Warp
        misc.hud:set("minute", misc.hud:get("minute") + 5)
        misc.director:set("enemy_buff", misc.director:get("enemy_buff") + (Difficulty.getActive().scale * 5))
    elseif item.item == 250202 and runStarted then -- Combat
        combatQueue = combatQueue + 5
    elseif item.item == 250203 and runStarted then -- Meteor
        playerInst:activateUseItem(true, Item.find("Glowing Meteorite"))
        playerInst:activateUseItem(true, Item.find("Glowing Meteorite"))
        playerInst:activateUseItem(true, Item.find("Glowing Meteorite"))
        playerInst:activateUseItem(true, Item.find("Glowing Meteorite"))
        playerInst:activateUseItem(true, Item.find("Glowing Meteorite"))
    end
end