local QBCore = exports['qb-core']:GetCoreObject()
local groupSizes, groupMembers, playerBackups = {}, {}, {}
local createdStashes, beingLooted = {}, {} 
local lobbyStage = {}
local activeLobbies = {}
local lootItemSet = {}
local finishingPlayers = {}

local function BuildLootItemSet()
    lootItemSet = {}
    if Config and Config.LootTable then
        for _, loot in ipairs(Config.LootTable) do
            lootItemSet[loot.item] = true
        end
    end
end

BuildLootItemSet()

-- [Davetler]
RegisterNetEvent('gs-survival:server:sendInvite', function(tId) TriggerClientEvent('gs-survival:client:receiveInvite', tId, source) end)

AddEventHandler('ox_inventory:onItemDropped', function(source, inventory, slot, item)
    -- Eğer yere atılan eşyanın metadatasında 'survivalItem' varsa
    if item.metadata and item.metadata.survivalItem then
        -- Eşyayı yerden (drop'tan) anında sil, kimse alamasın
        exports.ox_inventory:RemoveItem(inventory, item.name, item.count, item.metadata, slot)
        TriggerClientEvent('QBCore:Functions:Notify', source, "Survival eşyalarını yere atamazsın, eşya imha edildi!", "error")
    end
end)

local function CleanBucketEntities(bucketId)
    if not bucketId or bucketId == 0 then return end
    
    -- NPC'leri temizle
    local peds = GetAllPeds()
    for _, entity in ipairs(peds) do
        if GetEntityRoutingBucket(entity) == bucketId and not IsPedAPlayer(entity) then 
            DeleteEntity(entity) 
        end
    end

    -- Yerde kalan objeleri temizle
    local objects = GetAllObjects()
    for _, entity in ipairs(objects) do
        if GetEntityRoutingBucket(entity) == bucketId then 
            DeleteEntity(entity) 
        end
    end
end



-- [Başlatma]
RegisterNetEvent('gs-survival:server:startSurvival', function(invited, stageId)
    local src = source
    local peps = {src}
    
    -- [MESAFE KONTROLÜ]
    if invited then
        for _, id in pairs(invited) do
            local tPed = GetPlayerPed(id)
            if tPed ~= 0 and #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(tPed)) < 10.0 then 
                table.insert(peps, id) 
            else
                TriggerClientEvent('QBCore:Functions:Notify', src, "Arkadaşların çok uzakta!", "error")
                return 
            end
        end
    end

    local sId = stageId or 1 
    local bId = math.random(10000, 99999)
    
    -- [EKLEME]: Lobi verilerini ve Stage ID'yi kaydet (Düşmanların doğması için şart)
    groupSizes[bId] = #peps
    groupMembers[bId] = peps
    lobbyStage[bId] = sId 

    -- [EKLEME]: Seçilen bölümün verilerini çek
    local stageData = Config.Stages[sId]

    for _, id in pairs(peps) do
        local Player = QBCore.Functions.GetPlayer(id)
        if Player then
            local cid = Player.PlayerData.citizenid

            -- [ENVANTER YEDEKLEME]
            -- In_survival flag'ini en başta kaydet: crash olsa bile DB'de kalır
            Player.Functions.SetMetaData("in_survival", true)
            Player.Functions.Save()

            local stashId = 'surv_backup_' .. cid
            exports.ox_inventory:RegisterStash(stashId, "Survival Yedek", 50, 100000)
            exports.ox_inventory:ClearInventory(stashId)

            if not playerBackups[cid] then
                playerBackups[cid] = {}
                local items = exports.ox_inventory:GetInventoryItems(id)
                if items then 
                    for _, i in pairs(items) do 
                        table.insert(playerBackups[cid], {name=i.name, count=i.count, metadata=i.metadata})
                        exports.ox_inventory:AddItem(stashId, i.name, i.count, i.metadata)
                    end 
                end
            end

            -- [TEMİZLİK]
            exports.ox_inventory:ClearInventory(id)
            Wait(250)

            -- [1. KISIM: VARSAYILAN KİT EŞYALARI]
            if Config.Combat.DefaultItems then
                for _, data in ipairs(Config.Combat.DefaultItems) do
                    exports.ox_inventory:AddItem(id, data.item, data.count, { survivalItem = true })
                end
            end

            -- [2. KISIM: SİLAH VE MERMİ AYARI]
            local starterWeapon = Player.PlayerData.metadata['survival_weapon'] or Config.Combat.DefaultWeapon or "weapon_pistol"
            local ammoType = Config.Combat.DefaultAmmo or "ammo-9"
            local ammoCount = Config.Combat.DefaultAmmoAmount or 100

            for k, v in pairs(Config.Upgrades) do
                if v.value == starterWeapon and v.ammoType then
                    ammoType = v.ammoType
                    ammoCount = v.ammoAmount or ammoCount
                    break
                end
            end
            
            exports.ox_inventory:AddItem(id, starterWeapon, 1, { survivalItem = true })
            exports.ox_inventory:AddItem(id, ammoType, ammoCount, { survivalItem = true })

            -- [3. KISIM: ZIRH]
            local armorVal = Player.PlayerData.metadata['survival_armor'] or 0
            if armorVal > 0 then
                TriggerClientEvent('gs-survival:client:setArmor', id, armorVal)
            end
            
            -- [SİSTEMİ BAŞLAT]
            SetPlayerRoutingBucket(id, bId)
            
            -- [EKLEME]: Oyuncuyu yeni Stage'in merkezine ışınla
            if stageData and stageData.center then
                SetEntityCoords(GetPlayerPed(id), stageData.center.x, stageData.center.y, stageData.center.z)
            end

            TriggerClientEvent('hospital:client:Revive', id)
            TriggerClientEvent('gs-survival:client:initSurvival', id, bId, 1, peps, sId)
        end
    end
end)

RegisterNetEvent('gs-survival:server:spawnWave', function(bId, wave, stageId)
    -- [GÜNCELLEME]: Lobi stage bilgisini çek ve stageData'nın varlığını garantile
    local sId = (lobbyStage and lobbyStage[bId]) or stageId or 1
    local stageData = Config.Stages[sId]
    
    -- Eğer stageData bulunamazsa Stage 1'i baz al ki sistem çökmesin
    if not stageData then 
        stageData = Config.Stages[1] 
    end

    -- [EKLEME]: Önce stage içindeki dalgaya bak, yoksa genel dalga listesine bak
    local cfg = (stageData.Waves and stageData.Waves[wave]) or Config.Waves[wave]
    
    if not cfg or not groupMembers[bId] then return end

    local multiplier = stageData and stageData.multiplier or 1.0
    
    -- [GÜNCELLEME]: Spawn noktalarını öncelikle stageData'dan al
    local spawnPoints = (stageData and stageData.spawnPoints) or Config.SpawnPoints

    -- Config'deki npcCountPerPlayer her bir spawn noktasında doğacak sayı olsun
    local countPerPoint = cfg.npcCount or 1 

    for _, pos in pairs(spawnPoints) do 
        for i = 1, countPerPoint do
            Wait(150) -- Sunucuyu yormamak için kısa bir bekleme
            
            local npc = CreatePed(4, cfg.pedModel, pos.x + math.random(-2,2), pos.y + math.random(-2,2), pos.z, 0.0, true, true)
            
            -- Entity oluşana kadar bekle
            local timeout = 0
            while not DoesEntityExist(npc) and timeout < 100 do 
                Wait(10) 
                timeout = timeout + 1
            end
            
            if DoesEntityExist(npc) then
                SetEntityRoutingBucket(npc, bId)
                
                -- Köpek Dalgası Kontrolü
                if not cfg.isDogWave then 
                    GiveWeaponToPed(npc, GetHashKey(cfg.weapon or "weapon_pistol"), 999, false, true)
                    -- Oyunculara saldırması için (rastgele bir grup üyesini hedef alır)
                    local randomTarget = groupMembers[bId][math.random(1, #groupMembers[bId])]
                    TaskCombatPed(npc, GetPlayerPed(randomTarget), 0, 16)
                else 
                    -- Köpekler için saldırı komutu
                    local randomTarget = groupMembers[bId][math.random(1, #groupMembers[bId])]
                    TaskCombatPed(npc, GetPlayerPed(randomTarget), 0, 16) 
                end
                
                -- Client tarafında Blip ve Target ayarları için gönder
                for _, pId in pairs(groupMembers[bId]) do 
                    -- Multiplier (zorluk çarpanı) parametre olarak eklendi
                    TriggerClientEvent('gs-survival:client:setupNpc', pId, NetworkGetNetworkIdFromEntity(npc), multiplier) 
                end
            end
        end
    end
end)

QBCore.Functions.CreateCallback('gs-survival:server:hasCraftMaterials', function(source, cb, requirements)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end
    
    local hasAll = true
    for _, req in pairs(requirements) do
        local item = Player.Functions.GetItemByName(req.item)
        if not item or item.amount < req.amount then
            hasAll = false
            break
        end
    end
    cb(hasAll)
end)



-- Davet Onaylandığında Lobiyi Kaydet
RegisterNetEvent('gs-survival:server:confirmInvite', function(leaderId)
    local src = source
    local leader = QBCore.Functions.GetPlayer(leaderId)
    local member = QBCore.Functions.GetPlayer(src)

    if src == leaderId then return end
    
    if leader and member then
        -- Eğer bu liderin henüz bir lobisi yoksa oluştur
        if not activeLobbies[leaderId] then
            activeLobbies[leaderId] = { 
                leaderName = leader.PlayerData.charinfo.firstname .. " " .. leader.PlayerData.charinfo.lastname,
                members = {} 
            }
        end
        
        -- Üyeyi lobiye ekle
        activeLobbies[leaderId].members[src] = member.PlayerData.charinfo.firstname .. " " .. member.PlayerData.charinfo.lastname
        
        -- Diğer tarafa (lidere) oyuncunun eklendiğini bildir
        TriggerClientEvent('gs-survival:client:addInvited', leaderId, src)
        TriggerClientEvent('QBCore:Functions:Notify', leaderId, member.PlayerData.charinfo.firstname .. " lobiye katıldı!", "success")
        TriggerClientEvent('QBCore:Functions:Notify', src, "Lobiye katıldın!", "success")
    end
end)

-- Lobi Üyelerini Çekme (Hem Lider hem Üye için)
QBCore.Functions.CreateCallback('gs-survival:server:getLobbyMembers', function(source, cb, leaderId)
    local lobby = activeLobbies[leaderId]
    local memberList = {}
    
    if lobby then
        -- Önce Lideri Ekle
        table.insert(memberList, { id = leaderId, name = lobby.leaderName .. " (Lider)" })
        -- Sonra Diğer Üyeleri Ekle
        for id, name in pairs(lobby.members) do
            table.insert(memberList, { id = id, name = name })
        end
    end
    cb(memberList)
end)

-- Lobi Dağıtma
RegisterNetEvent('gs-survival:server:disbandLobby', function()
    local src = source
    if activeLobbies[src] then
        for memberId, _ in pairs(activeLobbies[src].members) do
            TriggerClientEvent('gs-survival:client:forceLeaveLobby', memberId)
        end
        activeLobbies[src] = nil
    end
end)

-- Lobiden Ayrılma (Üye İçin)
RegisterNetEvent('gs-survival:server:leaveLobby', function(leaderId)
    local src = source
    if activeLobbies[leaderId] and activeLobbies[leaderId].members[src] then
        activeLobbies[leaderId].members[src] = nil
        TriggerClientEvent('QBCore:Functions:Notify', leaderId, "Bir üye lobiden ayrıldı.", "error")
    end
end)

-- Malzemeleri Sil ve Eşyayı Ver
RegisterNetEvent('gs-survival:server:finishCrafting', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Güvenlik için son bir kontrol daha
    local canCraft = true
    for _, req in pairs(data.requirements) do
        local item = Player.Functions.GetItemByName(req.item)
        if not item or item.amount < req.amount then canCraft = false break end
    end

    if canCraft then
        for _, req in pairs(data.requirements) do
            Player.Functions.RemoveItem(req.item, req.amount)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[req.item], "remove")
        end
        Player.Functions.AddItem(data.item, data.amount)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[data.item], "add")
        TriggerClientEvent('QBCore:Functions:Notify', src, data.label .. " üretildi!", "success")
    end
end)

RegisterServerEvent('gs-survival:server:buyUpgrade')
AddEventHandler('gs-survival:server:buyUpgrade', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local upgradeId = data.type -- Config'deki anahtar (armor veya weapon)
    local upgradeData = Config.Upgrades[upgradeId]

    -- [GÜVENLİK]: Config'de böyle bir ürün var mı?
    if not upgradeData then 
        print("^1[HATA]^7 Gecersiz market urunu: " .. tostring(upgradeId))
        return 
    end

    local cid = Player.PlayerData.citizenid
    local price = upgradeData.price
    local value = upgradeData.value
    local metaName = upgradeData.metadataName
    local sqlCol = upgradeData.sqlColumn

    -- [SAHİPLİK KONTROLÜ]: Zaten sahip mi?
    local currentUpgrade = Player.PlayerData.metadata[metaName]
    if currentUpgrade == value then
        return TriggerClientEvent('ox_lib:notify', src, { 
            title = 'Survival Market', 
            description = 'Zaten bu geliştirmeye sahipsin!', 
            type = 'error' 
        })
    end

    -- [ÖDEME VE KAYIT]
    if Player.Functions.RemoveMoney('cash', price, "survival-upgrade") or Player.Functions.RemoveMoney('bank', price, "survival-upgrade") then
        
        -- 1. RAM Güncelle (Metadata)
        Player.Functions.SetMetaData(metaName, value)
        
        -- 2. SQL Güncelle (oxmysql)
        local query = string.format('UPDATE players SET %s = ? WHERE citizenid = ?', sqlCol)
        exports.oxmysql:update(query, {value, cid}, function(affectedRows)
            if affectedRows > 0 then
                print(string.format("^2[SUCCESS]^7 %s guncellendi: %s", metaName, cid))
            end
        end)
        
        Player.Functions.Save() 

        TriggerClientEvent('ox_lib:notify', src, { 
            title = 'Survival Market', 
            description = upgradeData.label .. ' satın alındı!', 
            type = 'success' 
        })
    else
        TriggerClientEvent('ox_lib:notify', src, { 
            title = 'Survival Market', 
            description = 'Yeterli paran yok! Gereken: $' .. price, 
            type = 'error' 
        })
    end
end)
-- [Bitiş ve Geri Yükleme]
RegisterNetEvent('gs-survival:server:finishSurvival', function(isVictory)
    local src = source
    -- Aynı oyuncu için çift tetiklenmeyi önle
    if finishingPlayers[src] then return end
    finishingPlayers[src] = true
    Citizen.SetTimeout(5000, function() finishingPlayers[src] = nil end)

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then finishingPlayers[src] = nil return end 

    local bucketId = GetPlayerRoutingBucket(src)
    local isActuallyDead = false
    if Player.PlayerData and Player.PlayerData.metadata then
       isActuallyDead = Player.PlayerData.metadata["isdead"] or Player.PlayerData.metadata["inlaststand"]
    end
    
    local status = isVictory
    if isActuallyDead then status = false end

    local function RestorePlayer(targetId, victoryStatus)
        local TPlayer = QBCore.Functions.GetPlayer(targetId)
        if not TPlayer then return end
        local cid = TPlayer.PlayerData.citizenid

        -- In_survival flag'ini hemen temizle
        TPlayer.Functions.SetMetaData("in_survival", false)
        TPlayer.Functions.Save()

        TriggerClientEvent('gs-survival:client:cleanupBeforeLeave', targetId) 
        TriggerClientEvent('ox_inventory:disarm', targetId) 
        
        local currentInv = exports.ox_inventory:GetInventoryItems(targetId)
        local itemsToKeep = {}
        
        if victoryStatus and currentInv then
            for _, item in pairs(currentInv) do
                if lootItemSet[item.name] or (Config.SpecialLootItems and Config.SpecialLootItems[item.name]) then
                    table.insert(itemsToKeep, {name = item.name, count = item.count, metadata = item.metadata})
                end
            end
        end

        exports.ox_inventory:ClearInventory(targetId)
        Wait(600)
        SetPlayerRoutingBucket(targetId, 0)
        Wait(200)

        if playerBackups[cid] then
            for _, item in pairs(playerBackups[cid]) do
                exports.ox_inventory:AddItem(targetId, item.name, item.count, item.metadata)
            end
            playerBackups[cid] = nil 
        end
        -- Stash'i her zaman temizle (playerBackups olsun ya da olmasın)
        exports.ox_inventory:ClearInventory('surv_backup_' .. cid)

        if #itemsToKeep > 0 then
            for _, loot in pairs(itemsToKeep) do
                exports.ox_inventory:AddItem(targetId, loot.name, loot.count, loot.metadata)
            end
        end
    end

    if isActuallyDead then
        local allDead = true
        if groupMembers[bucketId] then
            for _, playerId in ipairs(groupMembers[bucketId]) do
                local pData = QBCore.Functions.GetPlayer(playerId)
                if pData and pData.PlayerData and pData.PlayerData.metadata then
                    if not (pData.PlayerData.metadata["isdead"] or pData.PlayerData.metadata["inlaststand"]) then
                        allDead = false
                        break 
                    end
                end
            end
        end

        if allDead then
            CleanBucketEntities(bucketId)
            if groupMembers[bucketId] then
                for _, playerId in ipairs(groupMembers[bucketId]) do
                    RestorePlayer(playerId, false) 
                    TriggerClientEvent('gs-survival:client:stopEverything', playerId, false)
                end
            end
            groupMembers[bucketId] = nil
            lobbyStage[bucketId] = nil -- [EKLENDİ]: Lobi bittiği için stage verisini temizle
            createdStashes = {}
            beingLooted = {}
        end
    elseif status then
        -- [DURUM 3]: ZAFER DURUMU
        local isLastPerson = false
        if not groupMembers[bucketId] or #groupMembers[bucketId] <= 1 then 
            CleanBucketEntities(bucketId)
            isLastPerson = true
        end

        -- [DÜZELTME]: Seviye Atlatma ve SQL Kaydı
        local playedStage = lobbyStage[bucketId] or 1
        local currentLevel = Player.PlayerData.metadata["survival_level"] or 1

        if playedStage == currentLevel then
            local nextLevel = currentLevel + 1
            Player.Functions.SetMetaData("survival_level", nextLevel)
    
            -- BURASI EKLENDİ: Metadata ile yetinmeyip direkt DB'ye yazıyoruz
            exports.oxmysql:update('UPDATE players SET survival_level = ? WHERE citizenid = ?', {nextLevel, Player.PlayerData.citizenid})
            Player.Functions.Save() 
        end

        RestorePlayer(src, true)
        TriggerClientEvent('gs-survival:client:stopEverything', src, true)
        
        if groupMembers[bucketId] then
            for i, id in ipairs(groupMembers[bucketId]) do
                if id == src then table.remove(groupMembers[bucketId], i) break end
            end
        end

        if isLastPerson then
            lobbyStage[bucketId] = nil -- [EKLENDİ]: Son kişi çıktığında tabloyu temizle
            createdStashes = {}
            beingLooted = {}
        end
    else
        -- [DURUM 4]: ALANDAN KAÇMA VEYA DİĞER DURUMLAR
        local isLastPerson = false
        if not groupMembers[bucketId] or #groupMembers[bucketId] <= 1 then 
            CleanBucketEntities(bucketId)
            isLastPerson = true
        end

        RestorePlayer(src, false)
        TriggerClientEvent('gs-survival:client:stopEverything', src, false)

        if groupMembers[bucketId] then
            for i, id in ipairs(groupMembers[bucketId]) do
                if id == src then table.remove(groupMembers[bucketId], i) break end
            end
        end

        if isLastPerson then
            lobbyStage[bucketId] = nil -- [EKLENDİ]: Son kişi çıktığında tabloyu temizle
            createdStashes = {}
            beingLooted = {}
        end
    end
end)

-- [OYUNDAN ÇIKTIĞINDA]
AddEventHandler('playerDropped', function(reason)
    local src = source

    -- 1. [LOBİ TEMİZLİĞİ] (Maç başlamadan önceki lobi aşaması için)
    -- Eğer bu kişi bir liderin davetli listesindeyse onu sil
    for leaderId, data in pairs(activeLobbies) do
        if data.members and data.members[src] then
            data.members[src] = nil
            -- Lidere arkadaşının çıktığını haber ver
            TriggerClientEvent('QBCore:Functions:Notify', leaderId, "Bir grup üyesi sunucudan ayrıldı.", "error")
            -- Liderin ekranındaki (invitedPlayers) listesini güncelle
            TriggerClientEvent('gs-survival:client:removeFromInvited', leaderId, src)
            break
        end
    end

    -- 2. [MAÇ TEMİZLİĞİ] (Senin mevcut bucket mantığın)
    local bucketId = GetPlayerRoutingBucket(src)
    if bucketId ~= 0 and groupMembers and groupMembers[bucketId] then
        for i, id in ipairs(groupMembers[bucketId]) do
            if id == src then 
                table.remove(groupMembers[bucketId], i) 
                break 
            end
        end
        
        -- Eğer odada kimse kalmadıysa dünyayı temizle
        if #groupMembers[bucketId] == 0 then
            CleanBucketEntities(bucketId)
            groupMembers[bucketId] = nil
        end
    end
end)
-- [TEKRAR GİRDİĞİNDE EŞYALARI GERİ VERME]
QBCore.Functions.CreateCallback('gs-survival:server:checkReconnectBackup', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb(false) end
    
    local cid = Player.PlayerData.citizenid
    local stashId = 'surv_backup_' .. cid
    
    -- Stash'i kayıt et ve mevcut içeriğini kontrol et
    exports.ox_inventory:RegisterStash(stashId, "Survival Yedek", 50, 100000)
    local items = exports.ox_inventory:GetInventoryItems(stashId)
    
    -- in_survival flag'i false/nil ise bu oyuncu gerçekten survival'da değildi
    local inSurvival = Player.PlayerData.metadata["in_survival"]
    if not inSurvival then
        -- Stash'te arta kalan eşya varsa sessizce temizle, bildirim gösterme
        if items and next(items) then
            exports.ox_inventory:ClearInventory(stashId)
        end
        if playerBackups[cid] then playerBackups[cid] = nil end
        return cb(false)
    end

    -- Oyuncu gerçekten survival'daydı (in_survival = true): yedekten geri yükle
    if (items and next(items)) or (playerBackups[cid] and #playerBackups[cid] > 0) then
        -- KRİTİK: Önce survival'dan kalan silahları/mermileri temizle
        exports.ox_inventory:ClearInventory(src)
        Wait(1000) -- Envanterin silindiğinden emin olmak için bekle
        
        -- Eğer veritabanında (Stash) eşya varsa oradan ver (Restart sonrası durum)
        if items and next(items) then
            for _, item in pairs(items) do
                exports.ox_inventory:AddItem(src, item.name, item.count, item.metadata)
            end
        -- Eğer RAM'de varsa oradan ver (Normal reconnect durumu)
        elseif playerBackups[cid] then
            for _, item in pairs(playerBackups[cid]) do
                exports.ox_inventory:AddItem(src, item.name, item.count, item.metadata)
            end
        end

        -- Her iki durumda da RAM ve stash'i temizle
        playerBackups[cid] = nil
        exports.ox_inventory:ClearInventory(stashId)

        -- in_survival flag'ini de sıfırla
        Player.Functions.SetMetaData("in_survival", false)
        Player.Functions.Save()

        cb(true)
    else
        -- Flag true ama ne stash'te ne RAM'de eşya var: güvenlik olarak flag'i sıfırla
        Player.Functions.SetMetaData("in_survival", false)
        Player.Functions.Save()
        cb(false)
    end
end)

-- [NPC LOOT SİSTEMİ]
RegisterNetEvent('gs-survival:server:createNpcStash', function(npcNetId, currentWave) -- currentWave parametresini ekledik
    local src = source
    local wave = currentWave or 1 -- Eğer dalga bilgisi gelmezse varsayılan 1 yap
    local stashId = "surv_" .. npcNetId .. "_" .. math.random(1111, 9999) 
    
    beingLooted[npcNetId] = nil

    -- [DÜZENLEME]: Artık Config.Loot üzerinden değil, Config.LootTable üzerinden dönüyor
    -- 1. Stash'i oluştur
    exports.ox_inventory:RegisterStash(stashId, "Düşman Üzeri", 10, 5000) 
    
    -- 2. Eşyaları ekle (Kısa bir beklemeyle)
    Wait(150)
    
    -- Dalga arttıkça genel şansı biraz artıran çarpan (Stratejik derinlik için)
    local luckMultiplier = 1.0 + (wave * 0.05) 
    local possibleLoot = {}

    for _, loot in ipairs(Config.LootTable) do
        -- SADECE dalga şartı tutuyorsa veya dalga şartı hiç yoksa item düşebilir
        if not loot.minWave or wave >= loot.minWave then
            local roll = math.random(1, 100)
            -- Şans kontrolü (Dalga çarpanı ile)
            if roll <= (loot.chance * luckMultiplier) then
                local amount = math.random(loot.min, loot.max)
                exports.ox_inventory:AddItem(stashId, loot.item, amount)
                table.insert(possibleLoot, loot.item)
            end
        end
    end

    -- Eğer şanssızlıktan hiçbir şey çıkmadıysa boş kalmasın diye ufak bir para ekle
    if #possibleLoot == 0 then
        exports.ox_inventory:AddItem(stashId, "money", math.random(50, 150))
    end
    
    -- 3. ÖNCE Client'a envanteri aç komutu gönder
    TriggerClientEvent('gs-survival:client:openNpcStash', src, stashId)
    
    -- 4. HEMEN ARDINDAN NPC'yi ve Blip'i silmesi için client'ı tetikle
    TriggerClientEvent('gs-survival:client:deleteNPC', -1, npcNetId)
end)

-- [DOKUNULMAYAN DİĞER KODLAR]

QBCore.Functions.CreateCallback('gs-survival:server:checkLootStatus', function(source, cb, npcNetId)
    if beingLooted[npcNetId] then
        -- Eğer bu NPC zaten birisi tarafından aranıyorsa
        TriggerClientEvent('QBCore:Notify', source, "Bu ceset zaten başkası tarafından aranıyor!", "error")
        cb(false)
    else
        -- Kimse aramıyorsa, arayan kişi olarak kaydet
        beingLooted[npcNetId] = source
        cb(true)
    end
end)


RegisterNetEvent('gs-survival:server:cancelLoot', function(npcNetId)
    beingLooted[npcNetId] = nil
end)

QBCore.Functions.CreateCallback('gs-survival:server:getNearbyPlayers', function(s, cb, list)
    local nearby = {}
    for _, v in pairs(list) do
        local p = QBCore.Functions.GetPlayer(v)
        if p then table.insert(nearby, {id = v, name = p.PlayerData.charinfo.firstname .. " " .. p.PlayerData.charinfo.lastname}) end
    end
    cb(nearby)
end)

RegisterNetEvent('gs-survival:server:giveStarterItems', function(weaponName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local hasWeaponUpgrade = Player.PlayerData.metadata['survival_weapon'] or "weapon_pistol"
    
    -- Hile kontrolü ve eşya verme
    if hasWeaponUpgrade == weaponName then
        exports.ox_inventory:AddItem(src, weaponName, 1, { survivalItem = true })
        exports.ox_inventory:AddItem(src, "ammo-9", 100, { survivalItem = true })
    end
end)
