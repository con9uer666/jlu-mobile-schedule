import Foundation
import WatchConnectivity
import os

final class PhoneWatchBridge: NSObject, WCSessionDelegate {
    static let shared = PhoneWatchBridge()
    private let log = Logger(subsystem: "com.jlu.schedule", category: "WatchSync")
    private var latestData: Data?
    private var lastContent: NSDictionary?
    private var cacheURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("watch-schedule.json")
    }

    func start() {
        guard WCSession.isSupported() else { return }
        latestData = try? Data(contentsOf: cacheURL)
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func publish(_ json: String) throws {
        guard let data = json.data(using: .utf8) else { return }
        _ = try WatchSchedule.decode(data)
        var content = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        content.removeValue(forKey: "updatedAt")
        let identity = content as NSDictionary
        guard lastContent != identity else { return }
        try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: cacheURL, options: .atomic)
        latestData = data
        lastContent = identity
        sendLatest()
    }

    private func context() -> [String: Any]? {
        guard let data = latestData, let compressed = try? WatchScheduleTransport.pack(data), compressed.count < 60_000 else { return nil }
        return [WatchScheduleTransport.payloadKey: compressed]
    }

    private func sendLatest(force: Bool = false) {
        guard WCSession.isSupported(), latestData != nil else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        do {
            if let context = context() {
                if force || !NSDictionary(dictionary: session.applicationContext).isEqual(to: context) {
                    try session.updateApplicationContext(context)
                }
                if session.isReachable {
                    session.sendMessage(context, replyHandler: nil) { [weak self] error in
                        self?.log.debug("Immediate sync deferred: \(error.localizedDescription)")
                    }
                }
            } else if let data = latestData {
                // Immutable file for each queued transfer; never overwrite a
                // file still owned by WatchConnectivity.
                let directory = cacheURL.deletingLastPathComponent().appendingPathComponent("WatchTransfers")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let file = directory.appendingPathComponent(UUID().uuidString + ".json")
                try data.write(to: file, options: .atomic)
                for transfer in session.outstandingFileTransfers {
                    transfer.cancel()
                    try? FileManager.default.removeItem(at: transfer.file.fileURL)
                }
                session.transferFile(file, metadata: ["kind": "schedule"])
            }
        } catch {
            log.error("Watch sync failed: \(error.localizedDescription)")
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.sendLatest(force: true) }
    }
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.sendLatest(force: true) }
    }
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.sendLatest() }
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            guard message["requestSchedule"] as? Bool == true else { replyHandler([:]); return }
            if let context = self.context() {
                replyHandler(context)
            } else {
                replyHandler(["pending": true])
                self.sendLatest(force: true)
            }
        }
    }
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        try? FileManager.default.removeItem(at: fileTransfer.file.fileURL)
        if let error { log.error("Watch file transfer failed: \(error.localizedDescription)") }
    }
}
