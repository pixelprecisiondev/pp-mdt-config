local tabletEntity = nil -- DO NOT CHANGE
local tabletModel = "pp_tablet"
local tabletDict = "amb@world_human_seat_wall_tablet@female@base"
local tabletAnim = "base"
local imagePromise = nil
local items = nil

return {
    locale = 'en', -- EN | PL
    keybind = true,

    startTabletAnimation = function()
        lib.requestAnimDict(tabletDict)
        if tabletEntity then
            stopTabletAnimation()
        end
        lib.requestModel(tabletModel)
        tabletEntity = CreateObject(GetHashKey(tabletModel), 1.0, 1.0, 1.0, 1, 1, 0)
        AttachEntityToEntity(tabletEntity, cache.ped, GetPedBoneIndex(cache.ped, 57005), 0.12, 0.10, -0.13, 25.0, 170.0, 160.0, true, true, false, true, 1, true)
        TaskPlayAnim(cache.ped, tabletDict, tabletAnim, 8.0, -8.0, -1, 50, 0, false, false, false)
    end,

    stopTabletAnimation = function()
        if tabletEntity then
            StopAnimTask(cache.ped, tabletDict, tabletAnim ,8.0, -8.0, -1, 50, 0, false, false, false)
            DeleteEntity(tabletEntity)
            tabletEntity = nil
        end
    end,

    getWeaponData = function(weapon)
        if not items and GetResourceState('ox_inventory') == 'started' then
            items = exports.ox_inventory:Items()
        end
        return {
            model = (items and items[weapon['weapon']]?.label) or weapon['weapon'],
            img = ("https://cfx-nui-ox_inventory/web/images/%s.png"):format(weapon['weapon'])
        }
    end,

    cameraTextUI = '[BACKSPACE] - Cancel   \n[ENTER] - Confirm',

    cameras = {
        offsets = {
            prop_cctv_cam_01a = {
                initialCamCoord = vector3(0.14, -0.62, 0.21),
                initialCamRot = vector3(-30.0, 0.0, 209.4)
            },
            prop_cctv_cam_01b = {
                initialCamCoord = vector3(-0.04, -1.29, 0.22),
                initialCamRot = vector3(-30.0, 0.0, 139.50)
            },
            prop_cctv_cam_03a = {
                initialCamCoord = vector3(-0.47, -0.45, 0.28),
                initialCamRot = vector3(0.0, 0.0, 118.0)
            },
            prop_cctv_cam_05a = {
                initialCamCoord = vector3(0.05, -0.19, 0.1),
                initialCamRot = vector3(-20.0, 0.0, 175.5)
            },
            prop_cctv_cam_06a = {
                initialCamCoord = vector3(0.01, -0.07, 0.14),
                initialCamRot = vector3(0.0, 0.0, 178.0)
            }
        },
        getVehicleSirenState = function(vehicle)
            if GetResourceState('Renewed-Sirensync') == 'started' then
                return {
                    sirenSound = Entity(vehicle).state.sirenMode ~= 0,
                    sirenLights = IsVehicleSirenOn(vehicle),
                }
            else
                return {
                    sirenSound = IsVehicleSirenSoundOn(vehicle),
                    sirenLights = IsVehicleSirenOn(vehicle),
                }
            end
        end
    },

    mugshot = {
        playerCoords = vector4(405.59, -997.18, -99.00, 90.00), -- Player position and heading
        cameraCoords_1 = vector3(402.92, -1000.72, -99.01),     -- Initial camera position
        cameraCoords_2 = vector3(402.99, -1003.02, -99.00),     -- Zoomed-in camera position
        cameraPointCoords = vector3(402.99, -998.02, -99.00)    -- Camera focus point
    }
}