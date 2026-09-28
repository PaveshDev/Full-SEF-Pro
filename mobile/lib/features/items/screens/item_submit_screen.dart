import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/app_shell.dart';
import '../../../core/theme/app_colors.dart';
import '../models/item_model.dart';
import '../services/items_api_service.dart';

class SelectedPhotoItem {
  final XFile file;
  final Uint8List bytes;
  final String name;
  final int sizeBytes;

  SelectedPhotoItem({
    required this.file,
    required this.bytes,
    required this.name,
    required this.sizeBytes,
  });
}

class ItemSubmitScreen extends StatefulWidget {
  const ItemSubmitScreen({super.key});

  @override
  State<ItemSubmitScreen> createState() => _ItemSubmitScreenState();
}

class _ItemSubmitScreenState extends State<ItemSubmitScreen> {
  final _formKey = GlobalKey<FormState>();
  final ItemsApiService _api = ItemsApiService();
  final ImagePicker _picker = ImagePicker();

  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _descController = TextEditingController();

  List<CategoryModel> _categories = [];
  String? _selectedCategoryId;
  final List<SelectedPhotoItem> _selectedPhotos = [];
  bool _isLoadingCategories = true;
  bool _isPickingPhoto = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final list = await _api.getCategories();
      if (mounted) {
        setState(() {
          _categories = list;
          if (list.isNotEmpty) _selectedCategoryId = list.first.id;
          _isLoadingCategories = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _pickImagesFromDevice() async {
    setState(() => _isPickingPhoto = true);
    try {
      // 1. Try pickMultiImage first (supports multiple file selection without canvas resize)
      final pickedList = await _picker.pickMultiImage();
      if (pickedList.isNotEmpty) {
        final newPhotos = <SelectedPhotoItem>[];
        for (final file in pickedList) {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) {
            newPhotos.add(SelectedPhotoItem(
              file: file,
              bytes: bytes,
              name: file.name,
              sizeBytes: bytes.length,
            ));
          }
        }
        if (mounted && newPhotos.isNotEmpty) {
          setState(() {
            _selectedPhotos.addAll(newPhotos);
          });
        }
        return;
      }

      // 2. Fallback to single pickImage if pickMultiImage returned empty
      final single = await _picker.pickImage(source: ImageSource.gallery);
      if (single != null) {
        final bytes = await single.readAsBytes();
        if (bytes.isNotEmpty && mounted) {
          setState(() {
            _selectedPhotos.add(SelectedPhotoItem(
              file: single,
              bytes: bytes,
              name: single.name,
              sizeBytes: bytes.length,
            ));
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file picker: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<void> _takePhoto() async {
    setState(() => _isPickingPhoto = true);
    try {
      final picked = await _picker.pickImage(source: ImageSource.camera);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (bytes.isNotEmpty && mounted) {
          setState(() {
            _selectedPhotos.add(SelectedPhotoItem(
              file: picked,
              bytes: bytes,
              name: picked.name,
              sizeBytes: bytes.length,
            ));
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera unavailable: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      setState(() => _errorMessage = 'Please select a category');
      return;
    }

    if (_selectedPhotos.isEmpty) {
      setState(() => _errorMessage = 'Please upload at least one photo of the item.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final item = await _api.createItem(
        name: _nameController.text.trim(),
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        conditionDescription: _descController.text.trim(),
        categoryId: _selectedCategoryId!,
      );

      // Upload all chosen photos
      for (final photo in _selectedPhotos) {
        try {
          await _api.uploadPhotoBytes(item.id, photo.bytes, photo.name);
        } catch (photoErr) {
          debugPrint('Error uploading photo ${photo.name}: $photoErr');
        }
      }

      // Automatically trigger real-time AI assessment
      try {
        await _api.triggerAiAssessment(item.id);
      } catch (_) {}

      if (mounted) {
        context.go('/items/${item.id}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to submit item. Please check your network and try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Register E-Waste Item',
      child: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Card: Item Details
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Device Information',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slateDark),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Describe the disused electronic item you want to recover',
                                  style: TextStyle(fontSize: 12, color: AppColors.slateLight),
                                ),
                                const Divider(height: 24),

                                // Category Dropdown
                                const Text('Category *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  value: _selectedCategoryId,
                                  decoration: const InputDecoration(
                                    hintText: '-- Select Category --',
                                    prefixIcon: Icon(Icons.category_outlined, size: 18),
                                  ),
                                  items: _categories.map((c) {
                                    return DropdownMenuItem(value: c.id, child: Text(c.name));
                                  }).toList(),
                                  onChanged: (val) => setState(() => _selectedCategoryId = val),
                                ),
                                const SizedBox(height: 14),

                                // Item Name
                                const Text('Device / Item Name *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(hintText: 'e.g. iPhone 11 Pro 64GB'),
                                  validator: (val) => val == null || val.trim().isEmpty ? 'Item name is required' : null,
                                ),
                                const SizedBox(height: 14),

                                // Brand and Model row
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Brand *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                          const SizedBox(height: 4),
                                          TextFormField(
                                            controller: _brandController,
                                            decoration: const InputDecoration(hintText: 'e.g. Apple'),
                                            validator: (val) => val == null || val.trim().isEmpty ? 'Brand required' : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Model *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                          const SizedBox(height: 4),
                                          TextFormField(
                                            controller: _modelController,
                                            decoration: const InputDecoration(hintText: 'e.g. A2215'),
                                            validator: (val) => val == null || val.trim().isEmpty ? 'Model required' : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Condition Description
                                const Text('Physical & Working Condition *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _descController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. Screen cracked, turns on, battery health 78%, camera working, no charger.',
                                  ),
                                  validator: (val) => val == null || val.trim().isEmpty ? 'Condition details are required' : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Card: Photo Picker
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.photo_library_outlined, size: 20, color: AppColors.primary),
                                    SizedBox(width: 8),
                                    Text(
                                      'Item Photos',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slateDark),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Upload photos from your device to assist the AI assessment in evaluating device condition and scrap value.',
                                  style: TextStyle(fontSize: 12, color: AppColors.slateLight),
                                ),
                                const SizedBox(height: 14),

                                // Preview of selected photos
                                if (_selectedPhotos.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFBBF7D0)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle, size: 16, color: Color(0xFF16A34A)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '✓ ${_selectedPhotos.length} photo${_selectedPhotos.length > 1 ? "s" : ""} selected for upload',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 130,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _selectedPhotos.length,
                                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                                      itemBuilder: (context, i) {
                                        final photo = _selectedPhotos[i];
                                        final sizeKb = (photo.sizeBytes / 1024).toStringAsFixed(0);
                                        return Stack(
                                          children: [
                                            Container(
                                              width: 110,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: AppColors.border),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: ClipRRect(
                                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                                                      child: Image.memory(
                                                        photo.bytes,
                                                        width: 110,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, __, ___) => Container(
                                                          color: Colors.grey.shade100,
                                                          child: const Center(
                                                            child: Icon(Icons.image, size: 28, color: Colors.grey),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          photo.name,
                                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        Text(
                                                          '$sizeKb KB',
                                                          style: const TextStyle(fontSize: 9, color: AppColors.slateLight),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedPhotos.removeAt(i);
                                                  });
                                                },
                                                child: const CircleAvatar(
                                                  radius: 11,
                                                  backgroundColor: Colors.black54,
                                                  child: Icon(Icons.close, size: 14, color: Colors.white),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ],

                                // Action buttons
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _isPickingPhoto ? null : _pickImagesFromDevice,
                                      icon: _isPickingPhoto
                                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Icon(Icons.upload_file, size: 18),
                                      label: Text(_selectedPhotos.isEmpty ? 'Browse Photos / Upload from Device' : 'Add More Photos'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: _isPickingPhoto ? null : _takePhoto,
                                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                                      label: const Text('Take Photo'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _handleSubmit,
                          icon: _isSubmitting
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.auto_awesome),
                          label: Text(_isSubmitting ? 'Evaluating with Gemini AI...' : 'Submit & Run AI Assessment'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
