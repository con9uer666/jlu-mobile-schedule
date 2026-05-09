import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 吉大教务登录 + 抓取 WebView。
///
/// 401 原因是关键 session cookie 是 HttpOnly,`document.cookie` 拿不到,
/// Dio 拿不全 cookie 就会 401。所以干脆在 WebView 里用 fetch 直接调接口,
/// 同源自带完整 cookie,证书也走系统信任链。Dart 端只解析结果。
class JlujwappLoginPage extends StatefulWidget {
  const JlujwappLoginPage({super.key});

  static const _entryUrl =
      'https://iedu.jlu.edu.cn/jwapp/sys/wdkb/*default/index.do?THEME=indigo&EMAP_LANG=zh';

  @override
  State<JlujwappLoginPage> createState() => _JlujwappLoginPageState();
}

class _JlujwappLoginPageState extends State<JlujwappLoginPage> {
  late final WebViewController _controller;
  bool _fetching = false;
  String _hint = '请用统一身份认证登录,成功后会自动抓课表';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
      )
      ..addJavaScriptChannel(
        'JwappBridge',
        onMessageReceived: (msg) => _onBridgeMessage(msg.message),
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) {
          if (_fetching) return;
          if (_isLoggedInUrl(url)) {
            unawaited(_runFetcher());
          }
        },
      ))
      ..loadRequest(Uri.parse(JlujwappLoginPage._entryUrl));
  }

  bool _isLoggedInUrl(String url) {
    if (!url.contains('iedu.jlu.edu.cn')) return false;
    if (url.contains('/jwapp/sys/wdkb/')) return true;
    return false;
  }

  Future<void> _runFetcher() async {
    _fetching = true;
    setState(() => _hint = '登录成功,正在抓取课表...');
    // 注入脚本后立刻执行。一次性把三个接口串起来,最后通过 Bridge 返回。
    try {
      await _controller.runJavaScript(_fetcherScript);
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

  static const _fetcherScript = r'''
(async () => {
  const post = async (path, body) => {
    const r = await fetch(path, {
      method: 'POST',
      credentials: 'include',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'X-Requested-With': 'XMLHttpRequest',
      },
      body: body || '',
    });
    if (!r.ok) throw new Error(path + ' HTTP ' + r.status);
    const j = await r.json();
    if (j.code !== '0' && j.code !== 0) {
      throw new Error(path + ' code=' + j.code);
    }
    return j;
  };
  try {
    const term = await post('/jwapp/sys/wdkb/modules/jshkcb/dqxnxq.do');
    const termRow = ((term.datas || {}).dqxnxq || {}).rows || [];
    if (!termRow.length) throw new Error('dqxnxq 空');
    const xnxqdm = termRow[0].DM;
    const termName = termRow[0].MC || '';
    const parts = xnxqdm.split('-');
    if (parts.length < 3) throw new Error('xnxqdm 格式 ' + xnxqdm);
    const xn = parts[0] + '-' + parts[1];
    const xq = parts[2];

    const meta = await post(
      '/jwapp/sys/wdkb/modules/jshkcb/cxjcs.do',
      'XN=' + encodeURIComponent(xn) + '&XQ=' + encodeURIComponent(xq)
    );
    const metaRow = ((meta.datas || {}).cxjcs || {}).rows || [];
    if (!metaRow.length) throw new Error('cxjcs 空');
    const ksrq = metaRow[0].XQKSRQ;
    const zzc = metaRow[0].ZZC;

    const sch = await post(
      '/jwapp/sys/wdkb/modules/xskcb/cxxszhxqkb.do',
      'XNXQDM=' + encodeURIComponent(xnxqdm)
    );
    const rows = ((sch.datas || {}).cxxszhxqkb || {}).rows || [];

    JwappBridge.postMessage(JSON.stringify({
      ok: true,
      xnxqdm: xnxqdm,
      termName: termName,
      startDate: ksrq,
      totalWeeks: zzc,
      rows: rows,
    }));
  } catch (e) {
    JwappBridge.postMessage(JSON.stringify({
      ok: false,
      error: (e && e.message) ? e.message : String(e),
    }));
  }
})();
''';

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('登录教务')),
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
