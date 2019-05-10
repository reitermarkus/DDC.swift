import XCTest

import Nimble
import Quick

@testable import DDC

func ddcToEdid() {
  let displayID: CGDirectDisplayID = 0

  let ddc = DDC(for: displayID)!

  let edid = ddc.edid()!

  _ = edid
}

class DDCSpec: QuickSpec {
  override func spec() {
    describe(".firmwareLevel()") {
      it("is not nil") {
        guard let screen = NSScreen.main else {
          fail("No screen found.")
          return
        }

        let firmware = DDC(for: screen)?.firmwareLevel(minReplyDelay: UInt64(20 * kMillisecondScale))
        expect(firmware).to(be("3.9"))
      }
    }

    describe(".vcpVersion()") {
      it("is not nil") {
        guard let screen = NSScreen.main else {
          fail("No screen found.")
          return
        }

        let version = DDC(for: screen)?.vcpVersion(minReplyDelay: UInt64(20 * kMillisecondScale))
        expect(version).to(be("2.1"))
      }
    }

    describe(".enableAppReport()") {
      it("is true") {
        guard let screen = NSScreen.main else {
          fail("No screen found.")
          return
        }

        expect(DDC(for: screen)?.enableAppReport()).to(beTrue())
      }
    }

    describe(".capability()") {
      it("is not nil") {
        guard let screen = NSScreen.main else {
          fail("No screen found.")
          return
        }

        expect(DDC(for: screen)?.capability(minReplyDelay: UInt64(20 * kMillisecondScale))).notTo(beNil())
      }
    }

    describe(".edid()") {
      it("is not nil") {
        guard let screen = NSScreen.main else {
          fail("No screen found.")
          return
        }

        expect(DDC(for: screen)?.edid()).notTo(beNil())
      }
    }

    describe(".edidOld()") {
      it("is not nil") {
        guard let screen = NSScreen.main else {
          fail("No screen found.")
          return
        }

        expect(DDC(for: screen)?.edidOld()).notTo(beNil())
      }
    }

    describe(".supported()") {
      it("is true") {
        guard let screen = NSScreen.main else {
          fail("No screen found.")
          return
        }

        expect(DDC(for: screen)?.supported()).to(beTrue())
      }
    }

    describe(".read()") {
      it("succeeds with a bunch of tries") {
        guard let screen = NSScreen.main else {
          fail("No screen found.")
          return
        }

        for _ in 0..<100 {
          var value = DDC(for: screen)?.read(command: .brightness, tries: 10, minReplyDelay: UInt64(20 * kMillisecondScale))
          expect(value).notTo(beNil())

          if value == nil {
            break
          }

          value = DDC(for: screen)?.read(command: .audioSpeakerVolume, tries: 10, minReplyDelay: UInt64(20 * kMillisecondScale))
          expect(value).notTo(beNil())

          if value == nil {
            break
          }
        }
      }
    }

    describe(".servicePort()") {
      it("returns the service port") {
        guard let screen = NSScreen.main else {
          fail("No screen found.")
          return
        }

        expect(DDC(for: screen)).notTo(beNil())
      }
    }
  }
}
