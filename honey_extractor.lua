--[[

	TechAge Apiary
	=======

	Copyright (C) 2023 Olesya Sibidanova

	AGPL v3
	See LICENSE.txt for more information


	TA2/TA3/TA4 Honey extractor, getting Honey and Beeswax from Filled Frames

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
	"item_image[0,0;1,1;bees:frame_full]"..
	"image[0,0;1,1;techage_form_mask.png]"..
	"image[3.5,0;1,1;"..techage.get_power_image(pos, nvm).."]"..
	"image[3.5,1;1,1;techage_form_arrow.png]"..
	"image_button[3.5,2;1,1;"..self:get_state_button_image(nvm)..";state_button;]"..
	"tooltip[3.5,2;1,1;"..self:get_state_tooltip(nvm).."]"..
	"list[context;dst;5,0;3,3;]"..
	"item_image[5,0;1,1;bees:bottle_honey]"..
	"image[5,0;1,1;techage_form_mask.png]"..
	"list[current_player;main;0,4;8,4;]"..
	"listring[context;dst]"..
	"listring[current_player;main]"..
	"listring[context;src]"..
	"listring[current_player;main]"..
	default.get_hotbar_bg(0, 4)
end


local function extracting(pos, crd, nvm, inv)
	local item_count = ta_apiary.count_items(inv, "src", "bees:frame_full", crd.num_items)
	item_count = ta_apiary.count_items(inv, "src", "vessels:glass_bottle", item_count)

	if item_count == 0 then
		crd.State:idle(pos, nvm)
		return
	end

	local honey_stack = ItemStack({name = "bees:bottle_honey", count = item_count})

	local wax_stack = ItemStack({name = "bees:wax", count = item_count})

	local empty_frames_stack = ItemStack({name = "bees:frame_empty", count = item_count})

	if inv:room_for_item("dst", honey_stack)
		and inv:room_for_item("dst", wax_stack)
		and inv:room_for_item("dst", empty_frames_stack) then

		local full_frames_stack = ItemStack({name = "bees:frame_full", count = item_count})
		inv:remove_item("src", full_frames_stack)

		local bottles_stack = ItemStack({name = "vessels:glass_bottle", count = item_count})
		inv:remove_item("src", bottles_stack)

		inv:add_item("dst", honey_stack)
		inv:add_item("dst", wax_stack)
		inv:add_item("dst", empty_frames_stack)

		crd.State:keep_running(pos, nvm, COUNTDOWN_TICKS)
	else
		crd.State:blocked(pos, nvm)
	end
end

local function keep_running(pos, elapsed)
	local nvm = techage.get_nvm(pos)
	local crd = ta_apiary.CRD(pos)
	local inv = M(pos):get_inventory()
	extracting(pos, crd, nvm, inv)
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
	"techage_filling_ta#.png^ta_apiary_extractor.png^techage_frame_ta#.png",
	"techage_filling_ta#.png^ta_apiary_extractor_front_inactive.png^techage_frame_ta#.png",
}
tiles.act = {
	-- up, down, right, left, back, front
	"ta_apiary_extractor_top_active.png^techage_frame_ta#_top.png",
	"techage_filling_ta#.png^techage_frame_ta#.png",
	"techage_filling_ta#.png^techage_frame_ta#.png^techage_appl_outp.png",
	"techage_filling_ta#.png^techage_frame_ta#.png^techage_appl_inp.png",
	"techage_filling_ta#.png^ta_apiary_extractor.png^techage_frame_ta#.png",
	"techage_filling_ta#.png^ta_apiary_extractor_front_active.png^techage_frame_ta#.png",
}


local node_name_ta2, node_name_ta3, node_name_ta4 =
	techage.register_consumer("honey_extractor", S("Honey Extractor"), tiles, {
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
		{"group:wood",    "basic_materials:plastic_sheet", "group:wood"},
		{"techage:tubeS", "bees:extractor",                "techage:tubeS"},
		{"group:wood",    "techage:iron_ingot",            "group:wood"},
	},
})

minetest.register_craft({
	output = node_name_ta3,
	recipe = {
		{"", "basic_materials:motor", ""},
		{"", node_name_ta2, ""},
		{"", "techage:vacuum_tube", ""},
	},
})

minetest.register_craft({
	output = node_name_ta4,
	recipe = {
		{"", "techage:ta4_carbon_fiber", ""},
		{"", node_name_ta3, ""},
		{"", "techage:ta4_wlanchip", ""},
	},
})


techage.recipes.register_craft_type("extracting", {
	description = S("Extracting"),
	icon = 'ta_apiary_extractor_front_active.png',
	width = 2,
	height = 1,
})

techage.recipes.register_craft({items={"bees:frame_full", "vessels:glass_bottle"}, type="extracting", output="bees:bottle_honey"})
techage.recipes.register_craft({items={"bees:frame_full", "vessels:glass_bottle"}, type="extracting", output="bees:wax"})
techage.recipes.register_craft({items={"bees:frame_full", "vessels:glass_bottle"}, type="extracting", output="bees:frame_empty"})

