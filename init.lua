--[[

	TechAge Apiary
	=======

	Copyright (C) 2023 Olesya Sibidanova

	AGPL v3
	See LICENSE.txt for more information

]]--


local MP = minetest.get_modpath("ta_apiary")

dofile(MP.."/lib.lua")

if minetest.get_modpath("bees") then
	dofile(MP.."/bee_hive.lua")
	dofile(MP.."/honey_extractor.lua")
end

if minetest.get_modpath("mobs_animal") then
	dofile(MP.."/honey_sink.lua")
end

