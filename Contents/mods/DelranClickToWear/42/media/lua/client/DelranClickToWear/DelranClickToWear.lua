local function dprint(...)
  if isDebugEnabled() then
    print("[DELRAN'S CLICK TO WEAR]: ", ...);
  end
end

-- This global variable holds the cached world objects that were found by the game near a right click.
---@type IsoWorldInventoryObject[]
WORLD_OBJECTS_CACHE = {};

---@param player IsoPlayer
---@param worldItem IsoWorldInventoryObject
function MoveToAndWear(player, worldItem)
  local clothingItem = worldItem:getItem();
  if not clothingItem:IsClothing() and not clothingItem:IsInventoryContainer() then
    dprint("Selected item is not a clothing item : ", clothingItem:getType(), " ", clothingItem:getName());
    return;
  end
  -- Move to object square and keep the TimedActionQueue.
  --luautils.walkAdj(player, worldItem:getSquare(), true);

  dprint("Transfering item : ", clothingItem, " to player ", player:getIndex());
  dprint("Clothing item container : ", clothingItem:getContainer());
  ISWorldObjectContextMenu.onGrabWItem({}, worldItem, player:getIndex());
  --ISTimedActionQueue.add(ISInventoryTransferAction:new(player, clothingItem, clothingItem:getContainer(),player:getInventory()));
  --ISInventoryPaneContextMenu.onGrabItems({ clothingItem }, player:getIndex());
  -- Transfer the clothing item in the player inventory.
  --ISInventoryPaneContextMenu.transferItems({ clothingItem }, player:getInventory(), player:getIndex())

  dprint("Queueing wear clothing action : ", clothingItem:getName(), " on player ", player:getIndex());
  -- Wear the item.
  ISTimedActionQueue.add(ISWearClothing:new(player, clothingItem));

  --[[
  local i = 0;
  OnTick = function()
    if i > 1000 then
      Events.OnTick.Remove(OnTick);
      worldItem:setHighlighted(false);
      return nil;
    end
    i = i + 1;
    worldItem:setHighlightColor(1, 1, 1, 1);
    worldItem:setHighlighted(true);
    --worldItem:setOutlineHighlight(true);
  end

  Events.OnTick.Add(OnTick);
  ]]
end

---@param playerNum number
---@param context ISContextMenu
---@param worldObjects IsoObject[]
function DrawWearOnClickMenu(playerNum, context, worldObjects)
  local player = getSpecificPlayer(playerNum);
  ---@type { [string]: IsoWorldInventoryObject }
  local clothingItems = {};
  for _, worldObject in ipairs(worldObjects) do
    if instanceof(worldObject, "IsoWorldInventoryObject") then
      ---@type IsoWorldInventoryObject
      ---@diagnostic disable-next-line: assign-type-mismatch
      local worldInventoryItem = worldObject;
      local inventoryItem = worldInventoryItem:getItem();
      dprint("DISPLAY MENY ITEM CONTAINER : ", inventoryItem:getContainer());
      if inventoryItem:IsClothing() or inventoryItem:IsInventoryContainer() then
        clothingItems[inventoryItem:getName()] = worldInventoryItem;
      end
    end
  end

  ---@type { [string]: IsoWorldInventoryObject }
  local cachedClothingWorldItem = {};
  for _, cachedWorldObject in ipairs(WORLD_OBJECTS_CACHE) do
    local cachedInventoryItem = cachedWorldObject:getItem();
    if cachedInventoryItem:IsClothing() or cachedInventoryItem:IsInventoryContainer() then
      cachedClothingWorldItem[cachedInventoryItem:getName()] = cachedWorldObject;
    end
  end

  if not table.isempty(clothingItems) or not table.isempty(cachedClothingWorldItem) then
    ---@type ISContextMenu
    local subMenu = context:getNew(context);
    for itemName, clothingItem in pairs(clothingItems) do
      subMenu:addOption(itemName, player, MoveToAndWear, clothingItem);

      -- Check the item is cached in our global variable, if it is, remove it from the cache
      --   so that it doesn't appear twice in the menu.
      for objectName, cachedObject in pairs(cachedClothingWorldItem) do
        if clothingItem == cachedObject then
          cachedClothingWorldItem[objectName] = nil;
          break
        end
      end
    end

    -- Get the remaining items from the cache that weren't present in the worldObjects table
    for _, cachedWorldObject in ipairs(cachedClothingWorldItem) do
      local cachedInventoryItem = cachedWorldObject:getItem();
      subMenu:addOption(cachedInventoryItem:getName(), player, MoveToAndWear, cachedWorldObject);
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
