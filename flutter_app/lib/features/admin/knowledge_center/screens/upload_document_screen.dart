import 'dart:io';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../models/knowledge_models.dart';
import '../providers/knowledge_providers.dart';

class UploadDocumentScreen extends ConsumerStatefulWidget {
  /// If set, this upload replaces an existing document (new version).
  final String? replacingDocumentId;
  final String? replacingDocumentName;

  const UploadDocumentScreen({
    super.key, this.replacingDocumentId, this.replacingDocumentName,
  });

  @override
  ConsumerState<UploadDocumentScreen> createState() =>
      _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends ConsumerState<UploadDocumentScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  File? _file;
  String? _fileName;
  DocumentCategory _category = DocumentCategory.companyProcedures;
  DateTime _effectiveDate = DateTime.now();
  DateTime? _expirationDate;

  bool get _isReplacement => widget.replacingDocumentId != null;

  @override
  void initState() {
    super.initState();
    if (widget.replacingDocumentName != null) {
      _nameCtrl.text = widget.replacingDocumentName!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await fp.FilePicker.platform.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'xlsx', 'csv', 'zip'],
    );
    if (result == null || result.files.single.path == null) return;
    setState(() {
      _file = File(result.files.single.path!);
      _fileName = result.files.single.name;
    });
  }

  Future<void> _submit() async {
    if (_file == null) return;
    if (!_isReplacement && _nameCtrl.text.trim().isEmpty) return;

    final notifier = ref.read(docUploadProvider.notifier);
    if (_isReplacement) {
      await notifier.uploadReplacement(
        documentId: widget.replacingDocumentId!,
        file: _file!,
        effectiveDate: _effectiveDate,
        expirationDate: _expirationDate,
      );
    } else {
      await notifier.uploadNew(
        file: _file!,
        name: _nameCtrl.text.trim(),
        category: _category,
        description: _descCtrl.text.trim(),
        effectiveDate: _effectiveDate,
        expirationDate: _expirationDate,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final upload = ref.watch(docUploadProvider);

    ref.listen<DocUploadState>(docUploadProvider, (prev, next) {
      if (next.status == UploadStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document uploaded — processing in background'),
            backgroundColor: CIPTheme.success,
          ),
        );
        context.pop();
      }
    });

    return Scaffold(
      backgroundColor: CIPTheme.surface,
      appBar: AppBar(
        backgroundColor: CIPTheme.surface,
        elevation: 0,
        title: Text(
            _isReplacement ? 'Upload New Version' : 'Upload Document',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_isReplacement)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CIPTheme.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CIPTheme.primary.withOpacity(0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, color: CIPTheme.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This will create a new version of "${widget.replacingDocumentName}". '
                    'The previous version will be archived automatically.',
                    style: const TextStyle(
                        color: CIPTheme.primary, fontSize: 12, height: 1.4),
                  ),
                ),
              ]),
            ),

          // File picker
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              height: 130,
              decoration: BoxDecoration(
                color: _file != null
                    ? CIPTheme.primary.withOpacity(0.06)
                    : CIPTheme.navLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _file != null ? CIPTheme.primary : CIPTheme.divider,
                  width: _file != null ? 1.5 : 1,
                ),
              ),
              child: _file == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('📄', style: TextStyle(fontSize: 36)),
                        SizedBox(height: 8),
                        Text('Tap to select file',
                            style: TextStyle(
                                color: CIPTheme.textPrimary,
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text('PDF · DOCX · XLSX · CSV · ZIP',
                            style: TextStyle(
                                color: CIPTheme.textMuted, fontSize: 11)),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle,
                            color: CIPTheme.primary, size: 32),
                        const SizedBox(height: 8),
                        Text(_fileName ?? '',
                            style: const TextStyle(
                                color: CIPTheme.primary,
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        TextButton(
                          onPressed: _pickFile,
                          child: const Text('Change file',
                              style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),

          if (!_isReplacement) ...[
            const _Label('Document Name'),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: CIPTheme.textPrimary),
              decoration: const InputDecoration(
                  hintText: 'e.g. Fatigue Management Manual'),
            ),
            const SizedBox(height: 16),

            const _Label('Category'),
            const SizedBox(height: 6),
            _CategoryPicker(
              value: _category,
              onChanged: (c) => setState(() => _category = c),
            ),
            const SizedBox(height: 16),

            const _Label('Description'),
            const SizedBox(height: 6),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              style: const TextStyle(color: CIPTheme.textPrimary),
              decoration: const InputDecoration(
                  hintText: 'Brief description of this document'),
            ),
            const SizedBox(height: 16),
          ],

          const _Label('Effective Date'),
          const SizedBox(height: 6),
          _DatePickerField(
            value: _effectiveDate,
            onChanged: (d) => setState(() => _effectiveDate = d),
          ),
          const SizedBox(height: 16),

          const _Label('Expiration Date (optional)'),
          const SizedBox(height: 6),
          _DatePickerField(
            value: _expirationDate,
            onChanged: (d) => setState(() => _expirationDate = d),
            optional: true,
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_file != null &&
                      upload.status != UploadStatus.uploading)
                  ? _submit
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: CIPTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: upload.status == UploadStatus.uploading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text(
                upload.status == UploadStatus.uploading
                    ? 'Uploading…'
                    : (_isReplacement ? 'Upload New Version' : 'Upload Document'),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),

          if (upload.status == UploadStatus.error && upload.error != null) ...[
            const SizedBox(height: 12),
            Text(upload.error!,
                style: const TextStyle(color: CIPTheme.error, fontSize: 12)),
          ],

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CIPTheme.navLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(children: [
              Icon(Icons.lock_outline, color: CIPTheme.textMuted, size: 14),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Documents are stored securely and never exposed to the '
                  'mobile app. Only AI-generated answers and citations are shared.',
                  style: TextStyle(color: CIPTheme.textMuted, fontSize: 11, height: 1.4),
                ),
              ),
            ]),
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
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: CIPTheme.textSecondary, fontSize: 12,
          fontWeight: FontWeight.w600));
}

class _CategoryPicker extends StatelessWidget {
  final DocumentCategory value;
  final ValueChanged<DocumentCategory> onChanged;
  const _CategoryPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: DocumentCategory.values.map((c) {
        final active = c == value;
        return GestureDetector(
          onTap: () => onChanged(c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: active
                  ? CIPTheme.primary.withOpacity(0.15)
                  : CIPTheme.navLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: active ? CIPTheme.primary : CIPTheme.divider,
                  width: active ? 1.5 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(c.icon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 5),
              Text(c.label,
                  style: TextStyle(
                      color: active ? CIPTheme.primary : CIPTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final bool optional;

  const _DatePickerField({
    required this.value, required this.onChanged, this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
          builder: (_, child) => Theme(
            data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(primary: CIPTheme.primary)),
            child: child!,
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: CIPTheme.navLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: CIPTheme.divider),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined,
              color: CIPTheme.textMuted, size: 16),
          const SizedBox(width: 10),
          Text(
            value != null
                ? '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}'
                : (optional ? 'Not set' : 'Select date'),
            style: const TextStyle(color: CIPTheme.textPrimary, fontSize: 13),
          ),
        ]),
      ),
    );
  }
}
