local LocalGates = require('local_gates')

return {
    gates = {
    },
    noGoZones = {
    },
    trajectoryGates = {
    },
    mapSettings = {
        scale = { x = 1.000, y = 1.000 },
        curvature = 1.000,
        rotation = 0.000,
        tension = -0.500,
        mergeDistance = 5.000,
        lineWidth = 60.000,
        startLine = {
            length = 20.000,
            angle = 0.000
        },
        finishLine = {
            length = 20.000,
            angle = 0.000
        }
    },
    maxAllowedTransitions = 99,

    startPosition = vec3(0.000, 0.000, 0.000),
    startRotation = 0.000,
    alternateStartPosition = vec3(0.000, 0.000, 0.000),
    alternateStartRotation = 0.000,
    perfectEntrySpeed = 120,
    gatesTransparency = {
        normal = 1.0,
        start = 1.0,
        finish = 1.0,
        oz = 1.0,
        noGoZone = 1.0,
        trajectory = 1.0
    }
}