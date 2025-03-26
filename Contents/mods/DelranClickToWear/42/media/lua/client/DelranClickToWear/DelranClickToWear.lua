local function dprint(...)
  if isDebugEnabled() then
    print("[DELRAN'S CLICK TO WEAR]: ", ...);
  end
end

---@param player IsoPlayer
---@param clothingItem IsoWorldInventoryObject
function MoveToAndWear(player, clothingItem)
  ISInventoryPaneContextMenu.transferIfNeeded(player, clothingItem);
  ISTimedActionQueue.add(ISWearClothing:new(player, clothingItem:getItem()));
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

  if not table.isempty(clothingItems) then
    ---@type ISContextMenu
    local subMenu = context:getNew(context);
    for _, clothingItem in ipairs(clothingItems) do
      subMenu:addOption(clothingItem:getName(), player, MoveToAndWear, clothingItem);
    end
    local subMenuOption = context:insertOptionAfter(getText("ContextMenu_Grab"), "Wear");
    context:addSubMenu(subMenuOption, subMenu);
  end
end

Events.OnFillWorldObjectContextMenu.Add(DrawWearOnClickMenu)
