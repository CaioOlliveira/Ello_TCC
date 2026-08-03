import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_palette.dart';

Future<Uint8List?> pickAvatarImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Selecionar da galeria'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Usar câmera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      );
    },
  );

  if (source == null) return null;

  try {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 90,
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
      throw const FormatException('Arquivo de imagem inválido.');
    }
    if (!context.mounted) return null;

    return showAvatarCropDialog(context, bytes);
  } catch (error) {
    if (!context.mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is FormatException
              ? error.message
              : 'Não foi possível selecionar a imagem.',
        ),
      ),
    );
    return null;
  }
}

Future<Uint8List?> showAvatarCropDialog(
  BuildContext context,
  Uint8List bytes,
) async {
  final image = await _decodeImage(bytes);
  if (!context.mounted) return null;

  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _AvatarCropDialog(image: image),
  );
}

Future<Uint8List> cropCenterSquare(Uint8List bytes) async {
  final image = await _decodeImage(bytes);
  final side = image.width < image.height ? image.width : image.height;
  final sourceLeft = ((image.width - side) / 2).roundToDouble();
  final sourceTop = ((image.height - side) / 2).roundToDouble();

  return _encodeCrop(
    image,
    Rect.fromLTWH(sourceLeft, sourceTop, side.toDouble(), side.toDouble()),
  );
}

class _AvatarCropDialog extends StatefulWidget {
  const _AvatarCropDialog({required this.image});

  final ui.Image image;

  @override
  State<_AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<_AvatarCropDialog> {
  static const _boxSize = 260.0;
  final _controller = TransformationController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerImage());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Size get _displaySize {
    final ratio = widget.image.width / widget.image.height;
    if (ratio >= 1) return Size(_boxSize * ratio, _boxSize);
    return Size(_boxSize, _boxSize / ratio);
  }

  void _centerImage() {
    if (!mounted) return;
    final size = _displaySize;
    _controller.value = Matrix4.identity()
      ..translateByDouble(
        (_boxSize - size.width) / 2,
        (_boxSize - size.height) / 2,
        0,
        1,
      );
  }

  Future<void> _usePhoto() async {
    setState(() => _saving = true);
    try {
      final cropped = await _cropFromTransform(
        widget.image,
        _controller.value,
        _displaySize,
        _boxSize,
      );
      if (mounted) Navigator.of(context).pop(cropped);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível ajustar a imagem.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displaySize = _displaySize;

    return AlertDialog(
      title: const Text('Ajustar foto'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox.square(
              dimension: _boxSize,
              child: DecoratedBox(
                decoration: BoxDecoration(color: adaptive(context, const Color(0xFFEAF5F6), AppDarkColors.tintedInfo)),
                child: InteractiveViewer(
                  constrained: false,
                  minScale: 1,
                  maxScale: 4,
                  boundaryMargin: const EdgeInsets.all(_boxSize),
                  transformationController: _controller,
                  child: SizedBox(
                    width: displaySize.width,
                    height: displaySize.height,
                    child: RawImage(
                      image: widget.image,
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Arraste e aproxime para enquadrar a foto.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: adaptive(context, const Color(0xFF5E6E72), AppDarkColors.textSecondary)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _usePhoto,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Usar foto'),
        ),
      ],
    );
  }
}

Future<Uint8List> _cropFromTransform(
  ui.Image image,
  Matrix4 transform,
  Size displaySize,
  double boxSize,
) {
  final inverse = Matrix4.inverted(transform);
  final childTopLeft = MatrixUtils.transformPoint(inverse, Offset.zero);
  final childBottomRight = MatrixUtils.transformPoint(
    inverse,
    Offset(boxSize, boxSize),
  );
  final visibleRect = Rect.fromPoints(childTopLeft, childBottomRight);
  final sourceRect = Rect.fromLTRB(
    visibleRect.left / displaySize.width * image.width,
    visibleRect.top / displaySize.height * image.height,
    visibleRect.right / displaySize.width * image.width,
    visibleRect.bottom / displaySize.height * image.height,
  );

  return _encodeCrop(
    image,
    _squareInsideImage(
      sourceRect,
      Size(image.width.toDouble(), image.height.toDouble()),
    ),
  );
}

Rect _squareInsideImage(Rect rect, Size imageSize) {
  final bounds = Offset.zero & imageSize;
  final clipped = rect.intersect(bounds);
  final fallbackSide = imageSize.shortestSide;
  final side = clipped.isEmpty
      ? fallbackSide
      : clipped.shortestSide.clamp(1.0, fallbackSide);
  final center = clipped.isEmpty ? bounds.center : clipped.center;
  final left = (center.dx - side / 2).clamp(0.0, imageSize.width - side);
  final top = (center.dy - side / 2).clamp(0.0, imageSize.height - side);

  return Rect.fromLTWH(left, top, side, side);
}

Future<Uint8List> _encodeCrop(ui.Image image, Rect sourceRect) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  canvas.drawImageRect(
    image,
    sourceRect,
    const Rect.fromLTWH(0, 0, 600, 600),
    Paint()..filterQuality = FilterQuality.high,
  );

  final picture = recorder.endRecording();
  final cropped = await picture.toImage(600, 600);
  final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
  if (data == null) throw const FormatException('Arquivo de imagem inválido.');

  return data.buffer.asUint8List();
}

Future<ui.Image> _decodeImage(Uint8List bytes) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(bytes, completer.complete);
  return completer.future;
}
