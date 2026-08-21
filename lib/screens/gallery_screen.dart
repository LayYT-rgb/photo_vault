import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/trash_service.dart';
import 'trash_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _trash = TrashService();
  final Set<String> _selected = {};
  List<AssetEntity> _assets = [];
  Set<String> _trashedIds = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        setState(() {
          _loading = false;
          _error = 'Доступ к галерее не разрешён. Разреши доступ в настройках приложения.';
        });
        return;
      }

      await _trash.purgeExpired();

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );
      if (albums.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Альбомы не найдены.';
        });
        return;
      }
      final allAlbum = albums.first;
      final count = await allAlbum.assetCountAsync;
      final assets = await allAlbum.getAssetListRange(start: 0, end: count);
      final trashedMap = await _trash.getTrashedIds();

      setState(() {
        _assets = assets;
        _trashedIds = trashedMap.keys.toSet();
        _loading = false;
      });
    } catch (e, stack) {
      setState(() {
        _loading = false;
        _error = 'Ошибка: $e\n\n$stack';
      });
    }
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Переместить в корзину?'),
        content: Text(
          'Выбрано: ${_selected.length}. Фото можно будет восстановить '
          'в течение ${TrashService.restoreWindowDays} дней.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('В корзину')),
        ],
      ),
    );
    if (confirmed != true) return;

    await _trash.moveManyToTrash(_selected.toList());
    setState(() {
      _trashedIds.addAll(_selected);
      _selected.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(child: Text(_error!)),
        ),
      );
    }

    final visible = _assets.where((a) => !_trashedIds.contains(a.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Моя галерея'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Корзина',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TrashScreen()),
            ).then((_) => _init()),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : visible.isEmpty
              ? const Center(child: Text('Нет доступа к галерее или фото не найдены'))
              : GridView.builder(
                  padding: const EdgeInsets.all(4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final asset = visible[index];
                    final isSelected = _selected.contains(asset.id);
                    return GestureDetector(
                      onTap: () => setState(() {
                        isSelected ? _selected.remove(asset.id) : _selected.add(asset.id);
                      }),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          FutureBuilder(
                            future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return Container(color: Colors.grey[300]);
                              return Image.memory(snapshot.data!, fit: BoxFit.cover);
                            },
                          ),
                          if (isSelected)
                            Container(
                              color: Colors.black45,
                              child: const Icon(Icons.check_circle, color: Colors.white),
                            ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: _selected.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _deleteSelected,
              icon: const Icon(Icons.delete_outline),
              label: Text('В корзину (${_selected.length})'),
            ),
    );
  }
}
