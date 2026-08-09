import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class RecaptchaChallenge extends StatefulWidget {
  const RecaptchaChallenge({required this.url, super.key});

  final String url;

  @override
  State<RecaptchaChallenge> createState() => _RecaptchaChallengeState();
}

class _RecaptchaChallengeState extends State<RecaptchaChallenge> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'TravlaRecaptcha',
        onMessageReceived: (message) {
          if (message.message.isNotEmpty && mounted) {
            Navigator.of(context).pop(message.message);
          }
        },
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Travla security check',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            trailing: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
