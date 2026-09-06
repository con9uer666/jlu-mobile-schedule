import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../data/school_provider.dart';

/// 通用学校教务登录 + 抓取 WebView。
/// 具体行为(入口 URL / UA / 登录判定 / 抓取脚本)全部由传入的 [provider] 决定。
///
/// pop 回来的 bundle 结构见 [SchoolProvider] 注释。
///
/// 用 flutter_inappwebview 而不是 webview_flutter 的原因:
/// 教务系统证书常见问题(国产 CA 未预置 / 域名错配)会让 WKWebView/Chromium
/// 直接白屏,webview_flutter 不暴露 SSL 错误回调。这里用 InAppWebView 的
/// onReceivedServerTrustAuthRequest 针对入口域名主动放行。
class SchoolLoginPage extends StatefulWidget {
  const SchoolLoginPage({super.key, required this.provider});

  final SchoolProvider provider;

  @override
  State<SchoolLoginPage> createState() => _SchoolLoginPageState();
}

class _SchoolLoginPageState extends State<SchoolLoginPage> {
  InAppWebViewController? _controller;
  bool _fetching = false;
  bool _loadError = false;
  int _progress = 0;
  String _hint = '请用统一身份认证登录,成功后会自动抓课表';
  late final String _trustRootHost;

  @override
  void initState() {
    super.initState();
    _trustRootHost = widget.provider.trustRootHost;
  }

  Future<void> _runFetcher() async {
    _fetching = true;
    setState(() => _hint = '登录成功,正在抓取课表...');
    try {
      await _controller?.evaluateJavascript(source: widget.provider.fetcherScript);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetching = false;
        _hint = '脚本注入失败:$e';
      });
    }
  }

  void _onBridgeMessage(String raw) {
    if (!mounted) return;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    if (decoded['ok'] != true) {
      setState(() {
        _fetching = false;
        _hint = '抓取失败:${decoded['error']}';
      });
      return;
    }
    Navigator.of(context).pop(decoded);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('登录 ${widget.provider.displayName}'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: CupertinoColors.systemGrey6.resolveFrom(context),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.info_circle, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _hint,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (_progress > 0 && _progress < 100)
                    Text(
                      '$_progress%',
                      style: const TextStyle(fontSize: 12),
                    ),
                  if (_loadError)
                    CupertinoButton(
                      padding: const EdgeInsets.only(left: 8),
                      minSize: 0,
                      onPressed: () {
                        setState(() {
                          _loadError = false;
                          _hint = '重试中...';
                        });
                        _controller?.reload();
                      },
                      child: const Text('重试', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: CupertinoColors.white,
                child: InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(widget.provider.entryUrl),
                  ),
                  initialSettings: InAppWebViewSettings(
                    userAgent: widget.provider.userAgent,
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                    useShouldOverrideUrlLoading: false,
                    transparentBackground: false,
                  ),
                  onWebViewCreated: (controller) {
                    _controller = controller;
                    controller.addJavaScriptHandler(
                      handlerName: 'JwappBridge',
                      callback: (args) {
                        if (args.isNotEmpty) {
                          _onBridgeMessage(args.first.toString());
                        }
                        return null;
                      },
                    );
                  },
                  onLoadStart: (_, url) {
                    if (!mounted) return;
                    setState(() {
                      _loadError = false;
                      _hint = '加载中:$url';
                    });
                  },
                  onLoadStop: (controller, url) async {
                    if (!mounted) return;
                    // 替换 webview_flutter 的 JavaScriptChannel(JwappBridge.postMessage)
                    // 为 InAppWebView 的 handler。注入一个 shim,让抓取脚本无需改写。
                    await controller.evaluateJavascript(source: '''
                      if (!window.JwappBridge) {
                        window.JwappBridge = {
                          postMessage: function(msg) {
                            window.flutter_inappwebview.callHandler('JwappBridge', msg);
                          }
                        };
                      }
                    ''');
                    if (!_fetching) {
                      setState(() => _hint = '已加载:$url');
                    }
                    if (_fetching) return;
                    if (widget.provider.isLoggedIn(url?.toString() ?? '')) {
                      unawaited(_runFetcher());
                    }
                  },
                  onProgressChanged: (_, p) {
                    if (!mounted) return;
                    setState(() => _progress = p);
                  },
                  onReceivedServerTrustAuthRequest: (_, challenge) async {
                    final host = challenge.protectionSpace.host;
                    // 放行信任根域及其所有子域,覆盖登录跳转链路(入口域 → SSO/CAS
                    // 子域),解决教务/统一认证证书 CA 缺失导致的信任挑战被取消。
                    if (host == _trustRootHost ||
                        host.endsWith('.$_trustRootHost')) {
                      return ServerTrustAuthResponse(
                        action: ServerTrustAuthResponseAction.PROCEED,
                      );
                    }
                    return ServerTrustAuthResponse(
                      action: ServerTrustAuthResponseAction.CANCEL,
                    );
                  },
                  onReceivedError: (_, request, error) {
                    if (!mounted) return;
                    if (!request.isForMainFrame!) return;
                    setState(() {
                      _fetching = false;
                      _loadError = true;
                      _hint = '页面加载失败(${error.type}):${error.description}';
                    });
                  },
                  onReceivedHttpError: (_, request, response) {
                    if (!mounted) return;
                    if (!request.isForMainFrame!) return;
                    setState(() {
                      _hint = 'HTTP ${response.statusCode}:${request.url}';
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
