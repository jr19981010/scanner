import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:omr_shared/omr_shared.dart';

import '../../net/sync_socket.dart';
import '../../omr/grader.dart';
import '../result/result_preview_screen.dart';

/// Camera-based OMR path. Phase-3 OMR returns a stub (all blank); once the
/// pipeline in [omr/] is filled in, this screen captures a still and grades it.
class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    required this.socket,
    required this.exam,
    required this.answerKey,
    required this.studentNo,
  });

  final SyncSocket socket;
  final Exam exam;
  final List<AnswerKeyEntry> answerKey;
  final String studentNo;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _ctl;
  bool _busy = false;
  String _status = 'Align the answer sheet inside the frame.';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      setState(() => _status = 'No camera available.');
      return;
    }
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    _ctl = CameraController(back, ResolutionPreset.high, enableAudio: false);
    await _ctl!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctl?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final ctl = _ctl;
    if (ctl == null || !ctl.value.isInitialized || _busy) return;
    setState(() {
      _busy = true;
      _status = 'Capturing…';
    });
    try {
      final shot = await ctl.takePicture();
      setState(() => _status = 'Running OMR…');
      final answers = await runOmrPipeline(
        imagePath: shot.path,
        itemCount: widget.exam.itemCount,
        choiceCount: widget.exam.choiceCount,
      );
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ResultPreviewScreen(
          exam: widget.exam,
          answerKey: widget.answerKey,
          studentNo: widget.studentNo,
          answers: answers,
          socket: widget.socket,
        ),
      ));
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctl = _ctl;
    return Scaffold(
      appBar: AppBar(title: Text('Scan · ${widget.studentNo}')),
      body: Column(
        children: [
          Expanded(
            child: ctl == null || !ctl.value.isInitialized
                ? const Center(child: CircularProgressIndicator())
                : CameraPreview(ctl),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_status),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FilledButton.icon(
                onPressed: _busy ? null : _capture,
                icon: const Icon(Icons.camera),
                label: const Text('Capture & grade'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
