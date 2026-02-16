local isOpen = false

-- ------------------------------------------------------------
-- UI bridge
-- ------------------------------------------------------------
local function sendUI(action, data)
  SendNUIMessage({ action = action, data = data })
end

local function fetchBootstrap()
  local ok, bootstrap = pcall(function()
    return lib.callback.await('prp-device:getBootstrap', false)
  end)

  if ok and bootstrap and bootstrap.user then
    return bootstrap
  end

  return {
    user = {
      phone_number = 'Unknown',
      citizenid = 'Unknown',
      server_id = GetPlayerServerId(PlayerId()),
      settings = {},
    },
    config = {},
    conversations = {},
    unread_notifications = {},
    isAdmin = false,
  }
end

-- ------------------------------------------------------------
-- Control blocking while open
-- ------------------------------------------------------------
local function startControlBlockThread()
  CreateThread(function()
    while isOpen do
      DisableControlAction(0, 1, true)   -- look left/right
      DisableControlAction(0, 2, true)   -- look up/down
      DisableControlAction(0, 24, true)  -- attack
      DisableControlAction(0, 25, true)  -- aim
      DisableControlAction(0, 37, true)  -- weapon wheel
      DisableControlAction(0, 45, true)  -- reload
      DisableControlAction(0, 200, true) -- pause
      DisablePlayerFiring(PlayerId(), true)
      Wait(0)
    end
  end)
end

-- ------------------------------------------------------------
-- Open / Close
-- ------------------------------------------------------------
local function openTablet()
  if isOpen then return end
  isOpen = true

  SetNuiFocus(true, true)
  SetNuiFocusKeepInput(false)

  startControlBlockThread()

  local bootstrap = fetchBootstrap()
  sendUI('open', bootstrap)
end

local function closeTablet()
  if not isOpen then
    sendUI('close')
    return
  end

  isOpen = false
  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(false)
  sendUI('close')
end

RegisterCommand('tablet', function()
  if isOpen then closeTablet() else openTablet() end
end, false)

RegisterKeyMapping('tablet', 'Open Tablet', 'keyboard', 'F2')

-- Panic close while testing
RegisterCommand('nuireset', function()
  isOpen = false
  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(false)
  sendUI('close')
  print('[tablet] forced close')
end, false)

-- ------------------------------------------------------------
-- NUI callbacks (tablet)
-- ------------------------------------------------------------

-- keep legacy close name from old tablet UI
RegisterNUICallback('close_tablet', function(_, cb)
  closeTablet()
  cb({ ok = true })
end)

-- shared close name for React UI (same as phone)
RegisterNUICallback('close', function(_, cb)
  closeTablet()
  cb({ ok = true })
end)

-- ------------------------------------------------------------
-- Business callbacks (from your tablet ui/app.js)
-- ------------------------------------------------------------
RegisterNUICallback('biz_listBusinesses', function(_, cb)
  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:biz_listBusinesses', false)
  end)
  if not ok then cb({ ok = false, error = 'callback_failed' }) return end
  cb(resp or { ok = false })
end)

RegisterNUICallback('biz_getBusiness', function(data, cb)
  local businessId = data and tonumber(data.businessId)
  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:biz_getBusiness', false, businessId)
  end)
  if not ok then cb({ ok = false, error = 'callback_failed' }) return end
  cb(resp or { ok = false })
end)

RegisterNUICallback('biz_openPlacement', function(data, cb)
  local businessId = data and tonumber(data.businessId)
  TriggerEvent('prp-device:biz_openPlacement', businessId)
  cb({ ok = true })
end)

RegisterNUICallback('biz_createBusiness', function(data, cb)
  local name = data and tostring(data.name or '') or ''
  name = name:gsub('^%s+', ''):gsub('%s+$', '')
  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:biz_createBusiness', false, { name = name })
  end)
  if not ok then cb({ ok = false, error = 'callback_failed' }) return end
  cb(resp or { ok = false })
end)

RegisterNUICallback('biz_upsertRole', function(data, cb)
  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:biz_upsertRole', false, data)
  end)
  if not ok then cb({ ok = false, error = 'callback_failed' }) return end
  cb(resp or { ok = false })
end)

RegisterNUICallback('biz_deleteRole', function(data, cb)
  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:biz_deleteRole', false, data)
  end)
  if not ok then cb({ ok = false, error = 'callback_failed' }) return end
  cb(resp or { ok = false })
end)

RegisterNUICallback('biz_hireEmployee', function(data, cb)
  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:biz_hireEmployee', false, data)
  end)
  if not ok then cb({ ok = false, error = 'callback_failed' }) return end
  cb(resp or { ok = false })
end)

-- ------------------------------------------------------------
-- Tablet parity callbacks (messages / settings / wallet / calls)
-- Mirrors phone.lua callback names so shared apps work on both.
-- ------------------------------------------------------------

-- Messages
RegisterNUICallback('sendMessage', function(data, cb)
  local peer = data and data.peer_number
  local body = data and data.body
  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:sendMessage', false, peer, body)
  end)
  if not ok then cb({ ok = false, error = 'callback_failed' }) return end
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
  if not ok then cb({ ok = false, error = 'callback_failed' }) return end
  cb(resp or { ok = false })
end)

-- Wallet
RegisterNUICallback('walletGetAccounts', function(_, cb)
  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:wallet:getAccounts', false)
  end)
  if not ok then cb({ ok = false, error = 'callback_failed' }) return end
  cb(resp or { ok = false })
end)

RegisterNUICallback('walletHistory', function(_, cb)
  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:wallet:history', false)
  end)
  if not ok then cb({ ok = false, error = 'callback_failed' }) return end
  cb(resp or { ok = false })
end)

RegisterNUICallback('walletTransfer', function(data, cb)
  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:wallet:transfer', false, data)
  end)
  if not ok then cb({ ok = false, error = 'callback_failed' }) return end
  cb(resp or { ok = false })
end)

-- Calls
RegisterNUICallback('callDial', function(data, cb)
  local number = data and (data.number or data.to_number or data.toNumber)
  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:callDial', false, number)
  end)
  if not ok then cb({ ok = false, error = 'callback_failed' }) return end
  cb(resp or { ok = false })
end)

RegisterNUICallback('callAccept', function(data, cb)
  local callId = data and (data.call_id or data.callId)
  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:callAccept', false, callId)
  end)
  if not ok then cb({ ok = false, error = 'callback_failed' }) return end
  cb(resp or { ok = false })
end)

RegisterNUICallback('callDecline', function(data, cb)
  local callId = data and (data.call_id or data.callId)
  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:callDecline', false, callId)
  end)
  if not ok then cb({ ok = false, error = 'callback_failed' }) return end
  cb(resp or { ok = false })
end)

RegisterNUICallback('callHangup', function(data, cb)
  local callId = data and (data.call_id or data.callId)
  local ok, resp = pcall(function()
    return lib.callback.await('prp-device:callHangup', false, callId)
  end)
  if not ok then cb({ ok = false, error = 'callback_failed' }) return end
  cb(resp or { ok = false })
end)

-- ------------------------------------------------------------
-- Server -> UI events
-- ------------------------------------------------------------
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

-- Cleanup
AddEventHandler('onClientResourceStart', function(res)
  if res ~= GetCurrentResourceName() then return end
  isOpen = false
  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(false)
  sendUI('close')
end)

AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  isOpen = false
  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(false)
  sendUI('close')
end)
