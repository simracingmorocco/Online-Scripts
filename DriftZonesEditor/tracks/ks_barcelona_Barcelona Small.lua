local LocalGates = require('local_gates')

return {
    gates = {
        { type = "start", position = vec3(118.339, 2.550, -493.454), rotation = 138.122, pitch = 0.0, roll = 0.0, size = {width = 0.100, length = 11.810}, line_width = 1.00, color_r = 0.90, color_g = 0.90, color_b = 0.90 },
        { type = "normal", position = vec3(225.819, 0.420, -586.185), rotation = 52.593, pitch = 0.0, roll = 0.0, size = {width = 2.000, length = 5.000}, score_multiplier = 2.00, target_angle = 81, line_width = 1.00, color_r = 0.90, color_g = 0.90, color_b = 0.90 },
        { type = "normal", position = vec3(269.179, -2.047, -582.451), rotation = 308.280, pitch = 0.0, roll = 0.0, size = {width = 2.000, length = 5.000}, score_multiplier = 1.00, target_angle = 64 },
        { type = "normal", position = vec3(332.347, -7.494, -522.067), rotation = 128.008, pitch = 0.0, roll = 0.0, size = {width = 2.000, length = 5.760}, score_multiplier = 1.00, target_angle = 77 },
        { type = "normal", position = vec3(374.597, -8.908, -526.814), rotation = 43.977, pitch = 0.0, roll = 0.0, size = {width = 2.000, length = 5.000}, score_multiplier = 1.00, target_angle = 74 },
        { type = "finish", position = vec3(382.660, -8.627, -540.360), rotation = 123.412, pitch = 0.0, roll = 0.0, size = {width = 0.100, length = 14.800} },
    },
    noGoZones = {
        {
            position = vec3(343.197, -7.867, -525.783),
            rotation = 37.889,
            size = {width = 0.100, length = 2.700}
        },
    },
    trajectoryGates = {
        {
            type = "trajectory",
            position = vec3(243.629, -0.516, -583.703),
            rotation = -1.589,
            pitch = 0.0,
            roll = 0.0,
            size = {width = 0.100, length = 2.500}
        },
        {
            type = "trajectory",
            position = vec3(216.149, 0.776, -566.341),
            rotation = 323.079,
            pitch = 0.0,
            roll = 0.0,
            size = {width = 0.100, length = 2.500}
        },
    },
    mapSettings = {
        scale = { x = 1.000, y = 1.000 },
        curvature = 0.750,
        rotation = -41.100,
        tension = -0.320,
        mergeDistance = 20.000,
        lineWidth = 60.000,
        startLine = {
            length = 18.300,
            angle = 0.000
        },
        finishLine = {
            length = 18.400,
            angle = -6.300
        }
    },
    squareSettings = {
        {
            index = 1,
            offset = vec2(0.000, 0.000),
            rotation = 228.122,
            size = {width = 40.000, height = 15.000},
            deleted = false
        },
        {
            index = 2,
            offset = vec2(-65.000, 46.000),
            rotation = 94.400,
            size = {width = 40.000, height = 15.000},
            deleted = false
        },
        {
            index = 3,
            offset = vec2(67.000, -54.000),
            rotation = 4.400,
            size = {width = 40.000, height = 15.000},
            deleted = false
        },
        {
            index = 4,
            offset = vec2(-82.000, 59.000),
            rotation = 4.400,
            size = {width = 40.000, height = 15.000},
            deleted = false
        },
        {
            index = 5,
            offset = vec2(-26.000, 89.000),
            rotation = -79.000,
            size = {width = 40.000, height = 15.000},
            deleted = false
        },
        {
            index = 6,
            offset = vec2(0.000, 0.000),
            rotation = 213.412,
            size = {width = 40.000, height = 15.000},
            deleted = false
        },
        {
            index = 7,
            offset = vec2(-41.000, 24.000),
            rotation = 35.700,
            size = {width = 12.000, height = 2.000},
            deleted = false
        },
    },
    mapTexts = {
        {
            text = "Finish",
            position = vec2(276.697, -584.043)
        },
        {
            text = "NG-1",
            position = vec2(300.316, -578.808)
        },
        {
            text = "TG-1",
            position = vec2(136.542, -546.804)
        },
        {
            text = "TG-2",
            position = vec2(194.655, -582.140)
        },
        {
            text = "TG-3",
            position = vec2(264.267, -565.602)
        },
        {
            text = "TG-4",
            position = vec2(338.850, -566.078)
        },
        {
            text = "Start",
            position = vec2(156.081, -498.091)
        },
    },
    entrySpeedLine = {
        position = vec3(194.333, 1.552, -557.900),
        rotation = 234.668,
        length = 10.000
    },
    maxAllowedTransitions = 12,

    startPosition = vec3(91.538, 2.207, -450.295),
    startRotation = 108.867,
    alternateStartPosition = vec3(115.366, 2.551, -491.394),
    alternateStartRotation = 144.152,
    perfectEntrySpeed = 101,
    gatesTransparency = {
        normal = 1.0,
        start = 1.0,
        finish = 1.0,
        oz = 1.0,
        noGoZone = 1.0,
        trajectory = 1.0
    }
}