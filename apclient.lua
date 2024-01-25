local chests = { 'Chest1', 'Chest2', 'Chest3', 'Chest5'}

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

local itemsCollected = {}
local locationsMissing = {}
local combatQueue = 0
local scale = 0
local expQueue = 0

-----------------------------------------------------------------------
-- AP Client Handling                                                --
-----------------------------------------------------------------------
function connect(server, slot, password)
    function on_socket_connected()
        print("Socket connected")
    end

    function on_socket_error(msg)
        print("Socket error: " .. msg)
    end

    function on_socket_disconnected()
        print("Socket disconnected")
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
        slotData = data
        
        curPlayerSlot = ap:get_player_number()
        connected = true

        print(slotData)
        -- print(ap.checked_locations)
        print(ap.missing_locations)

        locationsMissing = ap.missing_locations
    end

    function on_slot_refused(reasons)
        print("Slot refused: " .. table.concat(reasons, ", "))
    end

    function on_items_received(items)
        if(skipItemSend) then
            return
        end

        print("Items received:")
        for _, item in ipairs(items) do
            print(ap:get_item_name(item.item))

            if playerInst == nil then -- Check if playerInst has been initialized
                return

            -- Items
            elseif item.item == 250001 then -- Common Item
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
                misc.director:set("enemy_buff", misc.director:get("enemy_buff") + (scale * 5))
            elseif item.item == 250202 and runStarted then -- Combat
                combatQueue = combatQueue + 5
            elseif item.item == 250203 and runStarted then -- Meteor
                playerInst:activateUseItem(true, Item.find("Glowing Meteorite"))
                playerInst:activateUseItem(true, Item.find("Glowing Meteorite"))
                playerInst:activateUseItem(true, Item.find("Glowing Meteorite"))
                playerInst:activateUseItem(true, Item.find("Glowing Meteorite"))
                playerInst:activateUseItem(true, Item.find("Glowing Meteorite"))
            end

            table.insert(itemsCollected, item)
        end

        skipItemSend = false
        runStarted = true
    end

    function on_location_info(items)
        print("Locations scouted: ")
        for _, item in ipairs(items) do
            print(item.item)
        end
    end

    function on_location_checked(locations)
        print("Locations checked: " .. table.concat(locations, ", "))
        print("Checked locations: " .. table.concat(ap.checked_locations, ", "))
    end

    function on_data_package_changed(data_package)
        print("Data package changed: ")
        print(data_package)
    end

    function on_print(msg)
        print(msg)
    end

    function on_print_json(msg, extra)
        -- print(ap:render_json(msg, message_format))
        -- for key, value in pairs(extra) do
        --     print("  " .. key .. ": " .. tostring(value))
        -- end
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
	connect(server, slot, password)
end)

-- Save the player instance to a local variable
callback.register("onPlayerInit", function(playerInstance)
    playerInst = playerInstance
end)

-- Give player collected items between runs
callback.register("onPlayerDraw", function(playerInstance)
    if not runStarted and connected then
        print(itemsCollected)
        -- Would have this a seperate function but game locks up if run in on_items_recieved
        for _, item in ipairs(itemsCollected) do 

            -- Items
            if item.item == 250001 then -- Common Item
                playerInstance:giveItem(common:roll())
            elseif item.item == 250002 then -- Uncommon Item
                playerInstance:giveItem(uncommon:roll())
            elseif item.item == 250003 then -- Rare Item
                playerInstance:giveItem(rare:roll())
            elseif item.item == 250004 then -- Boss Item
                bossItem = boss:roll()

                if bossItem.isUseItem then
                    bossItem:create(playerInstance.x, playerInstance.y)
                else 
                    playerInstance:giveItem(bossItem)
                end
            elseif item.item == 250005 then -- Equipment
                equipment:roll():create(playerInstance.x, playerInstance.y)
            
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
                misc.director:set("enemy_buff", misc.director:get("enemy_buff") + (scale * 5))
            end
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

-- Runs poll() every game tick while in game
callback.register("onStep", function()
	if ap then
        ap:poll() 
    end

    if misc.director:getAlarm(1) > 1 and combatQueue > 0 then
        print("spawning")
        misc.director:setAlarm(1, 1)
        combatQueue = combatQueue - 1
    end
end)

-- Location checker
callback.register("onMapObjectActivate", function(mapObject, activator)
    print(mapObject:getObject():getName())
    if connected then
        locationsChecked = {}
        object = mapObject:getObject():getName()

        if arrayContains(chests, object) then
            table.insert(locationsChecked, ap.missing_locations[1])
            ap:LocationChecks(locationsChecked)
        end
    end
end) 

-- Check when providence dies
callback.register("onNPCDeath", function(npc)
    local killed = npc:getObject()
    print(killed:getName())
    if killed:getName() == "Boss3" then
        ap:StatusUpdate(30)
    end
end)

callback.register("onGameStart", function()
    diff = Difficulty.getActive():getName()
    if diff == "Drizzle" then
        scale = 0.06
    elseif diff == "Rainstorm" then
        scale = 0.12
    elseif diff == "Monsoon" then
        scale = 0.16
    end
end)

-- Tracks when a current run ends
callback.register("onGameEnd", function()
    runStarted = false
    playerInst = nil
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