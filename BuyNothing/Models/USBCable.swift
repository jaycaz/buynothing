import Foundation

enum USBCableType: String, CaseIterable, Codable {
    case usbA = "USB-A"
    case usbC = "USB-C"
    case lightning = "Lightning"
    case microUSB = "Micro-USB"
    case miniUSB = "Mini-USB"
    case usb30 = "USB 3.0"
    case thunderbolt = "Thunderbolt"
    
    var displayName: String {
        return self.rawValue
    }
    
    var maxSpeed: String {
        switch self {
        case .usbA: return "480 Mbps"
        case .usbC: return "10 Gbps"
        case .lightning: return "480 Mbps"
        case .microUSB: return "480 Mbps"
        case .miniUSB: return "480 Mbps"
        case .usb30: return "5 Gbps"
        case .thunderbolt: return "40 Gbps"
        }
    }
}

enum USBCableLength: String, CaseIterable, Codable {
    case short = "< 1ft"
    case medium = "1-3ft"
    case long = "3-6ft"
    case extraLong = "> 6ft"
    case unknown = "Unknown"
}

enum USBCableCondition: String, CaseIterable, Codable {
    case new = "New"
    case likeNew = "Like New"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
}

struct USBCable: Identifiable, Codable {
    let id = UUID()
    var connectorType1: USBCableType
    var connectorType2: USBCableType?
    var length: USBCableLength
    var condition: USBCableCondition
    var color: String
    var brand: String?
    var notes: String?
    var imageData: Data?
    var dateAdded: Date
    var isAvailable: Bool
    
    init(
        connectorType1: USBCableType,
        connectorType2: USBCableType? = nil,
        length: USBCableLength = .unknown,
        condition: USBCableCondition = .good,
        color: String = "Black",
        brand: String? = nil,
        notes: String? = nil,
        imageData: Data? = nil
    ) {
        self.connectorType1 = connectorType1
        self.connectorType2 = connectorType2
        self.length = length
        self.condition = condition
        self.color = color
        self.brand = brand
        self.notes = notes
        self.imageData = imageData
        self.dateAdded = Date()
        self.isAvailable = true
    }
    
    var displayName: String {
        if let type2 = connectorType2 {
            return "\(connectorType1.displayName) to \(type2.displayName)"
        } else {
            return connectorType1.displayName
        }
    }
    
    var description: String {
        var desc = displayName
        if length != .unknown {
            desc += " (\(length.rawValue))"
        }
        if let brand = brand {
            desc += " - \(brand)"
        }
        return desc
    }
}