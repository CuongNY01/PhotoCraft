import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/photo_record.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  final Function(Uint8List bytes, String title, PhotoRecord record) onContinueEdit;

  const HistoryScreen({
    super.key,
    required this.onContinueEdit,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<PhotoRecord> _photos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPhotos({String? query}) async {
    setState(() => _isLoading = true);
    final list = await DBHelper.instance.getAllPhotos(query: query);
    if (mounted) {
      setState(() {
        _photos = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite(PhotoRecord record) async {
    if (record.id == null) return;
    await DBHelper.instance.toggleFavorite(record.id!, record.isFavorite);
    _loadPhotos(query: _searchController.text);
  }

  Future<void> _deleteRecord(PhotoRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Xác nhận xóa', style: TextStyle(color: Colors.white)),
        content: Text(
          'Bạn có chắc muốn xóa "${record.title}" khỏi lịch sử?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentPink),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && record.id != null) {
      await DBHelper.instance.deletePhoto(record.id!);
      _loadPhotos(query: _searchController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa bức ảnh khỏi lịch sử')),
        );
      }
    }
  }

  void _showEditDiaryDialog(PhotoRecord record) {
    final noteController = TextEditingController(text: record.note);
    int currentRating = record.rating;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '✏️ Sửa nhật ký: ${record.title}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Rating stars
                  Row(
                    children: [
                      const Text(
                        'Đánh giá: ',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      Row(
                        children: List.generate(5, (index) {
                          final s = index + 1;
                          return GestureDetector(
                            onTap: () => setModalState(() => currentRating = s),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Icon(
                                s <= currentRating ? Icons.star : Icons.star_border,
                                color: AppTheme.accentYellow,
                                size: 24,
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Nhập nội dung nhật ký cảm nghĩ...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final updated = record.copyWith(
                          note: noteController.text.trim(),
                          rating: currentRating,
                        );
                        await DBHelper.instance.updatePhoto(updated);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          _loadPhotos(query: _searchController.text);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✓ Đã cập nhật nhật ký')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Lưu thay đổi', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _continueEdit(PhotoRecord record) async {
    Uint8List? bytes;
    if (record.editedPath.startsWith('assets/')) {
      final d = await rootBundle.load(record.editedPath);
      bytes = d.buffer.asUint8List();
    } else if (!kIsWeb && File(record.editedPath).existsSync()) {
      bytes = await File(record.editedPath).readAsBytes();
    }
    if (bytes != null) {
      widget.onContinueEdit(bytes, record.title, record);
    }
  }

  Widget _buildThumbnail(String path) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover, width: 90, height: 90);
    }
    if (!kIsWeb && File(path).existsSync()) {
      return Image.file(File(path), fit: BoxFit.cover, width: 90, height: 90);
    }
    return Container(
      width: 90,
      height: 90,
      color: Colors.black26,
      child: const Icon(Icons.image, color: AppTheme.textSecondary),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử và nhật ký ảnh'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.accentCyan),
            onPressed: () => _loadPhotos(query: _searchController.text),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (q) => _loadPhotos(query: q),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: '🔍 Tìm kiếm theo tên, bộ lọc hoặc nhật ký',
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: AppTheme.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          _loadPhotos();
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Photo List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.accentCyan),
                  )
                : _photos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.history, size: 54, color: AppTheme.textSecondary),
                            SizedBox(height: 12),
                            Text(
                              'Không tìm thấy bức ảnh nào',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        itemCount: _photos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final item = _photos[index];
                          final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt);

                          return Container(
                            decoration: BoxDecoration(
                              color: AppTheme.cardColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppTheme.dividerColor),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top row: Thumbnail + Details
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: _buildThumbnail(item.editedPath),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.title,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () => _toggleFavorite(item),
                                                child: Icon(
                                                  item.isFavorite
                                                      ? Icons.favorite
                                                      : Icons.favorite_border,
                                                  color: item.isFavorite
                                                      ? AppTheme.accentPink
                                                      : AppTheme.textSecondary,
                                                  size: 22,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            dateStr,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 8),

                                          // Chips for Filter and Sharpening
                                          Wrap(
                                            spacing: 6,
                                            children: [
                                              _buildBadge('Bộ lọc: ${item.filterApplied}', const Color(0xFF5C6BC0)),
                                              _buildBadge('Làm nét: ${item.sharpenApplied}', const Color(0xFF8D6E63)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Diary box
                                if (item.note.isNotEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceLight.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Text(
                                              '📝 Nhật ký ảnh: ',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                            Row(
                                              children: List.generate(item.rating, (i) => const Icon(
                                                Icons.star,
                                                color: AppTheme.accentYellow,
                                                size: 14,
                                              )),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '"${item.note}"',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 10),

                                // Actions row: ✏️ Sửa nhật ký | ✨ Chỉnh sửa tiếp | 🗑️ Xóa
                                FittedBox(
                                  alignment: Alignment.centerRight,
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _showEditDiaryDialog(item),
                                        icon: const Icon(Icons.edit, size: 14, color: AppTheme.textSecondary),
                                        label: const Text(
                                          'Sửa nhật ký',
                                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      TextButton.icon(
                                        onPressed: () => _continueEdit(item),
                                        icon: const Icon(Icons.auto_awesome, size: 14, color: AppTheme.accentCyan),
                                        label: const Text(
                                          'Chỉnh sửa tiếp',
                                          style: TextStyle(fontSize: 12, color: AppTheme.accentCyan, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.accentPink),
                                        onPressed: () => _deleteRecord(item),
                                        tooltip: 'Xóa ảnh',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bg.withOpacity(0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: bg, fontWeight: FontWeight.bold),
      ),
    );
  }
}
