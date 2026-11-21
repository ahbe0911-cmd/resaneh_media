import 'dart:io';
import 'package:flutter/material.dart';

class ImageViewerPage extends StatelessWidget {
  final String filePath;
  final String title;
  const ImageViewerPage({super.key, required this.filePath, required this.title});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(backgroundColor: Colors.black,
      foregroundColor: Colors.white, title: Text(title,
        maxLines: 1, overflow: TextOverflow.ellipsis)),
    body: Center(child: InteractiveViewer(
      minScale: 0.7,
      maxScale: 6,
      boundaryMargin: const EdgeInsets.all(24),
      child: Image.file(File(filePath), fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => const Center(
          child: Text('نمایش این تصویر ممکن نیست.',
              style: TextStyle(color: Colors.white)),
        ),
      ),
    )),
  );
}
