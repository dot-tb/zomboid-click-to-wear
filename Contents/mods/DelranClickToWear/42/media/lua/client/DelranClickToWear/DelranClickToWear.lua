local function dprint(...)
  if isDebugEnabled() then
    print("[DELRAN'S CLICK TO WEAR]: ", ...);
  end
end

-- This global variable holds the cached world objects that were found by the game near a right click.
---@type IsoWorldInventoryObject[]
local WORLD_OBJECTS_CACHE = {};

---@type { [InventoryItem] : InventoryItem[] }
local REPLACED_ITEMS = {};

---@type { [string] : boolean }
local EQUIPPED_BODY_LOCATIONS = {};

function CanGrab(square, player)
  square = luautils.getCorrectSquareForWall(player, square);
  local diffX = math.abs(square:getX() + 0.5 - player:getX());
  local diffY = math.abs(square:getY() + 0.5 - player:getY());
  if diffX <= 1.6 and diffY <= 1.6 and player:getSquare():canReachTo(square) then
    return true;
  end
  return false;
end

---Is the passed InventoryItem a bag ?
---@param item InventoryItem
function IsBackpack(item)
  -- Patchwork solution to filter InventoryItems that are bags.
  return item:IsInventoryContainer() and item:canBeEquipped() == "Back";
end

---@param player IsoPlayer
---@param worldItem IsoWorldInventoryObject
function MoveToAndWear(player, worldItem)
  local wearableItem = worldItem:getItem();

  local IsBackpack = IsBackpack(wearableItem);
  if not wearableItem:IsClothing() and not IsBackpack then
    dprint("Selected item is not wearable : ", wearableItem:getType(), " ", wearableItem:getName());
    return;
  end

  if not IsBackpack then
    local bodyLocation = wearableItem:getBodyLocation();

    local locationGroup = player:getWornItems():getBodyLocationGroup();
    if EQUIPPED_BODY_LOCATIONS[bodyLocation] then
      dprint("Already replaced this bodylocation, canceling");
      return;
    else
      for equippedBodyLocation, _ in pairs(EQUIPPED_BODY_LOCATIONS) do
        if locationGroup:isExclusive(equippedBodyLocation, bodyLocation) then
          dprint("Trying to equip multiple items with eclusives bodylocations, canceling");
          return
        end
      end
      EQUIPPED_BODY_LOCATIONS[bodyLocation] = true;
    end
  else
    if not EQUIPPED_BODY_LOCATIONS["Backpack"] then
      EQUIPPED_BODY_LOCATIONS["Backpack"] = true;
    else
      dprint("Already equipped a backpack");
      return
    end
  end

  local square = worldItem:getSquare();
  local offsetX, offsetY, offsetZ = worldItem:getOffX(), worldItem:getOffY(), worldItem:getOffZ()
  local rotation = wearableItem:getWorldZRotation();

  if not CanGrab(square, player) then
    local exclude = {};
    ---@type IsoGridSquare
    local adjacent = AdjacentFreeTileFinder.Find(square, player);
    local i = 0;
    while not adjacent:isFree(false) do
      table.insert(exclude, adjacent)
      adjacent = AdjacentFreeTileFinder.Find(square, player, exclude);
      if adjacent == nil then break end
    end

    if adjacent ~= nil then
      ISTimedActionQueue.add(ISWalkToTimedAction:new(player, adjacent));
    else
      return
    end
  end

  local time = ISWorldObjectContextMenu.grabItemTime(player, worldItem)
  ISTimedActionQueue.add(ISGrabItemAction:new(player, worldItem, time))

  dprint("Queueing wear clothing action : ", wearableItem:getName(), " on player ", player:getIndex());
  -- Wear the item.
  ISTimedActionQueue.add(ISWearClothing:new(player, wearableItem));
  local replacingItems = REPLACED_ITEMS[worldItem:getItem()];
  if replacingItems then
    -- Only placing the first replaced item for now, the rest wil go to the inventory
    local item = replacingItems[1];
    ISTimedActionQueue.add(ISDropWorldItemAction:new(player, item, square, offsetX, offsetY, offsetZ,
      rotation, false));
  end
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

---@param player IsoPlayer
---@param worldItems  { [IsoWorldInventoryObject]: string }
function WearAll(player, worldItems)
  for worldItem, _ in pairs(worldItems) do
    MoveToAndWear(player, worldItem)
  end
end

---comment
---@param worldItem IsoWorldInventoryObject
---@param player IsoPlayer
---@param option any
function DoWearClothingTooltip(worldItem, player, option)
  local item = worldItem:getItem();

  local itemOnPlayerBack = player:getClothingItem_Back();
  if IsBackpack(item) and itemOnPlayerBack then
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip.description = getText("Tooltip_ReplaceWornItems") .. " <LINE> <INDENT:20> "
    tooltip.description = tooltip.description .. itemOnPlayerBack:getDisplayName();
    option.toolTip = tooltip
    REPLACED_ITEMS[item] = { itemOnPlayerBack };
  else
    local replacingItems = ISInventoryPaneContextMenu.doWearClothingTooltip(player, item, item, option);
    if replacingItems then
      for _, replacedItem in ipairs(replacingItems) do
        if not REPLACED_ITEMS[item] then REPLACED_ITEMS[item] = {} end;
        table.insert(REPLACED_ITEMS[item], replacedItem);
      end
    end
  end
end

---Draw the Wear context menu when right clicking on the world
---@param playerNum number
---@param context ISContextMenu
---@param worldObjects IsoObject[]
function DrawWearWorldItemMenu(playerNum, context, worldObjects)
  REPLACED_ITEMS = {};
  EQUIPPED_BODY_LOCATIONS = {};
  -- If the game didn't found any items to grab, we don't bother going further.
  if not context:getOptionFromName(getText("ContextMenu_Grab")) then
    return
  end

  local player = getSpecificPlayer(playerNum);

  -- So you can't get the size of a Hashmap in lua ? Wtf is this.
  local itemCount = 0;
  ---Wearable items found to be added as an option in our submenu
  ---@type { [IsoWorldInventoryObject]: string }
  local clothingItems = {};
  ---Hashmap that will contain items we already iterated over.

  for _, cachedWorldObject in ipairs(WORLD_OBJECTS_CACHE) do
    local cachedInventoryItem = cachedWorldObject:getItem();

    -- Only proceed if the item is wearable.
    if cachedInventoryItem:IsClothing() or IsBackpack(cachedInventoryItem) then
      clothingItems[cachedWorldObject] = cachedInventoryItem:getName();
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
      if not clothingItems[worldInventoryItem] and (inventoryItem:IsClothing() or IsBackpack(inventoryItem)) then
        clothingItems[worldInventoryItem] = inventoryItem:getName();
        itemCount = itemCount + 1;
      end
    end
  end


  -- If no items were added to the werable items, stop here.
  if itemCount == 0 then return end

  if itemCount == 1 then
    -- Can't I just get the first AND ONLY value of the table ? HOW
    -- WTF IS THIS LANGAGUE
    for uniqueWorldClothingItem, itemName in pairs(clothingItems) do
      local option = context:insertOptionAfter(getText("ContextMenu_Grab"), "Wear " .. itemName, player, MoveToAndWear,
        uniqueWorldClothingItem);
      DoWearClothingTooltip(uniqueWorldClothingItem, player, option);
      break;
    end
  else
    ---@type ISContextMenu
    local subMenu = context:getNew(context);

    local wearAllOption = subMenu:addOption('Wear all', player, WearAll, clothingItems);
    local wearAllOptionTooltip = ISInventoryPaneContextMenu.addToolTip();
    for worldItem, itemName in pairs(clothingItems) do
      local option = subMenu:addOption(itemName, player, MoveToAndWear, worldItem);
      DoWearClothingTooltip(worldItem, player, option);
      if option.toolTip then
        wearAllOptionTooltip.description = string.format("%s %s %s %s %s", wearAllOptionTooltip.description, "<TEXT>",
          itemName, "<LINE>", option.toolTip.description);
      end
    end
    wearAllOption.toolTip = wearAllOptionTooltip;

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
