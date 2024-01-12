require("apclient")
require("prefs")
require("utils")

callback.register("onLoad", function(item)
    getItemPools(ItemPool.findAll()) 

	connect(server, slot, password)
    
    print("Will run for 10 seconds ...")
    local t0 = os.clock()
    while os.clock() - t0 < 10 do
        local ran, error = pcall(function () error({ap:poll()}) end)
        if not ran then
            print("ap:poll() failed to run: ", error)
        end
    end
    print("shutting down...");
end)

callback.register("onStageEntry", function(npc)
	print(Stage.getCurrentStage())
end)

callback.register("onGameStart", function()
    if connected then
        
    end    
end)