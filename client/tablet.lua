-- prp-tablet/client/tablet.lua (NUI version)

local isOpen = false

local CMD = 'tablet'
local KEY = 'F2'

local function closeTablet()
  if not isOpen then return end
  isOpen = false

  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(false)

  SendNUIMessage({ action = 'close' })
end

local function openTablet()
  if isOpen then return end
  isOpen = true

  -- IMPORTANT: do NOT keep input
  SetNuiFocus(true, true)
  SetNuiFocusKeepInput(false)

  local bootstrap
  local ok = pcall(function()
    bootstrap = lib.callback.await('prp-device:getBootstrap', false)
  end)

  if not ok or not bootstrap then
    bootstrap = {
      user = {
        phone_number = 'Unknown',
        citizenid = 'Unknown',
        server_id = GetPlayerServerId(PlayerId())
      }
    }
  end

  local isAdmin = false
  pcall(function()
    local r = lib.callback.await('prp-business:server:isAdmin', false)
    isAdmin = (r == true or r == 1)
  end)
  bootstrap.isAdmin = isAdmin

  SendNUIMessage({ action = 'open', data = bootstrap })
end

-- =================
-- NUI callbacks
-- =================

RegisterNUICallback('close_tablet', function(_, cb)
  closeTablet()
  cb({ ok = true })
end)

RegisterNUICallback('biz_listBusinesses', function(_, cb)
  local rows = lib.callback.await('prp-business:tablet:listBusinesses', false) or {}
  cb({ ok = true, data = rows })
end)

RegisterNUICallback('biz_getBusiness', function(data, cb)
  local businessId = data and tonumber(data.businessId)
  if not businessId then
    cb({ ok = false, error = 'bad_request' })
    return
  end

  local result, err = lib.callback.await(
    'prp-business:tablet:getBusiness',
    false,
    businessId
  )

  if not result then
    cb({ ok = false, error = err or 'failed' })
    return
  end

  cb({ ok = true, data = result })
end)

RegisterNUICallback('biz_createBusiness', function(data, cb)
  local name = data and tostring(data.name or '')
  if name == '' then
    cb({ ok = false, error = 'missing_name' })
    return
  end

  local id, err = lib.callback.await(
    'prp-business:tablet:createBusiness',
    false,
    { name = name }
  )

  if not id then
    cb({ ok = false, error = err or 'failed' })
    return
  end

  cb({ ok = true, data = { businessId = id } })
end)

RegisterNUICallback('biz_upsertRole', function(data, cb)
  local businessId = data and tonumber(data.businessId)
  local role = data and data.role

  if not businessId or type(role) ~= 'table' then
    cb({ ok = false, error = 'bad_request' })
    return
  end

  local ok, err = lib.callback.await(
    'prp-business:tablet:upsertRole',
    false,
    businessId,
    role
  )

  cb({ ok = ok == true, error = err })
end)

RegisterNUICallback('biz_deleteRole', function(data, cb)
  local businessId = data and data.businessId
  local roleId = data and data.roleId

  local ok, err = lib.callback.await('prp-business:tablet:deleteRole', false, businessId, roleId)
  if ok == false then
    cb({ ok = false, error = err or 'unknown' })
    return
  end

  cb({ ok = true })
end)

RegisterNUICallback('biz_hireEmployee', function(data, cb)
  local businessId = data and tonumber(data.businessId)
  local citizenid = data and tostring(data.citizenid or '')
  local roleId = data and tonumber(data.roleId)
  local grade = data and tonumber(data.grade or 0) or 0

  if not businessId or citizenid == '' or not roleId then
    cb({ ok = false, error = 'bad_request' })
    return
  end

  local ok, err = lib.callback.await(
    'prp-business:tablet:hireEmployee',
    false,
    businessId,
    citizenid,
    roleId,
    grade
  )

  cb({ ok = ok == true, error = err })
end)

RegisterNUICallback('biz_addPoint', function(data, cb)
  local businessId = data and tonumber(data.businessId)
  local point = data and data.point

  if not businessId or type(point) ~= 'table' then
    cb({ ok = false, error = 'bad_request' })
    return
  end

  local id, err = lib.callback.await(
    'prp-business:tablet:addPoint',
    false,
    businessId,
    point
  )

  if not id then
    cb({ ok = false, error = err or 'failed' })
    return
  end

  cb({ ok = true, data = { id = id } })
end)

RegisterNUICallback('biz_openPlacement', function(data, cb)
  local businessId = data and tonumber(data.businessId)
  if not businessId then
    cb({ ok = false, error = 'no_business_selected' })
    return
  end

  TriggerEvent('prp-business:client:openPlacement', businessId)
  cb({ ok = true })
end)

-- =================================
-- HARD INPUT BLOCK WHILE TABLET OPEN
-- =================================
CreateThread(function()
  while true do
    if not isOpen then
      Wait(250)
    else
      Wait(0)

      -- Disable EVERYTHING so typing doesn't move player
      DisableAllControlActions(0)

      -- Re-enable mouse look + ESC
      EnableControlAction(0, 1, true)   -- LookLeftRight
      EnableControlAction(0, 2, true)   -- LookUpDown
      EnableControlAction(0, 322, true) -- ESC

      if IsDisabledControlJustPressed(0, 322) then
        closeTablet()
      end
    end
  end
end)

RegisterCommand(CMD, function()
  if isOpen then
    closeTablet()
  else
    openTablet()
  end
end, false)

RegisterKeyMapping(CMD, 'Open Tablet', 'keyboard', KEY)
