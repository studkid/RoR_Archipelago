require("apclient")

callback.register("onStageEntry", function(npc)
	print(Stage.getCurrentStage())
end)

callback.register("onItemInit", function(item)
	player:removeItem(item)
end) 
