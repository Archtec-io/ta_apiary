--[[

	TechAge Apiary
	=======

	Copyright (C) 2023 Olesya Sibidanova

	AGPL v3
	See LICENSE.txt for more information

	Base functions for the Techage Apiary mod
]]--

ta_apiary = {}

if minetest.get_translator then
	ta_apiary.bees_S = minetest.get_translator("bees")
	ta_apiary.S = minetest.get_translator("ta_apiary")
elseif minetest.global_exists("intllib") then
	ta_apiary.bees_S = intllib.Getter()
	ta_apiary.S = intllib.Getter()
else
	ta_apiary.bees_S = function(s) return s end
	ta_apiary.S = function(s) return s end
end

function ta_apiary.hive_artificial(pos)

	local spos = pos.x..","..pos.y..","..pos.z
	local formspec = "size[8,9]"
		.. "list[nodemeta:"..spos..";queen;3.5,1;1,1;]"
		.. "tooltip[3.5,1;1,1;Queen]"
		.. "list[nodemeta:"..spos..";frames;0,3;8,1;]"
		.. "tooltip[0,3;8,1;Frames]"
		.. "list[current_player;main;0,5;8,4;]"

	return formspec
end


function ta_apiary.polinate_flower(pos, flower)

	local spawn_pos = {
		x = pos.x + math.random(-3, 3),
		y = pos.y + math.random(-3, 3),
		z = pos.z + math.random(-3, 3)
	}
	local floor_pos = {x = spawn_pos.x, y = spawn_pos.y - 1, z = spawn_pos.z}
	local spawn = minetest.get_node(spawn_pos).name
	local floorn = minetest.get_node(floor_pos).name

	if floorn == "group:soil" and spawn == "air" then
		minetest.set_node(spawn_pos, {name = flower})
	end
end
