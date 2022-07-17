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

function search_for_resource(player, resource)
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
        local neighbors = cardinal_neighbors(chunk.position, 1)
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
    for _, chunk in ipairs(searched_chunks) do
        ping(chunk.position, player, util.format_number(chunk.with_neighbors, true))
    end
end

-- user clicked button directly
script.on_event(defines.events.on_lua_shortcut, function(event)
    if event and event.prototype_name == "resource-finder-button" then
        search_for_resource(game.players[event.player_index], 'iron-ore')
    end
end)