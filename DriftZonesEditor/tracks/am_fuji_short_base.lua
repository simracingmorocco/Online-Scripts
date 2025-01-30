local LocalGates = require('local_gates')

return {
    gates = {
        { type = "start", position = vec3(-65.215, 14.423, -6.034), rotation = 2.940, pitch = 0.0, roll = 0.0, size = {width = 0.100, length = 11.580}, line_width = 3.00, color_r = 0.00, color_g = 0.90, color_b = 0.00 },
        { type = "normal", position = vec3(101.413, 6.013, -1.553), rotation = -89.329, pitch = 0.0, roll = 0.0, size = {width = 1.810, length = 8.520}, score_multiplier = 1.00, target_angle = 30, line_width = 1.00, color_r = 0.90, color_g = 0.90, color_b = 0.90 },
        { type = "normal", position = vec3(181.456, 2.452, -60.072), rotation = 241.850, pitch = 0.0, roll = 0.0, size = {width = 1.520, length = 1.650}, score_multiplier = 1.00, target_angle = 30, line_width = 1.00, color_r = 0.90, color_g = 0.90, color_b = 0.90 },
        { type = "normal", position = vec3(205.977, 5.331, -105.666), rotation = 105.655, pitch = 0.0, roll = 0.0, size = {width = 2.000, length = 5.000}, score_multiplier = 1.00, target_angle = 30, line_width = 1.00, color_r = 0.90, color_g = 0.90, color_b = 0.90 },
        { type = "OZ", position = vec3(102.179, 11.670, -41.190), rotation = -27.720, pitch = 0.0, roll = 0.0, size = {width = 0.100, length = 2.500}, score_multiplier = 0.25, target_angle = 30, line_width = 1.00, color_r = 0.90, color_g = 0.90, color_b = 0.90 },
        { type = "OZ", position = vec3(95.645, 11.746, -38.751), rotation = -20.670, pitch = 0.0, roll = 0.0, size = {width = 0.100, length = 2.400}, score_multiplier = 0.25, target_angle = 30, line_width = 1.00, color_r = 0.90, color_g = 0.90, color_b = 0.90 },
        { type = "OZ", position = vec3(88.649, 11.854, -36.693), rotation = -11.413, pitch = 0.0, roll = 0.0, size = {width = 0.100, length = 2.500}, score_multiplier = 0.25, target_angle = 30, line_width = 1.00, color_r = 0.90, color_g = 0.90, color_b = 0.90 },
        { type = "normal", position = vec3(49.714, 13.323, -48.619), rotation = 124.276, pitch = 0.0, roll = 0.0, size = {width = 1.520, length = 2.700}, score_multiplier = 1.00, target_angle = 30, line_width = 1.00, color_r = 0.90, color_g = 0.90, color_b = 0.90 },
        { type = "finish", position = vec3(-3.626, 15.272, -89.821), rotation = 160.767, pitch = 0.0, roll = 0.0, size = {width = 0.100, length = 11.290}, line_width = 3.00, color_r = 0.90, color_g = 0.00, color_b = 0.00 },
    },
    noGoZones = {
        {
            position = vec3(162.416, 8.443, -98.795),
            rotation = 155.461,
            size = {width = 0.100, length = 1.440},
            line_width = 1.00
        },
    },
    trajectoryGates = {
    },
    mapSettings = {
        scale = { x = 0.790, y = 1.570 },
        curvature = 2.000,
        rotation = 6.300,
        tension = -0.490,
        mergeDistance = 20.000,
        lineWidth = 84.400,
        startLine = {
            length = 63.300,
            angle = 0.000
        },
        finishLine = {
            length = 63.300,
            angle = 0.000
        }
    },
    squareSettings = {
        {
            index = 1,
            offset = vec2(0.000, 0.000),
            rotation = 0.671,
            size = {width = 32.000, height = 12.000},
            deleted = false
        },
        {
            index = 2,
            offset = vec2(-56.000, 45.000),
            rotation = -6.600,
            size = {width = 32.000, height = 12.000},
            deleted = false
        },
        {
            index = 3,
            offset = vec2(41.000, 0.000),
            rotation = -65.900,
            size = {width = 32.000, height = 12.000},
            deleted = false
        },
        {
            index = 4,
            offset = vec2(0.000, 0.000),
            rotation = 62.280,
            size = {width = 12.000, height = 2.000},
            deleted = false
        },
        {
            index = 5,
            offset = vec2(0.000, 0.000),
            rotation = 69.330,
            size = {width = 12.000, height = 2.000},
            deleted = true
        },
        {
            index = 6,
            offset = vec2(0.000, 0.000),
            rotation = 78.587,
            size = {width = 12.000, height = 2.000},
            deleted = true
        },
        {
            index = 7,
            offset = vec2(0.000, 0.000),
            rotation = 214.276,
            size = {width = 22.000, height = 3.000},
            deleted = false
        },
        {
            index = 8,
            offset = vec2(-71.000, 0.000),
            rotation = 54.900,
            size = {width = 40.000, height = 15.000},
            deleted = false
        },
        {
            index = 9,
            offset = vec2(0.000, 0.000),
            rotation = 92.940,
            size = {width = 40.000, height = 15.000},
            deleted = false
        },
        {
            index = 10,
            offset = vec2(0.000, 0.000),
            rotation = 245.461,
            size = {width = 12.000, height = 2.000},
            deleted = false
        },
    },
    mapTexts = {
    },
    entrySpeedLine = {
        position = vec3(86.453, 6.750, -6.066),
        rotation = -88.865,
        length = 15.000
    },
    maxAllowedTransitions = 4,

    startPosition = vec3(-122.135, 17.396, -12.440),
    startRotation = -134.506,
    alternateStartPosition = vec3(-68.096, 14.562, -5.663),
    alternateStartRotation = -178.598,
    perfectEntrySpeed = 110,
    gatesTransparency = {
        normal = 1.0,
        start = 1.0,
        finish = 1.0,
        oz = 1.0,
        noGoZone = 1.0,
        trajectory = 1.0
    }
}