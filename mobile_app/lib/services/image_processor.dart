import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageProcessor {
  /// Rotate image by degrees (90, 180, 270)
  static Uint8List rotate(Uint8List bytes, int degrees) {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;
    final rotated = img.copyRotate(image, angle: degrees.toDouble());
    return Uint8List.fromList(img.encodeJpg(rotated, quality: 92));
  }

  /// Flip horizontally
  static Uint8List flipHorizontal(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;
    final flipped = img.copyFlip(image, direction: img.FlipDirection.horizontal);
    return Uint8List.fromList(img.encodeJpg(flipped, quality: 92));
  }

  /// Flip vertically
  static Uint8List flipVertical(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;
    final flipped = img.copyFlip(image, direction: img.FlipDirection.vertical);
    return Uint8List.fromList(img.encodeJpg(flipped, quality: 92));
  }

  /// Crop image by normalized rectangle (x, y, w, h from 0.0 to 1.0)
  static Uint8List cropNormalized(
    Uint8List bytes, {
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    int cropX = (left * image.width).clamp(0, image.width - 1).toInt();
    int cropY = (top * image.height).clamp(0, image.height - 1).toInt();
    int cropW = (width * image.width).clamp(10, image.width - cropX).toInt();
    int cropH = (height * image.height).clamp(10, image.height - cropY).toInt();

    final cropped = img.copyCrop(
      image,
      x: cropX,
      y: cropY,
      width: cropW,
      height: cropH,
    );
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
  }

  /// Crop image to a standard aspect ratio (e.g. 1:1, 4:3, 16:9) centered
  static Uint8List cropToAspectRatio(Uint8List bytes, double targetRatio) {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    int origW = image.width;
    int origH = image.height;
    double currentRatio = origW / origH;

    int newW = origW;
    int newH = origH;

    if (currentRatio > targetRatio) {
      // Image is wider than target: trim width
      newW = (origH * targetRatio).toInt();
    } else {
      // Image is taller than target: trim height
      newH = (origW / targetRatio).toInt();
    }

    int startX = (origW - newW) ~/ 2;
    int startY = (origH - newH) ~/ 2;

    final cropped = img.copyCrop(
      image,
      x: startX,
      y: startY,
      width: newW,
      height: newH,
    );
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
  }

  /// Client-side fallback filter if API is not running
  static Uint8List applyFallbackFilter(Uint8List bytes, String filterType, double intensity) {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    img.Image result = image;
    switch (filterType.toLowerCase()) {
      case 'grayscale':
      case 'trắng đen':
        result = img.grayscale(image);
        break;
      case 'sepia':
        result = img.sepia(image, amount: intensity);
        break;
      case 'invert':
      case 'đảo màu':
        result = img.invert(image);
        break;
      case 'vivid_hdr':
      case 'vivi hdr':
        result = img.adjustColor(image, saturation: 1.4, contrast: 1.25);
        break;
      default:
        break;
    }
    return Uint8List.fromList(img.encodeJpg(result, quality: 90));
  }
}
