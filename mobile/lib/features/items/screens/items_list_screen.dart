import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/app_shell.dart';
import '../../../core/config/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/item_model.dart';
import '../services/items_api_service.dart';

class ItemsListScreen extends StatefulWidget {
  const ItemsListScreen({super.key});

  @override
  State<ItemsListScreen> createState() => _ItemsListScreenState();
}

class _ItemsListScreenState extends State<ItemsListScreen> {
  final ItemsApiService _api = ItemsApiService();
  List<ItemModel> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final list = await _api.getItems(search: _searchQuery);
      if (mounted) {
        setState(() => _items = list);
      }
    } catch (_) {
      // Handle error gracefully
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'My Items',
      action: ElevatedButton.icon(
        onPressed: () => context.push('/items/new'),
        icon: const Icon(Icons.add, size: 16, color: Colors.white),
        label: const Text('Submit New Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _loadItems,
        color: AppColors.primary,
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search items by name, brand, or model...',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
                onChanged: (val) {
                  _searchQuery = val;
                  _loadItems();
                },
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primarySubtle,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.devices_other, size: 48, color: AppColors.primary),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No items registered yet',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.slateDark),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Submit your disused electronics to get real-time AI valuation and schedule eco-friendly doorstep collection.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.slateLight, fontSize: 13),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () => context.push('/items/submit'),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Register First Item'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => context.push('/items/${item.id}'),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Item Image Thumbnail or Placeholder
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceSubtle,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: item.images.isNotEmpty
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.network(
                                                  ApiConstants.resolveImageUrl(item.images.first.url),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => const Icon(Icons.devices, color: AppColors.primary),
                                                ),
                                              )
                                            : const Icon(Icons.devices, color: AppColors.primary),
                                      ),
                                      const SizedBox(width: 14),

                                      // Item Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item.name,
                                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.slateDark),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                StatusBadge(label: item.status),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${item.brand ?? ""} ${item.model ?? ""}'.trim(),
                                              style: const TextStyle(fontSize: 13, color: AppColors.slateLight),
                                            ),
                                            const SizedBox(height: 8),

                                            // Category Tag
                                            if (item.category != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surfaceSubtle,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  item.category!.name,
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slate),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
