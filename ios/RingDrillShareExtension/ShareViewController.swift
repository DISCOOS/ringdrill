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
          if let url = item as? URL {
            self.saveToSharedContainer(fileURL: url)
            self.launchMainApp() // 🚀 Launch after saving
          }
          self.completeExtension()
        }
        return
      }
    }

    completeExtension()
  }

  private func saveToSharedContainer(fileURL: URL) {
    let fileManager = FileManager.default
    guard let sharedContainer = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.org.discoos.ringdrill.dev") else {
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

  // 🚀 STEP 4: Launch main app when extension finishes
  private func launchMainApp() {
    guard let url = URL(string: "ringdrill://import") else { return }

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
