import 'dart:ui' as ui;

/// Offscreen renderer for Buffer A
/// 
/// Renders the Buffer A shader into an ui.Image at reduced resolution
/// for massive performance gains. The output is then used as a sampler
/// input for the composite shader.
class OffscreenBufferA {
  OffscreenBufferA({
    required this.program,
    required this.scale,
  });

  final ui.FragmentProgram program;
  final double scale;

  ui.Image? _image;
  ui.Image? get image => _image;

  Future<void> render({
    required ui.Size fullSize,
    required double time,
    required double intensity,
  }) async {
    final w = (fullSize.width * scale).round().clamp(2, 4096);
    final h = (fullSize.height * scale).round().clamp(2, 4096);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final shader = program.fragmentShader()
      ..setFloat(0, w.toDouble())   // uResolution.x
      ..setFloat(1, h.toDouble())   // uResolution.y
      ..setFloat(2, time)           // uTime
      ..setFloat(3, intensity);     // uIntensity

    final paint = ui.Paint()..shader = shader;
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), paint);

    final pic = recorder.endRecording();
    final img = await pic.toImage(w, h);

    _image?.dispose();
    _image = img;
  }

  void dispose() {
    _image?.dispose();
    _image = null;
  }
}
