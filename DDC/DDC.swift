import Cocoa
import Foundation
import IOKit
import os.log

public class DDC {
  public enum Command {
    case reset
    case resetBrighnessAndContrast
    case resetGeometry
    case resetColor
    case brightness
    case contrast
    case colorPresetA
    case redGain
    case greenGain
    case blueGain
    case autoSizeCenter
    case width
    case height
    case verticalPosition
    case horizontalPosition
    case pincushionAmp
    case pincushionPhase
    case keystoneBalance
    case pincushionBalance
    case topPincushionAmp
    case topPincushionBalance
    case bottomPincushionAmp
    case bottomPincushionBalance
    case verticalLinearity
    case verticalLinearityBalance
    case horizontalStaticConvergence
    case verticalStaticConvergence
    case moireCancel
    case inputSource
    case audioSpeakerVolume
    case redBlackLevel
    case greenBlackLevel
    case blueBlackLevel
    case orientation
    case audioMute
    case settings
    case onScreenDisplay
    case osdLanguage
    case dpms
    case colorPresetB
    case vcpVersion
    case colorPresetC
    case powerControl
    case topLeftScreenPurity
    case topRightScreenPurity
    case bottomLeftScreenPurity
    case bottomRightScreenPurity
    case sharpness
    case blackStabilizer

    public var value: UInt8 {
      switch self {
        case .reset:                       return 0x04
        case .resetBrighnessAndContrast:   return 0x05
        case .resetGeometry:               return 0x06
        case .resetColor:                  return 0x08
        case .brightness:                  return 0x10 // OK: LG 38UC99-W
        case .contrast:                    return 0x12 // OK: LG 38UC99-W
        case .colorPresetA:                return 0x14 // OK: Dell U2515H -> Presets: 4 = 5000K, 5 = 6500K, 6 = 7500K, 8 = 9300K, 9 = 10000K, 11 = 5700K, 12 = Custom Color
        case .redGain:                     return 0x16 // OK: LG 38UC99-W
        case .greenGain:                   return 0x18 // OK: LG 38UC99-W
        case .blueGain:                    return 0x1a // OK: LG 38UC99-W
        case .autoSizeCenter:              return 0x1e
        case .horizontalPosition:          return 0x20
        case .width:                       return 0x22
        case .pincushionAmp:               return 0x24
        case .pincushionBalance:           return 0x26
        case .horizontalStaticConvergence: return 0x28
        case .verticalStaticConvergence:   return 0x28
        case .verticalPosition:            return 0x30
        case .height:                      return 0x32
        case .pincushionPhase:             return 0x42
        case .keystoneBalance:             return 0x40
        case .topPincushionAmp:            return 0x46
        case .topPincushionBalance:        return 0x48
        case .bottomPincushionAmp:         return 0x4a
        case .bottomPincushionBalance:     return 0x4c
        case .verticalLinearity:           return 0x3a
        case .verticalLinearityBalance:    return 0x3c
        case .moireCancel:                 return 0x56
        case .inputSource:                 return 0x60
        case .audioSpeakerVolume:          return 0x62 // OK: LG 38UC99-W
        case .redBlackLevel:               return 0x6c // OK: LG 38UC99-W (not available from OSD)
        case .greenBlackLevel:             return 0x6e // OK: LG 38UC99-W (not available from OSD)
        case .blueBlackLevel:              return 0x70 // OK: LG 38UC99-W (not available from OSD)
        case .orientation:                 return 0xaa
        case .audioMute:                   return 0x8d
        case .settings:                    return 0xb0 // unsure on this one
        case .onScreenDisplay:             return 0xca // read only   -> returns '1' (OSD closed) or '2' (OSD active)
        case .osdLanguage:                 return 0xcc
        case .dpms:                        return 0xd6
        case .colorPresetB:                return 0xdC // Dell U2515H -> Presets: 0 = Standard, 2 = Multimedia, 3 = Movie, 5 = Game
        case .vcpVersion:                  return 0xdf
        case .colorPresetC:                return 0xe0 // Dell U2515H -> Brightness on/off (0 or 1)
        case .powerControl:                return 0xe1
        case .topLeftScreenPurity:         return 0xe8
        case .topRightScreenPurity:        return 0xe9
        case .bottomLeftScreenPurity:      return 0xea
        case .bottomRightScreenPurity:     return 0xeb
        case .sharpness:                   return 0x87 // OK: LG 38UC99-W
        case .blackStabilizer:             return 0xf9 // OK: LG 38UC99-W -> can only be set to 0
      }
    }
  }

  static var dispatchGroups: [CGDirectDisplayID: (DispatchQueue, DispatchGroup)] = [:]
  static var framebufferDispatchGroups: [io_service_t: (DispatchQueue, DispatchGroup)] = [:]

  let displayId: CGDirectDisplayID
  let framebuffer: io_service_t
  let replyTransactionType: IOOptionBits
  var enabled: Bool = false

  deinit {
    assert(IOObjectRelease(self.framebuffer) == KERN_SUCCESS)
  }

  public init?(for displayId: CGDirectDisplayID, withReplyTransactionType replyTransactionType: IOOptionBits? = nil) {
    self.displayId = displayId

    guard let framebuffer = DDC.ioFramebufferPortFromDisplayId(displayId: displayId) else {
      return nil
    }

    self.framebuffer = framebuffer

    if let replyTransactionType = replyTransactionType {
      self.replyTransactionType = replyTransactionType
    } else if let replyTransactionType = DDC.supportedTransactionType() {
      self.replyTransactionType = replyTransactionType
    } else {
      os_log("No supported reply transaction type found for display with ID %d.", type: .error, displayId)
      return nil
    }
  }

  public convenience init?(for screen: NSScreen, withReplyTransactionType replyTransactionType: IOOptionBits? = nil) {
    guard let displayId = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
      return nil
    }

    self.init(for: displayId, withReplyTransactionType: replyTransactionType)
  }

  public func write(command: Command, value: UInt8) -> Bool {
    return self.write(command: command.value, value: value)
  }

  public func write(command: UInt8, value: UInt8) -> Bool {
    let message: [UInt8] = [0x03, command, UInt8(value >> 8), UInt8(value & 0xFF)]
    var replyData: [UInt8] = []
    return self.sendMessage(message, replyData: &replyData, interval: 40000) != nil
  }

  public func enableAppReport(_ enable: Bool = true) -> Bool {
    let message: [UInt8] = [0xF5, enable ? 0x01 : 0x00]
    var replyData: [UInt8] = []

    guard self.sendMessage(message, replyData: &replyData) != nil else {
      return false
    }

    self.enabled = true
    return true
  }

  public func capability(minReplyDelay: UInt64? = nil) -> String? {
    var block_length = 0

    var cString: [UInt8] = []

    var tries = 0

    while true {
      let offset = cString.count
      let message: [UInt8] = [0xF3, UInt8(offset >> 8), UInt8(offset & 0xFF)]
      var replyData: [UInt8] = Array(repeating: 0, count: 38)

      guard self.sendMessage(message, replyData: &replyData, minReplyDelay: minReplyDelay, interval: 50000) != nil else {
        return nil
      }

      block_length = Int(replyData[1] & 0x7F) - 3

      if block_length < 0 {
        tries += 1

        if tries >= 3 {
          return nil
        }

        continue
      }

      tries = 0

      cString.append(contentsOf: replyData[5..<(block_length + 5)])

      if block_length < 32 {
        return String(cString: cString)
      }
    }
  }

  public func sendMessage(_ message: [UInt8], replyData: inout [UInt8] = [], minReplyDelay: UInt64? = nil, interval: UInt32 = 0) -> IOI2CRequest? {
    if DDC.dispatchGroups[self.displayId] == nil {
      DDC.dispatchGroups[self.displayId] = (DispatchQueue(label: "ddc-display-\(self.displayId)"), DispatchGroup())
    }

    let (queue, group) = DDC.dispatchGroups[self.displayId]!

    group.wait()
    group.enter()

    defer {
      queue.async {
        if interval > 0 {
          usleep(interval)
        }

        group.leave()
      }
    }

    var data: [UInt8] = [UInt8(0x51), UInt8(0x80 + message.count)] + message + [UInt8(0x6E)]

    for i in 0..<data.count {
      data[data.count - 1] ^= data[i]
    }

    var request = IOI2CRequest()

    request.commFlags = 0
    request.sendAddress = 0x6E
    request.sendTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
    request.sendBytes = UInt32(data.count)
    request.sendBuffer = withUnsafePointer(to: &data[0]) { vm_address_t(bitPattern: $0) }

    if replyData.count == 0 {
      request.replyTransactionType = IOOptionBits(kIOI2CNoTransactionType)
      request.replyBytes = 0
    } else {
      request.minReplyDelay = minReplyDelay ?? 10

      request.replyAddress = 0x6F
      request.replySubAddress = 0x51
      request.replyTransactionType = self.replyTransactionType
      request.replyBytes = UInt32(replyData.count)
      request.replyBuffer = withUnsafePointer(to: &replyData[0]) { vm_address_t(bitPattern: $0) }
    }

    guard DDC.send(request: &request, to: self.framebuffer) else {
      return nil
    }

    if replyData.count > 0 {
      let checksum = replyData.last!
      var calculated = UInt8(0x50)

      for i in 0..<(replyData.count - 1) {
        calculated ^= replyData[i]
      }

      guard checksum == calculated else {
        os_log("Checksum of reply does not match. Expected %d, got %d.", type: .error, checksum, calculated)
        return nil
      }
    }

    return request
  }

  // Send an “Identification Request” to check if DDC/CI is supported.
  public func supported() -> Bool {
    var replyData: [UInt8] = Array(repeating: 0, count: 3)

    guard let request = self.sendMessage([0xF1], replyData: &replyData) else {
      return false
    }

    // If a “Null Message” is returned, DDC/CI is supported.
    return replyData == [UInt8(request.sendAddress), 0x80, 0xBE]
  }

  public func read(command: Command, tries: UInt = 1, replyTransactionType: IOOptionBits? = nil, minReplyDelay: UInt64? = nil) -> (UInt16, UInt16)? {
    return self.read(command: command.value, tries: tries, replyTransactionType: replyTransactionType, minReplyDelay: minReplyDelay)
  }

  public func read(command: UInt8, tries: UInt = 1, replyTransactionType _: IOOptionBits? = nil, minReplyDelay: UInt64? = nil) -> (UInt16, UInt16)? {
    assert(tries > 0)

    let message: [UInt8] = [0x01, command]

    var replyData: [UInt8] = Array(repeating: 0, count: 11)

    for i in 1...tries {
      guard self.sendMessage(message, replyData: &replyData, minReplyDelay: minReplyDelay, interval: 40000) != nil else {
        continue
      }

      if replyData[2] != 0x02 {
        os_log("Got wrong response type for %{public}@. Expected %d, got %d.", type: .debug, String(reflecting: command), 0x02, replyData[2])
        continue
      }

      if replyData[3] != 0x00 {
        os_log("Reading %{public}@ is not supported.", type: .debug, String(reflecting: command))
        return nil
      }

      if i > 1 {
        os_log("Reading %{public}@ took %d tries.", type: .debug, String(reflecting: command), i)
      }

      let maxValue = UInt16(replyData[6] << 8) + UInt16(replyData[7])
      let currentValue = UInt16(replyData[8] << 8) + UInt16(replyData[9])
      return (currentValue, maxValue)
    }

    os_log("Reading %{public}@ failed.", type: .error, String(reflecting: command))
    return nil
  }

  private static func supportedTransactionType() -> IOOptionBits? {
    var ioIterator = io_iterator_t()

    guard IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceNameMatching("IOFramebufferI2CInterface"), &ioIterator) == KERN_SUCCESS else {
      return nil
    }

    defer {
      assert(IOObjectRelease(ioIterator) == KERN_SUCCESS)
    }

    while case let ioService = IOIteratorNext(ioIterator), ioService != 0 {
      var serviceProperties: Unmanaged<CFMutableDictionary>?

      guard IORegistryEntryCreateCFProperties(ioService, &serviceProperties, kCFAllocatorDefault, IOOptionBits()) == KERN_SUCCESS, serviceProperties != nil else {
        continue
      }

      let dict = serviceProperties!.takeRetainedValue() as NSDictionary

      if let types = dict[kIOI2CTransactionTypesKey] as? UInt64 {
        if (1 << kIOI2CDDCciReplyTransactionType) & types != 0 {
          os_log("kIOI2CDDCciReplyTransactionType is supported.", type: .debug)
          return IOOptionBits(kIOI2CDDCciReplyTransactionType)
        }

        if (1 << kIOI2CSimpleTransactionType) & types != 0 {
          os_log("kIOI2CSimpleTransactionType is supported.", type: .debug)
          return IOOptionBits(kIOI2CSimpleTransactionType)
        }
      }
    }

    return nil
  }

  static func send(request: inout IOI2CRequest, to framebuffer: io_service_t) -> Bool {
    if DDC.framebufferDispatchGroups[framebuffer] == nil {
      DDC.framebufferDispatchGroups[framebuffer] = (DispatchQueue(label: "ddc-framebuffer-\(framebuffer)"), DispatchGroup())
    }

    let (queue, group) = DDC.framebufferDispatchGroups[framebuffer]!

    group.wait()
    group.enter()

    defer {
      if request.replyTransactionType == kIOI2CNoTransactionType {
        queue.async {
          usleep(20000)
          group.leave()
        }
      } else {
        group.leave()
      }
    }

    var busCount: IOItemCount = 0

    guard IOFBGetI2CInterfaceCount(framebuffer, &busCount) == KERN_SUCCESS else {
      os_log("Failed to get interface count for framebuffer with ID %d.", type: .error, framebuffer)
      return false
    }

    for bus: IOOptionBits in 0..<busCount {
      var interface = io_service_t()

      guard IOFBCopyI2CInterfaceForBus(framebuffer, bus, &interface) == KERN_SUCCESS else {
        os_log("Failed to get interface %d for framebuffer with ID %d.", type: .error, bus, framebuffer)
        continue
      }

      var connect: IOI2CConnectRef?
      guard IOI2CInterfaceOpen(interface, IOOptionBits(), &connect) == KERN_SUCCESS else {
        os_log("Failed to connect to interface %d for framebuffer with ID %d.", type: .error, bus, framebuffer)
        continue
      }

      defer { IOI2CInterfaceClose(connect, IOOptionBits()) }

      guard IOI2CSendRequest(connect, IOOptionBits(), &request) == KERN_SUCCESS else {
        os_log("Failed to send request to interface %d for framebuffer with ID %d.", type: .error, bus, framebuffer)
        continue
      }

      guard request.result == KERN_SUCCESS else {
        os_log("Request to interface %d for framebuffer with ID %d failed.", type: .error, bus, framebuffer)
        continue
      }

      return true
    }

    return false
  }

  static func servicePort(from displayId: CGDirectDisplayID) -> io_object_t? {
    var servicePortIterator = io_iterator_t()

    let status: kern_return_t = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching(IOFRAMEBUFFER_CONFORMSTO), &servicePortIterator)

    guard status == KERN_SUCCESS else {
      os_log("No matching services found for display with ID %d.", type: .error, displayId)
      return nil
    }

    defer {
      assert(IOObjectRelease(servicePortIterator) == KERN_SUCCESS)
    }

    while case let servicePort = IOIteratorNext(servicePortIterator), servicePort != 0 {
      let dict = IODisplayCreateInfoDictionary(servicePort, IOOptionBits(kIODisplayOnlyPreferredName)).takeRetainedValue() as NSDictionary

      guard let vendorId = dict[kDisplayVendorID] as? CFIndex, CGDisplayVendorNumber(displayId) == vendorId else {
        continue
      }

      guard let productId = dict[kDisplayProductID] as? CFIndex, CGDisplayModelNumber(displayId) == productId else {
        continue
      }

      guard let serialNumber = dict[kDisplaySerialNumber] as? CFIndex, CGDisplaySerialNumber(displayId) == serialNumber else {
        continue
      }

      var name: io_name_t?
      let size = MemoryLayout.size(ofValue: name)
      if let framebufferName = (withUnsafeMutablePointer(to: &name) {
        $0.withMemoryRebound(to: Int8.self, capacity: size / MemoryLayout<Int8>.size) { (n) -> String? in
          guard IORegistryEntryGetName(servicePort, n) == kIOReturnSuccess else {
            return nil
          }

          return n.withMemoryRebound(to: CChar.self, capacity: size / MemoryLayout<CChar>.size) { String(cString: $0) }
        }
      }) {
        os_log("Framebuffer: %{public}@", type: .debug, framebufferName)
      }

      if let location = dict.object(forKey: kIODisplayLocationKey) as? String {
        os_log("Location: %{public}@", type: .debug, location)
      }

      os_log("Vendor ID: %d, Product ID: %d, Serial Number: %d", type: .debug, vendorId, productId, serialNumber)
      os_log("Unit Number: %d", type: .debug, CGDisplayUnitNumber(displayId))
      os_log("Service Port: %d", type: .debug, servicePort)

      return servicePort
    }

    os_log("No service port found for display with ID %d.", type: .error, displayId)
    return nil
  }

  static func ioFramebufferPortFromDisplayId(displayId: CGDirectDisplayID) -> io_service_t? {
    if CGDisplayIsBuiltin(displayId) == boolean_t(truncating: true) {
      return nil
    }

    guard let servicePort = self.servicePort(from: displayId) else {
      return nil
    }

    var busCount: IOItemCount = 0
    guard IOFBGetI2CInterfaceCount(servicePort, &busCount) == KERN_SUCCESS, busCount >= 1 else {
      os_log("No framebuffer port found for display with ID %d.", type: .error, displayId)
      return nil
    }

    return servicePort
  }

  public func edid() -> EDID? {
    guard let servicePort = DDC.servicePort(from: displayId) else {
      return nil
    }

    defer {
      assert(IOObjectRelease(servicePort) == KERN_SUCCESS)
    }

    let dict = IODisplayCreateInfoDictionary(servicePort, IOOptionBits(kIODisplayOnlyPreferredName)).takeRetainedValue() as NSDictionary

    if let displayEDID = dict["IODisplayEDIDOriginal"] as? Data {
      let bytes = [UInt8](displayEDID)
      return EDID(data: bytes)
    }

    os_log("No EDID entry found for display with ID %d.", type: .error, self.displayId)
    return nil
  }

  public func edidOld() -> EDID? {
    let receiveBytes = { (count: Int, offset: UInt8) -> [UInt8]? in
      var data: [UInt8] = [offset]
      var replyData: [UInt8] = Array(repeating: 0, count: count)

      var request = IOI2CRequest()

      request.sendAddress = 0xA0
      request.sendTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
      request.sendBuffer = withUnsafePointer(to: &data[0]) { UInt(bitPattern: $0) }
      request.sendBytes = UInt32(data.count)

      request.replyAddress = 0xA1
      request.replyTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
      request.replyBuffer = withUnsafePointer(to: &replyData[0]) { UInt(bitPattern: $0) }
      request.replyBytes = UInt32(replyData.count)

      guard DDC.send(request: &request, to: self.framebuffer) else {
        return nil
      }

      return replyData
    }

    guard let edidData = receiveBytes(128, 0) else {
      os_log("Failed receiving EDID for display with ID %d.", type: .error, self.displayId)
      return nil
    }

    let extensions = Int(edidData[126])

    if extensions > 0 {
      guard let extensionData = receiveBytes(128 * extensions, 128) else {
        os_log("Failed receiving EDID extensions for display with ID %d.", type: .error, self.displayId)
        return nil
      }

      return EDID(data: edidData + extensionData)
    }

    return EDID(data: edidData)
  }
}
