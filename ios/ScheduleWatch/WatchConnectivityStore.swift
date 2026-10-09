import Combine
import Foundation
import WatchConnectivity
import WatchKit
import WidgetKit
import os

final class WatchConnectivityStore: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityStore()
    @Published private(set) var schedule = WatchScheduleStore.load()
    @Published private(set) var status = "请在 iPhone 上打开课程表，完成首次同步"
    private let log = Logger(subsystem: "com.jlu.schedule.watchkitapp", category: "WatchSync")
    private var pendingTasks: [WKWatchConnectivityRefreshBackgroundTask] = []
    private var contentObservation: NSKeyValueObservation?

    override private init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        contentObservation = session.observe(\.hasContentPending, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.completeBackgroundTasks() }
        }
        session.activate()
    }

    func refresh() {
        if let cached = WatchScheduleStore.load() { schedule = cached }
        let session = WCSession.default
        guard session.activationState == .activated else { session.activate(); return }
        receive(session.receivedApplicationContext)
        guard session.isReachable else { return }
        session.sendMessage(["requestSchedule": true], replyHandler: { [weak self] reply in
            DispatchQueue.main.async { self?.receive(reply) }
        }, errorHandler: { [weak self] error in
            self?.log.debug("Phone request deferred: \(error.localizedDescription)")
        })
    }

    private func receive(_ context: [String: Any]) {
        guard let compressed = context[WatchScheduleTransport.payloadKey] as? Data else { return }
        do { try accept(WatchScheduleTransport.unpack(compressed)) }
        catch { failed(error) }
    }

    private func accept(_ data: Data) throws {
        let incoming = try WatchSchedule.decode(data)
        if let current = schedule, current.updatedAt >= incoming.updatedAt { return }
        schedule = try WatchScheduleStore.save(data)
        status = "已同步"
        WidgetCenter.shared.reloadTimelines(ofKind: WatchScheduleStore.widgetKind)
    }

    private func failed(_ error: Error) {
        status = "同步未完成，请打开 iPhone 课程表后重试"
        log.error("Schedule receive failed: \(error.localizedDescription)")
    }

    func handle(_ task: WKWatchConnectivityRefreshBackgroundTask) {
        pendingTasks.append(task)
        completeBackgroundTasks()
    }

    private func completeBackgroundTasks() {
        let session = WCSession.default
        guard session.activationState == .activated, !session.hasContentPending else { return }
        pendingTasks.forEach { $0.setTaskCompletedWithSnapshot(false) }
        pendingTasks.removeAll()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.refresh()
            self.completeBackgroundTasks()
        }
    }
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.refresh() }
    }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.receive(applicationContext)
            self.completeBackgroundTasks()
        }
    }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { self.receive(message) }
    }
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard file.metadata?["kind"] as? String == "schedule" else { return }
        // Read before returning: WatchConnectivity removes its temporary file.
        let result = Result { try Data(contentsOf: file.fileURL) }
        DispatchQueue.main.async {
            do { try self.accept(result.get()) }
            catch { self.failed(error) }
            self.completeBackgroundTasks()
        }
    }
}

final class ScheduleWatchDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() { _ = WatchConnectivityStore.shared }
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            if let connectivity = task as? WKWatchConnectivityRefreshBackgroundTask {
                WatchConnectivityStore.shared.handle(connectivity)
            } else {
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
