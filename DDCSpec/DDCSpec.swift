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
    describe(".servicePort()") {
      it("returns the service port") {
        guard let screen = NSScreen.main else {
          return
        }

        expect(DDC(for: screen)).notTo(beNil())
      }
    }
  }
}
