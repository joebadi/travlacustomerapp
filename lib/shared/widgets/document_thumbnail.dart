import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';

/// Renders a real thumbnail of a stored document: an image straight from its
/// (signed) URL, or a PDF's first page rendered to a bitmap via pdfx (cached
/// across rebuilds). Falls back to a neutral document icon while loading or
/// when nothing can be rendered.
class DocumentThumbnail extends ConsumerStatefulWidget {
  const DocumentThumbnail({
    super.key,
    required this.url,
    required this.mime,
    this.width = double.infinity,
    this.iconSize = 26,
  });

  final String? url;
  final String? mime;
  final double width;
  final double iconSize;

  @override
  ConsumerState<DocumentThumbnail> createState() => _DocumentThumbnailState();
}

class _DocumentThumbnailState extends ConsumerState<DocumentThumbnail> {
  // Rendered first pages are cached so the (often-rebuilt) host doesn't refetch.
  static final Map<String, Uint8List> _pdfCache = {};
  Uint8List? _pdfBytes;
  bool _rendering = false;

  bool get _isPdf {
    final mime = widget.mime?.toLowerCase() ?? '';
    if (mime.contains('pdf')) return true;
    if (mime.startsWith('image/')) return false;
    return (widget.url ?? '').toLowerCase().contains('.pdf');
  }

  @override
  void initState() {
    super.initState();
    if (widget.url != null && _isPdf) _loadPdf();
  }

  @override
  void didUpdateWidget(covariant DocumentThumbnail old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _pdfBytes = null;
      if (widget.url != null && _isPdf) _loadPdf();
    }
  }

  Future<void> _loadPdf() async {
    final url = widget.url!;
    final cached = _pdfCache[url];
    if (cached != null) {
      setState(() => _pdfBytes = cached);
      return;
    }
    if (_rendering) return;
    _rendering = true;
    try {
      final response = await ref.read(apiClientProvider).dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final doc = await PdfDocument.openData(
        Uint8List.fromList(response.data ?? const []),
      );
      final page = await doc.getPage(1);
      final image = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.png,
      );
      await page.close();
      await doc.close();
      final bytes = image?.bytes;
      if (bytes != null) _pdfCache[url] = bytes;
      if (mounted) setState(() => _pdfBytes = bytes);
    } catch (_) {
      // Leave the fallback in place.
    } finally {
      _rendering = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url == null) return _fallback();

    if (_isPdf) {
      return _pdfBytes != null
          ? Image.memory(_pdfBytes!, fit: BoxFit.cover, width: widget.width)
          : _fallback();
    }

    return Image.network(
      widget.url!,
      fit: BoxFit.cover,
      width: widget.width,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _fallback(),
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6F8F7), Color(0xFFE7EEEA)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.description_outlined,
          color: AppColors.forest700,
          size: widget.iconSize,
        ),
      ),
    );
  }
}
