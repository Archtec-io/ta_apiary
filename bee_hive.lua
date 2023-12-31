--[[

	TechAge Apiary
	=======

	Copyright (C) 2023 Olesya Sibidanova

	AGPL v3
	See LICENSE.txt for more information

	TA2+ Bee Hive, an Apiary with tubes support

]]--

local S = ta_apiary.S

local function hive_artificial(pos)
	local spos = pos.x..","..pos.y..","..pos.z
	local formspec = "size[8,9]"
		.. "list[nodemeta:"..spos..";queen;3.5,1;1,1;]"
		.. "tooltip[3.5,1;1,1;Queen]"
		.. "list[nodemeta:"..spos..";frames;0,3;8,1;]"
		.. "tooltip[0,3;8,1;Frames]"
		.. "list[current_player;main;0,5;8,4;]"
	return formspec
end

local function polinate_flower(pos, flower)
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

local function stackOrNil(stack)
	if stack and stack.get_count and stack:get_count() > 0 then
		return stack
	end
	return nil
end

local function stop_hive(pos)
	local timer = minetest.get_node_timer(pos)
	local meta = minetest.get_meta(pos)

	meta:set_string("infotext", S("Requires Queen bee to function"))
	timer:stop()
end

-- Function for adding items to the hive via automation, e.g. pushers
local function tube_add_to_hive(pos, input_stack)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local timer = minetest.get_node_timer(pos)

	for i=1,8 do
		local stack_i = inv:get_stack("frames", i)
		if input_stack:get_count() > 0 and (not stack_i or stack_i:is_empty())
			and input_stack:get_name() == "bees:frame_empty" then
			local framestack = ItemStack("bees:frame_empty")
			inv:set_stack("frames", i, framestack)
			input_stack:set_count(input_stack:get_count() - 1)
			if not timer:is_started() and inv:contains_item("queen", "bees:queen") then
				timer:start(30)
				meta:set_string("infotext", S("Bees are aclimating"))
			end
		end
	end

	if input_stack:get_name() == "bees:queen" and not inv:contains_item("queen", "bees:queen") then
		local queenstack = ItemStack("bees:queen")
		inv:set_stack("queen", 1, queenstack)
		input_stack:set_count(input_stack:get_count() - 1)

		meta:set_string("queen", "bees:queen")
		meta:set_string("infotext", S("Queen inserted, now the empty frames"))
		if inv:contains_item("frames", "bees:frame_empty") then
			timer:start(30)
			meta:set_string("infotext", S("Bees are aclimating"))
		end
	end

	if input_stack:get_count() > 0 then
		return input_stack -- Not all items were added to chest
	else
		return true -- All items were added
	end
end

-- Function for taking items from the hive via automation, e.g. pushers
local function tube_take_from_hive(pos, item_name, count)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local itemstack = nil

	if not item_name then
		for i=1,8 do
			local stack_i = inv:get_stack("frames", i)
			if not itemstack or itemstack:is_empty() then
				itemstack = stack_i
				inv:set_stack("frames", i, ItemStack())
			elseif itemstack:get_count() < count
				and itemstack:get_free_space() > 0
				and itemstack:get_name() == stack_i:get_name() then
				itemstack:set_count(itemstack:get_count() + 1)
				inv:set_stack("frames", i, ItemStack())
			end
		end

		if not itemstack or itemstack:is_empty() then
			local queenstack = ItemStack("bees:queen")
			itemstack = inv:remove_item("queen", queenstack)
			if itemstack and not itemstack:is_empty() then
				stop_hive(pos)
			end
		end
	else
		local remstack = ItemStack({name=item_name, count=count})

		itemstack = inv:remove_item("frames", remstack)
		if not itemstack or itemstack:is_empty() then
			itemstack = inv:remove_item("queen", remstack)
			if itemstack and not itemstack:is_empty() then
				stop_hive(pos)
			end
		end
	end

	return stackOrNil(itemstack)
end

minetest.register_node("ta_apiary:bee_hive", {
	description = S("TA Apiary"),
	tiles = {"ta_apiary_bee_hive_side.png","ta_apiary_bee_hive_side.png","ta_apiary_bee_hive_side.png",
		 "ta_apiary_bee_hive_side.png","ta_apiary_bee_hive_side.png","ta_apiary_bee_hive_front.png"},
	paramtype2 = "facedir",
	groups = {
		snappy = 1, choppy = 2, oddly_breakable_by_hand = 2,
	},
	sounds = default.node_sound_wood_defaults(),

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()

		meta:set_int("agressive", 1)
		inv:set_size("queen", 1)
		inv:set_size("frames", 8)
		meta:set_string("infotext", S("Requires Queen bee to function"))
	end,

	can_dig = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()

		if inv:is_empty("queen") and inv:is_empty("frames") then
			return true
		else
			return false
		end
	end,

	on_rightclick = function(pos, _, clicker)
		local player_name = clicker:get_player_name()

		if minetest.is_protected(pos, player_name) then
			return
		end

		minetest.show_formspec(player_name,
			"ta_apiary:bee_hive",
			hive_artificial(pos)
		)

		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()

		if meta:get_int("agressive") == 1
		and inv:contains_item("queen", "bees:queen") then
			clicker:set_hp(clicker:get_hp() - 4)
		else
			meta:set_int("agressive", 1)
		end
	end,

	on_timer = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		local timer = minetest.get_node_timer(pos)

		if inv:contains_item("queen", "bees:queen") then
			if inv:contains_item("frames", "bees:frame_empty") then
				timer:start(30)

				local rad = 10
				local minp = {x = pos.x - rad, y = pos.y - rad, z = pos.z - rad}
				local maxp = {x = pos.x + rad, y = pos.y + rad, z = pos.z + rad}
				local flowers = minetest.find_nodes_in_area(minp, maxp, "group:flower")
				local progress = meta:get_int("progress")

				progress = progress + #flowers
				meta:set_int("progress", progress)

				if progress > 1000 then
					local flower = flowers[math.random(#flowers)]

					polinate_flower(flower, minetest.get_node(flower).name)

					local stacks = inv:get_list("frames")
					for k, _ in pairs(stacks) do
						if inv:get_stack("frames", k):get_name() == "bees:frame_empty" then
							meta:set_int("progress", 0)
							inv:set_stack("frames", k, "bees:frame_full")
							return
						end
					end
				else
					meta:set_string("infotext", S("progress:")
						.. " " .. progress .. " + " .. #flowers .. " / 1000")
				end
			else
				meta:set_string("infotext", S("Does not have empty frame(s)"))
				timer:stop()
			end
		end
	end,

	on_metadata_inventory_take = function(pos, listname)
		if listname == "queen" then
			stop_hive(pos)
		end
	end,

	allow_metadata_inventory_move = function(pos, from_list, _, to_list, to_index)
		local inv = minetest.get_meta(pos):get_inventory()
		if from_list == to_list then
			if inv:get_stack(to_list, to_index):is_empty() then
				return 1
			else
				return 0
			end
		else
			return 0
		end
	end,

	on_metadata_inventory_put = function(pos, listname, _, stack)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		local timer = minetest.get_node_timer(pos)

		if listname == "queen" or listname == "frames" then
			meta:set_string("queen", stack:get_name())
			meta:set_string("infotext", S("Queen inserted, now the empty frames"))

			if inv:contains_item("frames", "bees:frame_empty") then
				timer:start(30)
				meta:set_string("infotext", S("Bees are aclimating"))
			end
		end
	end,

	allow_metadata_inventory_put = function(pos, listname, index, stack)
		if not minetest.get_meta(pos):get_inventory():get_stack(listname, index):is_empty() then
			return 0
		end

		if listname == "queen" then
			if stack:get_name():match("bees:queen*") then
				return 1
			end
		elseif listname == "frames" then
			if stack:get_name() == ("bees:frame_empty") then
				return 1
			end
		end

		return 0
	end
})

techage.register_node({"ta_apiary:bee_hive"}, {
	on_inv_request = function(pos, in_dir, access_type)
		local meta = minetest.get_meta(pos)
		return meta:get_inventory(), "frames"
	end,

	on_pull_item = function(pos, in_dir, num, item_name)
		return tube_take_from_hive(pos, item_name, num)
	end,

	on_push_item = function(pos, in_dir, stack)
		return tube_add_to_hive(pos, stack)
	end,


	on_unpull_item = function(pos, in_dir, stack)
		return tube_add_to_hive(pos, stack)
	end
})


minetest.register_craft({
	output = "ta_apiary:bee_hive",
	recipe = {
		{"group:wood",    "basic_materials:plastic_sheet", "group:wood"},
		{"techage:tubeS", "bees:hive_artificial",          "techage:tubeS"},
		{"group:wood",    "techage:iron_ingot",            "group:wood"},
	},
})

if ta_apiary.abm_enabled then

	minetest.register_abm({
		label = "spawn bee particles",
		nodenames = {"ta_apiary:bee_hive"},
		interval = 10,
		chance = 1,

		action = function(pos, node)
			-- Bee particle
			minetest.add_particle({
				pos = {x = pos.x, y = pos.y, z = pos.z},
				velocity = {
					x = (math.random() - 0.5) * 5,
					y = (math.random() - 0.5) * 5,
					z = (math.random() - 0.5) * 5
				},
				acceleration = {
					x = math.random() - 0.5,
					y = math.random() - 0.5,
					z = math.random() - 0.5
				},
				expirationtime = math.random(2.5),
				size = math.random(3),
				collisiondetection = true,
				texture = "bees_particle_bee.png",
			})
			minetest.sound_play("bees", {
				pos = pos, gain = 0.6, max_hear_distance = 5}, true)
		end
	})

-- spawning bees around bee hive
	minetest.register_abm({
		label = "spawn bees around bee hives",
		nodenames = {"ta_apiary:bee_hive"},
		neighbors = {"group:flower", "group:leaves"},
		interval = 30,
		chance = 4,

		action = function(pos)
			local p = {
				x = pos.x + math.random(-5, 5),
				y = pos.y - math.random(0, 3),
				z = pos.z + math.random(-5, 5)
			}
			if minetest.get_node(p).name == "air" then
				minetest.add_node(p, {name="bees:bees"})
			end
		end
	})

end

