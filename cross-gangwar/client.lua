local QBCore = exports['qb-core']:GetCoreObject()
local currentWave, isSurvivalActive, myBucket = 0, false, 0
local activeStageId = 1
local spawnedPeds, invitedPlayers = {}, {}
local waitingForWave, countdown = false, 0
local notifiedDeath = false
local isEnding = false
local activeSurvivalPlayers = {}
local waveTimer = 0
local isLobbyLeader = false 
local inLobbyAsMember = false
local lobbyLeaderId = nil

-- [MARKET SİSTEMİ]
RegisterNetEvent('gs-survival:client:openMarket', function()
    local menu = {
        { header = "Survival Geliştirme Marketi", isMenuHeader = true },
        { 
            header = "Çelik Yelek Geliştirmesi", 
            txt = "Her tur 100 zırh ile başla. Fiyat: $50,000", 
            params = { event = "gs-survival:client:marketBridge", args = { type = "armor", value = 100, price = 50000 } } 
        },
        { 
            header = "Uzi Başlangıç Paketi", 
            txt = "Tabanca yerine Uzi ile başla. Fiyat: $100,000", 
            params = { event = "gs-survival:client:marketBridge", args = { type = "weapon", value = "WEAPON_MICROSMG", price = 100000 } } 
        },
        -- Geri Dön Butonu
        {
            header = "⬅️ Geri Dön",
            txt = "Ana Menüye Dön",
            params = {
                event = "gs-survival:client:openMenu" -- Senin istediğin geri dönüş eventi
            }
        }
    }
    exports['qb-menu']:openMenu(menu)
end)
RegisterNetEvent('gs-survival:client:marketBridge', function(args)
    TriggerServerEvent('gs-survival:server:buyUpgrade', args)
end)

RegisterNetEvent('gs-survival:client:setArmor', function(amount)
    Wait(1500)
    SetPedArmour(PlayerPedId(), tonumber(amount))
end)

-- [RECONNECT VE GÜVENLİ BÖLGE KONTROLÜ]
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(5000)
    QBCore.Functions.TriggerCallback('gs-survival:server:checkReconnectBackup', function(hasBackup)
        if hasBackup then
            local ped = PlayerPedId()
            FreezeEntityPosition(ped, true)
            isSurvivalActive = false
            DoScreenFadeOut(500)
            Wait(1000)
            SetEntityCoords(ped, Config.Npc.Coords.x, Config.Npc.Coords.y, Config.Npc.Coords.z)
            Wait(3000)
            DoScreenFadeIn(1000)
            FreezeEntityPosition(ped, false)
            QBCore.Functions.Notify("Eşyaların güvenli bölgede teslim edildi.", "success", 8000)
        end
    end)
end)

-- [İLİŞKİ AYARLARI]
Citizen.CreateThread(function()
    AddRelationshipGroup('HATES_PLAYER')
    SetRelationshipBetweenGroups(5, `HATES_PLAYER`, `PLAYER`)
    SetRelationshipBetweenGroups(5, `PLAYER`, `HATES_PLAYER`)
end)

-- [BAŞLANGIÇ NPC VE TARGET]
local startPed
Citizen.CreateThread(function()
    local model = Config.Npc.Model
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end

    startPed = CreatePed(4, model, Config.Npc.Coords.x, Config.Npc.Coords.y, Config.Npc.Coords.z - 1.0, Config.Npc.Coords.w, false, true)
    FreezeEntityPosition(startPed, true)
    SetEntityInvincible(startPed, true)
    SetBlockingOfNonTemporaryEvents(startPed, true)
    SetEntityAsMissionEntity(startPed, true, true)

    exports.ox_target:addLocalEntity(startPed, {
        {
            name = 'survival_main',
            icon = 'fas fa-users',
            label = Config.Npc.Label,
            canInteract = function(entity) return IsEntityVisible(entity) end,
            onSelect = function() TriggerEvent('gs-survival:client:openMenu') end
        },
        
    })
end)

-- [TEMİZLİK FONKSİYONU]
RegisterNetEvent('gs-survival:client:cleanupBeforeLeave', function()
    isSurvivalActive = false
    isEnding = true
    notifiedDeath = false
    exports['qb-core']:HideText()
    StopSpectating()
end)

-- [ÖLÜM VE SPECTATE SİSTEMİ]
Citizen.CreateThread(function()
    while true do
        Wait(1000)
        if isSurvivalActive then
            local ped = PlayerPedId()
            if IsEntityDead(ped) or IsPedFatallyInjured(ped) then
                if not notifiedDeath then
                    notifiedDeath = true
                    isSurvivalActive = false
                    TriggerServerEvent('gs-survival:server:finishSurvival', false)
                    
                    local livingOthers = false
                    local myId = GetPlayerServerId(PlayerId())
                    for _, id in ipairs(activeSurvivalPlayers) do
                        if tonumber(id) ~= tonumber(myId) then
                            local pIdx = GetPlayerFromServerId(id)
                            if pIdx ~= -1 and NetworkIsPlayerActive(pIdx) then
                                if not IsPedFatallyInjured(GetPlayerPed(pIdx)) then
                                    livingOthers = true
                                    break
                                end
                            end
                        end
                    end

                    if livingOthers then
                        QBCore.Functions.Notify("Öldün! Takım arkadaşlarını izliyorsun...", "error", 5000)
                        Wait(1000)
                        StartSurvivalSpectate()
                    end
                end
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        -- Trafik yoğunluğunu her karede sıfırla (Bu crash yapmaz)
        SetVehicleDensityMultiplierThisFrame(0.0)
        SetPedDensityMultiplierThisFrame(0.0)
        SetRandomVehicleDensityMultiplierThisFrame(0.0)
        SetParkedVehicleDensityMultiplierThisFrame(0.0)
        SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
        Citizen.Wait(0)
    end
end)

Citizen.CreateThread(function()
    while true do
        -- Alan temizliğini SADECE 5 saniyede bir yap (Crash engelleyen kısım)
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)
            ClearAreaOfVehicles(coords.x, coords.y, coords.z, 500.0, false, false, false, false, false)
            ClearAreaOfPeds(coords.x, coords.y, coords.z, 500.0, 1)
        end
        Citizen.Wait(5000) 
    end
end)

-- [MESAFE VE TRAFİK KONTROLÜ]
local teleportLeeway = 0
Citizen.CreateThread(function()
    local lastWarningTime = 0

    while true do
        local sleep = 1000

        if isSurvivalActive and not notifiedDeath then
            sleep = 500
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local stageData = Config.Stages[activeStageId]

            if stageData and stageData.center then
                local dist = #(coords - stageData.center)
                if teleportLeeway < 10 then teleportLeeway = teleportLeeway + 1 dist = 0 end
                if dist > Config.Combat.BoundaryDistance then
                    isSurvivalActive = false
                    teleportLeeway = 0
                    exports['qb-core']:HideText()
                    QBCore.Functions.Notify("Savaş alanından çok uzaklaştın!", "error")
                    SetEntityCoords(ped, Config.Npc.Coords.x, Config.Npc.Coords.y, Config.Npc.Coords.z)
                    TriggerServerEvent('gs-survival:server:finishSurvival', false)
                    TriggerEvent('gs-survival:client:stopEverything', false)
                elseif dist > (Config.Combat.BoundaryDistance - 20.0) then
                    if GetGameTimer() - lastWarningTime > 3000 then
                        QBCore.Functions.Notify("UYARI: Sınırdan çıkıyorsun!", "error", 3000)
                        lastWarningTime = GetGameTimer()
                    end
                end
            end

            -- UI VE DALGA YÖNETİMİ
            if not isEnding then
                local aliveCount = 0
                for _, v in pairs(spawnedPeds) do
                    if DoesEntityExist(v) and not IsPedDeadOrDying(v) then aliveCount = aliveCount + 1 end
                end

                local stageLabel = stageData and stageData.label or "Operasyon"
                local uiText = string.format("[ 🛡️ %s ]<br>", stageLabel:upper())
                
                -- [DÜZELTME]: Max Waves hesaplaması yeni stage yapısına göre güncellendi
                local maxWaves = 0
                local sId = activeStageId or 1
                if Config.Stages[sId] and Config.Stages[sId].Waves then
                    for k, v in pairs(Config.Stages[sId].Waves) do
                        maxWaves = maxWaves + 1
                    end
                end

                uiText = uiText .. string.format("🌊 Dalga: %s/%s<br>", currentWave, maxWaves)

                if waitingForWave then
                    local timerDisplay = countdown or 0
                    uiText = uiText .. string.format("⏳ Hazırlanıyor: %s sn", timerDisplay)
                else
                    uiText = uiText .. string.format("💀 Kalan Düşman: %s", aliveCount)
                end
                exports['qb-core']:DrawText(uiText, 'right')

                -- DALGA ATLATMA MANTIĞI
                if not waitingForWave and #spawnedPeds > 0 and aliveCount == 0 then
                    spawnedPeds = {}
                    -- [DÜZELTME]: Bir sonraki dalga kontrolü mevcut stage altındaki Waves tablosundan yapılıyor
                    if Config.Stages[sId] and Config.Stages[sId].Waves[currentWave + 1] then
                        currentWave = currentWave + 1
                        waitingForWave = true
                        exports.ox_lib:notify({
                            title = 'Sektör Temizlendi',
                            description = 'Yeni dalga için hazırlan!',
                            type = 'success',
                            position = 'top'
                        })
                        StartWaveCountdown()
                    else
                        isEnding = true
                        exports.ox_lib:notify({
                            title = 'Operasyon Başarılı',
                            description = 'Tüm dalgalar temizlendi! Ganimetleri topla.',
                            type = 'info',
                            position = 'top',
                            duration = 5000
                        })

                        Citizen.CreateThread(function()
                            local lootTimer = math.floor(Config.Combat.LootTime / 1000)
                            while lootTimer > 0 and isSurvivalActive do
                                exports['qb-core']:DrawText(string.format("💰 GANİMET TOPLAMA: %s sn", lootTimer), 'right')
                                Wait(1000)
                                lootTimer = lootTimer - 1
                            end
                            if isSurvivalActive then
                                isSurvivalActive = false
                                isEnding = false
                                exports['qb-core']:HideText()
                                SetEntityCoords(PlayerPedId(), Config.Npc.Coords.x, Config.Npc.Coords.y, Config.Npc.Coords.z)
                                TriggerServerEvent('gs-survival:server:finishSurvival', true)
                                TriggerEvent('gs-survival:client:stopEverything', true)
                            end
                        end)
                    end
                end
            end
        else
            sleep = 2000
            teleportLeeway = 0
            if not isSurvivalActive then exports['qb-core']:HideText() end
        end
        Wait(sleep)
    end
end)

-- Menüyü Açan Event
RegisterNetEvent('gs-survival:client:openCraftMenu', function()
    local craftMenu = {
        {
            header = "🛠️ Üretim Tezgahı",
            isMenuHeader = true,
        }
    }

    -- Mevcut tarifleri listeye ekliyoruz
    for _, recipe in ipairs(Config.CraftRecipes) do
        craftMenu[#craftMenu + 1] = recipe
    end

    -- Geri Dön / Kapat Butonu
    craftMenu[#craftMenu + 1] = {
        header = "⬅️ Geri Dön",
        txt = "Menüden çıkış yap veya önceki sayfaya dön",
        params = {
            event = "gs-survival:client:openMenu" -- Menüyü kapatır
            -- Eğer başka bir menüye dönmesini istiyorsan event adını buraya yazabilirsin.
        }
    }

    exports['qb-menu']:openMenu(craftMenu)
end)
RegisterCommand('survivalcraft', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    
    -- Başlangıç NPC'sinin koordinatlarını baz alıyoruz
    local dist = #(coords - vector3(Config.Npc.Coords.x, Config.Npc.Coords.y, Config.Npc.Coords.z))

    -- Eğer oyuncu NPC'ye 5 metreden yakınsa menü açılır
    if dist < 5.0 then
        TriggerEvent('gs-survival:client:openCraftMenu')
    else
        QBCore.Functions.Notify("Üretim tezgahını kullanmak için ana kampa gitmelisin!", "error")
    end
end, false) -- false: Herkes kullanabilir. Sadece admin istiyorsan true yapabilirsin.

-- Alternatif: Sadece test amaçlı, mesafe sınırı olmayan gizli komut
RegisterCommand('scraft_test', function()
    TriggerEvent('gs-survival:client:openCraftMenu')
end, true) -- true: Sadece adminler (ace permissions) kullanabilir

-- Üretim Süreci
RegisterNetEvent('gs-survival:client:craftItem', function(data)
    -- Önce sunucudan malzeme kontrolü yapıyoruz
    QBCore.Functions.TriggerCallback('gs-survival:server:hasCraftMaterials', function(hasMaterials)
        if hasMaterials then
            QBCore.Functions.Progressbar("crafting_item", data.label .. " Üretiliyor...", 5000, false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }, {
                animDict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@",
                anim = "machinic_loop_mechandplayer",
                flags = 16,
            }, {}, {}, function() -- Başarılı
                StopAnimTask(PlayerPedId(), "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", "machinic_loop_mechandplayer", 1.0)
                TriggerServerEvent('gs-survival:server:finishCrafting', data)
            end, function() -- İptal
                StopAnimTask(PlayerPedId(), "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", "machinic_loop_mechandplayer", 1.0)
                QBCore.Functions.Notify("Üretim iptal edildi.", "error")
            end)
        else
            QBCore.Functions.Notify("Yeterli malzemen yok!", "error")
        end
    end, data.requirements)
end)

RegisterNetEvent('gs-survival:client:deleteNPC', function(netId)

    local entity = NetToPed(netId)

   

    -- Eğer bu NPC'ye bağlı bir blip varsa önce onu sil

    if DoesEntityExist(entity) then

        local blip = GetBlipFromEntity(entity)

        if DoesBlipExist(blip) then

            RemoveBlip(blip)

        end

       

        -- NPC'yi sil

        DeleteEntity(entity)

    end

end)


-- [DALGA BAŞLATMA VE NPC KURULUM]
function StartWaveCountdown()
    waitingForWave = true
    countdown = Config.Combat.WaveWaitTime or 15

    Citizen.CreateThread(function()
        while countdown > 0 and (isSurvivalActive or notifiedDeath) do
            Wait(1000)
            countdown = countdown - 1
        end

        if isSurvivalActive and not notifiedDeath then
            waitingForWave = false
            
            -- [YENİ]: Yeni dalga başlamadan hemen önce yerdeki tüm eski cesetleri temizle
            TriggerEvent('gs-survival:client:clearWorldSpecial')
            
            -- Ardından yeni dalgayı spawn et
            TriggerServerEvent('gs-survival:server:spawnWave', myBucket, currentWave, activeStageId)
        end
    end)
end

RegisterNetEvent('gs-survival:client:initSurvival', function(bucket, wave, partyMembers, stageId)
    activeStageId = stageId or 1
    local stageData = Config.Stages[activeStageId]

    isSurvivalActive = true
    currentWave = wave or 1
    myBucket = bucket
    spawnedPeds = {}
    notifiedDeath = false
    isEnding = false
    activeSurvivalPlayers = partyMembers or {}

    DoScreenFadeOut(500)
    Wait(600)

    if DoesEntityExist(startPed) then
        SetEntityVisible(startPed, false, false)
        SetEntityCoords(startPed, Config.Npc.Coords.x, Config.Npc.Coords.y, Config.Npc.Coords.z - 100.0)
    end

    if stageData and stageData.center then
        SetEntityCoords(PlayerPedId(), stageData.center.x, stageData.center.y, stageData.center.z)
    else
        SetEntityCoords(PlayerPedId(), Config.Npc.Coords.x, Config.Npc.Coords.y, Config.Npc.Coords.z)
        print("^1HATA: Config.Stages["..activeStageId.."] merkezi bulunamadı!^7")
    end

    DoScreenFadeIn(500)
    StartWaveCountdown()
end)

RegisterNetEvent('gs-survival:client:setupNpc', function(npcNetId, multiplier)
    local timeout = 0
    while not NetworkDoesNetworkIdExist(npcNetId) and timeout < 100 do Wait(10) timeout = timeout + 1 end

    local npc = NetToPed(npcNetId)
    local stageMult = multiplier or 1.0

    if DoesEntityExist(npc) then
        table.insert(spawnedPeds, npc)
        SetEntityAsMissionEntity(npc, true, true)
        SetPedRelationshipGroupHash(npc, `HATES_PLAYER`)

        local newAccuracy = math.floor(Config.Combat.NpcAccuracy * stageMult)
        SetPedAccuracy(npc, newAccuracy)

        local newHealth = math.floor(200 * stageMult)
        SetEntityMaxHealth(npc, newHealth)
        SetEntityHealth(npc, newHealth)

        SetPedCombatAttributes(npc, 46, true)
        SetPedCombatAttributes(npc, 5, true)
        SetPedConfigFlag(npc, 184, true)

        local blip = AddBlipForEntity(npc)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, 1)
        SetBlipScale(blip, 0.7)
        TaskCombatPed(npc, PlayerPedId(), 0, 16)

        local stashTargetName = 'loot_' .. npcNetId
        exports.ox_target:addLocalEntity(npc, {
            {
                name = stashTargetName,
                icon = 'fas fa-hand-holding',
                label = 'Üstünü Ara',
                distance = 2.0,
                canInteract = function(entity) return IsPedDeadOrDying(entity) end,
                onSelect = function(data)
                    QBCore.Functions.TriggerCallback('gs-survival:server:checkLootStatus', function(canLoot)
                        if canLoot then
                            QBCore.Functions.Progressbar("search_npc", "Üstü Aranıyor...", 3000, false, true, {
                                disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true,
                            }, {
                                animDict = "amb@medic@standing@tendtodead@idle_a", anim = "idle_a", flags = 1,
                            }, {}, {}, function()
                                exports.ox_target:removeLocalEntity(data.entity, stashTargetName)
                                StopAnimTask(PlayerPedId(), "amb@medic@standing@tendtodead@idle_a", "idle_a", 1.0)
                                TriggerServerEvent('gs-survival:server:createNpcStash', npcNetId, currentWave)
                            end, function()
                                TriggerServerEvent('gs-survival:server:cancelLoot', npcNetId)
                                QBCore.Functions.Notify("İşlem iptal edildi!", "error")
                            end)
                        end
                    end, npcNetId)
                end
            }
        })
    end
end)

-- [ENVANTER KONTROLÜ]
CreateThread(function()
    while true do
        local sleep = 1000
        if isSurvivalActive then
            sleep = 5
            if LocalPlayer.state.invOpen and not Entity(PlayerPedId()).state.isLooting then
                exports.ox_inventory:closeInventory()
                QBCore.Functions.Notify("Savaş sırasında envanterini kullanamazsın!", "error")
            end
        end
        Wait(sleep)
    end
end)

-- [OYUN SONLANDIRMA]
RegisterNetEvent('gs-survival:client:stopEverything', function(isVictory)
    isSpectating = false
    StopSpectating()
    Wait(200)
    TriggerEvent('gs-survival:client:cleanupBeforeLeave')
    TriggerEvent('gs-survival:client:clearWorldSpecial')

    DoScreenFadeOut(500)
    Wait(600)

    if DoesEntityExist(startPed) then
        SetEntityVisible(startPed, true, false)
        SetEntityCoords(startPed, Config.Npc.Coords.x, Config.Npc.Coords.y, Config.Npc.Coords.z - 1.0)
    end

    exports['qb-core']:HideText()
    local ped = PlayerPedId()
    SetEntityCoords(ped, Config.Npc.Coords.x, Config.Npc.Coords.y, Config.Npc.Coords.z)
    SetEntityVisible(ped, true)
    FreezeEntityPosition(ped, false)

    Wait(500)
    DoScreenFadeIn(1000)
    QBCore.Functions.Notify(isVictory and "Operasyon Başarıyla Tamamlandı!" or "Operasyon Başarısız Oldu!", isVictory and "success" or "error")
end)

-- [DÜNYA TEMİZLİĞİ]
RegisterNetEvent('gs-survival:client:clearWorldSpecial', function()
    -- Sadece bu client'ın spawn ettiği/tablosuna giren pedleri temizler
    if spawnedPeds and #spawnedPeds > 0 then
        for i = #spawnedPeds, 1, -1 do
            local ped = spawnedPeds[i]
            if DoesEntityExist(ped) then
                -- Blip temizliği
                local blip = GetBlipFromEntity(ped)
                if DoesBlipExist(blip) then
                    RemoveBlip(blip)
                end
                
                -- NPC'yi dünyadan sil
                SetEntityAsMissionEntity(ped, true, true)
                DeleteEntity(ped)
            end
            table.remove(spawnedPeds, i)
        end
    end
    -- Tabloyu tamamen sıfırla
    spawnedPeds = {}
end)
-- [SPECTATE SİSTEMİ]
local spectateIndex, isSpectating, spectateCam = 1, false, nil
function StartSurvivalSpectate()
    if isSpectating then return end
    local function getLiving()
        local living = {}
        local myServerId = GetPlayerServerId(PlayerId())
        for _, id in ipairs(activeSurvivalPlayers) do
            if tonumber(id) ~= tonumber(myServerId) then
                local pIdx = GetPlayerFromServerId(id)
                if pIdx ~= -1 and NetworkIsPlayerActive(pIdx) then
                    local targetPed = GetPlayerPed(pIdx)
                    if DoesEntityExist(targetPed) and not IsPedFatallyInjured(targetPed) then
                        table.insert(living, pIdx)
                    end
                end
            end
        end
        return living
    end

    local initialMembers = getLiving()
    if #initialMembers == 0 then return end

    isSpectating = true
    Citizen.CreateThread(function()
        while isSpectating do
            local livingMembers = getLiving()
            if #livingMembers > 0 then
                if spectateIndex > #livingMembers then spectateIndex = 1 end
                local targetPed = GetPlayerPed(livingMembers[spectateIndex])

                if not spectateCam then 
                    spectateCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
                    RenderScriptCams(true, false, 0, true, true)
                end

                if DoesEntityExist(targetPed) then
                    local targetCoords = GetEntityCoords(targetPed)
                    local offset = GetOffsetFromEntityInWorldCoords(targetPed, 0.0, -3.5, 1.5)
                    SetCamCoord(spectateCam, offset.x, offset.y, offset.z)
                    PointCamAtEntity(spectateCam, targetPed, 0, 0, 0, true)
                end

                if IsControlJustPressed(0, 34) then
                    spectateIndex = spectateIndex - 1
                    if spectateIndex < 1 then spectateIndex = #livingMembers end
                elseif IsControlJustPressed(0, 35) then
                    spectateIndex = spectateIndex + 1
                    if spectateIndex > #livingMembers then spectateIndex = 1 end
                end
            else
                isSpectating = false
                StopSpectating()
                break
            end
            Wait(0)
        end
    end)
end

function StopSpectating()
    isSpectating = false
    RenderScriptCams(false, false, 0, true, true)
    if spectateCam then
        DestroyCam(spectateCam, true)
        spectateCam = nil
    end
    DestroyAllCams(true)
    local ped = PlayerPedId()
    SetEntityVisible(ped, true)
    FreezeEntityPosition(ped, false)
    SetFocusEntity(ped)
end

-- [LOOT SİSTEMİ]
RegisterNetEvent('gs-survival:client:openNpcStash', function(sId)
    Entity(PlayerPedId()).state:set('isLooting', true, true)
    exports.ox_inventory:openInventory('stash', sId)
    CreateThread(function()
        while LocalPlayer.state.invOpen do Wait(100) end
        Entity(PlayerPedId()).state:set('isLooting', false, true)
    end)
end)

RegisterNetEvent('gs-survival:client:removeFromInvited', function(targetId)
    for i=1, #invitedPlayers do
        if invitedPlayers[i] == targetId then
            table.remove(invitedPlayers, i)
            break
        end
    end
end)

-- [MENÜLER VE DAVET SİSTEMİ]
RegisterNetEvent('gs-survival:client:openMenu', function()
    QBCore.Functions.GetPlayerData(function(PlayerData)
        local userLevel = PlayerData.metadata["survival_level"] or 1
        local menu = { { header = "💀 South Side Survival", isMenuHeader = true } }

        -- [LOBİ ÜYELERİ] Hem lider hem üye görebilir
        if #invitedPlayers > 0 or LocalPlayer.state.inLobby then
            table.insert(menu, { 
                header = "📋 Mevcut Lobi Üyeleri", 
                txt = "Grubundaki savaşçıları görüntüle", 
                params = { event = "gs-survival:client:viewLobbyMembers" } 
            })
        end

        table.insert(menu, { header = "📍 Operasyon Bölgesi Seç", txt = "Seviye: " .. userLevel, params = { event = "gs-survival:client:stageMenu", args = { level = userLevel } } })
        table.insert(menu, { header = "🛒 Geliştirme Marketi", params = { event = "gs-survival:client:openMarket" } })
        table.insert(menu, { header = "🛠️ Craft Menüsü", params = { event = "gs-survival:client:openCraftMenu" } })

        -- [LOBİ KONTROLLERİ]
        if #invitedPlayers > 0 then -- LİDER
            table.insert(menu, { header = "➕ Arkadaşını Davet Et", params = { event = "gs-survival:client:inviteMenu" } })
            table.insert(menu, { header = "🚫 Lobiyi Dağıt", txt = "Grubu tamamen dağıtır", params = { event = "gs-survival:client:disbandLobby" } })
        elseif LocalPlayer.state.inLobby then -- ÜYE
            table.insert(menu, { header = "🏃 Lobiden Ayrıl", txt = "Gruptan tek başına çıkarsın", params = { event = "gs-survival:client:leaveLobby" } })
        else -- YALNIZ
            table.insert(menu, { header = "🤝 Arkadaşını Davet Et", params = { event = "gs-survival:client:inviteMenu" } })
        end

        exports['qb-menu']:openMenu(menu)
    end)
end)

-- Üyenin lideri tanıması için davet kabul eventini güncelle


-- Lobi Üyelerini Gösterme (Senkronize)


-- [LOBİ ÜYELERİ LİSTESİ]
RegisterNetEvent('gs-survival:client:viewLobbyMembers', function()
    local leaderId = #invitedPlayers > 0 and GetPlayerServerId(PlayerId()) or lobbyLeaderId

    QBCore.Functions.TriggerCallback('gs-survival:server:getLobbyMembers', function(members)
        local memberMenu = { { header = "👥 Mevcut Savaşçılar", isMenuHeader = true } }
        
        if members and #members > 0 then
            for _, m in ipairs(members) do
                table.insert(memberMenu, { 
                    header = "🎖️ " .. m.name, 
                    txt = "Oyuncu ID: " .. m.id .. (m.id == leaderId and " (Lider)" or ""), 
                    isMenuHeader = true 
                })
            end
        else
            table.insert(memberMenu, { header = "🏜️ Liste boş", isMenuHeader = true })
        end

        table.insert(memberMenu, { header = "⬅️ Geri Dön", params = { event = "gs-survival:client:openMenu" } })
        exports['qb-menu']:openMenu(memberMenu)
    end, leaderId)
end)



-- Lobi Üyelerini Görüntüleme
RegisterNetEvent('gs-survival:client:viewLobbyMembers', function()
    -- Eğer invitedPlayers doluysa biz liderizdir (kendi ID'miz), değilse lobbyLeaderId
    local leaderId = #invitedPlayers > 0 and GetPlayerServerId(PlayerId()) or lobbyLeaderId

    QBCore.Functions.TriggerCallback('gs-survival:server:getLobbyMembers', function(members)
        local memberMenu = { { header = "👥 Mevcut Savaşçılar", isMenuHeader = true } }
        
        if #members > 0 then
            for _, m in ipairs(members) do
                table.insert(memberMenu, { header = "🎖️ " .. m.name, txt = "Oyuncu ID: " .. m.id, isMenuHeader = true })
            end
        else
            table.insert(memberMenu, { header = "🏜️ Lobi Boş", txt = "Listelenecek kimse yok.", isMenuHeader = true })
        end

        table.insert(memberMenu, { header = "⬅️ Geri Dön", params = { event = "gs-survival:client:openMenu" } })
        exports['qb-menu']:openMenu(memberMenu)
    end, leaderId)
end)

-- Lobiden Ayrılma Butonu Eventi
RegisterNetEvent('gs-survival:client:leaveLobby', function()
    TriggerServerEvent('gs-survival:server:leaveLobby', lobbyLeaderId)
    LocalPlayer.state:set('inLobby', false, true)
    lobbyLeaderId = nil
    QBCore.Functions.Notify("Lobiden ayrıldın.", "error")
end)

-- Lobi Dağıtma Butonu Eventi
RegisterNetEvent('gs-survival:client:disbandLobby', function()
    TriggerServerEvent('gs-survival:server:disbandLobby')
    invitedPlayers = {}
    QBCore.Functions.Notify("Lobi dağıtıldı.", "error")
end)

-- Daveti kabul ettiğinde üye durumunu aktif et
-- Mevcut acceptInvite eventinin içine "inLobbyAsMember = true" ekle

-- [STAGE MENÜLERİ]
RegisterNetEvent('gs-survival:client:stageMenu', function(data)
    local userLevel = data.level
    local stageMenu = {
        { header = "Operasyon Bölgeleri", isMenuHeader = true },
    }

    for stageId, stageData in ipairs(Config.Stages) do
        local isLocked = stageId > userLevel
        local stageLabel = stageData.label or ("Bölüm " .. stageId)
        table.insert(stageMenu, {
            header = (isLocked and "🔒 " or "📍 ") .. stageLabel,
            txt = isLocked and "Bu bölge henüz kilitli!" or "Zorluk: x" .. (stageData.multiplier or 1.0),
            disabled = isLocked,
            params = {
                event = "gs-survival:client:startFinal",
                args = { stageId = stageId }
            }
        })
    end
  
    table.insert(stageMenu, { header = "Geri Dön", params = { event = "gs-survival:client:openMenu" } })
    exports['qb-menu']:openMenu(stageMenu)
end)

-- [DAVET MENÜSÜ]
RegisterNetEvent('gs-survival:client:inviteMenu', function()
    local players = {}
    local activePlayers = GetActivePlayers()
    local playerPos = GetEntityCoords(PlayerPedId())
    for _, player in ipairs(activePlayers) do
        local targetPed = GetPlayerPed(player)
        if #(playerPos - GetEntityCoords(targetPed)) < 15.0 then
            table.insert(players, GetPlayerServerId(player))
        end
    end

    if #invitedPlayers >= 4 then 
        QBCore.Functions.Notify("Lobi zaten dolu! (Maksimum 4 kişi)", "error")
        return 
    end

    QBCore.Functions.TriggerCallback('gs-survival:server:getNearbyPlayers', function(nearbyPlayers)
        local menu = {{ header = "Yakındaki Oyuncular", isMenuHeader = true }}
        local found = false
        
        if nearbyPlayers then
            for _, v in pairs(nearbyPlayers) do
                if v.id ~= GetPlayerServerId(PlayerId()) then
                    found = true
                    table.insert(menu, { 
                        header = v.name, 
                        txt = "ID: "..v.id, 
                        params = { isServer = true, event = "gs-survival:server:sendInvite", args = v.id } 
                    })
                end
            end
        end

        if not found then 
            table.insert(menu, { header = "Kimse yok", txt = "Arkadaşın uzakta.", disabled = true }) 
        end

        -- Geri Dön Butonu (Callback içindeki listenin sonuna ekliyoruz)
        table.insert(menu, {
            header = "⬅️ Geri Dön",
            txt = "Ana Menüye Dön",
            params = {
                event = "gs-survival:client:openMenu" -- Geri dönmek istediğin event
            }
        })

        exports['qb-menu']:openMenu(menu)
    end, players)
end)

RegisterNetEvent('gs-survival:client:receiveInvite', function(leaderId)
    local inviteMenu = {
        { header = "📩 Operasyon Daveti", isMenuHeader = true },
        { 
            header = "✅ Kabul Et", 
            txt = "Savaşa katılmak istiyor musun?", 
            params = { 
                event = "gs-survival:client:acceptInvite", 
                args = { leaderId = leaderId } 
            } 
        },
        { 
            header = "❌ Reddet", 
            params = { event = "gs-survival:client:denyInvite" } 
        }
    }
    exports['qb-menu']:openMenu(inviteMenu)
end)

RegisterNetEvent('gs-survival:client:acceptInvite', function(data)
    lobbyLeaderId = data.leaderId
    LocalPlayer.state:set('inLobby', true, true)
    TriggerServerEvent('gs-survival:server:confirmInvite', data.leaderId)
    QBCore.Functions.Notify("Lobiye katıldın!", "success")
end)

RegisterNetEvent('gs-survival:client:denyInvite', function()
    QBCore.Functions.Notify("Daveti reddettin.", "error")
    -- Lider tarafına bildirim göndermek istersen buraya bir server event ekleyebiliriz
end)

RegisterNetEvent('gs-survival:client:addInvited', function(playerId)
    local alreadyIn = false
    for _, id in pairs(invitedPlayers) do
        if id == playerId then alreadyIn = true break end
    end

    if not alreadyIn then
        table.insert(invitedPlayers, playerId)
        QBCore.Functions.Notify("Yeni bir savaşçı lobiye katıldı!", "success")
    else
        QBCore.Functions.Notify("Zaten bir lobide!", "error")
    end
end)

-- [SURVIVAL BAŞLATMA]
RegisterNetEvent('gs-survival:client:startFinal', function(data)
    local selectedStage = data and data.stageId or 1
    activeStageId = selectedStage
    TriggerServerEvent('gs-survival:server:startSurvival', invitedPlayers, selectedStage)
    -- invitedPlayers = {}
end)