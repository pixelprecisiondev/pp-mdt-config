return {
    locale = 'en', -- available locales: https://pastebin.com/AzTKE9St

    homepage = {
        dispatchlimit = 10,
        maxSearchResults = 20
    },

    announcements = {
        minContentLength = 30
    },

    citizen = {
        licensePrefix = {
            ["Boat License"] = "BOAT"
        }
    },

    formLimits = {
        ['evidences'] = {
            title = { min = 5, max = 40},
            description = { min = 20, max = 300}
        },
        ['cases'] = {
            title = { min = 5, max = 40},
            description = { min = 20, max = 300}
        },
        ['notes'] = {
            title = { min = 5, max = 40},
            description = { min = 20, max = 300}
        },
    },

    playerPositionRefreshRate = 1000, -- time in milliseconds which indicates how often the player's position on the map should be updated

    patrols = {
        statusTypes = {"Patrol", "Break", "Own Intervention", "Responding", "Other", "Transporting a detainee"},
        patrolTypes = {
            { value = "heli", label = "Helicopter" },
            { value = "car", label = "Car" },
            { value = "walk", label = "Walk" },
            { value = "boat", label = "Boat" },
            { value = "bike", label = "Bike" },
            { value = "motorbike", label = "Motorbike" },
        },
        statusColorMap = {
            ['Patrol'] = "blue",
            ['Break'] = "orange",
            ['Own Intervention'] = "purple",
            ['Responding'] = "green",
            ['Other'] = "gray",
            ['Transporting a detainee'] = "cyan"
        }
    },
    dispatch = {
        limit = 20,
        distanceCalculate = {
            unit = "miles",
            useRoadDistance = true
        },
        weaponColors = {
            ['handgun'] = "blue",
            ['smg'] = "red",
            ['rifle'] = "gray",
            ['sniper_rifle'] = "orange",
            ['shotgun'] = "purple",
            ['heavy'] = "black",
            ['thrown'] = "green"
        },
        timeLabels = {
            seconds = {
                { min = 0, max = 1, label = "a second" },
                { min = 2, max = 59, label = "x seconds" }
            },
            minutes = {
                { min = 1, max = 1, label = "a minute" },
                { min = 2, max = 59, label = "x minutes" }
            },
            hours = {
                { min = 1, max = 1, label = "an hour" },
                { min = 2, max = 23, label = "x hours" }
            },
            days = {
                { min = 1, max = 1, label = "a day" },
                { min = 2, max = 6, label = "x days" }
            },
            weeks = {
                { min = 1, max = 1, label = "a week" },
                { min = 2, max = 4, label = "x weeks" }
            },
            months = {
                { min = 1, max = 1, label = "a month" },
                { min = 2, max = 11, label = "x months" }
            },
            years = {
                { min = 1, max = 1, label = "a year" },
                { min = 2, max = 100, label = "x years" }
            }
        }
    }
}