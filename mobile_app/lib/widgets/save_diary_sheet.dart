import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../database/db_helper.dart';
import '../models/photo_record.dart';
import '../theme/app_theme.dart';

class SaveDiarySheet extends StatefulWidget {
  final Uint8List imageBytes;
  final String initialTitle;
  final String filterApplied;
  final String sharpenApplied;
  final PhotoRecord? existingRecord;

  const SaveDiarySheet({
    super.key,
    required this.imageBytes,
    this.initialTitle = 'Hoàng hôn ven biển',
    this.filterApplied = 'Gốc',
    this.sharpenApplied = 'Không',
    this.existingRecord,
  });

  @override
  State<SaveDiarySheet> createState() => _SaveDiarySheetState();
}

class _SaveDiarySheetState extends State<SaveDiarySheet> {
  late TextEditingController _titleController;
  late TextEditingController _noteController;
  int _rating = 5;
  bool _isFavorite = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingRecord?.title ?? widget.initialTitle,
    );
    _noteController = TextEditingController(
      text: widget.existingRecord?.note ?? '',
    );
    _rating = widget.existingRecord?.rating ?? 5;
    _isFavorite = widget.existingRecord?.isFavorite ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<String> _saveImageToDisk(Uint8List bytes) async {
    if (kIsWeb) {
      return 'web_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    }
    final docDir = await getApplicationDocumentsDirectory();
    final filename = 'photocraft_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(p.join(docDir.path, filename));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<void> _shareImage() async {
    try {
      final shareText = '${_titleController.text}\n${_noteController.text}';
      if (kIsWeb) {
        await Share.share(shareText);
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final shareFile = File(p.join(tempDir.path, 'photocraft_share.jpg'));
      await shareFile.writeAsBytes(widget.imageBytes);

      await Share.shareXFiles(
        [XFile(shareFile.path)],
        text: shareText,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chia sẻ: $e')),
        );
      }
    }
  }

  Future<void> _saveRecord() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên bức ảnh')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final savedPath = await _saveImageToDisk(widget.imageBytes);

      final record = PhotoRecord(
        id: widget.existingRecord?.id,
        title: _titleController.text.trim(),
        editedPath: savedPath,
        originalPath: widget.existingRecord?.originalPath ?? savedPath,
        filterApplied: widget.filterApplied,
        sharpenApplied: widget.sharpenApplied,
        note: _noteController.text.trim(),
        rating: _rating,
        isFavorite: _isFavorite,
        createdAt: DateTime.now(),
      );

      if (widget.existingRecord?.id != null) {
        await DBHelper.instance.updatePhoto(record);
      } else {
        await DBHelper.instance.insertPhoto(record);
      }

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.accentGreen,
            content: Text(
              '✓ Đã lưu ảnh và nhật ký thành công!',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu ảnh: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header + Favorite Heart
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Lưu trữ & Nhật ký ảnh',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() => _isFavorite = !_isFavorite);
                  },
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? AppTheme.accentPink : AppTheme.textSecondary,
                    size: 26,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Image Preview
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  color: Colors.black,
                  child: Image.memory(
                    widget.imageBytes,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tên bức ảnh
            const Text(
              'Tên bức ảnh:',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Nhập tên bức ảnh...',
              ),
            ),
            const SizedBox(height: 14),

            // Nhật ký cảm nghĩ + Star rating
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nhật ký cảm nghĩ:',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                Row(
                  children: List.generate(5, (index) {
                    final starIndex = index + 1;
                    return GestureDetector(
                      onTap: () => setState(() => _rating = starIndex),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(
                          starIndex <= _rating ? Icons.star : Icons.star_border,
                          color: AppTheme.accentYellow,
                          size: 22,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              maxLines: 3,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Cảm nghĩ hoặc ghi chú về bức ảnh này...',
              ),
            ),
            const SizedBox(height: 20),

            // Action buttons: [Chia sẻ] & [Lưu]
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _shareImage,
                    icon: const Icon(Icons.share, size: 18, color: Colors.white),
                    label: const Text('Chia sẻ', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cardColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppTheme.dividerColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveRecord,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Lưu',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
