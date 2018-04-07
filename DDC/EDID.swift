//
//  EDID.swift
//  DDC
//
//  Created by Markus Reiter on 28.03.18.
//  Copyright © 2018 Markus Reiter. All rights reserved.
//

import Cocoa
import Foundation

internal extension UInt16 {
  init?(_ bytes: [UInt8]) {
    guard bytes.count == 2 else {
      return nil
    }

    self.init(UnsafePointer(bytes).withMemoryRebound(to: UInt16.self, capacity: 1) { $0.pointee })
  }
}

internal extension UInt32 {
  init?(_ bytes: [UInt8]) {
    guard bytes.count == 4 else {
      return nil
    }

    self.init(UnsafePointer(bytes).withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee })
  }
}

internal extension UInt64 {
  init?(_ bytes: [UInt8]) {
    guard bytes.count == 8 else {
      return nil
    }

    self.init(UnsafePointer(bytes).withMemoryRebound(to: UInt64.self, capacity: 1) { $0.pointee })
  }
}

class EDID {
  private static let HEADER = 0x00ffffffffffff00

  enum Descriptor {
    case timing(IODetailedTimingInformation)
    case serialNumber(String)
    case text(String)
    case rangeLimits(String)
    case displayName(String)
  }

  struct StandardTimingInformation {
    let resolution: UInt8
    let aspectRatio: UInt8
    let verticalFrequency: UInt8

    init?(with data: [UInt8]) {
      if data[0] == 1 && data[1] == 1 {
        return nil
      }

      self.resolution = data[0]
      self.aspectRatio = data[1] >> 6
      self.verticalFrequency = data[1] & 0b111111
    }
  }

  let rawValue: [UInt8]

  lazy var header: UInt64 = { [unowned self] in UInt64(Array(self.rawValue[0...7]))! }()

  lazy var manufacturerId: UInt16 = { [unowned self] in UInt16([self.rawValue[9], self.rawValue[8]])! }()
  lazy var productCode: UInt16 = { [unowned self] in UInt16(Array(self.rawValue[10...11]))! }()
  lazy var serialNumber: UInt32 = { [unowned self] in UInt32(Array(self.rawValue[12...15]))! }()

  lazy var week: UInt8 = { [unowned self] in self.rawValue[16] }()
  lazy var year: Int = { [unowned self] in 1990 + Int(self.rawValue[17]) }()

  lazy var edidVersion: UInt8 = { [unowned self] in self.rawValue[18] }()
  lazy var edidRevision: UInt8 = { [unowned self] in self.rawValue[19] }()

  lazy var videoInputParameters: UInt8 = { [unowned self] in self.rawValue[20] }()

  lazy var screenWidth: Measurement? = { [unowned self] in
    if self.rawValue[21] == 0 {
      return nil
    }

    return Measurement(value: Double(self.rawValue[21]), unit: UnitLength.centimeters)
  }()
  lazy var screenHeight: Measurement? = { [unowned self] in
    if self.rawValue[22] == 0 {
      return nil
    }

    return Measurement(value: Double(self.rawValue[22]), unit: UnitLength.centimeters)
  }()
  lazy var aspectRatio: Float? = { [unowned self] in
    if self.screenWidth != nil, self.screenHeight == nil {
      let landscapeAspectRatio = Float(self.rawValue[21]) * 2.54 + 1.0
      return landscapeAspectRatio
    }

    if self.screenHeight != nil, self.screenWidth == nil {
      let portraitAspectRatio = Float(self.rawValue[22]) * 0.71 + 0.28
      let landscapeAspectRatio = 1.0 / portraitAspectRatio
      return landscapeAspectRatio
    }

    return nil
  }()

  lazy var gamma: Float = { [unowned self] in ((Float(self.rawValue[23]) / 255.0 * 2.54 + 1.0) * 100.0).rounded() / 100.0 }()

  lazy var features: UInt8 = { [unowned self] in self.rawValue[24] }()

  lazy var redAndGreenLeastSignificantBits: UInt8 = { [unowned self] in self.rawValue[25] }()
  lazy var blueAndWhiteLeastSignificantBits: UInt8 = { [unowned self] in self.rawValue[26] }()
  lazy var redXValueMostSignificantBits: UInt8 = { [unowned self] in self.rawValue[27] }()
  lazy var redYValueMostSignificantBits: UInt8 = { [unowned self] in self.rawValue[28] }()
  lazy var greenXValueMostSignificantBits: UInt8 = { [unowned self] in self.rawValue[29] }()
  lazy var greenYValueMostSignificantBits: UInt8 = { [unowned self] in self.rawValue[30] }()
  lazy var blueXValueMostSignificantBits: UInt8 = { [unowned self] in self.rawValue[31] }()
  lazy var blueYValueMostSignificantBits: UInt8 = { [unowned self] in self.rawValue[32] }()
  lazy var whitePointXValueMostSignificantBits: UInt8 = { [unowned self] in self.rawValue[33] }()
  lazy var whitePointYValueMostSignificantBits: UInt8 = { [unowned self] in self.rawValue[34] }()

  lazy var timing720x400At70Hz: Bool   = { [unowned self] in self.rawValue[35] & 0b10000000 == 1 }()
  lazy var timing720x400At88Hz: Bool   = { [unowned self] in self.rawValue[35] & 0b01000000 == 1 }()
  lazy var timing640x480At60Hz: Bool   = { [unowned self] in self.rawValue[35] & 0b00100000 == 1 }()
  lazy var timing640x480At67Hz: Bool   = { [unowned self] in self.rawValue[35] & 0b00010000 == 1 }()
  lazy var timing640x480At72Hz: Bool   = { [unowned self] in self.rawValue[35] & 0b00001000 == 1 }()
  lazy var timing640x480At75Hz: Bool   = { [unowned self] in self.rawValue[35] & 0b00000100 == 1 }()
  lazy var timing800x600At56Hz: Bool   = { [unowned self] in self.rawValue[35] & 0b00000010 == 1 }()
  lazy var timing800x600At60Hz: Bool   = { [unowned self] in self.rawValue[35] & 0b00000001 == 1 }()

  lazy var timing800x600At72Hz: Bool   = { [unowned self] in self.rawValue[36] & 0b10000000 == 1 }()
  lazy var timing800x600At75Hz: Bool   = { [unowned self] in self.rawValue[36] & 0b01000000 == 1 }()
  lazy var timing832x624At75Hz: Bool   = { [unowned self] in self.rawValue[36] & 0b00100000 == 1 }()
  lazy var timing1024x768At87Hz: Bool  = { [unowned self] in self.rawValue[36] & 0b00010000 == 1 }()
  lazy var timing1024x768At60Hz: Bool  = { [unowned self] in self.rawValue[36] & 0b00001000 == 1 }()
  lazy var timing1024x768At72Hz: Bool  = { [unowned self] in self.rawValue[36] & 0b00000100 == 1 }()
  lazy var timing1024x768At75Hz: Bool  = { [unowned self] in self.rawValue[36] & 0b00000010 == 1 }()
  lazy var timing1280x1024At75Hz: Bool = { [unowned self] in self.rawValue[36] & 0b00000001 == 1 }()

  lazy var timing1152x870At75Hz: Bool  = { [unowned self] in self.rawValue[37] & 0b10000000 == 1 }()
  lazy var timingModeA: Bool           = { [unowned self] in self.rawValue[37] & 0b01000000 == 1 }()
  lazy var timingModeB: Bool           = { [unowned self] in self.rawValue[37] & 0b00100000 == 1 }()
  lazy var timingModeC: Bool           = { [unowned self] in self.rawValue[37] & 0b00010000 == 1 }()
  lazy var timingModeD: Bool           = { [unowned self] in self.rawValue[37] & 0b00001000 == 1 }()
  lazy var timingModeE: Bool           = { [unowned self] in self.rawValue[37] & 0b00000100 == 1 }()
  lazy var timingModeF: Bool           = { [unowned self] in self.rawValue[37] & 0b00000010 == 1 }()
  lazy var timingModeG: Bool           = { [unowned self] in self.rawValue[37] & 0b00000001 == 1 }()

  lazy var standardDisplayModes: (StandardTimingInformation?, StandardTimingInformation?, StandardTimingInformation?, StandardTimingInformation?, StandardTimingInformation?, StandardTimingInformation?, StandardTimingInformation?, StandardTimingInformation?) = { [unowned self] in
    (
      StandardTimingInformation(with: Array(self.rawValue[38...39])),
      StandardTimingInformation(with: Array(self.rawValue[40...41])),
      StandardTimingInformation(with: Array(self.rawValue[42...43])),
      StandardTimingInformation(with: Array(self.rawValue[44...45])),
      StandardTimingInformation(with: Array(self.rawValue[46...47])),
      StandardTimingInformation(with: Array(self.rawValue[48...49])),
      StandardTimingInformation(with: Array(self.rawValue[50...51])),
      StandardTimingInformation(with: Array(self.rawValue[52...53]))
    )
  }()

  lazy var descriptors: (Descriptor, Descriptor, Descriptor, Descriptor) =  { [unowned self] in
    (
      EDID.detailedTimingInformation(from: Array(self.rawValue[54...71])),
      EDID.detailedTimingInformation(from: Array(self.rawValue[72...89])),
      EDID.detailedTimingInformation(from: Array(self.rawValue[90...107])),
      EDID.detailedTimingInformation(from: Array(self.rawValue[108...125]))
    )
  }()

  lazy var extensions: UInt8 = { [unowned self] in self.rawValue[126] }()

  lazy var checksum: UInt8 = { [unowned self] in self.rawValue[0...127].reduce(UInt8(0)) { $0.addingReportingOverflow($1).partialValue } }()

  init?(data: [UInt8]) {
    guard data.count >= 128 else {
      return nil
    }

    self.rawValue = data

    guard self.header == EDID.HEADER else {
      return nil
    }

    guard self.checksum == 0 else {
      return nil
    }
  }

  func manufacturerString() -> String {
    let offset = UInt16("A".unicodeScalars.first!.value - 1)

    let letter1 = self.manufacturerId >> 10 & 0b11111 + offset
    let letter2 = self.manufacturerId >>  5 & 0b11111 + offset
    let letter3 = self.manufacturerId >>  0 & 0b11111 + offset

    return String(format: "%c%c%c", letter1, letter2, letter3)
  }

  func edidVersionString() -> String {
    return "\(self.edidVersion).\(self.edidRevision)"
  }

  private static func parseDescriptorString(_ data: [UInt8]) -> String {
    var string = ""

    for c in data[5...17] {
      let char = Character(UnicodeScalar(c))

      if char == "\n" {
        break
      }

      string.append(char)
    }

    return string
  }

  private static func detailedTimingInformation(from data: [UInt8]) -> Descriptor {
    let pixelClock = UnsafePointer(Array(data[0...1])).withMemoryRebound(to: UInt16.self, capacity: 1) { $0.pointee }

    if pixelClock == 0 {
      let type = data[3]

      switch type {
      case 0xFF:
        return Descriptor.serialNumber(parseDescriptorString(data))
      case 0xFE:
        return Descriptor.text(parseDescriptorString(data))
      case 0xFD:
        return Descriptor.rangeLimits("")
      case 0xFC:
        return Descriptor.displayName(parseDescriptorString(data))
      default: break

      }
    }

    var timingInformation = IODetailedTimingInformation()

    timingInformation.pixelClock = UInt64(pixelClock)

    timingInformation.horizontalActive = UnsafePointer([data[4] >> 4, data[2]]).withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }
    timingInformation.horizontalBlanking = UnsafePointer([data[4] & 0b1111, data[3]]).withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }

    timingInformation.verticalActive =  UnsafePointer([data[7] >> 4, data[5]]).withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }
    timingInformation.verticalBlanking =  UnsafePointer([data[7] & 0b1111, data[6]]).withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }


    timingInformation.horizontalSyncOffset = UnsafePointer([data[11] >> 6, data[8]]).withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }
    timingInformation.horizontalSyncPulseWidth = UnsafePointer([data[11] >> 4 & 0b11, data[9]]).withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }

    timingInformation.verticalSyncOffset = UInt32((data[10] >> 4) & 0b1111) | (UInt32((data[11] >> 2) & 0b11) << 4)
    timingInformation.verticalSyncPulseWidth = UInt32(data[10] & 0b1111) | (UInt32(data[11] & 0b11) << 4)

    timingInformation.horizontalScaled = UnsafePointer([data[14] >> 4, data[12]]).withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }
    timingInformation.verticalScaled = UnsafePointer([data[14] & 0b1111, data[13]]).withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }

    timingInformation.horizontalBorderLeft = UInt32(data[15])
    timingInformation.horizontalBorderRight = UInt32(data[15])

    timingInformation.verticalBorderTop = UInt32(data[16])
    timingInformation.verticalBorderBottom = UInt32(data[16])

    return Descriptor.timing(timingInformation)
  }
}

