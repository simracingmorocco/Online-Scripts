local LocalGates = require('local_gates')

return {
    gates = {
        { type = "start", position = vec3(-63.550, -0.005, 132.633), rotation = 231.539, pitch = 0.0, roll = 0.0, size = {width = 0.100, length = 15.990} },
        { type = "normal", position = vec3(-92.453, -0.005, 37.787), rotation = 163.198, pitch = 0.0, roll = 0.0, size = {width = 2.000, length = 3.950}, score_multiplier = 2.00, target_angle = 50, line_width = 0.81, color_r = 0.77, color_g = 0.90, color_b = 1.00 },
        { type = "normal", position = vec3(-94.467, -0.005, -8.683), rotation = 217.497, pitch = 0.0, roll = 0.0, size = {width = 2.000, length = 4.620}, score_multiplier = 1.60, target_angle = 30, line_width = 0.81, color_r = 0.77, color_g = 0.90, color_b = 1.00 },
        { type = "OZ", position = vec3(-61.769, -0.005, -53.112), rotation = 234.670, pitch = 0.0, roll = 0.0, size = {width = 0.100, length = 2.500}, score_multiplier = 1.00, target_angle = 30, line_width = 1.00, color_r = 0.90, color_g = 0.90, color_b = 0.90 },
        { type = "OZ", position = vec3(-128.220, -0.005, -59.771), rotation = 188.690, pitch = 0.0, roll = 0.0, size = {width = 0.100, length = 2.500}, score_multiplier = 1.00 },
        { type = "normal", position = vec3(-159.281, -0.005, -75.507), rotation = 149.585, pitch = 0.0, roll = 0.0, size = {width = 2.000, length = 5.000}, score_multiplier = 1.00, target_angle = 30, line_width = 0.81, color_r = 0.77, color_g = 0.90, color_b = 1.00 },
        { type = "normal", position = vec3(-142.102, -0.005, -131.442), rotation = 248.965, pitch = 0.0, roll = 0.0, size = {width = 1.900, length = 4.710}, score_multiplier = 1.50, target_angle = 30, line_width = 0.81, color_r = 0.77, color_g = 0.90, color_b = 1.00 },
        { type = "finish", position = vec3(-91.508, -0.005, -106.390), rotation = 43.563, pitch = 0.0, roll = 0.0, size = {width = 0.100, length = 13.590}, line_width = 1.00, color_r = 0.90, color_g = 0.90, color_b = 0.90 },
    },
    noGoZones = {
        {
            position = vec3(-68.654, -0.005, -30.396),
            rotation = 299.950,
            size = {width = 0.100, length = 2.500}
        },
    },
    trajectoryGates = {
        {
            type = "trajectory",
            position = vec3(-96.608, -0.005, -61.594),
            rotation = 343.837,
            pitch = 0.0,
            roll = 0.0,
            size = {width = 0.100, length = 2.500}
        },
    },
    mapSettings = {
        scale = { x = 1.000, y = 1.000 },
        curvature = 1.000,
        rotation = 63.200,
        tension = -0.130,
        mergeDistance = 5.200,
        lineWidth = 72.200,
        startLine = {
            length = 26.700,
            angle = 0.000
        },
        finishLine = {
            length = 26.700,
            angle = 0.000
        }
    },
    squareSettings = {
        {
            index = 1,
            offset = vec2(0.000, 0.000),
            rotation = 321.539,
            size = {width = 40.000, height = 15.000},
            deleted = false
        },
        {
            index = 2,
            offset = vec2(16.000, -49.000),
            rotation = -37.300,
            size = {width = 21.000, height = 9.000},
            deleted = false
        },
        {
            index = 3,
            offset = vec2(23.000, -28.000),
            rotation = -173.400,
            size = {width = 21.000, height = 9.000},
            deleted = false
        },
        {
            index = 4,
            offset = vec2(26.000, -8.000),
            rotation = 21.900,
            size = {width = 18.000, height = 2.000},
            deleted = false
        },
        {
            index = 5,
            offset = vec2(11.000, -35.000),
            rotation = -4.400,
            size = {width = 18.000, height = 2.000},
            deleted = false
        },
        {
            index = 6,
            offset = vec2(-31.000, -7.000),
            rotation = -61.500,
            size = {width = 21.000, height = 9.000},
            deleted = false
        },
        {
            index = 7,
            offset = vec2(-35.000, -37.000),
            rotation = 0.000,
            size = {width = 21.000, height = 9.000},
            deleted = false
        },
        {
            index = 8,
            offset = vec2(0.000, 0.000),
            rotation = 133.563,
            size = {width = 40.000, height = 15.000},
            deleted = false
        },
        {
            index = 9,
            offset = vec2(27.000, -48.000),
            rotation = -131.700,
            size = {width = 14.000, height = 2.000},
            deleted = false
        },
    },
    mapTexts = {
        {
            text = "TG-1",
            position = vec2(-130.951, -7.327)
        },
        {
            text = "TG-2",
            position = vec2(-110.559, -30.339)
        },
        {
            text = "NG-1",
            position = vec2(-95.539, 10.781)
        },
        {
            text = "Start",
            position = vec2(-158.793, 111.884)
        },
        {
            text = "TG-3",
            position = vec2(-110.803, -112.202)
        },
        {
            text = "TG-4",
            position = vec2(-84.183, -116.729)
        },
        {
            text = "Finish",
            position = vec2(-79.931, -40.148)
        },
        {
            text = "OZ-1",
            position = vec2(-80.296, 11.158)
        },
        {
            text = "OZ-2",
            position = vec2(-90.657, -81.645)
        },
    },
    maxAllowedTransitions = 2,

    startPosition = vec3(-23.823, -0.005, 129.928),
    startRotation = -29.199,
    alternateStartPosition = vec3(-62.171, -0.005, 134.995),
    alternateStartRotation = 50.899,
    perfectEntrySpeed = 110,
    gatesTransparency = {
        normal = 1.0,
        start = 0.9,
        finish = 1.0,
        oz = 1.0,
        noGoZone = 1.0,
        trajectory = 1.0
    }
}