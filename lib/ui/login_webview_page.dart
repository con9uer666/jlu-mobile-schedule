import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/school_provider.dart';

/// 通用学校教务登录 + 抓取 WebView。
/// 具体行为(入口 URL / UA / 登录判定 / 抓取脚本)全部由传入的 [provider] 决定。
///
/// pop 回来的 bundle 结构见 [SchoolProvider] 注释。
class SchoolLoginPage extends StatefulWidget {
  const SchoolLoginPage({super.key, required this.provider});

  final SchoolProvider provider;

  @override
  State<SchoolLoginPage> createState() => _SchoolLoginPageState();
}

class _SchoolLoginPageState extends State<SchoolLoginPage> {
  late final WebViewController _controller;
  bool _fetching = false;
  String _hint = '请用统一身份认证登录,成功后会自动抓课表';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(widget.provider.userAgent)
      ..addJavaScriptChannel(
        'JwappBridge',
        onMessageReceived: (msg) => _onBridgeMessage(msg.message),
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) {
          if (_fetching) return;
          if (widget.provider.isLoggedIn(url)) {
            unawaited(_runFetcher());
          }
        },
      ))
      ..loadRequest(Uri.parse(widget.provider.entryUrl));
  }

  Future<void> _runFetcher() async {
    _fetching = true;
    setState(() => _hint = '登录成功,正在抓取课表...');
    try {
      await _controller.runJavaScript(widget.provider.fetcherScript);
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
                ],
              ),
            ),
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
      ),
    );
  }
}
