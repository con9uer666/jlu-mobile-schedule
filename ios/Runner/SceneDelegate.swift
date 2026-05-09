import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // 冷启动:App 因为 widget 点击被拉起时,url 在 connectionOptions.urlContexts 里。
    if let url = connectionOptions.urlContexts.first?.url {
      handleWidgetURL(url)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    // app 已经在后台时点 widget 走这里。
    if let url = URLContexts.first?.url {
      handleWidgetURL(url)
    }
    super.scene(scene, openURLContexts: URLContexts)
  }

  private func handleWidgetURL(_ url: URL) {
    guard let app = UIApplication.shared.delegate as? AppDelegate else { return }
    _ = app.application(UIApplication.shared, open: url, options: [:])
  }
}
