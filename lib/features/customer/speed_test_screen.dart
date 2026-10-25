import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Internet Speed Test',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF005CAB),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
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
              color: const Color(0xFF005CAB),
            ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loadFailed)
                  Container(
                    color: const Color(0xFFF5F5F5),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          size: 56,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Could not load the speed test.\n'
                          'Check your internet connection and try again.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF005CAB),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
