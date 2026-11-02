import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../database/db_helper.dart';
import '../models/photo_record.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  final Function(Uint8List imageBytes, String title, PhotoRecord? record) onOpenEditor;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenFavorites;

  const HomeScreen({
    super.key,
    required this.onOpenEditor,
    required this.onOpenHistory,
    required this.onOpenFavorites,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  Map<String, int> _stats = {'total': 0, 'favorites': 0, 'diaries': 0};
  List<PhotoRecord> _recentPhotos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await DBHelper.instance.seedInitialDataIfEmpty();
    final stats = await DBHelper.instance.getStats();
    final recents = await DBHelper.instance.getRecentPhotos(limit: 6);
    if (mounted) {
      setState(() {
        _stats = stats;
        _recentPhotos = recents;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        final title = source == ImageSource.camera ? 'Ảnh chụp mới' : file.name;
        widget.onOpenEditor(bytes, title, null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chọn ảnh: $e')),
        );
      }
    }
  }

  void _showSamplePhotosDialog() {
    final samples = [
      {'title': 'Hoàng hôn biển', 'asset': 'assets/samples/sunset.jpg'},
      {'title': 'Chân dung nghệ thuật', 'asset': 'assets/samples/portrait.jpg'},
      {'title': 'Phố đêm rực rỡ', 'asset': 'assets/samples/night_city.jpg'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🎨 Chọn ảnh mẫu có sẵn',
                    style: TextStyle(
                      fontSize: 18,
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
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: samples.length,
                itemBuilder: (c, idx) {
                  final item = samples[idx];
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      final assetData = await rootBundle.load(item['asset']!);
                      final bytes = assetData.buffer.asUint8List();
                      widget.onOpenEditor(bytes, item['title']!, null);
                    },
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              item['asset']!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item['title']!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageWidget(String path) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover);
    }
    if (!kIsWeb && File(path).existsSync()) {
      return Image.file(File(path), fit: BoxFit.cover);
    }
    return Container(
      color: Colors.black26,
      child: const Icon(Icons.image, color: AppTheme.textSecondary),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.accentCyan,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top App Header
                const Text(
                  'PhotoCraft Application',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Biên tập và nâng cao chất lượng ảnh',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // 3 Hero Action Cards
                Row(
                  children: [
                    // Chụp ảnh (Camera)
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.camera_alt,
                        label: 'Chụp ảnh',
                        color: const Color(0xFF7C4DFF),
                        onTap: () => _pickImage(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Thư viện (Gallery)
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.photo_library,
                        label: 'Thư viện',
                        color: const Color(0xFF00B0FF),
                        onTap: () => _pickImage(ImageSource.gallery),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Ảnh mẫu (Samples)
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.palette,
                        label: 'Ảnh mẫu',
                        color: const Color(0xFFE91E63),
                        onTap: _showSamplePhotosDialog,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Statistics Banner
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          count: '${_stats['total']}',
                          label: 'Đã biên tập',
                          color: const Color(0xFFB388FF),
                          onTap: widget.onOpenHistory,
                        ),
                      ),
                      Container(height: 36, width: 1, color: AppTheme.dividerColor),
                      Expanded(
                        child: _buildStatItem(
                          count: '${_stats['favorites']}',
                          label: 'Yêu thích ♥',
                          color: const Color(0xFF00E5FF),
                          onTap: widget.onOpenFavorites,
                        ),
                      ),
                      Container(height: 36, width: 1, color: AppTheme.dividerColor),
                      Expanded(
                        child: _buildStatItem(
                          count: '${_stats['diaries']}',
                          label: 'Nhật ký ảnh',
                          color: const Color(0xFFFF4081),
                          onTap: widget.onOpenHistory,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Section: Chỉnh sửa gần đây
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Chỉnh sửa gần đây',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onOpenHistory,
                      child: const Text(
                        'Xem tất cả',
                        style: TextStyle(color: AppTheme.accentCyan, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: AppTheme.accentCyan),
                    ),
                  )
                else if (_recentPhotos.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.image_search, size: 48, color: AppTheme.textSecondary),
                        SizedBox(height: 10),
                        Text(
                          'Chưa có ảnh nào được chỉnh sửa',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 180,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _recentPhotos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final record = _recentPhotos[index];
                        return GestureDetector(
                          onTap: () async {
                            Uint8List? bytes;
                            if (record.editedPath.startsWith('assets/')) {
                              final d = await rootBundle.load(record.editedPath);
                              bytes = d.buffer.asUint8List();
                            } else if (!kIsWeb && File(record.editedPath).existsSync()) {
                              bytes = await File(record.editedPath).readAsBytes();
                            }
                            if (bytes != null) {
                              widget.onOpenEditor(bytes, record.title, record);
                            }
                          },
                          child: Container(
                            width: 140,
                            decoration: BoxDecoration(
                              color: AppTheme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.dividerColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: _buildImageWidget(record.editedPath),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Text(
                                    record.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 105,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String count,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
