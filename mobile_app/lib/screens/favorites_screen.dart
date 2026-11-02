import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/db_helper.dart';
import '../models/photo_record.dart';
import '../theme/app_theme.dart';

class FavoritesScreen extends StatefulWidget {
  final Function(Uint8List bytes, String title, PhotoRecord record) onOpenPhoto;

  const FavoritesScreen({
    super.key,
    required this.onOpenPhoto,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<PhotoRecord> _favoritePhotos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final favs = await DBHelper.instance.getFavoritePhotos();
    if (mounted) {
      setState(() {
        _favoritePhotos = favs;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite(PhotoRecord record) async {
    if (record.id == null) return;
    await DBHelper.instance.toggleFavorite(record.id!, record.isFavorite);
    _loadFavorites();
  }

  Widget _buildImage(String path) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover, width: double.infinity);
    }
    if (!kIsWeb && File(path).existsSync()) {
      return Image.file(File(path), fit: BoxFit.cover, width: double.infinity);
    }
    return Container(
      color: Colors.black26,
      child: const Center(
        child: Icon(Icons.image, color: AppTheme.textSecondary, size: 36),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yêu thích ♥'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.accentCyan),
            onPressed: _loadFavorites,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentCyan),
            )
          : _favoritePhotos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.favorite_border, size: 54, color: AppTheme.textSecondary),
                      SizedBox(height: 12),
                      Text(
                        'Chưa có ảnh nào trong mục Yêu thích',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Nhấn biểu tượng trái tim khi lưu hoặc trong Lịch sử để thêm vào đây',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _favoritePhotos.length,
                  itemBuilder: (context, index) {
                    final item = _favoritePhotos[index];
                    return GestureDetector(
                      onTap: () async {
                        Uint8List? bytes;
                        if (item.editedPath.startsWith('assets/')) {
                          final d = await rootBundle.load(item.editedPath);
                          bytes = d.buffer.asUint8List();
                        } else if (!kIsWeb && File(item.editedPath).existsSync()) {
                          bytes = await File(item.editedPath).readAsBytes();
                        }
                        if (bytes != null) {
                          widget.onOpenPhoto(bytes, item.title, item);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Thumbnail + Heart badge
                            Expanded(
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(18),
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: double.infinity,
                                      child: _buildImage(item.editedPath),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () => _toggleFavorite(item),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.55),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.favorite,
                                          color: AppTheme.accentPink,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Title & Subtitle
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.filterApplied} • ${item.sharpenApplied}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.accentCyan,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
