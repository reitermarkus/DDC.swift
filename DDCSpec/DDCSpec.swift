import XCTest

import Quick
import Nimble

import DDC

func ddcToEdid() {
  let displayID: CGDirectDisplayID = 0

  let ddc = DDC(for: displayID)!

  let edid = ddc.edid()!

  let _ = edid
}

class DDCSpec: QuickSpec {


}
