local function isValueTooLarge(val)
    local valType = type(val)
    if valType == "string" then
        -- if you send a string larger then this you're doing something very
        -- wrong
        return val:len() > 500
    elseif valType == "table" then
        -- we shouldn't be sending large data over state bags
        return msgpack.pack_args(val):len() > 5000
    end
    return false
end

local function rejectStateChange(caller, ent, state, key, curVal)
    -- reset the state bag back to its original value, this won't remove the key
    -- from the server but theres no way to remove a key currently anyways until
    -- https://github.com/citizenfx/fivem/pull/2108 is merged or someone
    -- partially applies these changes outside of this PR
    TriggerEvent("StateBagAbuse", caller, ent)
    DropPlayer(caller, "Reliable state bag packet overflow")
    -- we have to execute this after the change handler so we just wait a tick
    -- to set it back to its current value
    SetTimeout(0, function()
        -- server replicates by default, this will set the state back to the
        -- original value
        state[key] = curVal
    end)
end

AddStateBagChangeHandler("", "", function(bagName, key, value, source, replicated)
    -- global state isn't able to be set from the client
    if bagName == "global" then return end
    -- we're the ones that set this data, we don't want to possibly drop the
    -- player for it
    if not replicated then return end
    local ent
    local owner
    local state


    if bagName:find("entity") then
        ent = GetEntityFromStateBagName(bagName)
        owner = NetworkGetEntityOwner(ent)
        state = Entity(ent).state
    else
        ent = GetPlayerFromStateBagName(bagName)
        owner = ent
        state = Player(ent).state
    end

    -- get the current value, the value of the current state wont change until
    -- after the state bag change handler finishes
    local curVal = state[key]
    if type(key) == "string" then
        -- keys should never be above 20 characters long, if it is then reject
        -- and drop the owning player
        if key:len() > 20 then
            rejectStateChange(owner, ent, state, key, curVal)
        end
    end

    if isValueTooLarge(value) then
        rejectStateChange(owner, ent, state, key, curVal)
    end
end)