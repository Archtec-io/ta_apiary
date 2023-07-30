--[[

	TechAge Apiary
	=======

	Copyright (C) 2023 Olesya Sibidanova

	AGPL v3
	See LICENSE.txt for more information


	TA2/TA3/TA4 Honey Sink, getting Honey from Bee Hives

]]--

-- for lazy programmers
local M = minetest.get_meta
local S = ta_apiary.S

local STANDBY_TICKS = 3
local COUNTDOWN_TICKS = 4
local CYCLE_TIME = 4

local function formspec(self, pos, nvm)
	return "size[8,8]"..
	default.gui_bg..
	default.gui_bg_img..
	default.gui_slots..
	"list[context;src;0,0;3,3;]"..
	"item_image[0,0;1,1;mobs:honey]"..
	"image[0,0;1,1;techage_form_mask.png]"..
	"image[3.5,0;1,1;"..techage.get_power_image(pos, nvm).."]"..
	"image[3.5,1;1,1;techage_form_arrow.png]"..
	"image_button[3.5,2;1,1;"..self:get_state_button_image(nvm)..";state_button;]"..
	"tooltip[3.5,2;1,1;"..self:get_state_tooltip(nvm).."]"..
	"list[context;dst;5,0;3,3;]"..
	"item_image[5,0;1,1;mobs:honey]"..
	"image[5,0;1,1;techage_form_mask.png]"..
	"list[current_player;main;0,4;8,4;]"..
	"listring[context;dst]"..
	"listring[current_player;main]"..
	"listring[context;src]"..
	"listring[current_player;main]"..
	default.get_hotbar_bg(0, 4)
end

local function space_for_items(inv, list_name, item_name, max_count)
	local item_stack = ItemStack({name=item_name, count=max_count})
	while item_stack:get_count() > 0 do
		if inv:room_for_item(list_name, item_stack) then
			return item_stack:get_count()
		else
			item_stack:set_count(item_stack:get_count() - 1)
		end
	end
	return 0
end

local function sink_from_hive(hive_inv, inv, num_items)
	local get_items = ta_apiary.count_items(hive_inv, "beehive", "mobs:honey", num_items)
	if get_items < 1 then
		return 0
	end

	local put_items = get_items
	if put_items < num_items and math.random(4) == 1 then
		put_items = math.random(put_items, num_items)
	end
	put_items = space_for_items(inv, "src", "mobs:honey", put_items)
	if put_items < 1 then
		return 0
	end

	if get_items > put_items then
		get_items = put_items
	end

	local get_stack = ItemStack({name = "mobs:honey", count = get_items})
	local put_stack = ItemStack({name = "mobs:honey", count = put_items})

	hive_inv:remove_item("beehive", get_stack)
	inv:add_item("src", put_stack)

	return put_items
end

local function sink_honey(pos, crd, nvm, inv)
	local above_pos = { x=pos.x, y=pos.y + 1, z=pos.z }
	local above_node_name = minetest.get_node(above_pos).name

	-- If node above is not loaded then set to the idle state
	if above_node_name == "ignore" then
		crd.State:idle(pos, nvm)
		return
	end

	-- If node above is loaded and it's not a beehive then set to the fault state
	if above_node_name ~= "mobs:beehive" then
		crd.State:fault(pos, nvm)
		return
	end

	local hive_inv = M(above_pos):get_inventory()
	if not hive_inv then
		crd.State:fault(pos, nvm)
		return
	end

	local put_items = sink_from_hive(hive_inv, inv, crd.num_items)

	-- Items transfered to src inventory. Now transfer to dst inventory
	-- At most crd.num_items could be transfered in total
	local leftover = crd.num_items - put_items
	if leftover < 1 then
		crd.State:keep_running(pos, nvm, COUNTDOWN_TICKS)
		return
	end

	local get_items = ta_apiary.count_items(inv, "src", "mobs:honey", leftover)
	if get_items < 1 then
		crd.State:idle(pos, nvm)
		return
	end

	local put_items = space_for_items(inv, "dst", "mobs:honey", get_items)
	if put_items < 1 then
		crd.State:blocked(pos, nvm)
		return
	end

	put_stack = ItemStack({name = "mobs:honey", count = put_items})
	inv:remove_item("src", put_stack)
	inv:add_item("dst", put_stack)
	crd.State:keep_running(pos, nvm, COUNTDOWN_TICKS)
end

local function keep_running(pos, elapsed)
	local nvm = techage.get_nvm(pos)
	local crd = ta_apiary.CRD(pos)
	local inv = M(pos):get_inventory()
	sink_honey(pos, crd, nvm, inv)
end

local function on_receive_fields(pos, formname, fields, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return
	end
	local nvm = techage.get_nvm(pos)
	ta_apiary.CRD(pos).State:state_button_event(pos, nvm, fields)
end

local function can_dig(pos, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return false
	end
	local inv = M(pos):get_inventory()
	return inv:is_empty("dst") and inv:is_empty("src")
end


local tiles = {}
-- '#' will be replaced by the stage number
-- '{power}' will be replaced by the power PNG
tiles.pas = {
	-- up, down, right, left, back, front
	"ta_apiary_extractor_top_inactive.png^techage_frame_ta#_top.png",
	"techage_filling_ta#.png^techage_frame_ta#.png",
	"techage_filling_ta#.png^techage_frame_ta#.png^techage_appl_outp.png",
	"techage_filling_ta#.png^techage_frame_ta#.png^techage_appl_inp.png",
	"techage_filling_ta#.png^default_wood.png^techage_frame_ta#.png",
	"techage_filling_ta#.png^default_wood.png^techage_frame_ta#.png",
}
tiles.act = {
	-- up, down, right, left, back, front
	"ta_apiary_extractor_top_active.png^techage_frame_ta#_top.png",
	"techage_filling_ta#.png^techage_frame_ta#.png",
	"techage_filling_ta#.png^techage_frame_ta#.png^techage_appl_outp.png",
	"techage_filling_ta#.png^techage_frame_ta#.png^techage_appl_inp.png",
	"techage_filling_ta#.png^default_wood.png^techage_frame_ta#.png",
	"techage_filling_ta#.png^default_wood.png^techage_frame_ta#.png",
}

local node_name_ta2, node_name_ta3, node_name_ta4 =
	techage.register_consumer("honey_sink", S("Honey Sink"), tiles, {
		drawtype = "nodebox",
		paramtype = "light",
		node_box = {
			type = "fixed",
			fixed = {
				{-8/16, -8/16, -8/16,  8/16, 8/16, -6/16},
				{-8/16, -8/16,  6/16,  8/16, 8/16,  8/16},
				{-8/16, -8/16, -8/16, -6/16, 8/16,  8/16},
				{ 6/16, -8/16, -8/16,  8/16, 8/16,  8/16},
				{-6/16, -8/16, -6/16,  6/16, 6/16,  6/16},
			},
		},
		selection_box = {
			type = "fixed",
			fixed = {-8/16, -8/16, -8/16,   8/16, 8/16, 8/16},
		},
		cycle_time = CYCLE_TIME,
		standby_ticks = STANDBY_TICKS,
		formspec = formspec,
		tubing = ta_apiary.tubing,
		after_place_node = function(pos, placer)
			local inv = M(pos):get_inventory()
			inv:set_size('src', 9)
			inv:set_size('dst', 9)
		end,
		can_dig = ta_apiary.can_dig,
		node_timer = keep_running,
		on_receive_fields = ta_apiary.on_receive_fields,
		allow_metadata_inventory_put = ta_apiary.allow_metadata_inventory_put,
		allow_metadata_inventory_move = ta_apiary.allow_metadata_inventory_move,
		allow_metadata_inventory_take = ta_apiary.allow_metadata_inventory_take,
		groups = {choppy=2, cracky=2, crumbly=2},
		sounds = default.node_sound_wood_defaults(),
		num_items = {0,1,2,4},
		power_consumption = {0,3,5,7},
		tube_sides = {L=1, R=1, U=1},
	}, nil, "ta_apiary:ta")

minetest.register_craft({
	output = node_name_ta2,
	recipe = {
		{"group:wood",    "techage:ta3_pipeS",  "group:wood"},
		{"techage:tubeS", "techage:ta3_silo",   "techage:tubeS"},
		{"group:wood",    "techage:iron_ingot", "group:wood"},
	},
})

minetest.register_craft({
	output = node_name_ta3,
	recipe = {
		{"",                               "basic_materials:motor", ""},
		{"basic_materials:heating_element", node_name_ta2,          "basic_materials:heating_element"},
		{"",                               "techage:vacuum_tube",   ""},
	},
})

minetest.register_craft({
	output = node_name_ta4,
	recipe = {
		{"",                "techage:ta4_carbon_fiber", ""},
		{"techage:ta4_leds", node_name_ta3,             "techage:ta4_leds"},
		{"",                "techage:ta4_wlanchip",     ""},
	},
})

