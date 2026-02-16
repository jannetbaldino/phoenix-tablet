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

-- ============================================================
-- PRP-TABLET parity callbacks (messages / settings / wallet / calls)
-- Paste below your biz_* callbacks
-- ============================================================

-- Support a shared UI close action (phone already uses "close")
RegisterNUICallback('close', function(_, cb)
  closeTablet()
  cb({ ok = true })
end)

-- Messages
RegisterNUICallback('sendMessage', function(data, cb)
  local peer = data and data.peer_number
  local body = data and data.body

  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:sendMessage', false, peer, body)
  end)

  if not ok then
    cb({ ok = false, error = 'callback_failed' })
    return
  end

  cb(resp or { ok = false })
end)

RegisterNUICallback('markNotifRead', function(data, cb)
  if data and data.id then
    TriggerServerEvent('prp-device:notifications:markRead', data.id)
  end
  cb({ ok = true })
end)

-- Settings
RegisterNUICallback('saveSettings', function(data, cb)
  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:settings:save', false, data)
  end)

  if not ok then
    cb({ ok = false, error = 'callback_failed' })
    return
  end

  cb(resp or { ok = false })
end)

-- Wallet
RegisterNUICallback('walletGetAccounts', function(_, cb)
  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:wallet:getAccounts', false)
  end)

  if not ok then
    cb({ ok = false, error = 'callback_failed' })
    return
  end

  cb(resp or { ok = false })
end)

RegisterNUICallback('walletHistory', function(_, cb)
  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:wallet:history', false)
  end)

  if not ok then
    cb({ ok = false, error = 'callback_failed' })
    return
  end

  cb(resp or { ok = false })
end)

RegisterNUICallback('walletTransfer', function(data, cb)
  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:wallet:transfer', false, data)
  end)

  if not ok then
    cb({ ok = false, error = 'callback_failed' })
    return
  end

  cb(resp or { ok = false })
end)

-- Calls (same callback names + payload flexibility as phone)
RegisterNUICallback('callDial', function(data, cb)
  local number = data and (data.number or data.to_number or data.toNumber)

  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:callDial', false, number)
  end)

  if not ok then
    cb({ ok = false, error = 'callback_failed' })
    return
  end

  cb(resp or { ok = false })
end)

RegisterNUICallback('callAccept', function(data, cb)
  local callId = data and (data.call_id or data.callId)

  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:callAccept', false, callId)
  end)

  if not ok then
    cb({ ok = false, error = 'callback_failed' })
    return
  end

  cb(resp or { ok = false })
end)

RegisterNUICallback('callDecline', function(data, cb)
  local callId = data and (data.call_id or data.callId)

  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:callDecline', false, callId)
  end)

  if not ok then
    cb({ ok = false, error = 'callback_failed' })
    return
  end

  cb(resp or { ok = false })
end)

RegisterNUICallback('callHangup', function(data, cb)
  local callId = data and (data.call_id or data.callId)

  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:callHangup', false, callId)
  end)

  if not ok then
    cb({ ok = false, error = 'callback_failed' })
    return
  end

  cb(resp or { ok = false })
end)

-- ------------------------------------------------------------
-- Server -> UI events (same as phone)
-- ------------------------------------------------------------
local function sendUI(action, data)
  SendNUIMessage({ action = action, data = data })
end

RegisterNetEvent('prp-device:call:incoming', function(payload)
  if not isOpen then return end
  sendUI('callIncoming', payload)
end)

RegisterNetEvent('prp-device:call:outgoing', function(payload)
  if not isOpen then return end
  sendUI('callOutgoing', payload)
end)

RegisterNetEvent('prp-device:call:active', function(payload)
  if not isOpen then return end
  sendUI('callActive', payload)
end)

RegisterNetEvent('prp-device:call:ended', function(payload)
  if not isOpen then return end
  sendUI('callEnded', payload)
end)

RegisterNetEvent('prp-device:notify', function(payload)
  if not isOpen then return end
  sendUI('notify', payload)
end)

RegisterNetEvent('prp-device:message:new', function(msg)
  if not isOpen then return end
  sendUI('messageNew', msg)
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
