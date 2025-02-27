//  Copyright © 2019 The nef Authors.

import AppKit
import Markup

class CarbonAppDelegate: NSObject, NSApplicationDelegate {
    private let main: (CarbonDownloader) -> Void
    private let carbonWebView: CarbonWebView
    private let downloader: CarbonDownloader
    private let queue: DispatchQueue
    
    private let window = NSWindow(contentRect: CarbonScreen.bounds,
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered,
                                  defer: true,
                                  screen: CarbonScreen())
    
    init(main: @escaping (CarbonDownloader) -> Void, provider: CarbonProvider) {
        self.carbonWebView = CarbonWebView(frame: CarbonScreen.bounds)
        self.main = main
        self.downloader = provider.resolveCarbonDownloader(view: carbonWebView)
        self.queue = DispatchQueue(label: String(describing: CarbonAppDelegate.self), qos: .userInitiated)
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window.contentView?.addSubview(carbonWebView)
        
        queue.async { // the whole CLI will run in our thread
            self.main(self.downloader)
        }
    }
    
    // MARK: private classes
    private class CarbonScreen: NSScreen {
        static let bounds = NSRect(x: 0, y: 0, width: 5000, height: 15000)
        
        override var frame: NSRect { return CarbonScreen.bounds }
        override var visibleFrame: NSRect { return CarbonScreen.bounds }
    }
}
