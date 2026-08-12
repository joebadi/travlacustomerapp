import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:url_launcher/url_launcher.dart';

/// Views a vehicle/policy document INSIDE the app — a native PDF reader
/// (pinch-zoom, page count) for PDFs and a pinch-zoom image viewer for
/// photos — instead of handing off to the device's browser. The URL is a
/// short-lived Laravel signed URL, so it needs no auth header to fetch.
class DocumentViewerScreen extends ConsumerStatefulWidget {
  const DocumentViewerScreen({
    super.key,
    required this.url,
    required this.title,
    this.mimeType,
  });

  final String url;
  final String title;
  final String? mimeType;

  @override
  ConsumerState<DocumentViewerScreen> createState() =>
      _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  PdfControllerPinch? _pdfController;
  bool _loading = true;
  String? _error;

  bool get _isPdf {
    final mime = widget.mimeType?.toLowerCase() ?? '';
    if (mime.contains('pdf')) return true;
    if (mime.startsWith('image/')) return false;
    return widget.url.toLowerCase().contains('.pdf');
  }

  bool get _isImage {
    final mime = widget.mimeType?.toLowerCase() ?? '';
    if (mime.startsWith('image/')) return true;
    if (_isPdf) return false;
    final lower = widget.url.toLowerCase();
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png');
  }

  @override
  void initState() {
    super.initState();
    if (_isPdf) {
      _loadPdf();
    } else {
      // Images load through the network Image widget itself.
      _loading = false;
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _loadPdf() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(apiClientProvider).dio.get<List<int>>(
        widget.url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(response.data ?? const []);
      if (!mounted) return;
      setState(() {
        _pdfController = PdfControllerPinch(
          document: PdfDocument.openData(bytes),
        );
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'This document could not be loaded.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _openExternally() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.forest950,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Open externally',
            onPressed: _openExternally,
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _isPdf ? _loadPdf : null);
    }
    if (_isPdf && _pdfController != null) {
      return Stack(
        children: [
          PdfViewPinch(controller: _pdfController!),
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: Center(child: _PageCounter(controller: _pdfController!)),
          ),
        ],
      );
    }
    if (_isImage) {
      return PhotoView(
        imageProvider: NetworkImage(widget.url),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        errorBuilder: (context, error, stackTrace) => _ErrorState(
          message: 'This image could not be loaded.',
          onRetry: null,
        ),
      );
    }
    return _ErrorState(
      message: "This file's format can't be previewed in the app.",
      onRetry: null,
    );
  }
}

class _PageCounter extends StatelessWidget {
  const _PageCounter({required this.controller});

  final PdfControllerPinch controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: controller.pageListenable,
      builder: (context, page, _) {
        final total = controller.pagesCount;
        if (total == null || total <= 1) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .6),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            'Page $page of $total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white70,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                ),
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
