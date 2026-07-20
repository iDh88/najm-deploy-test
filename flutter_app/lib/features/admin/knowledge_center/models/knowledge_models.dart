// Knowledge Center & Ask Operations AI — Flutter Models

enum DocumentCategory {
  gom, fatigueManagement, crewScheduling, tradePolicies,
  gacaRegulations, operationalBulletins, airportInformation,
  layoverGuides, companyProcedures, emergencyProcedures, other,
}

enum DocumentStatus { processing, active, archived, failed, disabled }
enum FileType { pdf, docx, xlsx, csv, zip, pptx, html, txt }

extension DocumentCategoryX on DocumentCategory {
  String get apiValue {
    switch (this) {
      case DocumentCategory.gom:                   return 'GOM';
      case DocumentCategory.fatigueManagement:      return 'FATIGUE_MANAGEMENT';
      case DocumentCategory.crewScheduling:         return 'CREW_SCHEDULING';
      case DocumentCategory.tradePolicies:          return 'TRADE_POLICIES';
      case DocumentCategory.gacaRegulations:        return 'GACA_REGULATIONS';
      case DocumentCategory.operationalBulletins:   return 'OPERATIONAL_BULLETINS';
      case DocumentCategory.airportInformation:     return 'AIRPORT_INFORMATION';
      case DocumentCategory.layoverGuides:          return 'LAYOVER_GUIDES';
      case DocumentCategory.companyProcedures:      return 'COMPANY_PROCEDURES';
      case DocumentCategory.emergencyProcedures:    return 'EMERGENCY_PROCEDURES';
      case DocumentCategory.other:                  return 'OTHER';
    }
  }

  String get label {
    switch (this) {
      case DocumentCategory.gom:                 return 'GOM';
      case DocumentCategory.fatigueManagement:    return 'Fatigue Management';
      case DocumentCategory.crewScheduling:       return 'Crew Scheduling';
      case DocumentCategory.tradePolicies:        return 'Trade Policies';
      case DocumentCategory.gacaRegulations:      return 'GACA Regulations';
      case DocumentCategory.operationalBulletins: return 'Operational Bulletins';
      case DocumentCategory.airportInformation:   return 'Airport Information';
      case DocumentCategory.layoverGuides:        return 'Layover Guides';
      case DocumentCategory.companyProcedures:    return 'Company Procedures';
      case DocumentCategory.emergencyProcedures:  return 'Emergency Procedures';
      case DocumentCategory.other:                return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case DocumentCategory.gom:                 return '📘';
      case DocumentCategory.fatigueManagement:    return '🔋';
      case DocumentCategory.crewScheduling:       return '📅';
      case DocumentCategory.tradePolicies:        return '🔄';
      case DocumentCategory.gacaRegulations:      return '⚖️';
      case DocumentCategory.operationalBulletins: return '📢';
      case DocumentCategory.airportInformation:   return '🛫';
      case DocumentCategory.layoverGuides:        return '🏨';
      case DocumentCategory.companyProcedures:    return '📋';
      case DocumentCategory.emergencyProcedures:  return '🚨';
      case DocumentCategory.other:                return '📄';
    }
  }

  static DocumentCategory fromApi(String v) {
    switch (v.toUpperCase()) {
      case 'GOM':                   return DocumentCategory.gom;
      case 'FATIGUE_MANAGEMENT':    return DocumentCategory.fatigueManagement;
      case 'CREW_SCHEDULING':       return DocumentCategory.crewScheduling;
      case 'TRADE_POLICIES':        return DocumentCategory.tradePolicies;
      case 'GACA_REGULATIONS':      return DocumentCategory.gacaRegulations;
      case 'OPERATIONAL_BULLETINS': return DocumentCategory.operationalBulletins;
      case 'AIRPORT_INFORMATION':   return DocumentCategory.airportInformation;
      case 'LAYOVER_GUIDES':        return DocumentCategory.layoverGuides;
      case 'COMPANY_PROCEDURES':    return DocumentCategory.companyProcedures;
      case 'EMERGENCY_PROCEDURES':  return DocumentCategory.emergencyProcedures;
      default:                      return DocumentCategory.other;
    }
  }
}

extension DocumentStatusX on DocumentStatus {
  static DocumentStatus fromApi(String v) {
    switch (v.toUpperCase()) {
      case 'PROCESSING': return DocumentStatus.processing;
      case 'ACTIVE':      return DocumentStatus.active;
      case 'ARCHIVED':    return DocumentStatus.archived;
      case 'FAILED':      return DocumentStatus.failed;
      default:            return DocumentStatus.disabled;
    }
  }

  String get label {
    switch (this) {
      case DocumentStatus.processing: return 'Processing';
      case DocumentStatus.active:     return 'Active';
      case DocumentStatus.archived:   return 'Archived';
      case DocumentStatus.failed:     return 'Failed';
      case DocumentStatus.disabled:   return 'Disabled';
    }
  }

  String get emoji {
    switch (this) {
      case DocumentStatus.processing: return '⏳';
      case DocumentStatus.active:     return '✅';
      case DocumentStatus.archived:   return '🗄️';
      case DocumentStatus.failed:     return '❌';
      case DocumentStatus.disabled:   return '🚫';
    }
  }
}

// ── Knowledge Document ────────────────────────────────────────────────────────

class KnowledgeDocument {
  final String id;
  final String name;
  final DocumentCategory category;
  final String description;
  final String? activeVersionId;
  final bool isDisabled;
  final DateTime createdAt;

  const KnowledgeDocument({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    this.activeVersionId,
    required this.isDisabled,
    required this.createdAt,
  });

  factory KnowledgeDocument.fromMap(String id, Map<String, dynamic> m) =>
      KnowledgeDocument(
        id: id,
        name: m['name'] as String? ?? '',
        category: DocumentCategoryX.fromApi(m['category'] as String? ?? 'OTHER'),
        description: m['description'] as String? ?? '',
        activeVersionId: m['activeVersionId'] as String?,
        isDisabled: m['isDisabled'] as bool? ?? false,
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}

// ── Document Version ──────────────────────────────────────────────────────────

class DocumentVersion {
  final String id;
  final String documentId;
  final int versionNumber;
  final String fileType;
  final DocumentStatus status;
  final DateTime effectiveDate;
  final DateTime? expirationDate;
  final String uploadedBy;
  final DateTime uploadedAt;
  final int? pageCount;
  final int? chunkCount;
  final String? processingError;

  const DocumentVersion({
    required this.id,
    required this.documentId,
    required this.versionNumber,
    required this.fileType,
    required this.status,
    required this.effectiveDate,
    this.expirationDate,
    required this.uploadedBy,
    required this.uploadedAt,
    this.pageCount,
    this.chunkCount,
    this.processingError,
  });

  factory DocumentVersion.fromMap(String id, Map<String, dynamic> m) =>
      DocumentVersion(
        id: id,
        documentId: m['documentId'] as String? ?? '',
        versionNumber: m['versionNumber'] as int? ?? 1,
        fileType: m['fileType'] as String? ?? 'PDF',
        status: DocumentStatusX.fromApi(m['status'] as String? ?? 'PROCESSING'),
        effectiveDate: DateTime.tryParse(m['effectiveDate'] as String? ?? '') ?? DateTime.now(),
        expirationDate: m['expirationDate'] != null
            ? DateTime.tryParse(m['expirationDate'] as String) : null,
        uploadedBy: m['uploadedBy'] as String? ?? '',
        uploadedAt: DateTime.tryParse(m['uploadedAt'] as String? ?? '') ?? DateTime.now(),
        pageCount: m['pageCount'] as int?,
        chunkCount: m['chunkCount'] as int?,
        processingError: m['processingError'] as String?,
      );

  String get versionLabel => 'Rev $versionNumber';
}

// ── Change Summary ────────────────────────────────────────────────────────────

class ChangeSummaryItem {
  final String category;   // rule_change | legality_change | fatigue_change | general
  final String description;
  final String? oldText;
  final String? newText;
  final String? section;

  const ChangeSummaryItem({
    required this.category,
    required this.description,
    this.oldText,
    this.newText,
    this.section,
  });

  factory ChangeSummaryItem.fromMap(Map<String, dynamic> m) => ChangeSummaryItem(
    category: m['category'] as String? ?? 'general',
    description: m['description'] as String? ?? '',
    oldText: m['oldText'] as String?,
    newText: m['newText'] as String?,
    section: m['section'] as String?,
  );

  String get categoryLabel {
    switch (category) {
      case 'rule_change':     return 'Rule Change';
      case 'legality_change': return 'Legality Change';
      case 'fatigue_change':  return 'Fatigue Change';
      default:                return 'General Update';
    }
  }

  String get categoryEmoji {
    switch (category) {
      case 'rule_change':     return '📏';
      case 'legality_change': return '⚖️';
      case 'fatigue_change':  return '🔋';
      default:                return 'ℹ️';
    }
  }
}

class DocumentChangeSummary {
  final String documentId;
  final String oldVersionId, newVersionId;
  final int oldVersionNumber, newVersionNumber;
  final DateTime generatedAt;
  final String overallSummary;
  final List<ChangeSummaryItem> items;

  const DocumentChangeSummary({
    required this.documentId,
    required this.oldVersionId,
    required this.newVersionId,
    required this.oldVersionNumber,
    required this.newVersionNumber,
    required this.generatedAt,
    required this.overallSummary,
    required this.items,
  });

  factory DocumentChangeSummary.fromMap(Map<String, dynamic> m) =>
      DocumentChangeSummary(
        documentId: m['documentId'] as String? ?? '',
        oldVersionId: m['oldVersionId'] as String? ?? '',
        newVersionId: m['newVersionId'] as String? ?? '',
        oldVersionNumber: m['oldVersionNumber'] as int? ?? 0,
        newVersionNumber: m['newVersionNumber'] as int? ?? 0,
        generatedAt: DateTime.tryParse(m['generatedAt'] as String? ?? '') ?? DateTime.now(),
        overallSummary: m['overallSummary'] as String? ?? '',
        items: (m['items'] as List? ?? [])
            .map((i) => ChangeSummaryItem.fromMap(Map<String, dynamic>.from(i as Map)))
            .toList(),
      );

  bool get hasRuleChanges => items.any((i) => i.category == 'rule_change');
  bool get hasLegalityChanges => items.any((i) => i.category == 'legality_change');
  bool get hasFatigueChanges => items.any((i) => i.category == 'fatigue_change');
}

// ── Ask Operations AI ──────────────────────────────────────────────────────────

class Citation {
  final String document;
  final String version;
  final String? section;
  final int? page;
  final String label;

  const Citation({
    required this.document,
    required this.version,
    this.section,
    this.page,
    required this.label,
  });

  factory Citation.fromMap(Map<String, dynamic> m) => Citation(
    document: m['document'] as String? ?? '',
    version: m['version'] as String? ?? '',
    section: m['section'] as String?,
    page: m['page'] as int?,
    label: m['label'] as String? ?? '',
  );
}

class AskAnswer {
  final String answer;
  final String confidence;   // HIGH | MEDIUM | LOW
  final List<Citation> citations;

  const AskAnswer({
    required this.answer,
    required this.confidence,
    required this.citations,
  });

  factory AskAnswer.fromMap(Map<String, dynamic> m) => AskAnswer(
    answer: m['answer'] as String? ?? '',
    confidence: m['confidence'] as String? ?? 'LOW',
    citations: (m['citations'] as List? ?? [])
        .map((c) => Citation.fromMap(Map<String, dynamic>.from(c as Map)))
        .toList(),
  );
}

class ChatMessage {
  final String text;
  final bool isUser;
  final AskAnswer? answer;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.answer,
    required this.timestamp,
  });
}
