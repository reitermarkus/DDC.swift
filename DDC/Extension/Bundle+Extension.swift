import Foundation

extension Bundle {
  var bundleName: String? {
    return object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String
  }
}
