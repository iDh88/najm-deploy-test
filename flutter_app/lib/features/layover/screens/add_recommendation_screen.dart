import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../services/layover_service.dart';
import '../services/auth_service.dart';

class AddRecommendationScreen extends StatefulWidget {
  final String cityId;
  final String? initialCategory;

  const AddRecommendationScreen({
    super.key,
    required this.cityId,
    this.initialCategory,
  });

  @override
  State<AddRecommendationScreen> createState() =>
      _AddRecommendationScreenState();
}

class _AddRecommendationScreenState extends State<AddRecommendationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = LayoverService();
  final _auth = AuthService();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

  String _category = '';
  bool _isHalal = false;
  List<File> _photos = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ?? AppConstants.layoverCategories.first.id;
    if (_category == 'all') _category = AppConstants.layoverCategories.first.id;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    _addressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 75);
    if (images.isNotEmpty) {
      setState(() {
        _photos = images.map((x) => File(x.path)).toList();
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final user = _auth.currentUser;
      // F28: real rank from the user's profile document (was hardcoded 'CA',
      // which mislabelled every submitter as a Captain). Neutral fallback if
      // the profile is missing rather than inventing a rank.
      final crewUser =
          user != null ? await _auth.getCrewUser(user.uid) : null;
      final submitterRank =
          (crewUser?.rank.isNotEmpty ?? false) ? crewUser!.rank : 'Crew';
      await _service.submitRecommendation(
        cityId: widget.cityId,
        category: _category,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        photos: _photos,
        latitude: double.tryParse(_latCtrl.text),
        longitude: double.tryParse(_lngCtrl.text),
        address: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        isHalal: _isHalal,
        submitterRank: submitterRank,
        submitterName: user?.displayName ??
            ((crewUser?.name.isNotEmpty ?? false)
                ? crewUser!.name
                : 'Crew Member'),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Recommendation added successfully!'),
            backgroundColor: NajmTheme.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: NajmTheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NajmTheme.navy,
      appBar: AppBar(
        backgroundColor: NajmTheme.navyMid,
        title: const Text('Add Recommendation'),
        leading: IconButton(
          icon: const Icon(Icons.close, color: NajmTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: NajmTheme.gold),
                  )
                : const Text('Post',
                    style: TextStyle(
                        color: NajmTheme.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Category picker ────────────────────────────
              const _Label('Category'),
              const SizedBox(height: 8),
              _CategoryPicker(
                selected: _category,
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 20),

              // ── Name ───────────────────────────────────────
              const _Label('Place Name *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(color: NajmTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'e.g. Al Baik Restaurant',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 16),

              // ── Description ────────────────────────────────
              const _Label('Description *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                style: const TextStyle(color: NajmTheme.textPrimary),
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Describe what makes this place great…',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Description is required'
                    : null,
              ),
              const SizedBox(height: 16),

              // ── Crew Notes ─────────────────────────────────
              const _Label('Crew Notes (optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                style: const TextStyle(color: NajmTheme.textPrimary),
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Tips for crew, best dishes, what to avoid…',
                ),
              ),
              const SizedBox(height: 16),

              // ── Address ────────────────────────────────────
              const _Label('Address (optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressCtrl,
                style: const TextStyle(color: NajmTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: '123 Main Street, City',
                  prefixIcon: Icon(Icons.place_outlined,
                      color: NajmTheme.textMuted, size: 18),
                ),
              ),
              const SizedBox(height: 16),

              // ── GPS Coords ─────────────────────────────────
              const _Label('GPS Coordinates (optional)'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      style: const TextStyle(color: NajmTheme.textPrimary),
                      decoration: const InputDecoration(hintText: 'Latitude'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      style: const TextStyle(color: NajmTheme.textPrimary),
                      decoration: const InputDecoration(hintText: 'Longitude'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Halal toggle ───────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: NajmTheme.navyLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: NajmTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    const Text('🟢',
                        style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Halal Certified',
                              style: TextStyle(
                                  color: NajmTheme.textPrimary,
                                  fontWeight: FontWeight.w600)),
                          Text('Food/drinks are halal',
                              style: TextStyle(
                                  color: NajmTheme.textMuted,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isHalal,
                      onChanged: (v) => setState(() => _isHalal = v),
                      activeColor: NajmTheme.saudiGreenLight,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Photos ─────────────────────────────────────
              const _Label('Photos (optional)'),
              const SizedBox(height: 8),
              _PhotoPicker(photos: _photos, onPick: _pickPhotos),
              const SizedBox(height: 12),

              // ── Content policy notice ──────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NajmTheme.info.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: NajmTheme.info.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: NajmTheme.info, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Najm blocks recommendations for bars, clubs, or alcohol. '
                        'All content must comply with Saudi Airlines crew guidelines.',
                        style: TextStyle(
                            color: NajmTheme.info,
                            fontSize: 11,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // ── Submit ─────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: NajmTheme.navy),
                        )
                      : const Text('Post Recommendation'),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _CategoryPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppConstants.layoverCategories.map((cat) {
        final isSelected = cat.id == selected;
        return GestureDetector(
          onTap: () => onChanged(cat.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? NajmTheme.gold.withOpacity(0.15)
                  : NajmTheme.navyLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? NajmTheme.gold : NajmTheme.cardBorder,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cat.icon,
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 5),
                Text(
                  cat.label,
                  style: TextStyle(
                    color: isSelected
                        ? NajmTheme.gold
                        : NajmTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final List<File> photos;
  final VoidCallback onPick;

  const _PhotoPicker({required this.photos, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          GestureDetector(
            onTap: onPick,
            child: Container(
              width: 90,
              height: 90,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: NajmTheme.navyLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: NajmTheme.gold.withOpacity(0.4),
                    style: BorderStyle.solid),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      color: NajmTheme.gold, size: 28),
                  SizedBox(height: 4),
                  Text('Add',
                      style: TextStyle(
                          color: NajmTheme.gold, fontSize: 11)),
                ],
              ),
            ),
          ),
          ...photos.map(
            (f) => Container(
              width: 90,
              height: 90,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                    image: FileImage(f), fit: BoxFit.cover),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: NajmTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      );
}
