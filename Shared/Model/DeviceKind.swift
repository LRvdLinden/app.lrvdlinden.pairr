import Foundation

/// What a device is; decides its icon.
enum DeviceKind: String, CaseIterable, Codable, Identifiable {
    case light, plug, lightSwitch, button, sensor, motion, contact, climate, lock,
         thermostat, camera, doorbell, bridge, speaker, blinds, smoke, fan,
         airPurifier, garage, tv, router, robot, other

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .light: "lightbulb.fill"
        case .plug: "powerplug.fill"
        case .lightSwitch: "lightswitch.on.fill"
        case .button: "button.programmable"
        case .sensor: "sensor.fill"
        case .motion: "figure.walk.motion"
        case .contact: "door.left.hand.open"
        case .climate: "thermometer.medium"
        case .lock: "lock.fill"
        case .thermostat: "heater.vertical.fill"
        case .camera: "web.camera.fill"
        case .doorbell: "bell.fill"
        case .bridge: "wifi.router.fill"
        case .speaker: "hifispeaker.fill"
        case .blinds: "blinds.horizontal.closed"
        case .smoke: "smoke.fill"
        case .fan: "fan.fill"
        case .airPurifier: "air.purifier.fill"
        case .garage: "door.garage.closed"
        case .tv: "tv.fill"
        case .router: "network"
        case .robot: "robotic.vacuum.fill"
        case .other: "cube.fill"
        }
    }

    var title: String {
        switch self {
        case .light: String(localized: "Light")
        case .plug: String(localized: "Smart plug")
        case .lightSwitch: String(localized: "Switch")
        case .button: String(localized: "Button")
        case .sensor: String(localized: "Sensor")
        case .motion: String(localized: "Motion sensor")
        case .contact: String(localized: "Door or window sensor")
        case .climate: String(localized: "Climate sensor")
        case .lock: String(localized: "Lock")
        case .thermostat: String(localized: "Thermostat")
        case .camera: String(localized: "Camera")
        case .doorbell: String(localized: "Doorbell")
        case .bridge: String(localized: "Bridge or hub")
        case .speaker: String(localized: "Speaker")
        case .blinds: String(localized: "Blinds or curtains")
        case .smoke: String(localized: "Smoke alarm")
        case .fan: String(localized: "Fan")
        case .airPurifier: String(localized: "Air purifier")
        case .garage: String(localized: "Garage door")
        case .tv: String(localized: "TV")
        case .router: String(localized: "Router or extender")
        case .robot: String(localized: "Robot vacuum")
        case .other: String(localized: "Other")
        }
    }

    /// HomeKit accessory category number, as in the X-HM:// setup payload.
    init?(homeKitCategory c: Int) {
        switch c {
        case 2: self = .bridge
        case 3: self = .fan
        case 4: self = .garage
        case 5: self = .light
        case 6: self = .lock
        case 7: self = .plug
        case 8: self = .lightSwitch
        case 9, 20, 21: self = .thermostat
        case 10: self = .sensor
        case 11: self = .camera
        case 12, 13: self = .contact
        case 14: self = .blinds
        case 15, 32: self = .button
        case 16: self = .router
        case 17: self = .camera
        case 18: self = .doorbell
        case 19, 22, 23: self = .airPurifier
        case 26, 27: self = .speaker
        case 31: self = .tv
        case 1: self = .other
        default: return nil
        }
    }
}
