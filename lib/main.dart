import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 首页：必应。改这里就换起始页。
const String kHomeUrl = 'https://www.bing.com';
const String kAppName = '柒柒浏览器';
const Color kSeed = Color(0xFF0A84FF);

void main() {
  runApp(const QiqiBrowserApp());
}

class QiqiBrowserApp extends StatelessWidget {
  const QiqiBrowserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kSeed),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kSeed,
          brightness: Brightness.dark,
        ),
      ),
      home: const BrowserPage(),
    );
  }
}

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  late final WebViewController _controller;
  final TextEditingController _addr = TextEditingController();
  final FocusNode _addrFocus = FocusNode();

  double _progress = 0;
  bool _loading = true;
  bool _canBack = false;
  bool _canForward = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int p) {
            if (mounted) setState(() => _progress = p / 100);
          },
          onPageStarted: (String url) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _failed = false;
              _progress = 0;
            });
            if (!_addrFocus.hasFocus) _addr.text = url;
          },
          onPageFinished: (String url) async {
            if (!mounted) return;
            setState(() => _loading = false);
            if (!_addrFocus.hasFocus) _addr.text = url;
            await _syncNav();
          },
          onUrlChange: (UrlChange change) {
            final String? u = change.url;
            if (u != null && mounted && !_addrFocus.hasFocus) {
              setState(() => _addr.text = u);
            }
          },
          onWebResourceError: (WebResourceError error) {
            if ((error.isForMainFrame ?? false) && mounted) {
              setState(() {
                _loading = false;
                _failed = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(kHomeUrl));
  }

  @override
  void dispose() {
    _addr.dispose();
    _addrFocus.dispose();
    super.dispose();
  }

  Future<void> _syncNav() async {
    final bool b = await _controller.canGoBack();
    final bool f = await _controller.canGoForward();
    if (mounted) {
      setState(() {
        _canBack = b;
        _canForward = f;
      });
    }
  }

  /// 输入归一化：完整 URL 直接用；像域名的补 https；其余当搜索词。
  String? _normalize(String raw) {
    final String t = raw.trim();
    if (t.isEmpty) return null;
    if (t.startsWith('http://') ||
        t.startsWith('https://') ||
        t.startsWith('about:') ||
        t.startsWith('file:')) {
      return t;
    }
    final bool looksLikeHost = !t.contains(' ') && t.contains('.');
    if (looksLikeHost) return 'https://$t';
    return 'https://www.bing.com/search?q=${Uri.encodeComponent(t)}';
  }

  Future<void> _go(String raw) async {
    final String? url = _normalize(raw);
    if (url == null) return;
    _addrFocus.unfocus();
    setState(() {
      _failed = false;
      _loading = true;
    });
    await _controller.loadRequest(Uri.parse(url));
  }

  Future<void> _reload() async {
    setState(() {
      _failed = false;
      _loading = true;
    });
    await _controller.reload();
  }

  Future<void> _goBack() async {
    await _controller.goBack();
    await _syncNav();
  }

  Future<void> _goForward() async {
    await _controller.goForward();
    await _syncNav();
  }

  Future<void> _stop() async {
    // webview_flutter 4.14 移除了 stopLoading，用 JS 停掉页面资源加载。
    try {
      await _controller.runJavaScript('window.stop();');
    } catch (_) {
      // 页面还没就绪时忽略
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool dark = theme.brightness == Brightness.dark;
    final Color bg = dark ? const Color(0xFF121214) : const Color(0xFFFFFFFF);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _goBack();
        } else {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        body: Column(
          children: <Widget>[
            _addressBar(cs, dark),
            SizedBox(
              height: 2,
              child: _loading
                  ? LinearProgressIndicator(
                      value: (_progress <= 0 || _progress >= 1)
                          ? null
                          : _progress,
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                    )
                  : null,
            ),
            Expanded(
              child: _failed
                  ? _errorView(cs)
                  : WebViewWidget(controller: _controller),
            ),
            _toolbar(cs, dark),
          ],
        ),
      ),
    );
  }

  Widget _addressBar(ColorScheme cs, bool dark) {
    final Color fill = dark ? const Color(0xFF2B2B2F) : const Color(0xFFF2F2F5);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 6),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: <Widget>[
                    const SizedBox(width: 12),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _addr,
                      builder: (BuildContext context, TextEditingValue v, _) {
                        final bool secure =
                            v.text.trim().startsWith('https://');
                        return Icon(
                          secure
                              ? Icons.lock_outline_rounded
                              : Icons.public_rounded,
                          size: 15,
                          color: cs.onSurfaceVariant,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _addr,
                        focusNode: _addrFocus,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.go,
                        autocorrect: false,
                        enableSuggestions: false,
                        maxLines: 1,
                        style: const TextStyle(fontSize: 14.5),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                          border: InputBorder.none,
                          hintText: '搜索或输入网址',
                          hintStyle: TextStyle(fontSize: 14.5),
                        ),
                        onSubmitted: _go,
                        onTap: () {
                          _addr.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: _addr.text.length,
                          );
                        },
                      ),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _addr,
                      builder: (BuildContext context, TextEditingValue v, _) {
                        if (v.text.isEmpty) return const SizedBox(width: 10);
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: InkResponse(
                            radius: 16,
                            onTap: () => _addr.clear(),
                            child: Icon(
                              Icons.cancel,
                              size: 16,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _loading ? _stop : _reload,
              icon: Icon(
                _loading ? Icons.close_rounded : Icons.refresh_rounded,
                size: 20,
              ),
              tooltip: _loading ? '停止' : '刷新',
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(ColorScheme cs, bool dark) {
    Widget btn(
      IconData icon,
      bool enabled,
      VoidCallback onTap,
      String tip,
    ) {
      return IconButton(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 21),
        tooltip: tip,
        visualDensity: VisualDensity.compact,
        disabledColor: cs.onSurface.withValues(alpha: 0.22),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: dark ? Colors.white10 : Colors.black12,
              width: 0.6,
            ),
          ),
        ),
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              btn(Icons.arrow_back_ios_new_rounded, _canBack, _goBack, '后退'),
              btn(Icons.arrow_forward_ios_rounded, _canForward, _goForward, '前进'),
              btn(Icons.refresh_rounded, true, _reload, '刷新'),
              btn(Icons.home_outlined, true, () => _go(kHomeUrl), '首页'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorView(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.wifi_off_rounded, size: 56, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              '这个页面打不开',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '检查一下网址或网络连接',
              style: TextStyle(fontSize: 13.5, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: _reload,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
