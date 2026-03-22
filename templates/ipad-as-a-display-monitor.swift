import AppKit
import Foundation
import IOKit

final class EventMonitor {
  private let reconnectScriptPath: String
  private let stateFilePath: String
  private let queue = DispatchQueue(label: "local.ipad-as-a-display.monitor")
  private var pendingReconnect: DispatchWorkItem?
  private var usbMatchedIterator: io_iterator_t = 0
  private var usbTerminatedIterator: io_iterator_t = 0
  private var notifyPort: IONotificationPortRef?

  init(reconnectScriptPath: String, stateFilePath: String) {
    self.reconnectScriptPath = reconnectScriptPath
    self.stateFilePath = stateFilePath
  }

  deinit {
    if usbMatchedIterator != 0 {
      IOObjectRelease(usbMatchedIterator)
    }
    if usbTerminatedIterator != 0 {
      IOObjectRelease(usbTerminatedIterator)
    }
    if let notifyPort {
      IONotificationPortDestroy(notifyPort)
    }
  }

  func start() {
    observeWake()
    observeUSBChanges()
    log("monitor started")
    scheduleReconnect(reason: "launch", delay: 2.0)
    RunLoop.main.run()
  }

  private func observeWake() {
    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification,
      object: nil,
      queue: nil
    ) { [weak self] _ in
      self?.log("wake detected")
      self?.scheduleReconnect(reason: "wake", delay: 2.0)
    }
  }

  private func observeUSBChanges() {
    guard let port = IONotificationPortCreate(kIOMainPortDefault) else {
      log("failed to create IOKit notification port")
      return
    }

    notifyPort = port

    if let source = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() {
      CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    let retainedSelf = Unmanaged.passUnretained(self).toOpaque()
    let matchedCallback: IOServiceMatchingCallback = { refcon, iterator in
      guard let refcon else { return }
      let monitor = Unmanaged<EventMonitor>.fromOpaque(refcon).takeUnretainedValue()
      monitor.drain(iterator)
      monitor.log("usb attach/change detected")
      monitor.scheduleReconnect(reason: "usb-attach", delay: 1.5)
    }
    let terminatedCallback: IOServiceMatchingCallback = { refcon, iterator in
      guard let refcon else { return }
      let monitor = Unmanaged<EventMonitor>.fromOpaque(refcon).takeUnretainedValue()
      monitor.drain(iterator)
      monitor.log("usb detach/change detected")
      monitor.setState("waiting-for-replug")
    }

    let matchedResult = IOServiceAddMatchingNotification(
      port,
      kIOMatchedNotification,
      IOServiceMatching("IOUSBHostDevice"),
      matchedCallback,
      retainedSelf,
      &usbMatchedIterator
    )

    if matchedResult == KERN_SUCCESS {
      drain(usbMatchedIterator)
    } else {
      log("failed to register usb matched notification: \(matchedResult)")
    }

    let terminatedResult = IOServiceAddMatchingNotification(
      port,
      kIOTerminatedNotification,
      IOServiceMatching("IOUSBHostDevice"),
      terminatedCallback,
      retainedSelf,
      &usbTerminatedIterator
    )

    if terminatedResult == KERN_SUCCESS {
      drain(usbTerminatedIterator)
    } else {
      log("failed to register usb terminated notification: \(terminatedResult)")
    }
  }

  private func drain(_ iterator: io_iterator_t) {
    while case let object = IOIteratorNext(iterator), object != 0 {
      IOObjectRelease(object)
    }
  }

  private func scheduleReconnect(reason: String, delay: TimeInterval) {
    queue.async { [weak self] in
      guard let self else { return }

      self.pendingReconnect?.cancel()

      let workItem = DispatchWorkItem { [weak self] in
        self?.runReconnect(reason: reason)
      }

      self.pendingReconnect = workItem
      self.queue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
  }

  private func runReconnect(reason: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = [reconnectScriptPath, "--reason", reason]

    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    do {
      try process.run()
      process.waitUntilExit()

      let output = readTrimmed(outputPipe.fileHandleForReading)
      let error = readTrimmed(errorPipe.fileHandleForReading)

      if !output.isEmpty {
        log(output)
      }
      if !error.isEmpty {
        log(error)
      }

      log("reconnect script finished with exit code \(process.terminationStatus) (\(reason))")
    } catch {
      log("failed to run reconnect script (\(reason)): \(error.localizedDescription)")
    }
  }

  private func readTrimmed(_ fileHandle: FileHandle) -> String {
    let data = fileHandle.readDataToEndOfFile()
    guard let string = String(data: data, encoding: .utf8) else {
      return ""
    }
    return string.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func setState(_ nextState: String) {
    do {
      try nextState.write(toFile: stateFilePath, atomically: true, encoding: .utf8)
    } catch {
      log("failed to update state file: \(error.localizedDescription)")
    }
  }

  private func log(_ message: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    print("\(formatter.string(from: Date())) [monitor] \(message)")
    fflush(stdout)
  }
}

let reconnectScriptPath = NSString(string: "~/Library/Application Support/ipad-as-a-display/ipad-as-a-display.sh").expandingTildeInPath
let stateFilePath = NSString(string: "~/Library/Application Support/ipad-as-a-display/last_state").expandingTildeInPath

signal(SIGTERM) { _ in
  exit(0)
}

let monitor = EventMonitor(reconnectScriptPath: reconnectScriptPath, stateFilePath: stateFilePath)
monitor.start()
