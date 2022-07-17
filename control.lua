local util = require('util')
local function chunk_area(chunk)
    return {
        left_top = {
            x = chunk.x * 32,
            y = chunk.y * 32,
        },
        right_bottom = {
            x = (chunk.x + 1) * 32,
            y = (chunk.y + 1) * 32,
        },
    }
end

local function chunk_pos(chunk)
    return {
        x = (chunk.x + 0.5) * 32,
        y = (chunk.y + 0.5) * 32
    }
end

local function round(v)
    return v and math.floor(v + 0.5)
end

local function chunk_key(chunk)
    return string.format('%s:%s:%d:%d',
            chunk.force.name,
            chunk.surface.name,
            chunk.position.x,
            chunk.position.y)
end

local function total_amount(surface, chunk, resource_name)
    local total = 0
    for _, resource_entity in pairs(surface.find_entities_filtered { type = 'resource',
                                                                     name = resource_name, area = chunk_area(chunk) }) do
        total = total + resource_entity.amount
    end
    return total
end

local function cardinal_neighbors(position, distance)
    distance = distance or 2
    local positions = {}
    for x = position.x - distance, position.x + distance do
        for y = position.y - distance, position.y + distance do
            if x ~= position.x or y ~= position.y then
                table.insert(positions, { x = x, y = y })
            end
        end
    end
    return positions
end

local function ping(chunk, player, description)
    description = description or 'Unnamed Chunk'
    local pos = chunk_pos(chunk)
    player.print(description .. ' at [gps=' .. round(pos.x) .. ',' .. round(pos.y) .. ']')
end

local function is_in_distance(chunk, list_of_chunks, distance)
    for _, existing_chunk in pairs(list_of_chunks) do
        if math.abs(chunk.position.x - existing_chunk.position.x) <= distance or math.abs(chunk.position.y - existing_chunk.position.y) <= distance then
            return true
        end
    end
    return false
end

local function format_amount(amount, resource_name)
    local prototype = game.entity_prototypes[resource_name]
    if prototype.infinite_resource then
        return math.floor(amount
                / prototype.normal_resource_amount
                * 100) .. '%'
    end
    return util.format_number(amount, true)
end

function search_for_resource(player, resource, distance, num_results)
    distance = distance or 1
    num_results = num_results or 5
    local surface = player.surface
    local force = player.force
    local searched_chunks = {}
    local chunks_with_res = {}

    -- Find chunks that contain the resource in question
    for chunk in surface.get_chunks() do
        if force.is_chunk_charted(surface, chunk) and surface.count_entities_filtered { type = 'resource',
                                                                                        name = resource,
                                                                                        area = chunk_area(chunk) } > 0
        then
            local amount = total_amount(surface, chunk, resource)
            local context_chunk = {
                position = chunk,
                force = force,
                surface = surface,
                amount = amount,
                with_neighbors = amount
            }
            chunks_with_res[chunk_key(context_chunk)] = context_chunk
        end
    end
    -- Naive approach: For each chunk, search neighbor chunks for same res and add to this chunk
    for _, chunk in pairs(chunks_with_res) do
        -- group with any adjacent chunk that also contains the resource
        local neighbors = cardinal_neighbors(chunk.position, distance)
        for _, neighbor in pairs(neighbors) do
            local neighbor_context = {
                position = neighbor,
                force = force,
                surface = surface,
            }
            if chunks_with_res[chunk_key(neighbor_context)] ~= nil then
                chunk.with_neighbors = chunk.with_neighbors + chunks_with_res[chunk_key(neighbor_context)].amount
            end
        end
        table.insert(searched_chunks, chunk)
    end
    table.sort(searched_chunks, function(a, b)
        return a.with_neighbors > b.with_neighbors
    end)
    local best_chunks = {}
    for _, chunk in ipairs(searched_chunks) do
        if not is_in_distance(chunk, best_chunks, distance) then
            local image = '[img=entity.' .. resource .. ']'
            ping(chunk.position, player, image .. format_amount(chunk.with_neighbors, resource))
            table.insert(best_chunks, chunk)
            if #best_chunks >= num_results then
                break
            end
        end
    end
end

-- user clicked button directly
script.on_event(defines.events.on_lua_shortcut, function(event)
    if event and event.prototype_name == "resource-finder-button" then
        open_gui(event.player_index)
    end
end)

-- taken from https://forums.factorio.com/viewtopic.php?t=98713
function add_titlebar(gui, caption, close_button_name)
    local titlebar = gui.add { type = "flow" }
    titlebar.drag_target = gui
    titlebar.add {
        type = "label",
        style = "frame_title",
        caption = caption,
        ignored_by_interaction = true,
    }
    local filler = titlebar.add {
        type = "empty-widget",
        style = "draggable_space",
        ignored_by_interaction = true,
    }
    filler.style.height = 24
    filler.style.horizontally_stretchable = true
    titlebar.add {
        type = "sprite-button",
        name = close_button_name,
        style = "frame_action_button",
        sprite = "utility/close_white",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
        tooltip = { "gui.close-instruction" },
    }
end

function open_gui(player_index)
    -- should probably use on_init and on_configuration_changed, but I can't figure out how to make it work in development
    if not global.players then
        global.players = {}
    end

    local player = game.get_player(player_index)
    local gui = player.gui.screen

    if gui.resource_finder then
        return
    end

    local frame = gui.add { type = "frame", name = "resource_finder", direction = "vertical" }
    add_titlebar(frame, "Resource Finder", "close_button")
    local close_button = frame.close_button
    frame.auto_center = true
    frame.style.size = { 286, 176 }

    -- local drop = frame.add{type="frame", style="drop-frame"}
    local drop = frame.add { type = "frame", style = "inside_shallow_frame_with_padding" }

    local left = drop.add { type = "flow", direction = "vertical" }
    left.style.right_margin = 12

    local right = drop.add { type = "flow", direction = "vertical" }

    left.add { type = "label", caption = "Type:" }
    local resource_type = left.add { type = "choose-elem-button", elem_type = "entity", name = "resource_type", entity = "iron-ore", elem_filters = { { filter = "type", type = "resource" } } }

    local range_label = right.add { type = "flow" }
    range_label.add { type = "label", caption = "Range:" }
    local range_slider = right.add { type = "slider", name = "range_slider", minimum_value = 0, maximum_value = 100, value = 1 }
    local range_value = range_label.add { type = "label", name = "range_value", caption = range_slider.slider_value }

    local count_label = right.add { type = "flow" }
    count_label.add { type = "label", caption = "Count:" }
    local count_slider = right.add { type = "slider", name = "count_slider", minimum_value = 1, maximum_value = 100, value = 5 }
    local count_value = count_label.add { type = "label", name = "count_value", caption = count_slider.slider_value }

    local ok_button = left.add { type = "button", name = "ok_button", caption = "Find" }
    ok_button.style.size = { 60, 28 }
    ok_button.style.top_margin = 2

    global.players[player_index] = {
        close_button = close_button,
        range_slider = range_slider,
        range_value = range_value,
        count_slider = count_slider,
        count_value = count_value,
        ok_button = ok_button,
        resource_type = resource_type,
        window = frame
    }

    player.opened = frame
end

script.on_event(defines.events.on_gui_value_changed, function(event)
    local gui = global.players[event.player_index]
    if not gui then
        return
    end

    if event.element.name == "range_slider" then
        gui.range_value.caption = event.element.slider_value
        return
    end

    if event.element.name == "count_slider" then
        gui.count_value.caption = event.element.slider_value
        return
    end
end)

function close_gui(player_index)
    local gui = global.players[player_index]
    if not gui then
        return
    end
    gui.window.destroy()
    global.players[player_index] = nil
end

script.on_event(defines.events.on_gui_click, function(event)
    local player = game.get_player(event.player_index)

    local gui = global.players[event.player_index]
    if not gui then
        return
    end

    if event.element.name == "close_button" then
        close_gui(event.player_index)
        return
    end

    if event.element.name == "ok_button" then
        local range = gui.range_slider.slider_value
        local count = gui.count_slider.slider_value
        local type = gui.resource_type.elem_value

        search_for_resource(game.players[event.player_index], type, range, count)
        return
    end
end)

script.on_event(defines.events.on_gui_closed, function(event)
    if event.element and event.element.name == "resource_finder" then
        close_gui(event.player_index)
    end
end)