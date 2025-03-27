local function dprint(...)
  if isDebugEnabled() then
    print("[DELRAN'S CLICK TO WEAR]: ", ...);
  end
end

-- This global variable holds the cached world objects that were found by the game near a right click.
---@type IsoWorldInventoryObject[]
WORLD_OBJECTS_CACHE = {};

---Is the passed InventoryItem a bag ?
---@param item InventoryItem
function IsBag(item)
  -- Patchwork solution to filter InventoryItems that are bags.
  return item:getType():match("^Bag_") ~= nil;
end

---@param player IsoPlayer
---@param worldItem IsoWorldInventoryObject
function MoveToAndWear(player, worldItem)
  local wearableItem = worldItem:getItem();
  if not wearableItem:IsClothing() and not wearableItem:IsInventoryContainer() then
    dprint("Selected item is not wearable : ", wearableItem:getType(), " ", wearableItem:getName());
    return;
  end

  luautils.walkAdj(player, worldItem:getSquare(), true);
  ISTimedActionQueue.add(ISInventoryTransferAction:new(player, wearableItem, wearableItem:getContainer(),
    player:getInventory()));
  --ISWorldObjectContextMenu.onGrabWItem({}, worldItem, player:getIndex());

  dprint("Queueing wear clothing action : ", wearableItem:getName(), " on player ", player:getIndex());
  -- Wear the item.
  ISTimedActionQueue.add(ISWearClothing:new(player, wearableItem));

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

---Draw the Wear context menu when right clicking on the world
---@param playerNum number
---@param context ISContextMenu
---@param worldObjects IsoObject[]
function DrawWearWorldItemMenu(playerNum, context, worldObjects)
  -- If the game didn't found any items to grab, we don't bother going further.
  if not context:getOptionFromName(getText("ContextMenu_Grab")) then
    return
  end

  local player = getSpecificPlayer(playerNum);

  -- So you can't get the size of a Hashmap in lua ? Wtf is this.
  local itemCount = 0;
  ---Wearable items found to be added as an option in our submenu
  ---@type { [string]: IsoWorldInventoryObject }
  local clothingItems = {};
  ---Hashmap that will contain items we already iterated over.
  ---@type { [IsoWorldInventoryObject]: boolean }
  local seenItems = {};

  for _, cachedWorldObject in ipairs(WORLD_OBJECTS_CACHE) do
    seenItems[cachedWorldObject] = true;
    local cachedInventoryItem = cachedWorldObject:getItem();

    -- Only proceed if the item is wearable.
    if cachedInventoryItem:IsClothing() or IsBag(cachedInventoryItem) then
      clothingItems[cachedInventoryItem:getName()] = cachedWorldObject;
      itemCount = itemCount + 1;
    end
  end

  for _, worldObject in ipairs(worldObjects) do
    -- Skip any object that is not an InventoryItem
    if instanceof(worldObject, "IsoWorldInventoryObject") then
      ---@type IsoWorldInventoryObject
      ---@diagnostic disable-next-line: assign-type-mismatch
      local worldInventoryItem = worldObject;
      local inventoryItem = worldInventoryItem:getItem();

      -- Only proceed if the item is wearable and was not seen in the world objects cache.
      if not seenItems[worldInventoryItem] and (inventoryItem:IsClothing() or IsBag(inventoryItem)) then
        clothingItems[inventoryItem:getName()] = worldInventoryItem;
        itemCount = itemCount + 1;
      end
    end
  end


  -- If no items were added to the werable items, stop here.
  if itemCount == 0 then return end

  if itemCount == 1 then
    -- Can't I just get the first AND ONLY value of the table ? HOW
    -- WTF IS THIS LANGAGUE
    for itemName, uniqueClothingItem in pairs(clothingItems) do
      context:insertOptionAfter(getText("ContextMenu_Grab"), "Wear " .. itemName, player, MoveToAndWear,
        uniqueClothingItem);
      break;
    end
  else
    ---@type ISContextMenu
    local subMenu = context:getNew(context);

    for itemName, clothingItem in pairs(clothingItems) do
      subMenu:addOption(itemName, player, MoveToAndWear, clothingItem);
    end

    -- Insert the sub menu just after the Grab option.
    local subMenuOption = context:insertOptionAfter(getText("ContextMenu_Grab"), "Wear");
    context:addSubMenu(subMenuOption, subMenu);
  end
end

Events.OnFillWorldObjectContextMenu.Add(DrawWearWorldItemMenu)

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
