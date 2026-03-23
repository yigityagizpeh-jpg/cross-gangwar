Config = {}

-- [GENEL AYARLAR]
Config.LobbyDistance = 20.0 

-- [KORUNACAK EŞYALAR]
Config.SpecialLootItems = { 
    ["ammo-9"] = true,
    ["scrapmetal"] = true,
    ["metalscrap"] = true,
    ["rubber"] = true,
    ["cloth"] = true,
    ["gunpowder"] = true,
    ["electronics"] = true,
    ["weapon_core"] = true,
    ["medkit"] = true,
    ["ifaks"] = true
}
Config.CraftRecipes = {
    {
        header = "9mm Mermi Paketi",
        txt = "Gereksinim: 10 Metal Parçası, 5 Barut",
        icon = "fas fa-box-open",
        params = {
            event = "gs-survival:client:craftItem",
            args = {
                item = "ammo-9",
                amount = 30,
                label = "9mm Mermi Paketi",
                requirements = {
                    { item = "metalscrap", amount = 10 },
                    { item = "gunpowder", amount = 5 }
                }
            }
        }
    },
    {
        header = "IFAK (Gelişmiş İlk Yardım)",
        txt = "Gereksinim: 3 Bandaj, 1 Yanık Kremi",
        icon = "fas fa-medkit",
        params = {
            event = "gs-survival:client:craftItem",
            args = {
                item = "ifaks",
                amount = 1,
                label = "IFAK",
                requirements = {
                    { item = "bandage", amount = 3 },
                    { item = "burncream", amount = 1 }
                }
            }
        }
    },
    {
        header = "Tamir Kiti (Repairkit)",
        txt = "Gereksinim: 15 Hurda Metal, 10 Kauçuk",
        icon = "fas fa-tools",
        params = {
            event = "gs-survival:client:craftItem",
            args = {
                item = "repairkit",
                amount = 1,
                label = "Repairkit",
                requirements = {
                    { item = "scrapmetal", amount = 15 },
                    { item = "rubber", amount = 10 }
                }
            }
        }
    }
}

-- [BÖLÜM (STAGE) YAPILANDIRMASI]
Config.Stages = {
    [1] = {
        label = "Gecekondu Baskını - Kolay",
        center = vector3(-127.15, -1584.77, 32.29), 
        multiplier = 1.0,
        spawnPoints = {
            -- Merkezin çevresindeki dar sokaklar ve çatılar/köşeler
            vector3(-81.26, -1613.18, 31.49), -- Kuzeybatı sokak arası
            vector3(-139.59, -1632.87, 32.55), -- Kuzeydoğu garaj arkası
            vector3(-71.32, -1586.99, 30.12), -- Güneydoğu çöp konteyner yanı
            vector3(-166.87, -1594.41, 34.36), -- Güneybatı ev arkası
            -- vector3(-125.10, -1470.80, 33.60), -- Kuzey girişi
        },
        Waves = {
            [1] = { npcCount = 3, pedModel = `g_m_y_famdnf_01`, isDogWave = false, label = "Sokak Çetesi", weapon = "weapon_bat" },
            [2] = { npcCount = 4, pedModel = `g_m_y_famca_01`, isDogWave = false, label = "Sokak Çetesi", weapon = "weapon_pistol" },
        }
    },
    [2] = {
        label = "Liman Operasyonu - Orta",
        center = vector3(1235.43, -3003.26, 9.32), 
        multiplier = 1.2,
        spawnPoints = {
            -- Konteynır araları ve vinç altları
            vector3(1228.03, -3068.66, 5.9), -- Konteynır bloğu A
            vector3(1222.08, -2906.67, 5.87), -- Vinç altı açık alan
            vector3(1174.97, -2933.73, 5.9), -- Kuzey Liman girişi
            vector3(1146.36, -3002.13, 5.9), -- Depo önü
            vector3(1164.24, -3054.69, 5.9), -- Rıhtım ucu
        },
        Waves = {
            [1] = { npcCount = 3, pedModel = `s_m_y_blackops_01`, isDogWave = false, label = "Liman Güvenliği", weapon = "weapon_smg" },
            [2] = { npcCount = 4, pedModel = `s_m_y_blackops_01`, isDogWave = false, label = "Liman Güvenliği", weapon = "weapon_smg" },
        }
    },
        [3] = {
        label = "Jilet Fadıl - Zor",
        center = vector3(1387.87, 1147.03, 114.33), 
        multiplier = 1.6,
        spawnPoints = {
            -- Konteynır araları ve vinç altları
            vector3(1318.72, 1106.94, 105.97), -- Konteynır bloğu A
            vector3(1418.45, 1177.02, 114.33), -- Vinç altı açık alan
            vector3(1432.47, 1121.08, 114.25), -- Kuzey Liman girişi
            vector3(1369.02, 1098.44, 113.86), -- Depo önü
            vector3(1473.22, 1130.18, 114.33), -- Rıhtım ucu
        },
        Waves = {
            [1] = { npcCount = 1, pedModel = `g_m_m_chicold_01`, isDogWave = false, label = "Koruma", weapon = "weapon_smg" },
            [2] = { npcCount = 1, pedModel = `g_m_m_chicold_01`, isDogWave = false, label = "Koruma", weapon = "weapon_smg" },
            [3] = { npcCount = 1, pedModel = `g_m_m_chicold_01`, isDogWave = false, label = "Koruma", weapon = "weapon_smg" },
            -- [4] = { npcCount = 6, pedModel = `g_m_m_chicold_01`, isDogWave = false, label = "Koruma", weapon = "weapon_smg" },
        }
    },
}
-- [BAŞLANGIÇ NPC AYARLARI]
Config.Npc = {
    Model = `a_m_m_og_boss_01`,
    Coords = vector4(-122.5, -1500.2, 33.5, 120.0), 
    Label = "Operasyon Menüsü"
}

-- [SAVAŞ VE ZORLUK AYARLARI]
Config.Combat = {
    WaveWaitTime = 45, 
    NpcAccuracy = 25, 
    BoundaryDistance = 90.0, -- Oyuncunun merkezden ne kadar uzaklaşabileceği
    LootTime = 180000, 
    FinalCountdown = 10,
    DefaultWeapon = "WEAPON_PISTOL",
    DefaultAmmo = "ammo-9",
    DefaultAmmoAmount = 100
}

-- [LOOT AYARLARI]
Config.LootTable = {
    -- Combat (Para ve Mermi)
    { item = "money", min = 100, max = 500, chance = 50, type = "combat" },
    { item = "black_money", min = 50, max = 200, chance = 20, type = "combat" },
    { item = "ammo-9", min = 10, max = 30, chance = 35, type = "combat" },
    
    -- Craft Malzemeleri (Common)
    { item = "scrapmetal", min = 2, max = 5, chance = 25, type = "craft" },
    { item = "metalscrap", min = 2, max = 4, chance = 20, type = "craft" },
    { item = "rubber", min = 1, max = 3, chance = 18, type = "craft" },
    { item = "cloth", min = 2, max = 4, chance = 22, type = "craft" },
    
    -- Survival (Food/Med)
    { item = "water_bottle", min = 1, max = 1, chance = 15, type = "survival" },
    { item = "tosti", min = 1, max = 1, chance = 12, type = "survival" },
    { item = "bandage", min = 1, max = 1, chance = 10, type = "survival" },
    { item = "burncream", min = 1, max = 1, chance = 5, type = "survival" },
    
    -- Nadir Malzemeler
    { item = "electronics", min = 1, max = 1, chance = 5, type = "rare", minWave = 3 }, 
    { item = "weapon_core", min = 1, max = 1, chance = 2, type = "rare", minWave = 5 },
    { item = "cryptostick", min = 1, max = 1, chance = 1, type = "rare", minWave = 4 }
}
-- [MARKET GELİŞTİRMELERİ]
Config.Upgrades = {
    ["armor"] = {
        price = 50000,
        value = 100,
        label = "Çelik Yelek (100 Zırh)",
        metadataName = "survival_armor",
        sqlColumn = "survival_armor"
    },
    ["weapon"] = {
        price = 100000,
        value = "WEAPON_MICROSMG",
        label = "Uzi Başlangıç Paketi",
        metadataName = "survival_weapon",
        sqlColumn = "survival_weapon",
        ammoType = "ammo-45",
        ammoAmount = 1000
    }
}
