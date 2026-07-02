import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {

  override func isContentValid() -> Bool {
    return true
  }

  override func didSelectPost() {
    // Try to get the shared file
    guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
          let attachments = item.attachments else {
      completeExtension()
      return
    }

    for provider in attachments {
      let typeIdentifier = UTType.item.identifier  // General file support

      if provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
        provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { (item, error) in
          // The extension's activation rule (TRUEPREDICATE) means it shows up
          // for every share target. A "Share" on a chat link or the Web
          // Share API on the catalog page delivers a web URL or plain text,
          // not a file — route those to the app as a link (same outcome as
          // tapping the link directly) instead of falling through to the
          // file-copy path, which would otherwise write whatever unrelated
          // bytes it found into a bogus "shared.drill".
          if let url = item as? URL {
            if url.isFileURL {
              if self.looksLikeZip(url) {
                self.saveToSharedContainer(fileURL: url)
                self.launchMainApp() // 🚀 Launch after saving
              }
            } else if let link = self.extractRingDrillLink(url.absoluteString) {
              self.launchMainApp(link: link)
            }
          } else if let text = item as? String, let link = self.extractRingDrillLink(text) {
            self.launchMainApp(link: link)
          }
          self.completeExtension()
        }
        return
      }
    }

    completeExtension()
  }

  // Pull a ringdrill.app /i/ or /o/ link out of shared text or a shared web
  // URL. /d/ is excluded: it is the raw-download alias and has no
  // corresponding in-app route. Mirrors the Android extraction regex in
  // MainActivity.kt so both platforms resolve the same share the same way.
  private func extractRingDrillLink(_ text: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: #"https://ringdrill\.app/(?:i|o)/\S+"#) else {
      return nil
    }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, range: range),
          let matchRange = Range(match.range, in: text) else {
      return nil
    }
    var link = String(text[matchRange])
    let trailingPunctuation = CharacterSet(charactersIn: ".,)]\"'")
    while let last = link.unicodeScalars.last, trailingPunctuation.contains(last) {
      link.removeLast()
    }
    return link
  }

  // Cheap magic-byte sniff: every ZIP (and therefore every .drill archive)
  // starts with the "PK" signature.
  private func looksLikeZip(_ fileURL: URL) -> Bool {
    guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return false }
    defer { handle.closeFile() }
    let header = handle.readData(ofLength: 2)
    return header.count == 2 && header[0] == 0x50 && header[1] == 0x4B
  }

  private func saveToSharedContainer(fileURL: URL) {
    let fileManager = FileManager.default
    guard let sharedContainer = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.app.ringdrill.shared") else {
      print("Failed to get shared container URL")
      return
    }

    let destinationURL = sharedContainer.appendingPathComponent("shared.drill")

    do {
      if fileManager.fileExists(atPath: destinationURL.path) {
        try fileManager.removeItem(at: destinationURL)
      }
      try fileManager.copyItem(at: fileURL, to: destinationURL)
      print("Saved .drill file to shared container: \(destinationURL.path)")
    } catch {
      print("Failed to copy file: \(error)")
    }
  }

  // 🚀 STEP 4: Launch main app when extension finishes. A shared RingDrill
  // link rides along as a query param on the same `ringdrill://import`
  // scheme used for files — no App-Group round-trip needed since the link
  // is just a string, unlike a file's bytes. AppDelegate reads it back out
  // and forwards it to Flutter via `onSharedLink`.
  private func launchMainApp(link: String? = nil) {
    var urlString = "ringdrill://import"
    if let link, let encoded = link.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
      urlString += "?link=\(encoded)"
    }
    guard let url = URL(string: urlString) else { return }

    var responder: UIResponder? = self
    let selector = NSSelectorFromString("openURL:")

    while responder != nil {
      if responder?.responds(to: selector) == true {
        _ = responder?.perform(selector, with: url)
        print("Launching main app via URL scheme")
        break
      }
      responder = responder?.next
    }
  }

  private func completeExtension() {
    self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
  }

  override func configurationItems() -> [Any]! {
    return []
  }
}
