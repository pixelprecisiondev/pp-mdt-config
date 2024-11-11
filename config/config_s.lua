local Framework = nil

if GetResourceState('es_extended') ~= 'missing' then
    Framework = 'ESX'
    ESX = exports.es_extended:getSharedObject()
elseif GetResourceState('qb-core') ~= 'missing' then
    Framework = 'QBCore'
    QBCore = exports['qb-core']:GetCoreObject()
elseif GetResourceState('qbx_core') ~= 'missing' then
    Framework = 'QBOX'
    qbox = exports.qbx_core
elseif GetResourceState('your_custom_framework') ~= 'missing' then -- fill it when you are using other framework
    Framework = 'your_custom_framework'
end

return {
    debug = false, --[[
        Set this to 'true' only when you need to troubleshoot issues within the resource.
        Enabling debug mode activates extra logging to help identify and resolve problems.
        This setting should always remain 'false' in production environments to avoid performance impacts.

        When debug mode is enabled, the following commands are also available for testing:
        - /dutystart - for entering duty
        - /dutystop  - for leaving duty
        - /testdispatch - to send a test dispatch report
    ]]
    locales = 'en', -- EN | PL

    imageUpload = {
        type = 'fivemanage', -- fivemanage | fmsdk | discord | custom
        token = '', -- fivemanage token | discord webhook
        custom = function(source)
            return nil --return url
        end
    },

    jobsWithAccess = { -- names of jobs that will have access to use MDT
        'police'
    },

    cameras = {
        enable = true,
        limit = 10 -- max limit of CCTV cameras
    },

    homePage = {
        getOfficerData = function(player)
            local radiochannel, image, badge = nil, nil, nil
            if Framework == 'ESX' then
                radiochannel = Player(player.source).state.radioChannel -- pma_voice use
                image = player.getMeta('mdt_image')
                badge = player.getMeta('badge') or 0
            elseif Framework == 'QBCore' or Framework == 'QBOX' then
                radiochannel = Player(player.PlayerData.source).state.radioChannel -- pma_voice use
                image = player.PlayerData.metadata.mdt_image
                badge = player.PlayerData.metadata.callsign or 0
            end
            return {
                radio = radiochannel,
                img = image,
                badge = badge
            }
        end,
        getPhoto = function(identifier)
            local image = nil
            if Framework == 'ESX' then
                local player = ESX.GetPlayerFromIdentifier(identifier)
                if player then
                    image = player.getMeta('mdt_image')
                else
                    local response = MySQL.query.await("SELECT JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.mdt_image')) AS mdt_image, FROM `users` WHERE `identifier` = ?", {
                        identifier
                    })
                    if response and response[1] then
                        image = response[1].mdt_image
                    end
                end
            elseif Framework == 'QBOX' then
                local player = qbox:GetPlayerByCitizenId(identifier) or qbox:GetOfflinePlayer(identifier)
                if player then
                    image = player.PlayerData.metadata.mdt_image
                end
            elseif Framework == 'QBCore' then
                local player = QBCore.Functions.GetPlayerByCitizenId(identifier) or QBCore.Functions.GetOfflinePlayerByCitizenId(identifier)
                if player then
                    image = player.PlayerData.metadata.mdt_image
                end
            end

            return image
        end
    },

    citizen = {
        updatePhoto = function(identifier, url)
            if Framework == 'ESX' then
                local player = ESX.GetPlayerFromIdentifier(identifier)
                if player then
                    player.setMeta('mdt_image', url)
                else
                    MySQL.update.await("UPDATE `users` SET `metadata` = JSON_SET(`metadata`, '$.mdt_image', ?) WHERE `identifier` = ?", {
                        url,
                        identifier
                    })
                end
            elseif Framework == 'QBCore' or Framework == 'QBOX' then
                local player = Framework == 'QBCore' and (QBCore.Functions.GetPlayerByCitizenId(identifier) or QBCore.Functions.GetOfflinePlayerByCitizenId(identifier)) or (qbox:GetPlayerByCitizenId(identifier) or qbox:GetOfflinePlayer(identifier))
                if player then
                    player.Functions.SetMetaData('mdt_image', url)
                else
                    MySQL.update.await("UPDATE `players` SET `metadata` = JSON_SET(`metadata`, '$.mdt_image', ?) WHERE `citizenid` = ?", {
                        url,
                        identifier
                    })
                end
            end
            return true
        end,
        getCitizenDetails = function(identifier)
            local data = {}
            local licenses = {}
    
            if Framework == 'ESX' then
                local player = ESX.GetPlayerFromIdentifier(identifier)
                if player then
                    data.firstname = player.get('firstName')
                    data.lastname = player.get('lastName')
                    data.birthdate = player.get('dob')
                    data.nationality = player.get('nationality')
                    data.mdt_image = player.getMeta('mdt_image')
                    data.badge = player.getMeta('badge')
                else
                    local response = MySQL.query.await("SELECT `firstname`, `lastName`, `dateofbirth` AS `dob`, `nationality`, JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.mdt_image')) AS mdt_image, JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.badge')) AS badge FROM `users` WHERE `identifier` = ?", {
                        identifier
                    })
                    if response and response[1] then
                        data = response[1]
                    end
                end
    
            elseif Framework == 'QBCore' then
                local player = QBCore.Functions.GetPlayerByCitizenId(identifier) or QBCore.Functions.GetOfflinePlayerByCitizenId(identifier)
                if player then
                    local playerData = player.PlayerData
                    data.firstname = playerData.charinfo.firstname
                    data.lastname = playerData.charinfo.lastname
                    data.birthdate = playerData.charinfo.birthdate
                    data.nationality = playerData.charinfo.nationality
                    data.mdt_image = playerData.metadata.mdt_image
                    data.badge = playerData.metadata.callsign
                end
    
            elseif Framework == 'QBOX' then
                local player = qbox:GetPlayerByCitizenId(identifier) or qbox:GetOfflinePlayer(identifier)
                if player then
                    local playerData = player.PlayerData
                    data.firstname = playerData.charinfo.firstname
                    data.lastname = playerData.charinfo.lastname
                    data.birthdate = playerData.charinfo.birthdate
                    data.nationality = playerData.charinfo.nationality
                    data.mdt_image = playerData.metadata.mdt_image
                    data.badge = playerData.metadata.callsign
                end
            end

            if not data.firstname then return {} end

            -- Retrieve licenses if available
            if Framework == 'ESX' then
                local userLicenses = MySQL.query.await("SELECT `type` FROM `user_licenses` WHERE `owner` = ?", { identifier })
                if userLicenses then
                    for _, userLicense in pairs(userLicenses) do
                        local licenseType = userLicense.type
                        local licenseLabel = MySQL.query.await("SELECT `label` FROM `licenses` WHERE `type` = ?", { licenseType })
                        if licenseLabel and licenseLabel[1] then
                            table.insert(licenses, {
                                label = licenseLabel[1].label,
                                owns = true
                            })
                        end
                    end
                end
            elseif Framework == 'QBCore' or Framework == 'QBOX' then
                local player = QBCore.Functions.GetPlayerByCitizenId(identifier) or QBCore.Functions.GetOfflinePlayerByCitizenId(identifier)
                if player and player.PlayerData.metadata.licenses then
                    for name, value in pairs(player.PlayerData.metadata.licenses) do
                        table.insert(licenses, {
                            label = name,
                            owns = value
                        })
                    end
                end
            end
            return {
                name = data.firstname .. ' ' .. data.lastname,
                dob = data.birthdate,
                img = data.mdt_image,
                ssn = identifier,
                nationality = data.nationality,
                licenses = licenses,
                badge = data.badge
            }
        end
    },

    vehicle = {
        getVehicleDetails = function(plate)
            local dbdata = {}

            if Framework == 'ESX' then
                dbdata = MySQL.query.await([[
                    SELECT
                        uv.owner AS identifier,
                        JSON_UNQUOTE(JSON_EXTRACT(uv.vehicle, '$.model')) AS hash,
                        uv.mdt_image AS img,
                        p.firstname AS firstname,
                        p.lastname AS lastname
                    FROM
                        `owned_vehicles` uv
                    LEFT JOIN
                        `users` p ON uv.owner = p.identifier
                    WHERE
                        uv.plate = ?
                ]], { plate })

            elseif Framework == 'QBCore' or Framework == 'QBOX' then
                dbdata = MySQL.query.await([[
                    SELECT
                        pv.citizenid AS identifier,
                        pv.hash,
                        pv.mdt_image AS img,
                        JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) AS firstname,
                        JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) AS lastname
                    FROM
                        `player_vehicles` pv
                    LEFT JOIN
                        `players` p ON pv.citizenid = p.citizenid
                    WHERE
                        pv.plate = ?
                ]], { plate })
            end

            if dbdata and #dbdata > 0 then
                local vehicleData = dbdata[1]
                vehicleData.name = vehicleData.firstname .. " " .. vehicleData.lastname
                return vehicleData
            else
                return {}
            end
        end,
        updatePhoto = function(plate, url)
            local affectedRows = 0

            if Framework == 'ESX' then
                affectedRows = MySQL.update.await('UPDATE `owned_vehicles` SET `mdt_image` = ? WHERE `plate` = ?', {
                    url, plate
                })
            elseif Framework == 'QBCore' or Framework == 'QBOX' then
                affectedRows = MySQL.update.await('UPDATE `player_vehicles` SET `mdt_image` = ? WHERE `plate` = ?', {
                    url, plate
                })
            end

            return affectedRows > 0 and true or false
        end
    },
    case = {
        mugshot = {
            enable = true,
            title = "Los Santos Police Department",
            subtitle = "Case #%s",
            updatePhoto = function(identifier, url)
                if Framework == 'ESX' then
                    local player = ESX.GetPlayerFromIdentifier(identifier)
                    if player then
                        player.setMeta('mdt_image', url)
                    else
                        MySQL.update.await("UPDATE `users` SET `metadata` = JSON_SET(`metadata`, '$.mdt_image', ?) WHERE `identifier` = ?", {
                            url,
                            identifier
                        })
                    end
                elseif Framework == 'QBCore' or Framework == 'QBOX' then
                    local player = Framework == 'QBCore' and (QBCore.Functions.GetPlayerByCitizenId(identifier) or QBCore.Functions.GetOfflinePlayerByCitizenId(identifier)) or (qbox:GetPlayerByCitizenId(identifier) or qbox:GetOfflinePlayer(identifier))
                    if player then
                        player.Functions.SetMetaData('mdt_image', url)
                    else
                        MySQL.update.await("UPDATE `players` SET `metadata` = JSON_SET(`metadata`, '$.mdt_image', ?) WHERE `citizenid` = ?", {
                            url,
                            identifier
                        })
                    end
                end
                return true
            end,
        },
        sendToJail = function(identifier, months, fine, data, source)
            local targetPlayer = Bridge.getPlayerFromIdentifier(identifier)
            if not targetPlayer then return end

            local targetSource = Bridge.getSource(targetPlayer)
            if not targetSource then return end
            --[[
                IMPORTANT:
                None of the following resources allow jailing players who are offline.
                This limitation means you’ll need to implement this feature manually if required!!
            ]]

            if GetResourceState('rcore_prison') == 'started' then
                exports['rcore_prison']:Jail(targetSource, months, '', source)
            elseif GetResourceState('RiP-Prison') == 'started' then
                exports['RiP-Prison']:jailIn(targetSource, nil, months)
            elseif GetResourceState('qbx_policejob') == 'started' then
                local currentDate = os.date('*t')
                if currentDate.day == 31 then
                    currentDate.day = 30
                end
                targetPlayer.Functions.SetMetaData('injail', months)
                targetPlayer.Functions.SetMetaData('criminalrecord', {
                    hasRecord = true,
                    date = currentDate
                })
                if GetResourceState('qbx_prison') == 'started' then
                    exports.qbx_prison:JailPlayer(targetSource, months)
                else
                    TriggerClientEvent('police:client:SendToJail', targetSource, months)
                end
            elseif GetResourceState('qb-policejob') == 'started' then
                TriggerEvent('police:server:JailPlayer', targetSource, months)
            elseif GetResourceState('esx-qalle-jail') == 'started' then
                TriggerEvent('esx-qalle-jail:jailPlayer', targetSource, months, '')
            end
        end,
        giveTicket = function(identifier, fine, data, source)
            local targetPlayer = Bridge.getPlayerFromIdentifier(identifier)
            if not targetPlayer then return end
            local targetSource = Bridge.getSource(targetPlayer)

            if targetSource then
                if GetResourceState('esx_billing') == 'started' then
                    TriggerEvent('esx_billing:sendBill', targetSource, 'society_police', 'Police', fine)
                elseif GetResourceState('okokBilling') == 'started' then
                    TriggerEvent("okokBilling:CreateCustomInvoice", targetSource, fine, 'LSPD ticket', 'Police', 'police', 'LSPD')
                elseif GetResourceState('codem-billing') == 'started' then
                    exports['codem-billing']:createBilling(source, targetSource, fine, 'LSPD ticket', 'police')
                end
            else
                if Framework == 'QBCore' then
                    targetPlayer.Functions.RemoveMoney('bank', fine, 'LSPD ticket')
                elseif Framework == 'ESX' then
                    targetPlayer.removeAccountMoney('bank', fine)
                elseif GetResourceState('Renewed-Banking') == 'started' then
                    exports['Renewed-Banking']:handleTransaction(identifier, 'LSPD ticket', fine, 'LSPD ticket', 'LSPD', 'police', 'withdraw')
                    exports['Renewed-Banking']:removeAccountMoney(identifier, fine)
                end
            end
        end,
        charges = {
            {
                id = 1,
                label = 'Speeding (Minor)',
                description = 'Exceeding the speed limit by up to 10 mph.',
                fine = 100,
                months = 0,
                level = 'low',
            },
            {
                id = 2,
                label = 'Speeding (Moderate)',
                description = 'Exceeding the speed limit by 11-20 mph.',
                fine = 500,
                months = 0,
                level = 'medium',
            },
            {
                id = 3,
                label = 'Speeding (Severe)',
                description = 'Exceeding the speed limit by over 20 mph.',
                fine = 1500,
                months = 1,
                level = 'high',
            },
            {
                id = 4,
                label = 'Reckless Driving',
                description = 'Operating a vehicle in a manner that endangers others.',
                fine = 3000,
                months = 3,
                level = 'high',
            },
            {
                id = 5,
                label = 'DUI (First Offense)',
                description = 'Driving under the influence of alcohol or drugs.',
                fine = 2000,
                months = 6,
                level = 'medium',
            },
            {
                id = 6,
                label = 'DUI (Repeat Offense)',
                description = 'Repeated offense of driving under the influence.',
                fine = 5000,
                months = 12,
                level = 'critical',
            },
            {
                id = 7,
                label = 'Assault (Minor)',
                description = 'Physical attack causing minor injuries.',
                fine = 1000,
                months = 6,
                level = 'low',
            },
            {
                id = 8,
                label = 'Assault (Severe)',
                description = 'Physical attack causing severe injuries.',
                fine = 5000,
                months = 24,
                level = 'high',
            },
            {
                id = 9,
                label = 'Robbery',
                description = 'Taking property from another person by force or threat.',
                fine = 10000,
                months = 36,
                level = 'critical',
            },
            {
                id = 10,
                label = 'Murder',
                description = 'Unlawful killing of another person.',
                fine = 25000,
                months = 60,
                level = 'critical',
            },
        }
    },

    patrols = {
        inviteExpiration = 60000,
    },

    dispatch = {
        getGender = function(frPlayer)
            if Framework == 'ESX' then
                local gender = frPlayer.get('sex')
                return gender == 'm' and "Male" or "Female"
            elseif Framework == 'QBCore' or Framework == 'QBOX' then
                return frPlayer.PlayerData.charinfo.gender == 0 and "Male" or "Female"
            end
        end,
        ignoreJobsWithAccess = true,
        gunShots = {
            enable = true,
            delay = 5000,
            locales = {
                title = 'Shots fired',
                description = 'Gun shots reported',
                code = '10-71',
                blip = '# 10-71 - Shots Fired'
            },
            monitoredWeapons = {
                ['Handgun'] = {
                    ['WEAPON_PISTOL'] = true,
                    ['WEAPON_COMBATPISTOL'] = true,
                    ['WEAPON_HEAVYPISTOL'] = true,
                    ['WEAPON_VINTAGEPISTOL'] = true,
                    ['WEAPON_SNSPISTOL'] = true,
                    ['WEAPON_PISTOL50'] = true,
                    ['WEAPON_REVOLVER'] = true,
                    ['WEAPON_REVOLVER_MK2'] = true,
                    ['WEAPON_DOUBLEACTION'] = true,
                    ['WEAPON_APPISTOL'] = true,
                    ['WEAPON_STUNGUN'] = true,
                    ['WEAPON_FLAREGUN'] = true,
                    ['WEAPON_MARKSMANPISTOL'] = true,
                    ['WEAPON_RAYPISTOL'] = true,
                    ['WEAPON_CERAMICPISTOL'] = true,
                    ['WEAPON_NAVYREVOLVER'] = true
                },
                ['SMG'] = {
                    ['WEAPON_MICROSMG'] = true,
                    ['WEAPON_SMG'] = true,
                    ['WEAPON_SMG_MK2'] = true,
                    ['WEAPON_ASSAULTSMG'] = true,
                    ['WEAPON_MINISMG'] = true,
                    ['WEAPON_MACHINEPISTOL'] = true,
                    ['WEAPON_COMBATPDW'] = true
                },
                ['Rifle'] = {
                    ['WEAPON_ASSAULTRIFLE'] = true,
                    ['WEAPON_ASSAULTRIFLE_MK2'] = true,
                    ['WEAPON_CARBINERIFLE'] = true,
                    ['WEAPON_CARBINERIFLE_MK2'] = true,
                    ['WEAPON_ADVANCEDRIFLE'] = true,
                    ['WEAPON_SPECIALCARBINE'] = true,
                    ['WEAPON_SPECIALCARBINE_MK2'] = true,
                    ['WEAPON_BULLPUPRIFLE'] = true,
                    ['WEAPON_BULLPUPRIFLE_MK2'] = true,
                    ['WEAPON_COMPACTRIFLE'] = true,
                    ['WEAPON_MILITARYRIFLE'] = true,
                    ['WEAPON_HEAVYRIFLE'] = true,
                    ['WEAPON_TACTICALRIFLE'] = true
                },
                ['Sniper rifle'] = {
                    ['WEAPON_SNIPERRIFLE'] = true,
                    ['WEAPON_HEAVYSNIPER'] = true,
                    ['WEAPON_HEAVYSNIPER_MK2'] = true,
                    ['WEAPON_MARKSMANRIFLE'] = true,
                    ['WEAPON_MARKSMANRIFLE_MK2'] = true
                },
                ['Shotgun'] = {
                    ['WEAPON_PUMPSHOTGUN'] = true,
                    ['WEAPON_PUMPSHOTGUN_MK2'] = true,
                    ['WEAPON_SAWNOFFSHOTGUN'] = true,
                    ['WEAPON_BULLPUPSHOTGUN'] = true,
                    ['WEAPON_ASSAULTSHOTGUN'] = true,
                    ['WEAPON_MUSKET'] = true,
                    ['WEAPON_HEAVYSHOTGUN'] = true,
                    ['WEAPON_DBSHOTGUN'] = true,
                    ['WEAPON_AUTOSHOTGUN'] = true,
                    ['WEAPON_COMBATSHOTGUN'] = true
                },
                ['Heavy rifle'] = {
                    ['WEAPON_GRENADELAUNCHER'] = true,
                    ['WEAPON_RPG'] = true,
                    ['WEAPON_MINIGUN'] = true,
                    ['WEAPON_FIREWORK'] = true,
                    ['WEAPON_RAILGUN'] = true,
                    ['WEAPON_HOMINGLAUNCHER'] = true,
                    ['WEAPON_COMPACTLAUNCHER'] = true,
                    ['WEAPON_RAYMINIGUN'] = true,
                    ['WEAPON_EMPLAUNCHER'] = true
                },
                ['Thrown'] = {
                    ['WEAPON_GRENADE'] = true,
                    ['WEAPON_STICKYBOMB'] = true,
                    ['WEAPON_PROXMINE'] = true,
                    ['WEAPON_BZGAS'] = true,
                    ['WEAPON_MOLOTOV'] = true,
                    ['WEAPON_FIREEXTINGUISHER'] = true,
                    ['WEAPON_PETROLCAN'] = true,
                    ['WEAPON_BALL'] = true,
                    ['WEAPON_SNOWBALL'] = true,
                    ['WEAPON_FLARE'] = true,
                    ['WEAPON_PIPEBOMB'] = true
                }
            }
        } 
    },

    permissions = {
        [0] = {
            announcements = {'view'},
            patrols = {'view'},
            citizens = {'view'},
            citizen = {'view'},
            vehicles = {'view'},
            vehicle = {'view'},
            weapons = {'view'},
            weapon = {'view'},
            evidences = {'view'},
            cases = {'view'},
            case = {'view'},
            cameras = {'view'},
            notes = {'view'},
            note = {'view'},
            settings = {'view'}
        },
        [1] = {
            homepage = {'chat', 'search'},
            announcements = {'create'},
            announcement = {'edit', 'remove'},
            patrols = {'create'},
            citizen = {'photo', 'viewcases', 'viewnotes', 'viewvehicles'},
            vehicle = {'photo', 'viewcases', 'viewnotes'},
            weapon = {'viewcases', 'viewnotes'},
            evidences = {'listview', 'create'},
            cases = {'listview', 'create'},
            case = {'edit', 'delete_warrant'},
            cameras = {'create', 'view_cctv', 'view_bodycam', 'view_dashcam'},
            notes = {'listview', 'create'},
            note = {'edit', 'remove'}
        }
    },

    queries = (Framework == 'QBCore' or Framework == 'QBOX') and {
        citizens = {
            table = "players",
            fields = {
                firstname = "JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname'))",
                lastname = "JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))",
                birthdate = "JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.birthdate'))",
                ssn = "citizenid",
                identifier = "citizenid",
                mdt_image = "JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.mdt_image'))",
                gender = [[
                    CASE
                        WHEN JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.gender')) = '0' THEN 'Male'
                        WHEN JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.gender')) = '1' THEN 'Female'
                        ELSE 'Unknown'
                    END
                ]]
            },
            filters = {
                gender_male = " AND JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.gender')) = '0'",
                gender_female = " AND JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.gender')) = '1'",
                birthdate_format = "%Y-%m-%d"
            }
        },
        vehicles = {
            table = "player_vehicles pv",
            join = "LEFT JOIN players p ON pv.citizenid = p.citizenid",
            fields = {
                plate = "pv.plate",
                identifier = "p.citizenid",
                vehicle = "pv.vehicle",
                hash = "pv.hash",
                mdt_image = "pv.mdt_image"
            }
        },
        ['getCitizenVehicles'] = 'SELECT `hash`, `plate` FROM `player_vehicles` WHERE `citizenid` = ?',
        ['getAuthor'] = [[
            SELECT
                JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) AS firstname,
                JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) AS lastname
            FROM
                players
            WHERE
                citizenid = ?
        ]],
        ['getCitizensByIdentifiers'] = [[
            SELECT
                citizenid AS identifier,
                JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) AS firstname,
                JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) AS lastname
            FROM
                players
            WHERE
                citizenid IN (?)
        ]],
        weapons = {
            ['usersSearch'] = 'SELECT citizenid FROM players WHERE JSON_EXTRACT(charinfo, "$.firstname") LIKE @search OR JSON_EXTRACT(charinfo, "$.lastname") LIKE @search',
            ['usersFullName'] = 'CONCAT(JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, "$.firstname")), " ", JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, "$.lastname")))',
            ['usersJoin'] = 'LEFT JOIN players p ON w.identifier = p.citizenid'
        },
        search = {
            ['citizens'] = [[
                SELECT
                    citizenid AS identifier,
                    JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) AS firstname,
                    JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) AS lastname
                FROM
                    players
                WHERE
                    JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) LIKE @query
                    OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) LIKE @query
                    OR CONCAT(
                        JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')), ' ',
                        JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))
                    ) LIKE @query
                LIMIT 20
            ]],
            ['vehicles'] = [[
                SELECT
                    plate, hash
                FROM
                    player_vehicles
                WHERE
                    plate LIKE @query
                LIMIT 20
            ]],
            ['officers'] = [[
                SELECT
                    p.citizenid AS identifier,
                    JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) AS firstname,
                    JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) AS lastname
                FROM
                    players p
                WHERE
                    JSON_UNQUOTE(JSON_EXTRACT(p.job, '$.name')) IN (@jobs)
                    AND (
                        JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) LIKE @query
                        OR JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) LIKE @query
                        OR CONCAT(
                            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), ' ',
                            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))
                        ) LIKE @query
                    )
                LIMIT 20
            ]],
            ['weapons'] = [[
                SELECT
                    mw.serialnumber,
                    JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) AS firstname, 
                    JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) AS lastname
                FROM
                    mdt_weapons mw
                INNER JOIN
                    players p ON mw.identifier = p.citizenid
                WHERE
                    mw.serialnumber LIKE @query
                    OR JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) LIKE @query
                    OR JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) LIKE @query
                    OR CONCAT(
                        JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), ' ',
                        JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))
                    ) LIKE @query
                LIMIT 20
            ]]
        }
    } or {
        citizens = {
            table = "users",
            fields = {
                firstname = "firstname",
                lastname = "lastname",
                birthdate = "birthdate",
                ssn = "identifier",
                identifier = "identifier",
                mdt_image = "JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.mdt_image'))",
                gender = [[
                    CASE
                        WHEN sex = '0' THEN 'Male'
                        WHEN sex = '1' THEN 'Female'
                        ELSE 'Unknown'
                    END
                ]]
            },
            filters = {
                gender_male = " AND sex = '0'",
                gender_female = " AND sex = '1'",
                birthdate_format = "%Y-%m-%d"
            }
        },
        vehicles = {
            table = "owned_vehicles uv",
            join = "LEFT JOIN users u ON uv.owner = u.identifier",
            fields = {
                plate = "uv.plate",
                identifier = "u.identifier",
                vehicle = "uv.vehicle",
                hash = "JSON_UNQUOTE(JSON_EXTRACT(uv.vehicle, '$.model'))",
                mdt_image = "uv.mdt_image"
            }
        },
        ['getCitizenVehicles'] = 'SELECT JSON_UNQUOTE(JSON_EXTRACT(vehicle, "$.model")) AS hash, `plate` FROM `owned_vehicles` WHERE `owner` = ?',
        ['getAuthor'] = [[
            SELECT
                firstname,
                lastname
            FROM
                users
            WHERE
                identifier = ?
        ]],
        ['getCitizensByIdentifiers'] = [[
            SELECT
                identifier AS identifier,
                firstname,
                lastname
            FROM
                users
            WHERE
                identifier IN (?)
        ]],
        weapons = {
            ['usersSearch'] = 'SELECT identifier FROM users WHERE firstname LIKE @search OR lastname LIKE @search',
            ['usersFullName'] = 'CONCAT(u.firstname, " ", u.lastname)',
            ['usersJoin'] = 'LEFT JOIN users u ON w.identifier = u.identifier'
        },
        search = {
            ['citizens'] = [[
                SELECT
                    identifier AS identifier,
                    firstname,
                    lastname
                FROM
                    users
                WHERE
                    firstname LIKE @query
                    OR lastname LIKE @query
                    OR CONCAT(firstname, ' ', lastname) LIKE @query
                LIMIT 20
            ]],
            ['vehicles'] = [[
                SELECT
                    plate, JSON_UNQUOTE(JSON_EXTRACT(vehicle, "$.model")) AS hash
                FROM
                    owned_vehicles
                WHERE
                    plate LIKE @query
                LIMIT 20
            ]],
            ['officers'] = [[
                SELECT
                    identifier,
                    lastname,
                    firstname
                FROM
                    users
                WHERE
                    job IN (@jobs)
                    AND (
                        firstname LIKE @query
                        OR lastname LIKE @query
                        OR CONCAT(firstname, ' ', lastname) LIKE @query
                    )
                LIMIT 20
            ]],
            ['weapons'] = [[
                SELECT
                    mw.serialnumber,
                    u.firstname, 
                    u.lastname
                FROM
                    mdt_weapons mw
                INNER JOIN
                    users u ON mw.identifier = u.identifier
                WHERE
                    mw.serialnumber LIKE @query
                    OR (
                        u.firstname LIKE @query
                        OR u.lastname LIKE @query
                        OR CONCAT(u.firstname, ' ', u.lastname) LIKE @query
                    )
                LIMIT 20
            ]]
        }
        
    }
}