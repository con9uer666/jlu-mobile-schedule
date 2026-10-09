import Flutter
import AVFoundation
import Speech
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  private var pendingDeepLink: String?
  private var methodChannel: FlutterMethodChannel?
  private var speechChannel: FlutterMethodChannel?
  private var watchChannel: FlutterMethodChannel?
  private let audioEngine = AVAudioEngine()
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var speechResult: FlutterResult?
  private var silenceTimer: Timer?
  private var lastTranscript = ""
  private var hasAudioTap = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    PhoneWatchBridge.shared.start()
    if let url = launchOptions?[.url] as? URL {
      pendingDeepLink = deepLinkString(from: url)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if let deepLink = deepLinkString(from: url) {
      pendingDeepLink = deepLink
      methodChannel?.invokeMethod("onDeepLink", arguments: deepLink)
    }
    return super.application(app, open: url, options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let watchChannel = FlutterMethodChannel(
      name: "com.jlu.schedule/watch",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    watchChannel.setMethodCallHandler { call, result in
      guard call.method == "pushSchedule", let json = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        try PhoneWatchBridge.shared.publish(json)
        result(nil)
      } catch {
        result(FlutterError(code: "watch_sync", message: "无法同步手表课表", details: error.localizedDescription))
      }
    }
    self.watchChannel = watchChannel

    // iOS 26 Liquid Glass：让 Flutter window 背景透明，底层插入 UIVisualEffectView。
    // iOS 26 会自动将 UIBlurEffect(style: .systemMaterial) 升级为 Liquid Glass 渲染。
    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let window = scene.windows.first(where: { $0.isKeyWindow }),
       let rootVC = window.rootViewController {
      rootVC.view.backgroundColor = .clear
      let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
      blur.frame = rootVC.view.bounds
      blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      rootVC.view.insertSubview(blur, at: 0)
    }

    let channel = FlutterMethodChannel(
      name: "com.jlu.schedule/widget",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "consumeInitialDeepLink":
        let link = self?.pendingDeepLink
        self?.pendingDeepLink = nil
        result(link)
      case "consumeInitialCourseId":
        let id = self?.pendingDeepLink.flatMap { URL(string: $0) }.flatMap { self?.parseCourseId(from: $0) }
        self?.pendingDeepLink = nil
        result(id)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    methodChannel = channel

    let speechChannel = FlutterMethodChannel(
      name: "com.jlu.schedule/speech",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    speechChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "语音服务不可用", details: nil))
        return
      }
      switch call.method {
      case "recognize":
        self.requestSpeechPermissions { granted in
          DispatchQueue.main.async {
            if granted {
              self.startRecognition(result: result)
            } else {
              result(FlutterError(code: "permission_denied", message: "请在系统设置中允许麦克风和语音识别权限", details: nil))
            }
          }
        }
      case "stop":
        self.finishRecognition()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.speechChannel = speechChannel
  }

  private func requestSpeechPermissions(completion: @escaping (Bool) -> Void) {
    SFSpeechRecognizer.requestAuthorization { speechStatus in
      guard speechStatus == .authorized else {
        completion(false)
        return
      }
      AVAudioApplication.requestRecordPermission { microphoneGranted in
        completion(microphoneGranted)
      }
    }
  }

  private func startRecognition(result: @escaping FlutterResult) {
    finishRecognition(sendResult: false)
    lastTranscript = ""
    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")),
          recognizer.isAvailable else {
      result(FlutterError(code: "unavailable", message: "系统语音识别当前不可用", details: nil))
      return
    }

    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.record, mode: .measurement, options: .duckOthers)
      try session.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      result(FlutterError(code: "audio_session", message: "无法启动麦克风", details: error.localizedDescription))
      return
    }

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    recognitionRequest = request
    speechResult = result
    let input = audioEngine.inputNode
    let format = input.outputFormat(forBus: 0)
    input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
      request.append(buffer)
    }
    hasAudioTap = true
    recognitionTask = recognizer.recognitionTask(with: request) { [weak self] recognition, error in
      guard let self else { return }
      DispatchQueue.main.async {
        if let recognition {
          self.silenceTimer?.invalidate()
          let text = recognition.bestTranscription.formattedString
          self.lastTranscript = text
          if recognition.isFinal {
            self.finishRecognition(text: text)
          } else {
            self.silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.4, repeats: false) { [weak self] _ in
              self?.finishRecognition(text: text)
            }
          }
        } else if let error {
          self.finishRecognition(error: error)
        }
      }
    }
    do {
      audioEngine.prepare()
      try audioEngine.start()
    } catch {
      finishRecognition(error: error)
    }
  }

  private func finishRecognition(text: String? = nil, error: Error? = nil, sendResult: Bool = true) {
    silenceTimer?.invalidate()
    silenceTimer = nil
    if audioEngine.isRunning { audioEngine.stop() }
    if hasAudioTap {
      audioEngine.inputNode.removeTap(onBus: 0)
      hasAudioTap = false
    }
    recognitionRequest?.endAudio()
    recognitionTask?.cancel()
    recognitionRequest = nil
    recognitionTask = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    guard sendResult, let callback = speechResult else {
      if !sendResult { speechResult = nil }
      return
    }
    speechResult = nil
    let finalText = text ?? lastTranscript
    if let error, finalText.isEmpty {
      callback(FlutterError(code: "recognition_failed", message: "没有识别到语音，请重试", details: error.localizedDescription))
    } else {
      callback(finalText)
    }
  }

  private func parseCourseId(from url: URL) -> String? {
    guard url.scheme == "schedule" else { return nil }
    guard url.host == "course" else { return nil }
    let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
    return comps?.queryItems?.first(where: { $0.name == "id" })?.value
  }

  private func deepLinkString(from url: URL) -> String? {
    guard url.scheme == "schedule" else { return nil }
    return url.absoluteString
  }
}
