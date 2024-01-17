require("apclient")
require("prefs")

callback.register("onStageEntry", function(npc)
	print(Stage.getCurrentStage())
end)

