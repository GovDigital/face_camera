import 'dart:math' show min;

import 'package:flutter/material.dart';

import '../../face_camera.dart';
import '../res/app_images.dart';

class FacePainter extends CustomPainter {
  FacePainter(
      {required this.imageSize,
      this.face,
      required this.indicatorShape,
      this.indicatorAssetImage,
      this.isFaceWellPositioned = false,
      this.showDebugLandmarks = false,
      this.mirrorX = true});
  final Size imageSize;
  double? scaleX, scaleY;
  final Face? face;
  final IndicatorShape indicatorShape;
  final String? indicatorAssetImage;
  final bool isFaceWellPositioned;
  final bool showDebugLandmarks;

  /// Whether to mirror the x-axis. True on Android (preview is mirrored),
  /// false on iOS (preview uses raw sensor orientation).
  final bool mirrorX;

  /// Transforms a raw x-coordinate to screen space.
  double _tx(double x, double width) {
    return mirrorX ? width - x * scaleX! : x * scaleX!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    scaleX = size.width / imageSize.width;
    scaleY = size.height / imageSize.height;

    // Handle fixedFrame mode separately
    if (indicatorShape == IndicatorShape.fixedFrame) {
      _drawFixedFrame(canvas, size);
      // Don't return early - continue to draw debug landmarks if enabled
      if (showDebugLandmarks && face != null) {
        _drawDebugLandmarks(canvas, size);
      }
      return;
    }

    if (face == null) return;

    Paint paint;

    if (face!.headEulerAngleY! > 10 || face!.headEulerAngleY! < -10) {
      paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = Colors.red;
    } else {
      paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = Colors.green;
    }

    switch (indicatorShape) {
      case IndicatorShape.defaultShape:
        canvas.drawPath(
          _defaultPath(
              rect: face!.boundingBox,
              widgetSize: size,
              scaleX: scaleX,
              scaleY: scaleY,
              mirrorX: mirrorX),
          paint,
        );
        break;
      case IndicatorShape.square:
        canvas.drawRRect(
            _scaleRect(
                rect: face!.boundingBox,
                widgetSize: size,
                scaleX: scaleX,
                scaleY: scaleY,
                mirrorX: mirrorX),
            paint);
        break;
      case IndicatorShape.circle:
        canvas.drawCircle(
          _circleOffset(
              rect: face!.boundingBox,
              widgetSize: size,
              scaleX: scaleX,
              scaleY: scaleY,
              mirrorX: mirrorX),
          face!.boundingBox.width / 2 * scaleX!,
          paint,
        );
        break;
      case IndicatorShape.triangle:
      case IndicatorShape.triangleInverted:
        canvas.drawPath(
          _trianglePath(
              rect: face!.boundingBox,
              widgetSize: size,
              scaleX: scaleX,
              scaleY: scaleY,
              mirrorX: mirrorX,
              isInverted:
                  indicatorShape == IndicatorShape.triangleInverted),
          paint,
        );
        break;
      case IndicatorShape.image:
        final AssetImage image =
            AssetImage(indicatorAssetImage ?? AppImages.faceNet);
        final ImageStream imageStream =
            image.resolve(ImageConfiguration.empty);

        imageStream.addListener(
            ImageStreamListener((ImageInfo imageInfo, bool synchronousCall) {
          final rect = face!.boundingBox;
          final Rect destinationRect = Rect.fromPoints(
            Offset(_tx(rect.left.toDouble(), size.width),
                rect.top.toDouble() * scaleY!),
            Offset(_tx(rect.right.toDouble(), size.width),
                rect.bottom.toDouble() * scaleY!),
          );

          canvas.drawImageRect(
            imageInfo.image,
            Rect.fromLTRB(0, 0, imageInfo.image.width.toDouble(),
                imageInfo.image.height.toDouble()),
            destinationRect,
            Paint(),
          );
        }));
        break;
      case IndicatorShape.fixedFrame:
        // Handled at the beginning of paint() method
        break;
      case IndicatorShape.none:
        break;
    }

    // Draw debug landmarks if enabled
    if (showDebugLandmarks && face != null) {
      _drawDebugLandmarks(canvas, size);
    }
  }

  /// Draw debug markers for facial landmarks
  void _drawDebugLandmarks(Canvas canvas, Size size) {
    if (face == null || scaleX == null || scaleY == null) return;

    final landmarkPaint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0;

    // Draw each landmark with different colors
    final landmarks = <FaceLandmarkType, Color>{
      FaceLandmarkType.leftEye: Colors.blue,
      FaceLandmarkType.rightEye: Colors.blue,
      FaceLandmarkType.noseBase: Colors.green,
      FaceLandmarkType.bottomMouth: Colors.red,
      FaceLandmarkType.leftMouth: Colors.red,
      FaceLandmarkType.rightMouth: Colors.red,
      FaceLandmarkType.leftCheek: Colors.yellow,
      FaceLandmarkType.rightCheek: Colors.yellow,
      FaceLandmarkType.leftEar: Colors.purple,
      FaceLandmarkType.rightEar: Colors.purple,
    };

    for (final entry in landmarks.entries) {
      final landmark = face!.landmarks[entry.key];
      if (landmark != null) {
        landmarkPaint.color = entry.value;

        // Convert landmark position to screen coordinates
        final x = _tx(landmark.position.x.toDouble(), size.width);
        final y = landmark.position.y.toDouble() * scaleY!;

        // Draw landmark as a circle
        canvas.drawCircle(Offset(x, y), 6.0, landmarkPaint);

        // Draw white border for visibility
        final borderPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = Colors.white;
        canvas.drawCircle(Offset(x, y), 6.0, borderPaint);
      }
    }

    // Draw face bounding box in debug mode (clamped to image bounds)
    final boundingBoxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.cyan;

    // Clamp bounding box to valid image range (ML Kit can extend beyond image)
    final clampedLeft =
        face!.boundingBox.left.clamp(0.0, imageSize.width);
    final clampedRight =
        face!.boundingBox.right.clamp(0.0, imageSize.width);
    final clampedTop =
        face!.boundingBox.top.clamp(0.0, imageSize.height);
    final clampedBottom =
        face!.boundingBox.bottom.clamp(0.0, imageSize.height);

    canvas.drawRect(
      Rect.fromLTRB(
        _tx(clampedLeft, size.width),
        clampedTop * scaleY!,
        _tx(clampedRight, size.width),
        clampedBottom * scaleY!,
      ),
      boundingBoxPaint,
    );
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.imageSize != imageSize ||
        oldDelegate.face != face ||
        oldDelegate.showDebugLandmarks != showDebugLandmarks ||
        oldDelegate.isFaceWellPositioned != isFaceWellPositioned ||
        oldDelegate.mirrorX != mirrorX;
  }

  /// Draw a fixed centered frame that changes color based on face position
  void _drawFixedFrame(Canvas canvas, Size size) {
    // Use 70% of width but cap to 40% of height so the frame stays
    // a consistent visual size across different camera aspect ratios
    // (e.g. 4:3 on iOS vs 16:9 on Android).
    final double squareSize = min(size.width * 0.7, size.height * 0.4);
    final Rect fixedRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: squareSize,
      height: squareSize,
    );

    // Determine color based on face positioning
    Paint paint;
    if (face == null) {
      // No face detected - white/gray
      paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = Colors.white.withValues(alpha: 0.5);
    } else if (isFaceWellPositioned) {
      // Face is properly positioned - green
      paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = Colors.green;
    } else {
      // Face detected but not positioned correctly - red
      paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = Colors.red;
    }

    // Draw fixed rounded square
    canvas.drawRRect(
      RRect.fromRectAndRadius(fixedRect, const Radius.circular(10)),
      paint,
    );
  }
}

double _txHelper(
    double x, double width, double? scaleX, bool mirrorX) {
  return mirrorX ? width - x * scaleX! : x * scaleX!;
}

Path _defaultPath(
    {required Rect rect,
    required Size widgetSize,
    double? scaleX,
    double? scaleY,
    bool mirrorX = true}) {
  double cornerExtension = 30.0;

  double left =
      _txHelper(rect.left.toDouble(), widgetSize.width, scaleX, mirrorX);
  double right =
      _txHelper(rect.right.toDouble(), widgetSize.width, scaleX, mirrorX);
  double top = rect.top.toDouble() * scaleY!;
  double bottom = rect.bottom.toDouble() * scaleY;
  return Path()
    ..moveTo(left - cornerExtension, top)
    ..lineTo(left, top)
    ..lineTo(left, top + cornerExtension)
    ..moveTo(right + cornerExtension, top)
    ..lineTo(right, top)
    ..lineTo(right, top + cornerExtension)
    ..moveTo(left - cornerExtension, bottom)
    ..lineTo(left, bottom)
    ..lineTo(left, bottom - cornerExtension)
    ..moveTo(right + cornerExtension, bottom)
    ..lineTo(right, bottom)
    ..lineTo(right, bottom - cornerExtension);
}

RRect _scaleRect(
    {required Rect rect,
    required Size widgetSize,
    double? scaleX,
    double? scaleY,
    bool mirrorX = true}) {
  return RRect.fromLTRBR(
      _txHelper(
          rect.left.toDouble(), widgetSize.width, scaleX, mirrorX),
      rect.top.toDouble() * scaleY!,
      _txHelper(
          rect.right.toDouble(), widgetSize.width, scaleX, mirrorX),
      rect.bottom.toDouble() * scaleY,
      const Radius.circular(10));
}

Offset _circleOffset(
    {required Rect rect,
    required Size widgetSize,
    double? scaleX,
    double? scaleY,
    bool mirrorX = true}) {
  return Offset(
    _txHelper(
        rect.center.dx, widgetSize.width, scaleX, mirrorX),
    rect.center.dy * scaleY!,
  );
}

Path _trianglePath(
    {required Rect rect,
    required Size widgetSize,
    double? scaleX,
    double? scaleY,
    bool mirrorX = true,
    bool isInverted = false}) {
  if (isInverted) {
    return Path()
      ..moveTo(
          _txHelper(
              rect.center.dx, widgetSize.width, scaleX, mirrorX),
          rect.bottom.toDouble() * scaleY!)
      ..lineTo(
          _txHelper(
              rect.left.toDouble(), widgetSize.width, scaleX, mirrorX),
          rect.top.toDouble() * scaleY)
      ..lineTo(
          _txHelper(
              rect.right.toDouble(), widgetSize.width, scaleX, mirrorX),
          rect.top.toDouble() * scaleY)
      ..close();
  }
  return Path()
    ..moveTo(
        _txHelper(
            rect.center.dx, widgetSize.width, scaleX, mirrorX),
        rect.top.toDouble() * scaleY!)
    ..lineTo(
        _txHelper(
            rect.left.toDouble(), widgetSize.width, scaleX, mirrorX),
        rect.bottom.toDouble() * scaleY)
    ..lineTo(
        _txHelper(
            rect.right.toDouble(), widgetSize.width, scaleX, mirrorX),
        rect.bottom.toDouble() * scaleY)
    ..close();
}
