import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_tokens.dart';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen> {
  static final Uri _speedTestUri = Uri.parse('https://speedtest.tm.com.my/');

  late final WebViewController _controller;
  int _progress = 0;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            if (kDebugMode) {
              debugPrint(
                '[SpeedTest] resource error ${error.errorCode} '
                '"${error.description}" '
                'mainFrame=${error.isForMainFrame} url=${error.url}',
              );
            }
            // Only a failed main page should replace the screen with a message.
            if (error.isForMainFrame == true && mounted) {
              setState(() => _loadFailed = true);
            }
          },
          onHttpError: (error) {
            if (kDebugMode) {
              debugPrint(
                '[SpeedTest] http error ${error.response?.statusCode} '
                'url=${error.request?.uri}',
              );
            }
          },
          onProgress: (progress) {
            if (mounted) {
              setState(() => _progress = progress);
            }
          },
        ),
      )
      ..loadRequest(_speedTestUri);
  }

  void _reload() {
    setState(() => _loadFailed = false);
    _controller.reload();
  }

  void _retry() {
    setState(() => _loadFailed = false);
    _controller.loadRequest(_speedTestUri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCard,
      appBar: AppBar(
        title: const Text('Internet Speed Test'),
        actions: [
          IconButton(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload speed test',
            onPressed: _reload,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 100)
            LinearProgressIndicator(
              value: _progress / 100,
              minHeight: 4,
              color: AppColors.primary,
              backgroundColor: AppColors.primaryTint,
            ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loadFailed) SpeedTestErrorView(onRetry: _retry),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown over the page when the speed test fails to load.
class SpeedTestErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const SpeedTestErrorView({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceCard,
      width: double.infinity,
      height: double.infinity,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  liveRegion: true,
                  container: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppColors.cancelledBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.wifi_off_rounded,
                          size: 36,
                          color: AppColors.cancelledFg,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Could not load the speed test.',
                        textAlign: TextAlign.center,
                        style: AppText.title.copyWith(color: AppColors.ink),
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        'Check your internet connection and try again.',
                        textAlign: TextAlign.center,
                        style: AppText.body.copyWith(color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(160, 48),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
