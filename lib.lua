--[[

	TechAge Apiary
	=======

	Copyright (C) 2023 Olesya Sibidanova

	AGPL v3
	See LICENSE.txt for more information

	Base functions for the Techage Apiary mod
]]--

local M = minetest.get_meta

ta_apiary = {}

ta_apiary.abm_enabled = minetest.settings:get_bool("ta_apiary_abm_enabled") ~= false


ta_apiary.S = minetest.get_translator("ta_apiary")

ta_apiary.CRD = function(pos) return (minetest.registered_nodes[techage.get_node_lvm(pos).name] or {}).consumer or {} end

ta_apiary.allow_metadata_inventory_put =
function (pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	if listname == "src" then
		local state = ta_apiary.CRD(pos).State
		if state then
			state:start_if_standby(pos)
		end
	end
	return stack:get_count()
end

ta_apiary.allow_metadata_inventory_move =
function(pos, from_list, from_index, to_list, to_index, count, player)
	local inv = M(pos):get_inventory()
	local stack = inv:get_stack(from_list, from_index)
	return ta_apiary.allow_metadata_inventory_put(pos, to_list, to_index, stack, player)
end

ta_apiary.allow_metadata_inventory_take =
function(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	return stack:get_count()
end

ta_apiary.on_receive_fields =
function(pos, formname, fields, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return
	end
	local nvm = techage.get_nvm(pos)
	ta_apiary.CRD(pos).State:state_button_event(pos, nvm, fields)
end

ta_apiary.can_dig =
function(pos, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return false
	end
	local inv = M(pos):get_inventory()
	return inv:is_empty("dst") and inv:is_empty("src")
end

ta_apiary.tubing = {
	on_pull_item = function(pos, in_dir, num)
		local meta = minetest.get_meta(pos)
		if meta:get_int("pull_dir") == in_dir then
			local inv = M(pos):get_inventory()
			return techage.get_items(pos, inv, "dst", num)
		end
	end,
	on_push_item = function(pos, in_dir, stack)
		local meta = minetest.get_meta(pos)
		if meta:get_int("push_dir") == in_dir or in_dir == 5 then
			local inv = M(pos):get_inventory()
			--CRD(pos).State:start_if_standby(pos) -- would need power!
			return techage.put_items(inv, "src", stack)
		end
	end,
	on_unpull_item = function(pos, in_dir, stack)
		local meta = minetest.get_meta(pos)
		if meta:get_int("pull_dir") == in_dir then
			local inv = M(pos):get_inventory()
			return techage.put_items(inv, "dst", stack)
		end
	end,
	on_recv_message = function(pos, src, topic, payload)
		return ta_apiary.CRD(pos).State:on_receive_message(pos, topic, payload)
	end,
	on_beduino_receive_cmnd = function(pos, src, topic, payload)
		return ta_apiary.CRD(pos).State:on_beduino_receive_cmnd(pos, topic, payload)
	end,
	on_beduino_request_data = function(pos, src, topic, payload)
		return ta_apiary.CRD(pos).State:on_beduino_request_data(pos, topic, payload)
	end,
	on_node_load = function(pos)
		ta_apiary.CRD(pos).State:on_node_load(pos)
	end,
}

ta_apiary.count_items =
function(inv, list_name, item_name, max_count)
	local item_stack = ItemStack({name=item_name, count=max_count})
	while item_stack:get_count() > 0 do
		if inv:contains_item(list_name, item_stack) then
			return item_stack:get_count()
		else
			item_stack:set_count(item_stack:get_count() - 1)
		end
	end
	return 0
end

