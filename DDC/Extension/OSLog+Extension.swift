import OSLog

extension OSLog {
  private static var subsystem = Bundle.main.bundleIdentifier
  private static var category = Bundle(identifier: "DDC")?.bundleName ?? ""
  static let target = OSLog(subsystem: subsystem!, category: category)
}
