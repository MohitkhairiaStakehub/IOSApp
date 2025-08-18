import UserNotifications

final class NotificationService: UNNotificationServiceExtension {

  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var bestAttemptContent: UNMutableNotificationContent?

  override func didReceive(_ request: UNNotificationRequest,
                           withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    self.contentHandler = contentHandler
    bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

    guard let bestAttemptContent else {
      contentHandler(request.content)
      return
    }

    // Read your custom keys from APNs payload
    let userInfo = bestAttemptContent.userInfo
    let mediaURLString = userInfo["media-url"] as? String ?? ""
    guard let mediaURL = URL(string: mediaURLString), !mediaURLString.isEmpty else {
      contentHandler(bestAttemptContent) // no image => show plain alert
      return
    }

    // Download the image and attach
    URLSession.shared.downloadTask(with: mediaURL) { tempURL, _, _ in
      defer { self.contentHandler?(bestAttemptContent) }

      guard let tempURL else { return }
      let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
      let dst = tmpDir.appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(mediaURL.pathExtension.isEmpty ? "jpg" : mediaURL.pathExtension)
      do {
        try FileManager.default.moveItem(at: tempURL, to: dst)
        if let attachment = try? UNNotificationAttachment(identifier: "image", url: dst) {
          bestAttemptContent.attachments = [attachment]
        }
      } catch {
        // Ignore – will show the plain alert
      }
    }.resume()
  }

  override func serviceExtensionTimeWillExpire() {
    if let contentHandler, let bestAttemptContent {
      contentHandler(bestAttemptContent)
    }
  }
}
