local function dprint(...)
  if isDebugEnabled() then
    print("[DELRAN'S CLICK TO WEAR]: ", ...);
  end
end

-- This global variable holds the cached
---@type IsoWorldInventoryObject[]
WORLD_OBJECTS_CACHE = {};

---@param player IsoPlayer
---@param worldItem IsoWorldInventoryObject
function MoveToAndWear(player, worldItem)
  local clothingItem = worldItem:getItem();
  if not clothingItem:IsClothing() then
    dprint("Selected item is not a clothing item.");
    return;
  end

  -- Move to object square and keep the TimedActionQueue.
  luautils.walkAdj(player, worldItem:getSquare(), true);

  -- Transfer the clothing item in the player inventory.
  ISInventoryPaneContextMenu.transferItems({ clothingItem }, player:getInventory(), player:getIndex())

  -- Wear the item.
  ISTimedActionQueue.add(ISWearClothing:new(player, clothingItem));
end

---@param playerNum number
---@param context ISContextMenu
---@param worldObjects IsoObject[]
function DrawWearOnClickMenu(playerNum, context, worldObjects)
  local player = getSpecificPlayer(playerNum);
  ---@type IsoWorldInventoryObject[]
  local clothingItems = {};
  for _, worldObject in ipairs(worldObjects) do
    if instanceof(worldObject, "IsoWorldInventoryObject") then
      ---@type IsoWorldInventoryObject
      ---@diagnostic disable-next-line: assign-type-mismatch
      local worldInventoryItem = worldObject;
      if worldInventoryItem:getItem():IsClothing() then
        table.insert(clothingItems, worldInventoryItem);
      end
    end
  end

  if not table.isempty(clothingItems) or not table.isempty(WORLD_OBJECTS_CACHE) then
    ---@type ISContextMenu
    local subMenu = context:getNew(context);
    for _, clothingItem in ipairs(clothingItems) do
      subMenu:addOption(clothingItem:getName(), player, MoveToAndWear, clothingItem);

      -- Check the item is cached in our global variable, if it is, remove it from the cache
      --   so that it doesn't appear twice in the menu.
      for index, cachedObject in ipairs(WORLD_OBJECTS_CACHE) do
        if clothingItem == cachedObject then
          table.remove(WORLD_OBJECTS_CACHE, index);
          break
        end
      end
    end

    -- Get the remaining items from the cache that weren't present in the worldObjects table
    for _, cachedObject in ipairs(WORLD_OBJECTS_CACHE) do
      subMenu:addOption(cachedObject:getName(), player, MoveToAndWear, cachedObject);
    end

    -- Insert the sub menu just after the Grab option.
    local subMenuOption = context:insertOptionAfter(getText("ContextMenu_Grab"), "Wear");
    context:addSubMenu(subMenuOption, subMenu);
  end
end

Events.OnFillWorldObjectContextMenu.Add(DrawWearOnClickMenu)

if not ORIGINAL_FUNC then
  dprint("LOADING MODULE");
  ORIGINAL_FUNC = ISWorldObjectContextMenu.getWorldObjectsInRadius;
else
  dprint("RELOADING MODULE");
end

-- Hijack getWorldObjectsInRadius to get the world objects found by the function, this will give us
--  the world objects near the mouse click without having to do all the calculation.
---@diagnostic disable-next-line: duplicate-set-field
function ISWorldObjectContextMenu.getWorldObjectsInRadius(playerNum, screenX, screenY, squares, radius, worldObjects)
  ORIGINAL_FUNC(playerNum, screenX, screenY, squares, radius, worldObjects);
  WORLD_OBJECTS_CACHE = worldObjects;
end
