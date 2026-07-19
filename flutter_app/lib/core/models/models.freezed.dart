// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

CIPUser _$CIPUserFromJson(Map<String, dynamic> json) {
  return _CIPUser.fromJson(json);
}

/// @nodoc
mixin _$CIPUser {
  String get id => throw _privateConstructorUsedError;
  String get crewId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get nameAr => throw _privateConstructorUsedError;
  CrewRank get rank => throw _privateConstructorUsedError;
  String get baseStation => throw _privateConstructorUsedError;
  List<String> get fleetTypes => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  String get phone => throw _privateConstructorUsedError;
  UserPreferences get preferences => throw _privateConstructorUsedError;
  UserMode get userMode => throw _privateConstructorUsedError;
  SubscriptionTier get subscriptionTier => throw _privateConstructorUsedError;
  DateTime? get subscriptionExpiry =>
      throw _privateConstructorUsedError; // stripeCustomerId removed (0.3) — legacy Stripe is not in the roadmap;
// json_serializable ignores the stale key on existing Firestore docs.
  Map<String, double> get preferenceVector =>
      throw _privateConstructorUsedError;
  int get coldStartPhase => throw _privateConstructorUsedError;
  int get totalMonthsActive => throw _privateConstructorUsedError;
  PrivacyConsents get privacyConsents => throw _privateConstructorUsedError;
  String get locale => throw _privateConstructorUsedError;
  String get accountStatus => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get lastActiveAt => throw _privateConstructorUsedError;

  /// Serializes this CIPUser to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CIPUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CIPUserCopyWith<CIPUser> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CIPUserCopyWith<$Res> {
  factory $CIPUserCopyWith(CIPUser value, $Res Function(CIPUser) then) =
      _$CIPUserCopyWithImpl<$Res, CIPUser>;
  @useResult
  $Res call(
      {String id,
      String crewId,
      String name,
      String nameAr,
      CrewRank rank,
      String baseStation,
      List<String> fleetTypes,
      String email,
      String phone,
      UserPreferences preferences,
      UserMode userMode,
      SubscriptionTier subscriptionTier,
      DateTime? subscriptionExpiry,
      Map<String, double> preferenceVector,
      int coldStartPhase,
      int totalMonthsActive,
      PrivacyConsents privacyConsents,
      String locale,
      String accountStatus,
      DateTime createdAt,
      DateTime lastActiveAt});

  $UserPreferencesCopyWith<$Res> get preferences;
  $PrivacyConsentsCopyWith<$Res> get privacyConsents;
}

/// @nodoc
class _$CIPUserCopyWithImpl<$Res, $Val extends CIPUser>
    implements $CIPUserCopyWith<$Res> {
  _$CIPUserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CIPUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? crewId = null,
    Object? name = null,
    Object? nameAr = null,
    Object? rank = null,
    Object? baseStation = null,
    Object? fleetTypes = null,
    Object? email = null,
    Object? phone = null,
    Object? preferences = null,
    Object? userMode = null,
    Object? subscriptionTier = null,
    Object? subscriptionExpiry = freezed,
    Object? preferenceVector = null,
    Object? coldStartPhase = null,
    Object? totalMonthsActive = null,
    Object? privacyConsents = null,
    Object? locale = null,
    Object? accountStatus = null,
    Object? createdAt = null,
    Object? lastActiveAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      crewId: null == crewId
          ? _value.crewId
          : crewId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      nameAr: null == nameAr
          ? _value.nameAr
          : nameAr // ignore: cast_nullable_to_non_nullable
              as String,
      rank: null == rank
          ? _value.rank
          : rank // ignore: cast_nullable_to_non_nullable
              as CrewRank,
      baseStation: null == baseStation
          ? _value.baseStation
          : baseStation // ignore: cast_nullable_to_non_nullable
              as String,
      fleetTypes: null == fleetTypes
          ? _value.fleetTypes
          : fleetTypes // ignore: cast_nullable_to_non_nullable
              as List<String>,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      preferences: null == preferences
          ? _value.preferences
          : preferences // ignore: cast_nullable_to_non_nullable
              as UserPreferences,
      userMode: null == userMode
          ? _value.userMode
          : userMode // ignore: cast_nullable_to_non_nullable
              as UserMode,
      subscriptionTier: null == subscriptionTier
          ? _value.subscriptionTier
          : subscriptionTier // ignore: cast_nullable_to_non_nullable
              as SubscriptionTier,
      subscriptionExpiry: freezed == subscriptionExpiry
          ? _value.subscriptionExpiry
          : subscriptionExpiry // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      preferenceVector: null == preferenceVector
          ? _value.preferenceVector
          : preferenceVector // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      coldStartPhase: null == coldStartPhase
          ? _value.coldStartPhase
          : coldStartPhase // ignore: cast_nullable_to_non_nullable
              as int,
      totalMonthsActive: null == totalMonthsActive
          ? _value.totalMonthsActive
          : totalMonthsActive // ignore: cast_nullable_to_non_nullable
              as int,
      privacyConsents: null == privacyConsents
          ? _value.privacyConsents
          : privacyConsents // ignore: cast_nullable_to_non_nullable
              as PrivacyConsents,
      locale: null == locale
          ? _value.locale
          : locale // ignore: cast_nullable_to_non_nullable
              as String,
      accountStatus: null == accountStatus
          ? _value.accountStatus
          : accountStatus // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastActiveAt: null == lastActiveAt
          ? _value.lastActiveAt
          : lastActiveAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }

  /// Create a copy of CIPUser
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserPreferencesCopyWith<$Res> get preferences {
    return $UserPreferencesCopyWith<$Res>(_value.preferences, (value) {
      return _then(_value.copyWith(preferences: value) as $Val);
    });
  }

  /// Create a copy of CIPUser
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PrivacyConsentsCopyWith<$Res> get privacyConsents {
    return $PrivacyConsentsCopyWith<$Res>(_value.privacyConsents, (value) {
      return _then(_value.copyWith(privacyConsents: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$CIPUserImplCopyWith<$Res> implements $CIPUserCopyWith<$Res> {
  factory _$$CIPUserImplCopyWith(
          _$CIPUserImpl value, $Res Function(_$CIPUserImpl) then) =
      __$$CIPUserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String crewId,
      String name,
      String nameAr,
      CrewRank rank,
      String baseStation,
      List<String> fleetTypes,
      String email,
      String phone,
      UserPreferences preferences,
      UserMode userMode,
      SubscriptionTier subscriptionTier,
      DateTime? subscriptionExpiry,
      Map<String, double> preferenceVector,
      int coldStartPhase,
      int totalMonthsActive,
      PrivacyConsents privacyConsents,
      String locale,
      String accountStatus,
      DateTime createdAt,
      DateTime lastActiveAt});

  @override
  $UserPreferencesCopyWith<$Res> get preferences;
  @override
  $PrivacyConsentsCopyWith<$Res> get privacyConsents;
}

/// @nodoc
class __$$CIPUserImplCopyWithImpl<$Res>
    extends _$CIPUserCopyWithImpl<$Res, _$CIPUserImpl>
    implements _$$CIPUserImplCopyWith<$Res> {
  __$$CIPUserImplCopyWithImpl(
      _$CIPUserImpl _value, $Res Function(_$CIPUserImpl) _then)
      : super(_value, _then);

  /// Create a copy of CIPUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? crewId = null,
    Object? name = null,
    Object? nameAr = null,
    Object? rank = null,
    Object? baseStation = null,
    Object? fleetTypes = null,
    Object? email = null,
    Object? phone = null,
    Object? preferences = null,
    Object? userMode = null,
    Object? subscriptionTier = null,
    Object? subscriptionExpiry = freezed,
    Object? preferenceVector = null,
    Object? coldStartPhase = null,
    Object? totalMonthsActive = null,
    Object? privacyConsents = null,
    Object? locale = null,
    Object? accountStatus = null,
    Object? createdAt = null,
    Object? lastActiveAt = null,
  }) {
    return _then(_$CIPUserImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      crewId: null == crewId
          ? _value.crewId
          : crewId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      nameAr: null == nameAr
          ? _value.nameAr
          : nameAr // ignore: cast_nullable_to_non_nullable
              as String,
      rank: null == rank
          ? _value.rank
          : rank // ignore: cast_nullable_to_non_nullable
              as CrewRank,
      baseStation: null == baseStation
          ? _value.baseStation
          : baseStation // ignore: cast_nullable_to_non_nullable
              as String,
      fleetTypes: null == fleetTypes
          ? _value._fleetTypes
          : fleetTypes // ignore: cast_nullable_to_non_nullable
              as List<String>,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      preferences: null == preferences
          ? _value.preferences
          : preferences // ignore: cast_nullable_to_non_nullable
              as UserPreferences,
      userMode: null == userMode
          ? _value.userMode
          : userMode // ignore: cast_nullable_to_non_nullable
              as UserMode,
      subscriptionTier: null == subscriptionTier
          ? _value.subscriptionTier
          : subscriptionTier // ignore: cast_nullable_to_non_nullable
              as SubscriptionTier,
      subscriptionExpiry: freezed == subscriptionExpiry
          ? _value.subscriptionExpiry
          : subscriptionExpiry // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      preferenceVector: null == preferenceVector
          ? _value._preferenceVector
          : preferenceVector // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      coldStartPhase: null == coldStartPhase
          ? _value.coldStartPhase
          : coldStartPhase // ignore: cast_nullable_to_non_nullable
              as int,
      totalMonthsActive: null == totalMonthsActive
          ? _value.totalMonthsActive
          : totalMonthsActive // ignore: cast_nullable_to_non_nullable
              as int,
      privacyConsents: null == privacyConsents
          ? _value.privacyConsents
          : privacyConsents // ignore: cast_nullable_to_non_nullable
              as PrivacyConsents,
      locale: null == locale
          ? _value.locale
          : locale // ignore: cast_nullable_to_non_nullable
              as String,
      accountStatus: null == accountStatus
          ? _value.accountStatus
          : accountStatus // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastActiveAt: null == lastActiveAt
          ? _value.lastActiveAt
          : lastActiveAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CIPUserImpl implements _CIPUser {
  const _$CIPUserImpl(
      {required this.id,
      required this.crewId,
      required this.name,
      required this.nameAr,
      required this.rank,
      required this.baseStation,
      final List<String> fleetTypes = const [],
      required this.email,
      this.phone = '',
      this.preferences = const UserPreferences(),
      this.userMode = UserMode.balanced,
      this.subscriptionTier = SubscriptionTier.free,
      this.subscriptionExpiry,
      final Map<String, double> preferenceVector = const {},
      this.coldStartPhase = 1,
      this.totalMonthsActive = 0,
      this.privacyConsents = const PrivacyConsents(),
      this.locale = 'ar',
      this.accountStatus = 'pending',
      required this.createdAt,
      required this.lastActiveAt})
      : _fleetTypes = fleetTypes,
        _preferenceVector = preferenceVector;

  factory _$CIPUserImpl.fromJson(Map<String, dynamic> json) =>
      _$$CIPUserImplFromJson(json);

  @override
  final String id;
  @override
  final String crewId;
  @override
  final String name;
  @override
  final String nameAr;
  @override
  final CrewRank rank;
  @override
  final String baseStation;
  final List<String> _fleetTypes;
  @override
  @JsonKey()
  List<String> get fleetTypes {
    if (_fleetTypes is EqualUnmodifiableListView) return _fleetTypes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_fleetTypes);
  }

  @override
  final String email;
  @override
  @JsonKey()
  final String phone;
  @override
  @JsonKey()
  final UserPreferences preferences;
  @override
  @JsonKey()
  final UserMode userMode;
  @override
  @JsonKey()
  final SubscriptionTier subscriptionTier;
  @override
  final DateTime? subscriptionExpiry;
// stripeCustomerId removed (0.3) — legacy Stripe is not in the roadmap;
// json_serializable ignores the stale key on existing Firestore docs.
  final Map<String, double> _preferenceVector;
// stripeCustomerId removed (0.3) — legacy Stripe is not in the roadmap;
// json_serializable ignores the stale key on existing Firestore docs.
  @override
  @JsonKey()
  Map<String, double> get preferenceVector {
    if (_preferenceVector is EqualUnmodifiableMapView) return _preferenceVector;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_preferenceVector);
  }

  @override
  @JsonKey()
  final int coldStartPhase;
  @override
  @JsonKey()
  final int totalMonthsActive;
  @override
  @JsonKey()
  final PrivacyConsents privacyConsents;
  @override
  @JsonKey()
  final String locale;
  @override
  @JsonKey()
  final String accountStatus;
  @override
  final DateTime createdAt;
  @override
  final DateTime lastActiveAt;

  @override
  String toString() {
    return 'CIPUser(id: $id, crewId: $crewId, name: $name, nameAr: $nameAr, rank: $rank, baseStation: $baseStation, fleetTypes: $fleetTypes, email: $email, phone: $phone, preferences: $preferences, userMode: $userMode, subscriptionTier: $subscriptionTier, subscriptionExpiry: $subscriptionExpiry, preferenceVector: $preferenceVector, coldStartPhase: $coldStartPhase, totalMonthsActive: $totalMonthsActive, privacyConsents: $privacyConsents, locale: $locale, accountStatus: $accountStatus, createdAt: $createdAt, lastActiveAt: $lastActiveAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CIPUserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.crewId, crewId) || other.crewId == crewId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.nameAr, nameAr) || other.nameAr == nameAr) &&
            (identical(other.rank, rank) || other.rank == rank) &&
            (identical(other.baseStation, baseStation) ||
                other.baseStation == baseStation) &&
            const DeepCollectionEquality()
                .equals(other._fleetTypes, _fleetTypes) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.preferences, preferences) ||
                other.preferences == preferences) &&
            (identical(other.userMode, userMode) ||
                other.userMode == userMode) &&
            (identical(other.subscriptionTier, subscriptionTier) ||
                other.subscriptionTier == subscriptionTier) &&
            (identical(other.subscriptionExpiry, subscriptionExpiry) ||
                other.subscriptionExpiry == subscriptionExpiry) &&
            const DeepCollectionEquality()
                .equals(other._preferenceVector, _preferenceVector) &&
            (identical(other.coldStartPhase, coldStartPhase) ||
                other.coldStartPhase == coldStartPhase) &&
            (identical(other.totalMonthsActive, totalMonthsActive) ||
                other.totalMonthsActive == totalMonthsActive) &&
            (identical(other.privacyConsents, privacyConsents) ||
                other.privacyConsents == privacyConsents) &&
            (identical(other.locale, locale) || other.locale == locale) &&
            (identical(other.accountStatus, accountStatus) ||
                other.accountStatus == accountStatus) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.lastActiveAt, lastActiveAt) ||
                other.lastActiveAt == lastActiveAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        crewId,
        name,
        nameAr,
        rank,
        baseStation,
        const DeepCollectionEquality().hash(_fleetTypes),
        email,
        phone,
        preferences,
        userMode,
        subscriptionTier,
        subscriptionExpiry,
        const DeepCollectionEquality().hash(_preferenceVector),
        coldStartPhase,
        totalMonthsActive,
        privacyConsents,
        locale,
        accountStatus,
        createdAt,
        lastActiveAt
      ]);

  /// Create a copy of CIPUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CIPUserImplCopyWith<_$CIPUserImpl> get copyWith =>
      __$$CIPUserImplCopyWithImpl<_$CIPUserImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CIPUserImplToJson(
      this,
    );
  }
}

abstract class _CIPUser implements CIPUser {
  const factory _CIPUser(
      {required final String id,
      required final String crewId,
      required final String name,
      required final String nameAr,
      required final CrewRank rank,
      required final String baseStation,
      final List<String> fleetTypes,
      required final String email,
      final String phone,
      final UserPreferences preferences,
      final UserMode userMode,
      final SubscriptionTier subscriptionTier,
      final DateTime? subscriptionExpiry,
      final Map<String, double> preferenceVector,
      final int coldStartPhase,
      final int totalMonthsActive,
      final PrivacyConsents privacyConsents,
      final String locale,
      final String accountStatus,
      required final DateTime createdAt,
      required final DateTime lastActiveAt}) = _$CIPUserImpl;

  factory _CIPUser.fromJson(Map<String, dynamic> json) = _$CIPUserImpl.fromJson;

  @override
  String get id;
  @override
  String get crewId;
  @override
  String get name;
  @override
  String get nameAr;
  @override
  CrewRank get rank;
  @override
  String get baseStation;
  @override
  List<String> get fleetTypes;
  @override
  String get email;
  @override
  String get phone;
  @override
  UserPreferences get preferences;
  @override
  UserMode get userMode;
  @override
  SubscriptionTier get subscriptionTier;
  @override
  DateTime?
      get subscriptionExpiry; // stripeCustomerId removed (0.3) — legacy Stripe is not in the roadmap;
// json_serializable ignores the stale key on existing Firestore docs.
  @override
  Map<String, double> get preferenceVector;
  @override
  int get coldStartPhase;
  @override
  int get totalMonthsActive;
  @override
  PrivacyConsents get privacyConsents;
  @override
  String get locale;
  @override
  String get accountStatus;
  @override
  DateTime get createdAt;
  @override
  DateTime get lastActiveAt;

  /// Create a copy of CIPUser
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CIPUserImplCopyWith<_$CIPUserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

UserPreferences _$UserPreferencesFromJson(Map<String, dynamic> json) {
  return _UserPreferences.fromJson(json);
}

/// @nodoc
mixin _$UserPreferences {
  List<String> get preferredDest => throw _privateConstructorUsedError;
  List<String> get avoidedDest => throw _privateConstructorUsedError;
  List<int> get preferredOff =>
      throw _privateConstructorUsedError; // 0=Sun, 1=Mon...
  double get maxDutyHours => throw _privateConstructorUsedError;
  double get minRestHours => throw _privateConstructorUsedError;
  bool get homebaseReturn => throw _privateConstructorUsedError;

  /// Serializes this UserPreferences to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UserPreferences
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserPreferencesCopyWith<UserPreferences> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserPreferencesCopyWith<$Res> {
  factory $UserPreferencesCopyWith(
          UserPreferences value, $Res Function(UserPreferences) then) =
      _$UserPreferencesCopyWithImpl<$Res, UserPreferences>;
  @useResult
  $Res call(
      {List<String> preferredDest,
      List<String> avoidedDest,
      List<int> preferredOff,
      double maxDutyHours,
      double minRestHours,
      bool homebaseReturn});
}

/// @nodoc
class _$UserPreferencesCopyWithImpl<$Res, $Val extends UserPreferences>
    implements $UserPreferencesCopyWith<$Res> {
  _$UserPreferencesCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserPreferences
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? preferredDest = null,
    Object? avoidedDest = null,
    Object? preferredOff = null,
    Object? maxDutyHours = null,
    Object? minRestHours = null,
    Object? homebaseReturn = null,
  }) {
    return _then(_value.copyWith(
      preferredDest: null == preferredDest
          ? _value.preferredDest
          : preferredDest // ignore: cast_nullable_to_non_nullable
              as List<String>,
      avoidedDest: null == avoidedDest
          ? _value.avoidedDest
          : avoidedDest // ignore: cast_nullable_to_non_nullable
              as List<String>,
      preferredOff: null == preferredOff
          ? _value.preferredOff
          : preferredOff // ignore: cast_nullable_to_non_nullable
              as List<int>,
      maxDutyHours: null == maxDutyHours
          ? _value.maxDutyHours
          : maxDutyHours // ignore: cast_nullable_to_non_nullable
              as double,
      minRestHours: null == minRestHours
          ? _value.minRestHours
          : minRestHours // ignore: cast_nullable_to_non_nullable
              as double,
      homebaseReturn: null == homebaseReturn
          ? _value.homebaseReturn
          : homebaseReturn // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserPreferencesImplCopyWith<$Res>
    implements $UserPreferencesCopyWith<$Res> {
  factory _$$UserPreferencesImplCopyWith(_$UserPreferencesImpl value,
          $Res Function(_$UserPreferencesImpl) then) =
      __$$UserPreferencesImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<String> preferredDest,
      List<String> avoidedDest,
      List<int> preferredOff,
      double maxDutyHours,
      double minRestHours,
      bool homebaseReturn});
}

/// @nodoc
class __$$UserPreferencesImplCopyWithImpl<$Res>
    extends _$UserPreferencesCopyWithImpl<$Res, _$UserPreferencesImpl>
    implements _$$UserPreferencesImplCopyWith<$Res> {
  __$$UserPreferencesImplCopyWithImpl(
      _$UserPreferencesImpl _value, $Res Function(_$UserPreferencesImpl) _then)
      : super(_value, _then);

  /// Create a copy of UserPreferences
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? preferredDest = null,
    Object? avoidedDest = null,
    Object? preferredOff = null,
    Object? maxDutyHours = null,
    Object? minRestHours = null,
    Object? homebaseReturn = null,
  }) {
    return _then(_$UserPreferencesImpl(
      preferredDest: null == preferredDest
          ? _value._preferredDest
          : preferredDest // ignore: cast_nullable_to_non_nullable
              as List<String>,
      avoidedDest: null == avoidedDest
          ? _value._avoidedDest
          : avoidedDest // ignore: cast_nullable_to_non_nullable
              as List<String>,
      preferredOff: null == preferredOff
          ? _value._preferredOff
          : preferredOff // ignore: cast_nullable_to_non_nullable
              as List<int>,
      maxDutyHours: null == maxDutyHours
          ? _value.maxDutyHours
          : maxDutyHours // ignore: cast_nullable_to_non_nullable
              as double,
      minRestHours: null == minRestHours
          ? _value.minRestHours
          : minRestHours // ignore: cast_nullable_to_non_nullable
              as double,
      homebaseReturn: null == homebaseReturn
          ? _value.homebaseReturn
          : homebaseReturn // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserPreferencesImpl implements _UserPreferences {
  const _$UserPreferencesImpl(
      {final List<String> preferredDest = const [],
      final List<String> avoidedDest = const [],
      final List<int> preferredOff = const [],
      this.maxDutyHours = 120,
      this.minRestHours = 10,
      this.homebaseReturn = true})
      : _preferredDest = preferredDest,
        _avoidedDest = avoidedDest,
        _preferredOff = preferredOff;

  factory _$UserPreferencesImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserPreferencesImplFromJson(json);

  final List<String> _preferredDest;
  @override
  @JsonKey()
  List<String> get preferredDest {
    if (_preferredDest is EqualUnmodifiableListView) return _preferredDest;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_preferredDest);
  }

  final List<String> _avoidedDest;
  @override
  @JsonKey()
  List<String> get avoidedDest {
    if (_avoidedDest is EqualUnmodifiableListView) return _avoidedDest;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_avoidedDest);
  }

  final List<int> _preferredOff;
  @override
  @JsonKey()
  List<int> get preferredOff {
    if (_preferredOff is EqualUnmodifiableListView) return _preferredOff;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_preferredOff);
  }

// 0=Sun, 1=Mon...
  @override
  @JsonKey()
  final double maxDutyHours;
  @override
  @JsonKey()
  final double minRestHours;
  @override
  @JsonKey()
  final bool homebaseReturn;

  @override
  String toString() {
    return 'UserPreferences(preferredDest: $preferredDest, avoidedDest: $avoidedDest, preferredOff: $preferredOff, maxDutyHours: $maxDutyHours, minRestHours: $minRestHours, homebaseReturn: $homebaseReturn)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserPreferencesImpl &&
            const DeepCollectionEquality()
                .equals(other._preferredDest, _preferredDest) &&
            const DeepCollectionEquality()
                .equals(other._avoidedDest, _avoidedDest) &&
            const DeepCollectionEquality()
                .equals(other._preferredOff, _preferredOff) &&
            (identical(other.maxDutyHours, maxDutyHours) ||
                other.maxDutyHours == maxDutyHours) &&
            (identical(other.minRestHours, minRestHours) ||
                other.minRestHours == minRestHours) &&
            (identical(other.homebaseReturn, homebaseReturn) ||
                other.homebaseReturn == homebaseReturn));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_preferredDest),
      const DeepCollectionEquality().hash(_avoidedDest),
      const DeepCollectionEquality().hash(_preferredOff),
      maxDutyHours,
      minRestHours,
      homebaseReturn);

  /// Create a copy of UserPreferences
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserPreferencesImplCopyWith<_$UserPreferencesImpl> get copyWith =>
      __$$UserPreferencesImplCopyWithImpl<_$UserPreferencesImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserPreferencesImplToJson(
      this,
    );
  }
}

abstract class _UserPreferences implements UserPreferences {
  const factory _UserPreferences(
      {final List<String> preferredDest,
      final List<String> avoidedDest,
      final List<int> preferredOff,
      final double maxDutyHours,
      final double minRestHours,
      final bool homebaseReturn}) = _$UserPreferencesImpl;

  factory _UserPreferences.fromJson(Map<String, dynamic> json) =
      _$UserPreferencesImpl.fromJson;

  @override
  List<String> get preferredDest;
  @override
  List<String> get avoidedDest;
  @override
  List<int> get preferredOff; // 0=Sun, 1=Mon...
  @override
  double get maxDutyHours;
  @override
  double get minRestHours;
  @override
  bool get homebaseReturn;

  /// Create a copy of UserPreferences
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserPreferencesImplCopyWith<_$UserPreferencesImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PrivacyConsents _$PrivacyConsentsFromJson(Map<String, dynamic> json) {
  return _PrivacyConsents.fromJson(json);
}

/// @nodoc
mixin _$PrivacyConsents {
  bool get behaviorTracking => throw _privateConstructorUsedError;
  bool get collaborativeFiltering => throw _privateConstructorUsedError;
  DateTime? get consentDate => throw _privateConstructorUsedError;

  /// Serializes this PrivacyConsents to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PrivacyConsents
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PrivacyConsentsCopyWith<PrivacyConsents> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PrivacyConsentsCopyWith<$Res> {
  factory $PrivacyConsentsCopyWith(
          PrivacyConsents value, $Res Function(PrivacyConsents) then) =
      _$PrivacyConsentsCopyWithImpl<$Res, PrivacyConsents>;
  @useResult
  $Res call(
      {bool behaviorTracking,
      bool collaborativeFiltering,
      DateTime? consentDate});
}

/// @nodoc
class _$PrivacyConsentsCopyWithImpl<$Res, $Val extends PrivacyConsents>
    implements $PrivacyConsentsCopyWith<$Res> {
  _$PrivacyConsentsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PrivacyConsents
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? behaviorTracking = null,
    Object? collaborativeFiltering = null,
    Object? consentDate = freezed,
  }) {
    return _then(_value.copyWith(
      behaviorTracking: null == behaviorTracking
          ? _value.behaviorTracking
          : behaviorTracking // ignore: cast_nullable_to_non_nullable
              as bool,
      collaborativeFiltering: null == collaborativeFiltering
          ? _value.collaborativeFiltering
          : collaborativeFiltering // ignore: cast_nullable_to_non_nullable
              as bool,
      consentDate: freezed == consentDate
          ? _value.consentDate
          : consentDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PrivacyConsentsImplCopyWith<$Res>
    implements $PrivacyConsentsCopyWith<$Res> {
  factory _$$PrivacyConsentsImplCopyWith(_$PrivacyConsentsImpl value,
          $Res Function(_$PrivacyConsentsImpl) then) =
      __$$PrivacyConsentsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool behaviorTracking,
      bool collaborativeFiltering,
      DateTime? consentDate});
}

/// @nodoc
class __$$PrivacyConsentsImplCopyWithImpl<$Res>
    extends _$PrivacyConsentsCopyWithImpl<$Res, _$PrivacyConsentsImpl>
    implements _$$PrivacyConsentsImplCopyWith<$Res> {
  __$$PrivacyConsentsImplCopyWithImpl(
      _$PrivacyConsentsImpl _value, $Res Function(_$PrivacyConsentsImpl) _then)
      : super(_value, _then);

  /// Create a copy of PrivacyConsents
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? behaviorTracking = null,
    Object? collaborativeFiltering = null,
    Object? consentDate = freezed,
  }) {
    return _then(_$PrivacyConsentsImpl(
      behaviorTracking: null == behaviorTracking
          ? _value.behaviorTracking
          : behaviorTracking // ignore: cast_nullable_to_non_nullable
              as bool,
      collaborativeFiltering: null == collaborativeFiltering
          ? _value.collaborativeFiltering
          : collaborativeFiltering // ignore: cast_nullable_to_non_nullable
              as bool,
      consentDate: freezed == consentDate
          ? _value.consentDate
          : consentDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PrivacyConsentsImpl implements _PrivacyConsents {
  const _$PrivacyConsentsImpl(
      {this.behaviorTracking = false,
      this.collaborativeFiltering = false,
      this.consentDate});

  factory _$PrivacyConsentsImpl.fromJson(Map<String, dynamic> json) =>
      _$$PrivacyConsentsImplFromJson(json);

  @override
  @JsonKey()
  final bool behaviorTracking;
  @override
  @JsonKey()
  final bool collaborativeFiltering;
  @override
  final DateTime? consentDate;

  @override
  String toString() {
    return 'PrivacyConsents(behaviorTracking: $behaviorTracking, collaborativeFiltering: $collaborativeFiltering, consentDate: $consentDate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PrivacyConsentsImpl &&
            (identical(other.behaviorTracking, behaviorTracking) ||
                other.behaviorTracking == behaviorTracking) &&
            (identical(other.collaborativeFiltering, collaborativeFiltering) ||
                other.collaborativeFiltering == collaborativeFiltering) &&
            (identical(other.consentDate, consentDate) ||
                other.consentDate == consentDate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, behaviorTracking, collaborativeFiltering, consentDate);

  /// Create a copy of PrivacyConsents
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PrivacyConsentsImplCopyWith<_$PrivacyConsentsImpl> get copyWith =>
      __$$PrivacyConsentsImplCopyWithImpl<_$PrivacyConsentsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PrivacyConsentsImplToJson(
      this,
    );
  }
}

abstract class _PrivacyConsents implements PrivacyConsents {
  const factory _PrivacyConsents(
      {final bool behaviorTracking,
      final bool collaborativeFiltering,
      final DateTime? consentDate}) = _$PrivacyConsentsImpl;

  factory _PrivacyConsents.fromJson(Map<String, dynamic> json) =
      _$PrivacyConsentsImpl.fromJson;

  @override
  bool get behaviorTracking;
  @override
  bool get collaborativeFiltering;
  @override
  DateTime? get consentDate;

  /// Create a copy of PrivacyConsents
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PrivacyConsentsImplCopyWith<_$PrivacyConsentsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FlightLine _$FlightLineFromJson(Map<String, dynamic> json) {
  return _FlightLine.fromJson(json);
}

/// @nodoc
mixin _$FlightLine {
  String get id => throw _privateConstructorUsedError;
  String get lineNumber => throw _privateConstructorUsedError;
  String get month => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get rank => throw _privateConstructorUsedError;
  String get lineType => throw _privateConstructorUsedError;
  String get carryOver => throw _privateConstructorUsedError;
  String get base => throw _privateConstructorUsedError;
  String get category => throw _privateConstructorUsedError;
  double get creditHours => throw _privateConstructorUsedError;
  double get blockHours => throw _privateConstructorUsedError;
  double get carryOverHours => throw _privateConstructorUsedError;
  int get totalLegs => throw _privateConstructorUsedError;
  int get fourLegCount => throw _privateConstructorUsedError;
  double get expense => throw _privateConstructorUsedError;
  double get allowance => throw _privateConstructorUsedError;
  double get income => throw _privateConstructorUsedError;
  bool get hasStarDays => throw _privateConstructorUsedError;
  DateTime get uploadedAt => throw _privateConstructorUsedError;
  String get validationStatus => throw _privateConstructorUsedError;
  LineSummary get summary => throw _privateConstructorUsedError;
  List<String> get destinations => throw _privateConstructorUsedError;
  List<Map<String, dynamic>> get destinationDetails =>
      throw _privateConstructorUsedError;
  List<int> get daysOff => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  List<FlightLeg> get legs => throw _privateConstructorUsedError;

  /// Serializes this FlightLine to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FlightLine
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FlightLineCopyWith<FlightLine> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FlightLineCopyWith<$Res> {
  factory $FlightLineCopyWith(
          FlightLine value, $Res Function(FlightLine) then) =
      _$FlightLineCopyWithImpl<$Res, FlightLine>;
  @useResult
  $Res call(
      {String id,
      String lineNumber,
      String month,
      String userId,
      String rank,
      String lineType,
      String carryOver,
      String base,
      String category,
      double creditHours,
      double blockHours,
      double carryOverHours,
      int totalLegs,
      int fourLegCount,
      double expense,
      double allowance,
      double income,
      bool hasStarDays,
      DateTime uploadedAt,
      String validationStatus,
      LineSummary summary,
      List<String> destinations,
      List<Map<String, dynamic>> destinationDetails,
      List<int> daysOff,
      bool isActive,
      List<FlightLeg> legs});

  $LineSummaryCopyWith<$Res> get summary;
}

/// @nodoc
class _$FlightLineCopyWithImpl<$Res, $Val extends FlightLine>
    implements $FlightLineCopyWith<$Res> {
  _$FlightLineCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FlightLine
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? lineNumber = null,
    Object? month = null,
    Object? userId = null,
    Object? rank = null,
    Object? lineType = null,
    Object? carryOver = null,
    Object? base = null,
    Object? category = null,
    Object? creditHours = null,
    Object? blockHours = null,
    Object? carryOverHours = null,
    Object? totalLegs = null,
    Object? fourLegCount = null,
    Object? expense = null,
    Object? allowance = null,
    Object? income = null,
    Object? hasStarDays = null,
    Object? uploadedAt = null,
    Object? validationStatus = null,
    Object? summary = null,
    Object? destinations = null,
    Object? destinationDetails = null,
    Object? daysOff = null,
    Object? isActive = null,
    Object? legs = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      lineNumber: null == lineNumber
          ? _value.lineNumber
          : lineNumber // ignore: cast_nullable_to_non_nullable
              as String,
      month: null == month
          ? _value.month
          : month // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      rank: null == rank
          ? _value.rank
          : rank // ignore: cast_nullable_to_non_nullable
              as String,
      lineType: null == lineType
          ? _value.lineType
          : lineType // ignore: cast_nullable_to_non_nullable
              as String,
      carryOver: null == carryOver
          ? _value.carryOver
          : carryOver // ignore: cast_nullable_to_non_nullable
              as String,
      base: null == base
          ? _value.base
          : base // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      creditHours: null == creditHours
          ? _value.creditHours
          : creditHours // ignore: cast_nullable_to_non_nullable
              as double,
      blockHours: null == blockHours
          ? _value.blockHours
          : blockHours // ignore: cast_nullable_to_non_nullable
              as double,
      carryOverHours: null == carryOverHours
          ? _value.carryOverHours
          : carryOverHours // ignore: cast_nullable_to_non_nullable
              as double,
      totalLegs: null == totalLegs
          ? _value.totalLegs
          : totalLegs // ignore: cast_nullable_to_non_nullable
              as int,
      fourLegCount: null == fourLegCount
          ? _value.fourLegCount
          : fourLegCount // ignore: cast_nullable_to_non_nullable
              as int,
      expense: null == expense
          ? _value.expense
          : expense // ignore: cast_nullable_to_non_nullable
              as double,
      allowance: null == allowance
          ? _value.allowance
          : allowance // ignore: cast_nullable_to_non_nullable
              as double,
      income: null == income
          ? _value.income
          : income // ignore: cast_nullable_to_non_nullable
              as double,
      hasStarDays: null == hasStarDays
          ? _value.hasStarDays
          : hasStarDays // ignore: cast_nullable_to_non_nullable
              as bool,
      uploadedAt: null == uploadedAt
          ? _value.uploadedAt
          : uploadedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      validationStatus: null == validationStatus
          ? _value.validationStatus
          : validationStatus // ignore: cast_nullable_to_non_nullable
              as String,
      summary: null == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as LineSummary,
      destinations: null == destinations
          ? _value.destinations
          : destinations // ignore: cast_nullable_to_non_nullable
              as List<String>,
      destinationDetails: null == destinationDetails
          ? _value.destinationDetails
          : destinationDetails // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      daysOff: null == daysOff
          ? _value.daysOff
          : daysOff // ignore: cast_nullable_to_non_nullable
              as List<int>,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      legs: null == legs
          ? _value.legs
          : legs // ignore: cast_nullable_to_non_nullable
              as List<FlightLeg>,
    ) as $Val);
  }

  /// Create a copy of FlightLine
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LineSummaryCopyWith<$Res> get summary {
    return $LineSummaryCopyWith<$Res>(_value.summary, (value) {
      return _then(_value.copyWith(summary: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$FlightLineImplCopyWith<$Res>
    implements $FlightLineCopyWith<$Res> {
  factory _$$FlightLineImplCopyWith(
          _$FlightLineImpl value, $Res Function(_$FlightLineImpl) then) =
      __$$FlightLineImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String lineNumber,
      String month,
      String userId,
      String rank,
      String lineType,
      String carryOver,
      String base,
      String category,
      double creditHours,
      double blockHours,
      double carryOverHours,
      int totalLegs,
      int fourLegCount,
      double expense,
      double allowance,
      double income,
      bool hasStarDays,
      DateTime uploadedAt,
      String validationStatus,
      LineSummary summary,
      List<String> destinations,
      List<Map<String, dynamic>> destinationDetails,
      List<int> daysOff,
      bool isActive,
      List<FlightLeg> legs});

  @override
  $LineSummaryCopyWith<$Res> get summary;
}

/// @nodoc
class __$$FlightLineImplCopyWithImpl<$Res>
    extends _$FlightLineCopyWithImpl<$Res, _$FlightLineImpl>
    implements _$$FlightLineImplCopyWith<$Res> {
  __$$FlightLineImplCopyWithImpl(
      _$FlightLineImpl _value, $Res Function(_$FlightLineImpl) _then)
      : super(_value, _then);

  /// Create a copy of FlightLine
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? lineNumber = null,
    Object? month = null,
    Object? userId = null,
    Object? rank = null,
    Object? lineType = null,
    Object? carryOver = null,
    Object? base = null,
    Object? category = null,
    Object? creditHours = null,
    Object? blockHours = null,
    Object? carryOverHours = null,
    Object? totalLegs = null,
    Object? fourLegCount = null,
    Object? expense = null,
    Object? allowance = null,
    Object? income = null,
    Object? hasStarDays = null,
    Object? uploadedAt = null,
    Object? validationStatus = null,
    Object? summary = null,
    Object? destinations = null,
    Object? destinationDetails = null,
    Object? daysOff = null,
    Object? isActive = null,
    Object? legs = null,
  }) {
    return _then(_$FlightLineImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      lineNumber: null == lineNumber
          ? _value.lineNumber
          : lineNumber // ignore: cast_nullable_to_non_nullable
              as String,
      month: null == month
          ? _value.month
          : month // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      rank: null == rank
          ? _value.rank
          : rank // ignore: cast_nullable_to_non_nullable
              as String,
      lineType: null == lineType
          ? _value.lineType
          : lineType // ignore: cast_nullable_to_non_nullable
              as String,
      carryOver: null == carryOver
          ? _value.carryOver
          : carryOver // ignore: cast_nullable_to_non_nullable
              as String,
      base: null == base
          ? _value.base
          : base // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      creditHours: null == creditHours
          ? _value.creditHours
          : creditHours // ignore: cast_nullable_to_non_nullable
              as double,
      blockHours: null == blockHours
          ? _value.blockHours
          : blockHours // ignore: cast_nullable_to_non_nullable
              as double,
      carryOverHours: null == carryOverHours
          ? _value.carryOverHours
          : carryOverHours // ignore: cast_nullable_to_non_nullable
              as double,
      totalLegs: null == totalLegs
          ? _value.totalLegs
          : totalLegs // ignore: cast_nullable_to_non_nullable
              as int,
      fourLegCount: null == fourLegCount
          ? _value.fourLegCount
          : fourLegCount // ignore: cast_nullable_to_non_nullable
              as int,
      expense: null == expense
          ? _value.expense
          : expense // ignore: cast_nullable_to_non_nullable
              as double,
      allowance: null == allowance
          ? _value.allowance
          : allowance // ignore: cast_nullable_to_non_nullable
              as double,
      income: null == income
          ? _value.income
          : income // ignore: cast_nullable_to_non_nullable
              as double,
      hasStarDays: null == hasStarDays
          ? _value.hasStarDays
          : hasStarDays // ignore: cast_nullable_to_non_nullable
              as bool,
      uploadedAt: null == uploadedAt
          ? _value.uploadedAt
          : uploadedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      validationStatus: null == validationStatus
          ? _value.validationStatus
          : validationStatus // ignore: cast_nullable_to_non_nullable
              as String,
      summary: null == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as LineSummary,
      destinations: null == destinations
          ? _value._destinations
          : destinations // ignore: cast_nullable_to_non_nullable
              as List<String>,
      destinationDetails: null == destinationDetails
          ? _value._destinationDetails
          : destinationDetails // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      daysOff: null == daysOff
          ? _value._daysOff
          : daysOff // ignore: cast_nullable_to_non_nullable
              as List<int>,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      legs: null == legs
          ? _value._legs
          : legs // ignore: cast_nullable_to_non_nullable
              as List<FlightLeg>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FlightLineImpl implements _FlightLine {
  const _$FlightLineImpl(
      {required this.id,
      required this.lineNumber,
      required this.month,
      required this.userId,
      this.rank = '',
      this.lineType = '',
      this.carryOver = '',
      this.base = '',
      this.category = '',
      this.creditHours = 0,
      this.blockHours = 0,
      this.carryOverHours = 0,
      this.totalLegs = 0,
      this.fourLegCount = 0,
      this.expense = 0,
      this.allowance = 0,
      this.income = 0,
      this.hasStarDays = false,
      required this.uploadedAt,
      this.validationStatus = 'pending',
      this.summary = const LineSummary(),
      final List<String> destinations = const [],
      final List<Map<String, dynamic>> destinationDetails = const [],
      final List<int> daysOff = const [],
      this.isActive = true,
      final List<FlightLeg> legs = const []})
      : _destinations = destinations,
        _destinationDetails = destinationDetails,
        _daysOff = daysOff,
        _legs = legs;

  factory _$FlightLineImpl.fromJson(Map<String, dynamic> json) =>
      _$$FlightLineImplFromJson(json);

  @override
  final String id;
  @override
  final String lineNumber;
  @override
  final String month;
  @override
  final String userId;
  @override
  @JsonKey()
  final String rank;
  @override
  @JsonKey()
  final String lineType;
  @override
  @JsonKey()
  final String carryOver;
  @override
  @JsonKey()
  final String base;
  @override
  @JsonKey()
  final String category;
  @override
  @JsonKey()
  final double creditHours;
  @override
  @JsonKey()
  final double blockHours;
  @override
  @JsonKey()
  final double carryOverHours;
  @override
  @JsonKey()
  final int totalLegs;
  @override
  @JsonKey()
  final int fourLegCount;
  @override
  @JsonKey()
  final double expense;
  @override
  @JsonKey()
  final double allowance;
  @override
  @JsonKey()
  final double income;
  @override
  @JsonKey()
  final bool hasStarDays;
  @override
  final DateTime uploadedAt;
  @override
  @JsonKey()
  final String validationStatus;
  @override
  @JsonKey()
  final LineSummary summary;
  final List<String> _destinations;
  @override
  @JsonKey()
  List<String> get destinations {
    if (_destinations is EqualUnmodifiableListView) return _destinations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_destinations);
  }

  final List<Map<String, dynamic>> _destinationDetails;
  @override
  @JsonKey()
  List<Map<String, dynamic>> get destinationDetails {
    if (_destinationDetails is EqualUnmodifiableListView)
      return _destinationDetails;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_destinationDetails);
  }

  final List<int> _daysOff;
  @override
  @JsonKey()
  List<int> get daysOff {
    if (_daysOff is EqualUnmodifiableListView) return _daysOff;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_daysOff);
  }

  @override
  @JsonKey()
  final bool isActive;
  final List<FlightLeg> _legs;
  @override
  @JsonKey()
  List<FlightLeg> get legs {
    if (_legs is EqualUnmodifiableListView) return _legs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_legs);
  }

  @override
  String toString() {
    return 'FlightLine(id: $id, lineNumber: $lineNumber, month: $month, userId: $userId, rank: $rank, lineType: $lineType, carryOver: $carryOver, base: $base, category: $category, creditHours: $creditHours, blockHours: $blockHours, carryOverHours: $carryOverHours, totalLegs: $totalLegs, fourLegCount: $fourLegCount, expense: $expense, allowance: $allowance, income: $income, hasStarDays: $hasStarDays, uploadedAt: $uploadedAt, validationStatus: $validationStatus, summary: $summary, destinations: $destinations, destinationDetails: $destinationDetails, daysOff: $daysOff, isActive: $isActive, legs: $legs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlightLineImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.lineNumber, lineNumber) ||
                other.lineNumber == lineNumber) &&
            (identical(other.month, month) || other.month == month) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.rank, rank) || other.rank == rank) &&
            (identical(other.lineType, lineType) ||
                other.lineType == lineType) &&
            (identical(other.carryOver, carryOver) ||
                other.carryOver == carryOver) &&
            (identical(other.base, base) || other.base == base) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.creditHours, creditHours) ||
                other.creditHours == creditHours) &&
            (identical(other.blockHours, blockHours) ||
                other.blockHours == blockHours) &&
            (identical(other.carryOverHours, carryOverHours) ||
                other.carryOverHours == carryOverHours) &&
            (identical(other.totalLegs, totalLegs) ||
                other.totalLegs == totalLegs) &&
            (identical(other.fourLegCount, fourLegCount) ||
                other.fourLegCount == fourLegCount) &&
            (identical(other.expense, expense) || other.expense == expense) &&
            (identical(other.allowance, allowance) ||
                other.allowance == allowance) &&
            (identical(other.income, income) || other.income == income) &&
            (identical(other.hasStarDays, hasStarDays) ||
                other.hasStarDays == hasStarDays) &&
            (identical(other.uploadedAt, uploadedAt) ||
                other.uploadedAt == uploadedAt) &&
            (identical(other.validationStatus, validationStatus) ||
                other.validationStatus == validationStatus) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            const DeepCollectionEquality()
                .equals(other._destinations, _destinations) &&
            const DeepCollectionEquality()
                .equals(other._destinationDetails, _destinationDetails) &&
            const DeepCollectionEquality().equals(other._daysOff, _daysOff) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            const DeepCollectionEquality().equals(other._legs, _legs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        lineNumber,
        month,
        userId,
        rank,
        lineType,
        carryOver,
        base,
        category,
        creditHours,
        blockHours,
        carryOverHours,
        totalLegs,
        fourLegCount,
        expense,
        allowance,
        income,
        hasStarDays,
        uploadedAt,
        validationStatus,
        summary,
        const DeepCollectionEquality().hash(_destinations),
        const DeepCollectionEquality().hash(_destinationDetails),
        const DeepCollectionEquality().hash(_daysOff),
        isActive,
        const DeepCollectionEquality().hash(_legs)
      ]);

  /// Create a copy of FlightLine
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FlightLineImplCopyWith<_$FlightLineImpl> get copyWith =>
      __$$FlightLineImplCopyWithImpl<_$FlightLineImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FlightLineImplToJson(
      this,
    );
  }
}

abstract class _FlightLine implements FlightLine {
  const factory _FlightLine(
      {required final String id,
      required final String lineNumber,
      required final String month,
      required final String userId,
      final String rank,
      final String lineType,
      final String carryOver,
      final String base,
      final String category,
      final double creditHours,
      final double blockHours,
      final double carryOverHours,
      final int totalLegs,
      final int fourLegCount,
      final double expense,
      final double allowance,
      final double income,
      final bool hasStarDays,
      required final DateTime uploadedAt,
      final String validationStatus,
      final LineSummary summary,
      final List<String> destinations,
      final List<Map<String, dynamic>> destinationDetails,
      final List<int> daysOff,
      final bool isActive,
      final List<FlightLeg> legs}) = _$FlightLineImpl;

  factory _FlightLine.fromJson(Map<String, dynamic> json) =
      _$FlightLineImpl.fromJson;

  @override
  String get id;
  @override
  String get lineNumber;
  @override
  String get month;
  @override
  String get userId;
  @override
  String get rank;
  @override
  String get lineType;
  @override
  String get carryOver;
  @override
  String get base;
  @override
  String get category;
  @override
  double get creditHours;
  @override
  double get blockHours;
  @override
  double get carryOverHours;
  @override
  int get totalLegs;
  @override
  int get fourLegCount;
  @override
  double get expense;
  @override
  double get allowance;
  @override
  double get income;
  @override
  bool get hasStarDays;
  @override
  DateTime get uploadedAt;
  @override
  String get validationStatus;
  @override
  LineSummary get summary;
  @override
  List<String> get destinations;
  @override
  List<Map<String, dynamic>> get destinationDetails;
  @override
  List<int> get daysOff;
  @override
  bool get isActive;
  @override
  List<FlightLeg> get legs;

  /// Create a copy of FlightLine
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FlightLineImplCopyWith<_$FlightLineImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LineSummary _$LineSummaryFromJson(Map<String, dynamic> json) {
  return _LineSummary.fromJson(json);
}

/// @nodoc
mixin _$LineSummary {
  int get totalLegs => throw _privateConstructorUsedError;
  double get totalBlockHours => throw _privateConstructorUsedError;
  double get totalDutyHours => throw _privateConstructorUsedError;
  int get totalDutyDays => throw _privateConstructorUsedError;
  int get internationalLegs => throw _privateConstructorUsedError;
  int get domesticLegs => throw _privateConstructorUsedError;
  int get layoverCount => throw _privateConstructorUsedError;
  double get estimatedSalaryMin => throw _privateConstructorUsedError;
  double get estimatedSalaryMax => throw _privateConstructorUsedError;
  double get salaryScore => throw _privateConstructorUsedError;
  double get restQualityScore => throw _privateConstructorUsedError;
  double get compositeScore => throw _privateConstructorUsedError;

  /// Serializes this LineSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LineSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LineSummaryCopyWith<LineSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LineSummaryCopyWith<$Res> {
  factory $LineSummaryCopyWith(
          LineSummary value, $Res Function(LineSummary) then) =
      _$LineSummaryCopyWithImpl<$Res, LineSummary>;
  @useResult
  $Res call(
      {int totalLegs,
      double totalBlockHours,
      double totalDutyHours,
      int totalDutyDays,
      int internationalLegs,
      int domesticLegs,
      int layoverCount,
      double estimatedSalaryMin,
      double estimatedSalaryMax,
      double salaryScore,
      double restQualityScore,
      double compositeScore});
}

/// @nodoc
class _$LineSummaryCopyWithImpl<$Res, $Val extends LineSummary>
    implements $LineSummaryCopyWith<$Res> {
  _$LineSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LineSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalLegs = null,
    Object? totalBlockHours = null,
    Object? totalDutyHours = null,
    Object? totalDutyDays = null,
    Object? internationalLegs = null,
    Object? domesticLegs = null,
    Object? layoverCount = null,
    Object? estimatedSalaryMin = null,
    Object? estimatedSalaryMax = null,
    Object? salaryScore = null,
    Object? restQualityScore = null,
    Object? compositeScore = null,
  }) {
    return _then(_value.copyWith(
      totalLegs: null == totalLegs
          ? _value.totalLegs
          : totalLegs // ignore: cast_nullable_to_non_nullable
              as int,
      totalBlockHours: null == totalBlockHours
          ? _value.totalBlockHours
          : totalBlockHours // ignore: cast_nullable_to_non_nullable
              as double,
      totalDutyHours: null == totalDutyHours
          ? _value.totalDutyHours
          : totalDutyHours // ignore: cast_nullable_to_non_nullable
              as double,
      totalDutyDays: null == totalDutyDays
          ? _value.totalDutyDays
          : totalDutyDays // ignore: cast_nullable_to_non_nullable
              as int,
      internationalLegs: null == internationalLegs
          ? _value.internationalLegs
          : internationalLegs // ignore: cast_nullable_to_non_nullable
              as int,
      domesticLegs: null == domesticLegs
          ? _value.domesticLegs
          : domesticLegs // ignore: cast_nullable_to_non_nullable
              as int,
      layoverCount: null == layoverCount
          ? _value.layoverCount
          : layoverCount // ignore: cast_nullable_to_non_nullable
              as int,
      estimatedSalaryMin: null == estimatedSalaryMin
          ? _value.estimatedSalaryMin
          : estimatedSalaryMin // ignore: cast_nullable_to_non_nullable
              as double,
      estimatedSalaryMax: null == estimatedSalaryMax
          ? _value.estimatedSalaryMax
          : estimatedSalaryMax // ignore: cast_nullable_to_non_nullable
              as double,
      salaryScore: null == salaryScore
          ? _value.salaryScore
          : salaryScore // ignore: cast_nullable_to_non_nullable
              as double,
      restQualityScore: null == restQualityScore
          ? _value.restQualityScore
          : restQualityScore // ignore: cast_nullable_to_non_nullable
              as double,
      compositeScore: null == compositeScore
          ? _value.compositeScore
          : compositeScore // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$LineSummaryImplCopyWith<$Res>
    implements $LineSummaryCopyWith<$Res> {
  factory _$$LineSummaryImplCopyWith(
          _$LineSummaryImpl value, $Res Function(_$LineSummaryImpl) then) =
      __$$LineSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int totalLegs,
      double totalBlockHours,
      double totalDutyHours,
      int totalDutyDays,
      int internationalLegs,
      int domesticLegs,
      int layoverCount,
      double estimatedSalaryMin,
      double estimatedSalaryMax,
      double salaryScore,
      double restQualityScore,
      double compositeScore});
}

/// @nodoc
class __$$LineSummaryImplCopyWithImpl<$Res>
    extends _$LineSummaryCopyWithImpl<$Res, _$LineSummaryImpl>
    implements _$$LineSummaryImplCopyWith<$Res> {
  __$$LineSummaryImplCopyWithImpl(
      _$LineSummaryImpl _value, $Res Function(_$LineSummaryImpl) _then)
      : super(_value, _then);

  /// Create a copy of LineSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalLegs = null,
    Object? totalBlockHours = null,
    Object? totalDutyHours = null,
    Object? totalDutyDays = null,
    Object? internationalLegs = null,
    Object? domesticLegs = null,
    Object? layoverCount = null,
    Object? estimatedSalaryMin = null,
    Object? estimatedSalaryMax = null,
    Object? salaryScore = null,
    Object? restQualityScore = null,
    Object? compositeScore = null,
  }) {
    return _then(_$LineSummaryImpl(
      totalLegs: null == totalLegs
          ? _value.totalLegs
          : totalLegs // ignore: cast_nullable_to_non_nullable
              as int,
      totalBlockHours: null == totalBlockHours
          ? _value.totalBlockHours
          : totalBlockHours // ignore: cast_nullable_to_non_nullable
              as double,
      totalDutyHours: null == totalDutyHours
          ? _value.totalDutyHours
          : totalDutyHours // ignore: cast_nullable_to_non_nullable
              as double,
      totalDutyDays: null == totalDutyDays
          ? _value.totalDutyDays
          : totalDutyDays // ignore: cast_nullable_to_non_nullable
              as int,
      internationalLegs: null == internationalLegs
          ? _value.internationalLegs
          : internationalLegs // ignore: cast_nullable_to_non_nullable
              as int,
      domesticLegs: null == domesticLegs
          ? _value.domesticLegs
          : domesticLegs // ignore: cast_nullable_to_non_nullable
              as int,
      layoverCount: null == layoverCount
          ? _value.layoverCount
          : layoverCount // ignore: cast_nullable_to_non_nullable
              as int,
      estimatedSalaryMin: null == estimatedSalaryMin
          ? _value.estimatedSalaryMin
          : estimatedSalaryMin // ignore: cast_nullable_to_non_nullable
              as double,
      estimatedSalaryMax: null == estimatedSalaryMax
          ? _value.estimatedSalaryMax
          : estimatedSalaryMax // ignore: cast_nullable_to_non_nullable
              as double,
      salaryScore: null == salaryScore
          ? _value.salaryScore
          : salaryScore // ignore: cast_nullable_to_non_nullable
              as double,
      restQualityScore: null == restQualityScore
          ? _value.restQualityScore
          : restQualityScore // ignore: cast_nullable_to_non_nullable
              as double,
      compositeScore: null == compositeScore
          ? _value.compositeScore
          : compositeScore // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$LineSummaryImpl implements _LineSummary {
  const _$LineSummaryImpl(
      {this.totalLegs = 0,
      this.totalBlockHours = 0,
      this.totalDutyHours = 0,
      this.totalDutyDays = 0,
      this.internationalLegs = 0,
      this.domesticLegs = 0,
      this.layoverCount = 0,
      this.estimatedSalaryMin = 0,
      this.estimatedSalaryMax = 0,
      this.salaryScore = 0,
      this.restQualityScore = 0,
      this.compositeScore = 0});

  factory _$LineSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$LineSummaryImplFromJson(json);

  @override
  @JsonKey()
  final int totalLegs;
  @override
  @JsonKey()
  final double totalBlockHours;
  @override
  @JsonKey()
  final double totalDutyHours;
  @override
  @JsonKey()
  final int totalDutyDays;
  @override
  @JsonKey()
  final int internationalLegs;
  @override
  @JsonKey()
  final int domesticLegs;
  @override
  @JsonKey()
  final int layoverCount;
  @override
  @JsonKey()
  final double estimatedSalaryMin;
  @override
  @JsonKey()
  final double estimatedSalaryMax;
  @override
  @JsonKey()
  final double salaryScore;
  @override
  @JsonKey()
  final double restQualityScore;
  @override
  @JsonKey()
  final double compositeScore;

  @override
  String toString() {
    return 'LineSummary(totalLegs: $totalLegs, totalBlockHours: $totalBlockHours, totalDutyHours: $totalDutyHours, totalDutyDays: $totalDutyDays, internationalLegs: $internationalLegs, domesticLegs: $domesticLegs, layoverCount: $layoverCount, estimatedSalaryMin: $estimatedSalaryMin, estimatedSalaryMax: $estimatedSalaryMax, salaryScore: $salaryScore, restQualityScore: $restQualityScore, compositeScore: $compositeScore)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LineSummaryImpl &&
            (identical(other.totalLegs, totalLegs) ||
                other.totalLegs == totalLegs) &&
            (identical(other.totalBlockHours, totalBlockHours) ||
                other.totalBlockHours == totalBlockHours) &&
            (identical(other.totalDutyHours, totalDutyHours) ||
                other.totalDutyHours == totalDutyHours) &&
            (identical(other.totalDutyDays, totalDutyDays) ||
                other.totalDutyDays == totalDutyDays) &&
            (identical(other.internationalLegs, internationalLegs) ||
                other.internationalLegs == internationalLegs) &&
            (identical(other.domesticLegs, domesticLegs) ||
                other.domesticLegs == domesticLegs) &&
            (identical(other.layoverCount, layoverCount) ||
                other.layoverCount == layoverCount) &&
            (identical(other.estimatedSalaryMin, estimatedSalaryMin) ||
                other.estimatedSalaryMin == estimatedSalaryMin) &&
            (identical(other.estimatedSalaryMax, estimatedSalaryMax) ||
                other.estimatedSalaryMax == estimatedSalaryMax) &&
            (identical(other.salaryScore, salaryScore) ||
                other.salaryScore == salaryScore) &&
            (identical(other.restQualityScore, restQualityScore) ||
                other.restQualityScore == restQualityScore) &&
            (identical(other.compositeScore, compositeScore) ||
                other.compositeScore == compositeScore));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      totalLegs,
      totalBlockHours,
      totalDutyHours,
      totalDutyDays,
      internationalLegs,
      domesticLegs,
      layoverCount,
      estimatedSalaryMin,
      estimatedSalaryMax,
      salaryScore,
      restQualityScore,
      compositeScore);

  /// Create a copy of LineSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LineSummaryImplCopyWith<_$LineSummaryImpl> get copyWith =>
      __$$LineSummaryImplCopyWithImpl<_$LineSummaryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LineSummaryImplToJson(
      this,
    );
  }
}

abstract class _LineSummary implements LineSummary {
  const factory _LineSummary(
      {final int totalLegs,
      final double totalBlockHours,
      final double totalDutyHours,
      final int totalDutyDays,
      final int internationalLegs,
      final int domesticLegs,
      final int layoverCount,
      final double estimatedSalaryMin,
      final double estimatedSalaryMax,
      final double salaryScore,
      final double restQualityScore,
      final double compositeScore}) = _$LineSummaryImpl;

  factory _LineSummary.fromJson(Map<String, dynamic> json) =
      _$LineSummaryImpl.fromJson;

  @override
  int get totalLegs;
  @override
  double get totalBlockHours;
  @override
  double get totalDutyHours;
  @override
  int get totalDutyDays;
  @override
  int get internationalLegs;
  @override
  int get domesticLegs;
  @override
  int get layoverCount;
  @override
  double get estimatedSalaryMin;
  @override
  double get estimatedSalaryMax;
  @override
  double get salaryScore;
  @override
  double get restQualityScore;
  @override
  double get compositeScore;

  /// Create a copy of LineSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LineSummaryImplCopyWith<_$LineSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FlightLeg _$FlightLegFromJson(Map<String, dynamic> json) {
  return _FlightLeg.fromJson(json);
}

/// @nodoc
mixin _$FlightLeg {
  String get id => throw _privateConstructorUsedError;
  String get lineId => throw _privateConstructorUsedError;
  String get flightNumber => throw _privateConstructorUsedError;
  String get origin => throw _privateConstructorUsedError;
  String get destination => throw _privateConstructorUsedError;
  LegType get legType => throw _privateConstructorUsedError;
  DateTime get departureLT => throw _privateConstructorUsedError;
  DateTime get arrivalLT => throw _privateConstructorUsedError;
  DateTime get departureUTC => throw _privateConstructorUsedError;
  DateTime get arrivalUTC => throw _privateConstructorUsedError;
  DateTime get dutyStart => throw _privateConstructorUsedError;
  DateTime get dutyEnd => throw _privateConstructorUsedError;
  DateTime get releaseTime => throw _privateConstructorUsedError;
  double get blockHours => throw _privateConstructorUsedError;
  double get fdpHours => throw _privateConstructorUsedError;
  String get aircraftType => throw _privateConstructorUsedError;
  bool get layover => throw _privateConstructorUsedError;
  double get layoverHours => throw _privateConstructorUsedError;
  double get payRate => throw _privateConstructorUsedError;
  double get estimatedPay => throw _privateConstructorUsedError;
  double get perDiem => throw _privateConstructorUsedError;
  LegalityStatus get legalityStatus => throw _privateConstructorUsedError;
  List<String> get legalityFlags => throw _privateConstructorUsedError;
  double get restAfterHours => throw _privateConstructorUsedError;
  double get restBeforeHours => throw _privateConstructorUsedError;
  int get sequence => throw _privateConstructorUsedError;

  /// Serializes this FlightLeg to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FlightLeg
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FlightLegCopyWith<FlightLeg> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FlightLegCopyWith<$Res> {
  factory $FlightLegCopyWith(FlightLeg value, $Res Function(FlightLeg) then) =
      _$FlightLegCopyWithImpl<$Res, FlightLeg>;
  @useResult
  $Res call(
      {String id,
      String lineId,
      String flightNumber,
      String origin,
      String destination,
      LegType legType,
      DateTime departureLT,
      DateTime arrivalLT,
      DateTime departureUTC,
      DateTime arrivalUTC,
      DateTime dutyStart,
      DateTime dutyEnd,
      DateTime releaseTime,
      double blockHours,
      double fdpHours,
      String aircraftType,
      bool layover,
      double layoverHours,
      double payRate,
      double estimatedPay,
      double perDiem,
      LegalityStatus legalityStatus,
      List<String> legalityFlags,
      double restAfterHours,
      double restBeforeHours,
      int sequence});
}

/// @nodoc
class _$FlightLegCopyWithImpl<$Res, $Val extends FlightLeg>
    implements $FlightLegCopyWith<$Res> {
  _$FlightLegCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FlightLeg
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? lineId = null,
    Object? flightNumber = null,
    Object? origin = null,
    Object? destination = null,
    Object? legType = null,
    Object? departureLT = null,
    Object? arrivalLT = null,
    Object? departureUTC = null,
    Object? arrivalUTC = null,
    Object? dutyStart = null,
    Object? dutyEnd = null,
    Object? releaseTime = null,
    Object? blockHours = null,
    Object? fdpHours = null,
    Object? aircraftType = null,
    Object? layover = null,
    Object? layoverHours = null,
    Object? payRate = null,
    Object? estimatedPay = null,
    Object? perDiem = null,
    Object? legalityStatus = null,
    Object? legalityFlags = null,
    Object? restAfterHours = null,
    Object? restBeforeHours = null,
    Object? sequence = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      lineId: null == lineId
          ? _value.lineId
          : lineId // ignore: cast_nullable_to_non_nullable
              as String,
      flightNumber: null == flightNumber
          ? _value.flightNumber
          : flightNumber // ignore: cast_nullable_to_non_nullable
              as String,
      origin: null == origin
          ? _value.origin
          : origin // ignore: cast_nullable_to_non_nullable
              as String,
      destination: null == destination
          ? _value.destination
          : destination // ignore: cast_nullable_to_non_nullable
              as String,
      legType: null == legType
          ? _value.legType
          : legType // ignore: cast_nullable_to_non_nullable
              as LegType,
      departureLT: null == departureLT
          ? _value.departureLT
          : departureLT // ignore: cast_nullable_to_non_nullable
              as DateTime,
      arrivalLT: null == arrivalLT
          ? _value.arrivalLT
          : arrivalLT // ignore: cast_nullable_to_non_nullable
              as DateTime,
      departureUTC: null == departureUTC
          ? _value.departureUTC
          : departureUTC // ignore: cast_nullable_to_non_nullable
              as DateTime,
      arrivalUTC: null == arrivalUTC
          ? _value.arrivalUTC
          : arrivalUTC // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dutyStart: null == dutyStart
          ? _value.dutyStart
          : dutyStart // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dutyEnd: null == dutyEnd
          ? _value.dutyEnd
          : dutyEnd // ignore: cast_nullable_to_non_nullable
              as DateTime,
      releaseTime: null == releaseTime
          ? _value.releaseTime
          : releaseTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      blockHours: null == blockHours
          ? _value.blockHours
          : blockHours // ignore: cast_nullable_to_non_nullable
              as double,
      fdpHours: null == fdpHours
          ? _value.fdpHours
          : fdpHours // ignore: cast_nullable_to_non_nullable
              as double,
      aircraftType: null == aircraftType
          ? _value.aircraftType
          : aircraftType // ignore: cast_nullable_to_non_nullable
              as String,
      layover: null == layover
          ? _value.layover
          : layover // ignore: cast_nullable_to_non_nullable
              as bool,
      layoverHours: null == layoverHours
          ? _value.layoverHours
          : layoverHours // ignore: cast_nullable_to_non_nullable
              as double,
      payRate: null == payRate
          ? _value.payRate
          : payRate // ignore: cast_nullable_to_non_nullable
              as double,
      estimatedPay: null == estimatedPay
          ? _value.estimatedPay
          : estimatedPay // ignore: cast_nullable_to_non_nullable
              as double,
      perDiem: null == perDiem
          ? _value.perDiem
          : perDiem // ignore: cast_nullable_to_non_nullable
              as double,
      legalityStatus: null == legalityStatus
          ? _value.legalityStatus
          : legalityStatus // ignore: cast_nullable_to_non_nullable
              as LegalityStatus,
      legalityFlags: null == legalityFlags
          ? _value.legalityFlags
          : legalityFlags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      restAfterHours: null == restAfterHours
          ? _value.restAfterHours
          : restAfterHours // ignore: cast_nullable_to_non_nullable
              as double,
      restBeforeHours: null == restBeforeHours
          ? _value.restBeforeHours
          : restBeforeHours // ignore: cast_nullable_to_non_nullable
              as double,
      sequence: null == sequence
          ? _value.sequence
          : sequence // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FlightLegImplCopyWith<$Res>
    implements $FlightLegCopyWith<$Res> {
  factory _$$FlightLegImplCopyWith(
          _$FlightLegImpl value, $Res Function(_$FlightLegImpl) then) =
      __$$FlightLegImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String lineId,
      String flightNumber,
      String origin,
      String destination,
      LegType legType,
      DateTime departureLT,
      DateTime arrivalLT,
      DateTime departureUTC,
      DateTime arrivalUTC,
      DateTime dutyStart,
      DateTime dutyEnd,
      DateTime releaseTime,
      double blockHours,
      double fdpHours,
      String aircraftType,
      bool layover,
      double layoverHours,
      double payRate,
      double estimatedPay,
      double perDiem,
      LegalityStatus legalityStatus,
      List<String> legalityFlags,
      double restAfterHours,
      double restBeforeHours,
      int sequence});
}

/// @nodoc
class __$$FlightLegImplCopyWithImpl<$Res>
    extends _$FlightLegCopyWithImpl<$Res, _$FlightLegImpl>
    implements _$$FlightLegImplCopyWith<$Res> {
  __$$FlightLegImplCopyWithImpl(
      _$FlightLegImpl _value, $Res Function(_$FlightLegImpl) _then)
      : super(_value, _then);

  /// Create a copy of FlightLeg
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? lineId = null,
    Object? flightNumber = null,
    Object? origin = null,
    Object? destination = null,
    Object? legType = null,
    Object? departureLT = null,
    Object? arrivalLT = null,
    Object? departureUTC = null,
    Object? arrivalUTC = null,
    Object? dutyStart = null,
    Object? dutyEnd = null,
    Object? releaseTime = null,
    Object? blockHours = null,
    Object? fdpHours = null,
    Object? aircraftType = null,
    Object? layover = null,
    Object? layoverHours = null,
    Object? payRate = null,
    Object? estimatedPay = null,
    Object? perDiem = null,
    Object? legalityStatus = null,
    Object? legalityFlags = null,
    Object? restAfterHours = null,
    Object? restBeforeHours = null,
    Object? sequence = null,
  }) {
    return _then(_$FlightLegImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      lineId: null == lineId
          ? _value.lineId
          : lineId // ignore: cast_nullable_to_non_nullable
              as String,
      flightNumber: null == flightNumber
          ? _value.flightNumber
          : flightNumber // ignore: cast_nullable_to_non_nullable
              as String,
      origin: null == origin
          ? _value.origin
          : origin // ignore: cast_nullable_to_non_nullable
              as String,
      destination: null == destination
          ? _value.destination
          : destination // ignore: cast_nullable_to_non_nullable
              as String,
      legType: null == legType
          ? _value.legType
          : legType // ignore: cast_nullable_to_non_nullable
              as LegType,
      departureLT: null == departureLT
          ? _value.departureLT
          : departureLT // ignore: cast_nullable_to_non_nullable
              as DateTime,
      arrivalLT: null == arrivalLT
          ? _value.arrivalLT
          : arrivalLT // ignore: cast_nullable_to_non_nullable
              as DateTime,
      departureUTC: null == departureUTC
          ? _value.departureUTC
          : departureUTC // ignore: cast_nullable_to_non_nullable
              as DateTime,
      arrivalUTC: null == arrivalUTC
          ? _value.arrivalUTC
          : arrivalUTC // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dutyStart: null == dutyStart
          ? _value.dutyStart
          : dutyStart // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dutyEnd: null == dutyEnd
          ? _value.dutyEnd
          : dutyEnd // ignore: cast_nullable_to_non_nullable
              as DateTime,
      releaseTime: null == releaseTime
          ? _value.releaseTime
          : releaseTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      blockHours: null == blockHours
          ? _value.blockHours
          : blockHours // ignore: cast_nullable_to_non_nullable
              as double,
      fdpHours: null == fdpHours
          ? _value.fdpHours
          : fdpHours // ignore: cast_nullable_to_non_nullable
              as double,
      aircraftType: null == aircraftType
          ? _value.aircraftType
          : aircraftType // ignore: cast_nullable_to_non_nullable
              as String,
      layover: null == layover
          ? _value.layover
          : layover // ignore: cast_nullable_to_non_nullable
              as bool,
      layoverHours: null == layoverHours
          ? _value.layoverHours
          : layoverHours // ignore: cast_nullable_to_non_nullable
              as double,
      payRate: null == payRate
          ? _value.payRate
          : payRate // ignore: cast_nullable_to_non_nullable
              as double,
      estimatedPay: null == estimatedPay
          ? _value.estimatedPay
          : estimatedPay // ignore: cast_nullable_to_non_nullable
              as double,
      perDiem: null == perDiem
          ? _value.perDiem
          : perDiem // ignore: cast_nullable_to_non_nullable
              as double,
      legalityStatus: null == legalityStatus
          ? _value.legalityStatus
          : legalityStatus // ignore: cast_nullable_to_non_nullable
              as LegalityStatus,
      legalityFlags: null == legalityFlags
          ? _value._legalityFlags
          : legalityFlags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      restAfterHours: null == restAfterHours
          ? _value.restAfterHours
          : restAfterHours // ignore: cast_nullable_to_non_nullable
              as double,
      restBeforeHours: null == restBeforeHours
          ? _value.restBeforeHours
          : restBeforeHours // ignore: cast_nullable_to_non_nullable
              as double,
      sequence: null == sequence
          ? _value.sequence
          : sequence // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FlightLegImpl implements _FlightLeg {
  const _$FlightLegImpl(
      {required this.id,
      required this.lineId,
      required this.flightNumber,
      required this.origin,
      required this.destination,
      this.legType = LegType.domestic,
      required this.departureLT,
      required this.arrivalLT,
      required this.departureUTC,
      required this.arrivalUTC,
      required this.dutyStart,
      required this.dutyEnd,
      required this.releaseTime,
      this.blockHours = 0,
      this.fdpHours = 0,
      this.aircraftType = '',
      this.layover = false,
      this.layoverHours = 0,
      this.payRate = 0,
      this.estimatedPay = 0,
      this.perDiem = 0,
      this.legalityStatus = LegalityStatus.legal,
      final List<String> legalityFlags = const [],
      this.restAfterHours = 0,
      this.restBeforeHours = 0,
      this.sequence = 0})
      : _legalityFlags = legalityFlags;

  factory _$FlightLegImpl.fromJson(Map<String, dynamic> json) =>
      _$$FlightLegImplFromJson(json);

  @override
  final String id;
  @override
  final String lineId;
  @override
  final String flightNumber;
  @override
  final String origin;
  @override
  final String destination;
  @override
  @JsonKey()
  final LegType legType;
  @override
  final DateTime departureLT;
  @override
  final DateTime arrivalLT;
  @override
  final DateTime departureUTC;
  @override
  final DateTime arrivalUTC;
  @override
  final DateTime dutyStart;
  @override
  final DateTime dutyEnd;
  @override
  final DateTime releaseTime;
  @override
  @JsonKey()
  final double blockHours;
  @override
  @JsonKey()
  final double fdpHours;
  @override
  @JsonKey()
  final String aircraftType;
  @override
  @JsonKey()
  final bool layover;
  @override
  @JsonKey()
  final double layoverHours;
  @override
  @JsonKey()
  final double payRate;
  @override
  @JsonKey()
  final double estimatedPay;
  @override
  @JsonKey()
  final double perDiem;
  @override
  @JsonKey()
  final LegalityStatus legalityStatus;
  final List<String> _legalityFlags;
  @override
  @JsonKey()
  List<String> get legalityFlags {
    if (_legalityFlags is EqualUnmodifiableListView) return _legalityFlags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_legalityFlags);
  }

  @override
  @JsonKey()
  final double restAfterHours;
  @override
  @JsonKey()
  final double restBeforeHours;
  @override
  @JsonKey()
  final int sequence;

  @override
  String toString() {
    return 'FlightLeg(id: $id, lineId: $lineId, flightNumber: $flightNumber, origin: $origin, destination: $destination, legType: $legType, departureLT: $departureLT, arrivalLT: $arrivalLT, departureUTC: $departureUTC, arrivalUTC: $arrivalUTC, dutyStart: $dutyStart, dutyEnd: $dutyEnd, releaseTime: $releaseTime, blockHours: $blockHours, fdpHours: $fdpHours, aircraftType: $aircraftType, layover: $layover, layoverHours: $layoverHours, payRate: $payRate, estimatedPay: $estimatedPay, perDiem: $perDiem, legalityStatus: $legalityStatus, legalityFlags: $legalityFlags, restAfterHours: $restAfterHours, restBeforeHours: $restBeforeHours, sequence: $sequence)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlightLegImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.lineId, lineId) || other.lineId == lineId) &&
            (identical(other.flightNumber, flightNumber) ||
                other.flightNumber == flightNumber) &&
            (identical(other.origin, origin) || other.origin == origin) &&
            (identical(other.destination, destination) ||
                other.destination == destination) &&
            (identical(other.legType, legType) || other.legType == legType) &&
            (identical(other.departureLT, departureLT) ||
                other.departureLT == departureLT) &&
            (identical(other.arrivalLT, arrivalLT) ||
                other.arrivalLT == arrivalLT) &&
            (identical(other.departureUTC, departureUTC) ||
                other.departureUTC == departureUTC) &&
            (identical(other.arrivalUTC, arrivalUTC) ||
                other.arrivalUTC == arrivalUTC) &&
            (identical(other.dutyStart, dutyStart) ||
                other.dutyStart == dutyStart) &&
            (identical(other.dutyEnd, dutyEnd) || other.dutyEnd == dutyEnd) &&
            (identical(other.releaseTime, releaseTime) ||
                other.releaseTime == releaseTime) &&
            (identical(other.blockHours, blockHours) ||
                other.blockHours == blockHours) &&
            (identical(other.fdpHours, fdpHours) ||
                other.fdpHours == fdpHours) &&
            (identical(other.aircraftType, aircraftType) ||
                other.aircraftType == aircraftType) &&
            (identical(other.layover, layover) || other.layover == layover) &&
            (identical(other.layoverHours, layoverHours) ||
                other.layoverHours == layoverHours) &&
            (identical(other.payRate, payRate) || other.payRate == payRate) &&
            (identical(other.estimatedPay, estimatedPay) ||
                other.estimatedPay == estimatedPay) &&
            (identical(other.perDiem, perDiem) || other.perDiem == perDiem) &&
            (identical(other.legalityStatus, legalityStatus) ||
                other.legalityStatus == legalityStatus) &&
            const DeepCollectionEquality()
                .equals(other._legalityFlags, _legalityFlags) &&
            (identical(other.restAfterHours, restAfterHours) ||
                other.restAfterHours == restAfterHours) &&
            (identical(other.restBeforeHours, restBeforeHours) ||
                other.restBeforeHours == restBeforeHours) &&
            (identical(other.sequence, sequence) ||
                other.sequence == sequence));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        lineId,
        flightNumber,
        origin,
        destination,
        legType,
        departureLT,
        arrivalLT,
        departureUTC,
        arrivalUTC,
        dutyStart,
        dutyEnd,
        releaseTime,
        blockHours,
        fdpHours,
        aircraftType,
        layover,
        layoverHours,
        payRate,
        estimatedPay,
        perDiem,
        legalityStatus,
        const DeepCollectionEquality().hash(_legalityFlags),
        restAfterHours,
        restBeforeHours,
        sequence
      ]);

  /// Create a copy of FlightLeg
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FlightLegImplCopyWith<_$FlightLegImpl> get copyWith =>
      __$$FlightLegImplCopyWithImpl<_$FlightLegImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FlightLegImplToJson(
      this,
    );
  }
}

abstract class _FlightLeg implements FlightLeg {
  const factory _FlightLeg(
      {required final String id,
      required final String lineId,
      required final String flightNumber,
      required final String origin,
      required final String destination,
      final LegType legType,
      required final DateTime departureLT,
      required final DateTime arrivalLT,
      required final DateTime departureUTC,
      required final DateTime arrivalUTC,
      required final DateTime dutyStart,
      required final DateTime dutyEnd,
      required final DateTime releaseTime,
      final double blockHours,
      final double fdpHours,
      final String aircraftType,
      final bool layover,
      final double layoverHours,
      final double payRate,
      final double estimatedPay,
      final double perDiem,
      final LegalityStatus legalityStatus,
      final List<String> legalityFlags,
      final double restAfterHours,
      final double restBeforeHours,
      final int sequence}) = _$FlightLegImpl;

  factory _FlightLeg.fromJson(Map<String, dynamic> json) =
      _$FlightLegImpl.fromJson;

  @override
  String get id;
  @override
  String get lineId;
  @override
  String get flightNumber;
  @override
  String get origin;
  @override
  String get destination;
  @override
  LegType get legType;
  @override
  DateTime get departureLT;
  @override
  DateTime get arrivalLT;
  @override
  DateTime get departureUTC;
  @override
  DateTime get arrivalUTC;
  @override
  DateTime get dutyStart;
  @override
  DateTime get dutyEnd;
  @override
  DateTime get releaseTime;
  @override
  double get blockHours;
  @override
  double get fdpHours;
  @override
  String get aircraftType;
  @override
  bool get layover;
  @override
  double get layoverHours;
  @override
  double get payRate;
  @override
  double get estimatedPay;
  @override
  double get perDiem;
  @override
  LegalityStatus get legalityStatus;
  @override
  List<String> get legalityFlags;
  @override
  double get restAfterHours;
  @override
  double get restBeforeHours;
  @override
  int get sequence;

  /// Create a copy of FlightLeg
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FlightLegImplCopyWith<_$FlightLegImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Bid _$BidFromJson(Map<String, dynamic> json) {
  return _Bid.fromJson(json);
}

/// @nodoc
mixin _$Bid {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get lineId => throw _privateConstructorUsedError;
  String get lineNumber => throw _privateConstructorUsedError;
  String get month => throw _privateConstructorUsedError;
  int get priority => throw _privateConstructorUsedError;
  BidStatus get status => throw _privateConstructorUsedError;
  UserMode get userMode => throw _privateConstructorUsedError;
  String get rank => throw _privateConstructorUsedError;
  String get lineType => throw _privateConstructorUsedError;
  String get carryOver => throw _privateConstructorUsedError;
  String get base => throw _privateConstructorUsedError;
  String get category => throw _privateConstructorUsedError;
  double get creditHours => throw _privateConstructorUsedError;
  double get blockHours => throw _privateConstructorUsedError;
  double get carryOverHours => throw _privateConstructorUsedError;
  int get totalLegs => throw _privateConstructorUsedError;
  int get fourLegCount => throw _privateConstructorUsedError;
  double get expense => throw _privateConstructorUsedError;
  double get allowance => throw _privateConstructorUsedError;
  double get income => throw _privateConstructorUsedError;
  bool get hasStarDays => throw _privateConstructorUsedError;
  bool get isAutoBid => throw _privateConstructorUsedError;
  List<String> get autoReasons => throw _privateConstructorUsedError;
  BidScoreSnapshot get scoreAtBid => throw _privateConstructorUsedError;
  double get estimatedSalary => throw _privateConstructorUsedError;
  DateTime get submittedAt => throw _privateConstructorUsedError;
  DateTime? get windowClosedAt => throw _privateConstructorUsedError;
  DateTime? get awardedAt => throw _privateConstructorUsedError;
  DateTime? get withdrawnAt => throw _privateConstructorUsedError;

  /// Serializes this Bid to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Bid
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BidCopyWith<Bid> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BidCopyWith<$Res> {
  factory $BidCopyWith(Bid value, $Res Function(Bid) then) =
      _$BidCopyWithImpl<$Res, Bid>;
  @useResult
  $Res call(
      {String id,
      String userId,
      String lineId,
      String lineNumber,
      String month,
      int priority,
      BidStatus status,
      UserMode userMode,
      String rank,
      String lineType,
      String carryOver,
      String base,
      String category,
      double creditHours,
      double blockHours,
      double carryOverHours,
      int totalLegs,
      int fourLegCount,
      double expense,
      double allowance,
      double income,
      bool hasStarDays,
      bool isAutoBid,
      List<String> autoReasons,
      BidScoreSnapshot scoreAtBid,
      double estimatedSalary,
      DateTime submittedAt,
      DateTime? windowClosedAt,
      DateTime? awardedAt,
      DateTime? withdrawnAt});

  $BidScoreSnapshotCopyWith<$Res> get scoreAtBid;
}

/// @nodoc
class _$BidCopyWithImpl<$Res, $Val extends Bid> implements $BidCopyWith<$Res> {
  _$BidCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Bid
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? lineId = null,
    Object? lineNumber = null,
    Object? month = null,
    Object? priority = null,
    Object? status = null,
    Object? userMode = null,
    Object? rank = null,
    Object? lineType = null,
    Object? carryOver = null,
    Object? base = null,
    Object? category = null,
    Object? creditHours = null,
    Object? blockHours = null,
    Object? carryOverHours = null,
    Object? totalLegs = null,
    Object? fourLegCount = null,
    Object? expense = null,
    Object? allowance = null,
    Object? income = null,
    Object? hasStarDays = null,
    Object? isAutoBid = null,
    Object? autoReasons = null,
    Object? scoreAtBid = null,
    Object? estimatedSalary = null,
    Object? submittedAt = null,
    Object? windowClosedAt = freezed,
    Object? awardedAt = freezed,
    Object? withdrawnAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      lineId: null == lineId
          ? _value.lineId
          : lineId // ignore: cast_nullable_to_non_nullable
              as String,
      lineNumber: null == lineNumber
          ? _value.lineNumber
          : lineNumber // ignore: cast_nullable_to_non_nullable
              as String,
      month: null == month
          ? _value.month
          : month // ignore: cast_nullable_to_non_nullable
              as String,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as BidStatus,
      userMode: null == userMode
          ? _value.userMode
          : userMode // ignore: cast_nullable_to_non_nullable
              as UserMode,
      rank: null == rank
          ? _value.rank
          : rank // ignore: cast_nullable_to_non_nullable
              as String,
      lineType: null == lineType
          ? _value.lineType
          : lineType // ignore: cast_nullable_to_non_nullable
              as String,
      carryOver: null == carryOver
          ? _value.carryOver
          : carryOver // ignore: cast_nullable_to_non_nullable
              as String,
      base: null == base
          ? _value.base
          : base // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      creditHours: null == creditHours
          ? _value.creditHours
          : creditHours // ignore: cast_nullable_to_non_nullable
              as double,
      blockHours: null == blockHours
          ? _value.blockHours
          : blockHours // ignore: cast_nullable_to_non_nullable
              as double,
      carryOverHours: null == carryOverHours
          ? _value.carryOverHours
          : carryOverHours // ignore: cast_nullable_to_non_nullable
              as double,
      totalLegs: null == totalLegs
          ? _value.totalLegs
          : totalLegs // ignore: cast_nullable_to_non_nullable
              as int,
      fourLegCount: null == fourLegCount
          ? _value.fourLegCount
          : fourLegCount // ignore: cast_nullable_to_non_nullable
              as int,
      expense: null == expense
          ? _value.expense
          : expense // ignore: cast_nullable_to_non_nullable
              as double,
      allowance: null == allowance
          ? _value.allowance
          : allowance // ignore: cast_nullable_to_non_nullable
              as double,
      income: null == income
          ? _value.income
          : income // ignore: cast_nullable_to_non_nullable
              as double,
      hasStarDays: null == hasStarDays
          ? _value.hasStarDays
          : hasStarDays // ignore: cast_nullable_to_non_nullable
              as bool,
      isAutoBid: null == isAutoBid
          ? _value.isAutoBid
          : isAutoBid // ignore: cast_nullable_to_non_nullable
              as bool,
      autoReasons: null == autoReasons
          ? _value.autoReasons
          : autoReasons // ignore: cast_nullable_to_non_nullable
              as List<String>,
      scoreAtBid: null == scoreAtBid
          ? _value.scoreAtBid
          : scoreAtBid // ignore: cast_nullable_to_non_nullable
              as BidScoreSnapshot,
      estimatedSalary: null == estimatedSalary
          ? _value.estimatedSalary
          : estimatedSalary // ignore: cast_nullable_to_non_nullable
              as double,
      submittedAt: null == submittedAt
          ? _value.submittedAt
          : submittedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      windowClosedAt: freezed == windowClosedAt
          ? _value.windowClosedAt
          : windowClosedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      awardedAt: freezed == awardedAt
          ? _value.awardedAt
          : awardedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      withdrawnAt: freezed == withdrawnAt
          ? _value.withdrawnAt
          : withdrawnAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }

  /// Create a copy of Bid
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BidScoreSnapshotCopyWith<$Res> get scoreAtBid {
    return $BidScoreSnapshotCopyWith<$Res>(_value.scoreAtBid, (value) {
      return _then(_value.copyWith(scoreAtBid: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$BidImplCopyWith<$Res> implements $BidCopyWith<$Res> {
  factory _$$BidImplCopyWith(_$BidImpl value, $Res Function(_$BidImpl) then) =
      __$$BidImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String userId,
      String lineId,
      String lineNumber,
      String month,
      int priority,
      BidStatus status,
      UserMode userMode,
      String rank,
      String lineType,
      String carryOver,
      String base,
      String category,
      double creditHours,
      double blockHours,
      double carryOverHours,
      int totalLegs,
      int fourLegCount,
      double expense,
      double allowance,
      double income,
      bool hasStarDays,
      bool isAutoBid,
      List<String> autoReasons,
      BidScoreSnapshot scoreAtBid,
      double estimatedSalary,
      DateTime submittedAt,
      DateTime? windowClosedAt,
      DateTime? awardedAt,
      DateTime? withdrawnAt});

  @override
  $BidScoreSnapshotCopyWith<$Res> get scoreAtBid;
}

/// @nodoc
class __$$BidImplCopyWithImpl<$Res> extends _$BidCopyWithImpl<$Res, _$BidImpl>
    implements _$$BidImplCopyWith<$Res> {
  __$$BidImplCopyWithImpl(_$BidImpl _value, $Res Function(_$BidImpl) _then)
      : super(_value, _then);

  /// Create a copy of Bid
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? lineId = null,
    Object? lineNumber = null,
    Object? month = null,
    Object? priority = null,
    Object? status = null,
    Object? userMode = null,
    Object? rank = null,
    Object? lineType = null,
    Object? carryOver = null,
    Object? base = null,
    Object? category = null,
    Object? creditHours = null,
    Object? blockHours = null,
    Object? carryOverHours = null,
    Object? totalLegs = null,
    Object? fourLegCount = null,
    Object? expense = null,
    Object? allowance = null,
    Object? income = null,
    Object? hasStarDays = null,
    Object? isAutoBid = null,
    Object? autoReasons = null,
    Object? scoreAtBid = null,
    Object? estimatedSalary = null,
    Object? submittedAt = null,
    Object? windowClosedAt = freezed,
    Object? awardedAt = freezed,
    Object? withdrawnAt = freezed,
  }) {
    return _then(_$BidImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      lineId: null == lineId
          ? _value.lineId
          : lineId // ignore: cast_nullable_to_non_nullable
              as String,
      lineNumber: null == lineNumber
          ? _value.lineNumber
          : lineNumber // ignore: cast_nullable_to_non_nullable
              as String,
      month: null == month
          ? _value.month
          : month // ignore: cast_nullable_to_non_nullable
              as String,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as BidStatus,
      userMode: null == userMode
          ? _value.userMode
          : userMode // ignore: cast_nullable_to_non_nullable
              as UserMode,
      rank: null == rank
          ? _value.rank
          : rank // ignore: cast_nullable_to_non_nullable
              as String,
      lineType: null == lineType
          ? _value.lineType
          : lineType // ignore: cast_nullable_to_non_nullable
              as String,
      carryOver: null == carryOver
          ? _value.carryOver
          : carryOver // ignore: cast_nullable_to_non_nullable
              as String,
      base: null == base
          ? _value.base
          : base // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      creditHours: null == creditHours
          ? _value.creditHours
          : creditHours // ignore: cast_nullable_to_non_nullable
              as double,
      blockHours: null == blockHours
          ? _value.blockHours
          : blockHours // ignore: cast_nullable_to_non_nullable
              as double,
      carryOverHours: null == carryOverHours
          ? _value.carryOverHours
          : carryOverHours // ignore: cast_nullable_to_non_nullable
              as double,
      totalLegs: null == totalLegs
          ? _value.totalLegs
          : totalLegs // ignore: cast_nullable_to_non_nullable
              as int,
      fourLegCount: null == fourLegCount
          ? _value.fourLegCount
          : fourLegCount // ignore: cast_nullable_to_non_nullable
              as int,
      expense: null == expense
          ? _value.expense
          : expense // ignore: cast_nullable_to_non_nullable
              as double,
      allowance: null == allowance
          ? _value.allowance
          : allowance // ignore: cast_nullable_to_non_nullable
              as double,
      income: null == income
          ? _value.income
          : income // ignore: cast_nullable_to_non_nullable
              as double,
      hasStarDays: null == hasStarDays
          ? _value.hasStarDays
          : hasStarDays // ignore: cast_nullable_to_non_nullable
              as bool,
      isAutoBid: null == isAutoBid
          ? _value.isAutoBid
          : isAutoBid // ignore: cast_nullable_to_non_nullable
              as bool,
      autoReasons: null == autoReasons
          ? _value._autoReasons
          : autoReasons // ignore: cast_nullable_to_non_nullable
              as List<String>,
      scoreAtBid: null == scoreAtBid
          ? _value.scoreAtBid
          : scoreAtBid // ignore: cast_nullable_to_non_nullable
              as BidScoreSnapshot,
      estimatedSalary: null == estimatedSalary
          ? _value.estimatedSalary
          : estimatedSalary // ignore: cast_nullable_to_non_nullable
              as double,
      submittedAt: null == submittedAt
          ? _value.submittedAt
          : submittedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      windowClosedAt: freezed == windowClosedAt
          ? _value.windowClosedAt
          : windowClosedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      awardedAt: freezed == awardedAt
          ? _value.awardedAt
          : awardedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      withdrawnAt: freezed == withdrawnAt
          ? _value.withdrawnAt
          : withdrawnAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BidImpl implements _Bid {
  const _$BidImpl(
      {required this.id,
      required this.userId,
      required this.lineId,
      required this.lineNumber,
      required this.month,
      this.priority = 1,
      this.status = BidStatus.draft,
      this.userMode = UserMode.balanced,
      this.rank = '',
      this.lineType = '',
      this.carryOver = '',
      this.base = '',
      this.category = '',
      this.creditHours = 0,
      this.blockHours = 0,
      this.carryOverHours = 0,
      this.totalLegs = 0,
      this.fourLegCount = 0,
      this.expense = 0,
      this.allowance = 0,
      this.income = 0,
      this.hasStarDays = false,
      this.isAutoBid = false,
      final List<String> autoReasons = const [],
      this.scoreAtBid = const BidScoreSnapshot(),
      this.estimatedSalary = 0,
      required this.submittedAt,
      this.windowClosedAt,
      this.awardedAt,
      this.withdrawnAt})
      : _autoReasons = autoReasons;

  factory _$BidImpl.fromJson(Map<String, dynamic> json) =>
      _$$BidImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String lineId;
  @override
  final String lineNumber;
  @override
  final String month;
  @override
  @JsonKey()
  final int priority;
  @override
  @JsonKey()
  final BidStatus status;
  @override
  @JsonKey()
  final UserMode userMode;
  @override
  @JsonKey()
  final String rank;
  @override
  @JsonKey()
  final String lineType;
  @override
  @JsonKey()
  final String carryOver;
  @override
  @JsonKey()
  final String base;
  @override
  @JsonKey()
  final String category;
  @override
  @JsonKey()
  final double creditHours;
  @override
  @JsonKey()
  final double blockHours;
  @override
  @JsonKey()
  final double carryOverHours;
  @override
  @JsonKey()
  final int totalLegs;
  @override
  @JsonKey()
  final int fourLegCount;
  @override
  @JsonKey()
  final double expense;
  @override
  @JsonKey()
  final double allowance;
  @override
  @JsonKey()
  final double income;
  @override
  @JsonKey()
  final bool hasStarDays;
  @override
  @JsonKey()
  final bool isAutoBid;
  final List<String> _autoReasons;
  @override
  @JsonKey()
  List<String> get autoReasons {
    if (_autoReasons is EqualUnmodifiableListView) return _autoReasons;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_autoReasons);
  }

  @override
  @JsonKey()
  final BidScoreSnapshot scoreAtBid;
  @override
  @JsonKey()
  final double estimatedSalary;
  @override
  final DateTime submittedAt;
  @override
  final DateTime? windowClosedAt;
  @override
  final DateTime? awardedAt;
  @override
  final DateTime? withdrawnAt;

  @override
  String toString() {
    return 'Bid(id: $id, userId: $userId, lineId: $lineId, lineNumber: $lineNumber, month: $month, priority: $priority, status: $status, userMode: $userMode, rank: $rank, lineType: $lineType, carryOver: $carryOver, base: $base, category: $category, creditHours: $creditHours, blockHours: $blockHours, carryOverHours: $carryOverHours, totalLegs: $totalLegs, fourLegCount: $fourLegCount, expense: $expense, allowance: $allowance, income: $income, hasStarDays: $hasStarDays, isAutoBid: $isAutoBid, autoReasons: $autoReasons, scoreAtBid: $scoreAtBid, estimatedSalary: $estimatedSalary, submittedAt: $submittedAt, windowClosedAt: $windowClosedAt, awardedAt: $awardedAt, withdrawnAt: $withdrawnAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BidImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.lineId, lineId) || other.lineId == lineId) &&
            (identical(other.lineNumber, lineNumber) ||
                other.lineNumber == lineNumber) &&
            (identical(other.month, month) || other.month == month) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.userMode, userMode) ||
                other.userMode == userMode) &&
            (identical(other.rank, rank) || other.rank == rank) &&
            (identical(other.lineType, lineType) ||
                other.lineType == lineType) &&
            (identical(other.carryOver, carryOver) ||
                other.carryOver == carryOver) &&
            (identical(other.base, base) || other.base == base) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.creditHours, creditHours) ||
                other.creditHours == creditHours) &&
            (identical(other.blockHours, blockHours) ||
                other.blockHours == blockHours) &&
            (identical(other.carryOverHours, carryOverHours) ||
                other.carryOverHours == carryOverHours) &&
            (identical(other.totalLegs, totalLegs) ||
                other.totalLegs == totalLegs) &&
            (identical(other.fourLegCount, fourLegCount) ||
                other.fourLegCount == fourLegCount) &&
            (identical(other.expense, expense) || other.expense == expense) &&
            (identical(other.allowance, allowance) ||
                other.allowance == allowance) &&
            (identical(other.income, income) || other.income == income) &&
            (identical(other.hasStarDays, hasStarDays) ||
                other.hasStarDays == hasStarDays) &&
            (identical(other.isAutoBid, isAutoBid) ||
                other.isAutoBid == isAutoBid) &&
            const DeepCollectionEquality()
                .equals(other._autoReasons, _autoReasons) &&
            (identical(other.scoreAtBid, scoreAtBid) ||
                other.scoreAtBid == scoreAtBid) &&
            (identical(other.estimatedSalary, estimatedSalary) ||
                other.estimatedSalary == estimatedSalary) &&
            (identical(other.submittedAt, submittedAt) ||
                other.submittedAt == submittedAt) &&
            (identical(other.windowClosedAt, windowClosedAt) ||
                other.windowClosedAt == windowClosedAt) &&
            (identical(other.awardedAt, awardedAt) ||
                other.awardedAt == awardedAt) &&
            (identical(other.withdrawnAt, withdrawnAt) ||
                other.withdrawnAt == withdrawnAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        userId,
        lineId,
        lineNumber,
        month,
        priority,
        status,
        userMode,
        rank,
        lineType,
        carryOver,
        base,
        category,
        creditHours,
        blockHours,
        carryOverHours,
        totalLegs,
        fourLegCount,
        expense,
        allowance,
        income,
        hasStarDays,
        isAutoBid,
        const DeepCollectionEquality().hash(_autoReasons),
        scoreAtBid,
        estimatedSalary,
        submittedAt,
        windowClosedAt,
        awardedAt,
        withdrawnAt
      ]);

  /// Create a copy of Bid
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BidImplCopyWith<_$BidImpl> get copyWith =>
      __$$BidImplCopyWithImpl<_$BidImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BidImplToJson(
      this,
    );
  }
}

abstract class _Bid implements Bid {
  const factory _Bid(
      {required final String id,
      required final String userId,
      required final String lineId,
      required final String lineNumber,
      required final String month,
      final int priority,
      final BidStatus status,
      final UserMode userMode,
      final String rank,
      final String lineType,
      final String carryOver,
      final String base,
      final String category,
      final double creditHours,
      final double blockHours,
      final double carryOverHours,
      final int totalLegs,
      final int fourLegCount,
      final double expense,
      final double allowance,
      final double income,
      final bool hasStarDays,
      final bool isAutoBid,
      final List<String> autoReasons,
      final BidScoreSnapshot scoreAtBid,
      final double estimatedSalary,
      required final DateTime submittedAt,
      final DateTime? windowClosedAt,
      final DateTime? awardedAt,
      final DateTime? withdrawnAt}) = _$BidImpl;

  factory _Bid.fromJson(Map<String, dynamic> json) = _$BidImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get lineId;
  @override
  String get lineNumber;
  @override
  String get month;
  @override
  int get priority;
  @override
  BidStatus get status;
  @override
  UserMode get userMode;
  @override
  String get rank;
  @override
  String get lineType;
  @override
  String get carryOver;
  @override
  String get base;
  @override
  String get category;
  @override
  double get creditHours;
  @override
  double get blockHours;
  @override
  double get carryOverHours;
  @override
  int get totalLegs;
  @override
  int get fourLegCount;
  @override
  double get expense;
  @override
  double get allowance;
  @override
  double get income;
  @override
  bool get hasStarDays;
  @override
  bool get isAutoBid;
  @override
  List<String> get autoReasons;
  @override
  BidScoreSnapshot get scoreAtBid;
  @override
  double get estimatedSalary;
  @override
  DateTime get submittedAt;
  @override
  DateTime? get windowClosedAt;
  @override
  DateTime? get awardedAt;
  @override
  DateTime? get withdrawnAt;

  /// Create a copy of Bid
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BidImplCopyWith<_$BidImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

BidScoreSnapshot _$BidScoreSnapshotFromJson(Map<String, dynamic> json) {
  return _BidScoreSnapshot.fromJson(json);
}

/// @nodoc
mixin _$BidScoreSnapshot {
  double get salaryScore => throw _privateConstructorUsedError;
  double get restScore => throw _privateConstructorUsedError;
  double get prefScore => throw _privateConstructorUsedError;
  double get composite => throw _privateConstructorUsedError;

  /// Serializes this BidScoreSnapshot to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BidScoreSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BidScoreSnapshotCopyWith<BidScoreSnapshot> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BidScoreSnapshotCopyWith<$Res> {
  factory $BidScoreSnapshotCopyWith(
          BidScoreSnapshot value, $Res Function(BidScoreSnapshot) then) =
      _$BidScoreSnapshotCopyWithImpl<$Res, BidScoreSnapshot>;
  @useResult
  $Res call(
      {double salaryScore,
      double restScore,
      double prefScore,
      double composite});
}

/// @nodoc
class _$BidScoreSnapshotCopyWithImpl<$Res, $Val extends BidScoreSnapshot>
    implements $BidScoreSnapshotCopyWith<$Res> {
  _$BidScoreSnapshotCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BidScoreSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? salaryScore = null,
    Object? restScore = null,
    Object? prefScore = null,
    Object? composite = null,
  }) {
    return _then(_value.copyWith(
      salaryScore: null == salaryScore
          ? _value.salaryScore
          : salaryScore // ignore: cast_nullable_to_non_nullable
              as double,
      restScore: null == restScore
          ? _value.restScore
          : restScore // ignore: cast_nullable_to_non_nullable
              as double,
      prefScore: null == prefScore
          ? _value.prefScore
          : prefScore // ignore: cast_nullable_to_non_nullable
              as double,
      composite: null == composite
          ? _value.composite
          : composite // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BidScoreSnapshotImplCopyWith<$Res>
    implements $BidScoreSnapshotCopyWith<$Res> {
  factory _$$BidScoreSnapshotImplCopyWith(_$BidScoreSnapshotImpl value,
          $Res Function(_$BidScoreSnapshotImpl) then) =
      __$$BidScoreSnapshotImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {double salaryScore,
      double restScore,
      double prefScore,
      double composite});
}

/// @nodoc
class __$$BidScoreSnapshotImplCopyWithImpl<$Res>
    extends _$BidScoreSnapshotCopyWithImpl<$Res, _$BidScoreSnapshotImpl>
    implements _$$BidScoreSnapshotImplCopyWith<$Res> {
  __$$BidScoreSnapshotImplCopyWithImpl(_$BidScoreSnapshotImpl _value,
      $Res Function(_$BidScoreSnapshotImpl) _then)
      : super(_value, _then);

  /// Create a copy of BidScoreSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? salaryScore = null,
    Object? restScore = null,
    Object? prefScore = null,
    Object? composite = null,
  }) {
    return _then(_$BidScoreSnapshotImpl(
      salaryScore: null == salaryScore
          ? _value.salaryScore
          : salaryScore // ignore: cast_nullable_to_non_nullable
              as double,
      restScore: null == restScore
          ? _value.restScore
          : restScore // ignore: cast_nullable_to_non_nullable
              as double,
      prefScore: null == prefScore
          ? _value.prefScore
          : prefScore // ignore: cast_nullable_to_non_nullable
              as double,
      composite: null == composite
          ? _value.composite
          : composite // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BidScoreSnapshotImpl implements _BidScoreSnapshot {
  const _$BidScoreSnapshotImpl(
      {this.salaryScore = 0,
      this.restScore = 0,
      this.prefScore = 0,
      this.composite = 0});

  factory _$BidScoreSnapshotImpl.fromJson(Map<String, dynamic> json) =>
      _$$BidScoreSnapshotImplFromJson(json);

  @override
  @JsonKey()
  final double salaryScore;
  @override
  @JsonKey()
  final double restScore;
  @override
  @JsonKey()
  final double prefScore;
  @override
  @JsonKey()
  final double composite;

  @override
  String toString() {
    return 'BidScoreSnapshot(salaryScore: $salaryScore, restScore: $restScore, prefScore: $prefScore, composite: $composite)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BidScoreSnapshotImpl &&
            (identical(other.salaryScore, salaryScore) ||
                other.salaryScore == salaryScore) &&
            (identical(other.restScore, restScore) ||
                other.restScore == restScore) &&
            (identical(other.prefScore, prefScore) ||
                other.prefScore == prefScore) &&
            (identical(other.composite, composite) ||
                other.composite == composite));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, salaryScore, restScore, prefScore, composite);

  /// Create a copy of BidScoreSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BidScoreSnapshotImplCopyWith<_$BidScoreSnapshotImpl> get copyWith =>
      __$$BidScoreSnapshotImplCopyWithImpl<_$BidScoreSnapshotImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BidScoreSnapshotImplToJson(
      this,
    );
  }
}

abstract class _BidScoreSnapshot implements BidScoreSnapshot {
  const factory _BidScoreSnapshot(
      {final double salaryScore,
      final double restScore,
      final double prefScore,
      final double composite}) = _$BidScoreSnapshotImpl;

  factory _BidScoreSnapshot.fromJson(Map<String, dynamic> json) =
      _$BidScoreSnapshotImpl.fromJson;

  @override
  double get salaryScore;
  @override
  double get restScore;
  @override
  double get prefScore;
  @override
  double get composite;

  /// Create a copy of BidScoreSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BidScoreSnapshotImplCopyWith<_$BidScoreSnapshotImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Trade _$TradeFromJson(Map<String, dynamic> json) {
  return _Trade.fromJson(json);
}

/// @nodoc
mixin _$Trade {
  String get id => throw _privateConstructorUsedError;
  TradeType get type => throw _privateConstructorUsedError;
  String get initiatorId => throw _privateConstructorUsedError;
  String get initiatorRank => throw _privateConstructorUsedError;
  String? get receiverId => throw _privateConstructorUsedError;
  TradeStatus get status => throw _privateConstructorUsedError;
  TradeLeg get offeredLeg => throw _privateConstructorUsedError;
  TradeLeg? get requestedLeg => throw _privateConstructorUsedError;
  TradeLegality get legality => throw _privateConstructorUsedError;
  bool get isAnonymous => throw _privateConstructorUsedError;
  String get note => throw _privateConstructorUsedError;
  DateTime get expiresAt => throw _privateConstructorUsedError;
  DateTime? get confirmedAt => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this Trade to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Trade
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TradeCopyWith<Trade> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TradeCopyWith<$Res> {
  factory $TradeCopyWith(Trade value, $Res Function(Trade) then) =
      _$TradeCopyWithImpl<$Res, Trade>;
  @useResult
  $Res call(
      {String id,
      TradeType type,
      String initiatorId,
      String initiatorRank,
      String? receiverId,
      TradeStatus status,
      TradeLeg offeredLeg,
      TradeLeg? requestedLeg,
      TradeLegality legality,
      bool isAnonymous,
      String note,
      DateTime expiresAt,
      DateTime? confirmedAt,
      DateTime createdAt});

  $TradeLegCopyWith<$Res> get offeredLeg;
  $TradeLegCopyWith<$Res>? get requestedLeg;
  $TradeLegalityCopyWith<$Res> get legality;
}

/// @nodoc
class _$TradeCopyWithImpl<$Res, $Val extends Trade>
    implements $TradeCopyWith<$Res> {
  _$TradeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Trade
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? initiatorId = null,
    Object? initiatorRank = null,
    Object? receiverId = freezed,
    Object? status = null,
    Object? offeredLeg = null,
    Object? requestedLeg = freezed,
    Object? legality = null,
    Object? isAnonymous = null,
    Object? note = null,
    Object? expiresAt = null,
    Object? confirmedAt = freezed,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as TradeType,
      initiatorId: null == initiatorId
          ? _value.initiatorId
          : initiatorId // ignore: cast_nullable_to_non_nullable
              as String,
      initiatorRank: null == initiatorRank
          ? _value.initiatorRank
          : initiatorRank // ignore: cast_nullable_to_non_nullable
              as String,
      receiverId: freezed == receiverId
          ? _value.receiverId
          : receiverId // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as TradeStatus,
      offeredLeg: null == offeredLeg
          ? _value.offeredLeg
          : offeredLeg // ignore: cast_nullable_to_non_nullable
              as TradeLeg,
      requestedLeg: freezed == requestedLeg
          ? _value.requestedLeg
          : requestedLeg // ignore: cast_nullable_to_non_nullable
              as TradeLeg?,
      legality: null == legality
          ? _value.legality
          : legality // ignore: cast_nullable_to_non_nullable
              as TradeLegality,
      isAnonymous: null == isAnonymous
          ? _value.isAnonymous
          : isAnonymous // ignore: cast_nullable_to_non_nullable
              as bool,
      note: null == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String,
      expiresAt: null == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      confirmedAt: freezed == confirmedAt
          ? _value.confirmedAt
          : confirmedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }

  /// Create a copy of Trade
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TradeLegCopyWith<$Res> get offeredLeg {
    return $TradeLegCopyWith<$Res>(_value.offeredLeg, (value) {
      return _then(_value.copyWith(offeredLeg: value) as $Val);
    });
  }

  /// Create a copy of Trade
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TradeLegCopyWith<$Res>? get requestedLeg {
    if (_value.requestedLeg == null) {
      return null;
    }

    return $TradeLegCopyWith<$Res>(_value.requestedLeg!, (value) {
      return _then(_value.copyWith(requestedLeg: value) as $Val);
    });
  }

  /// Create a copy of Trade
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TradeLegalityCopyWith<$Res> get legality {
    return $TradeLegalityCopyWith<$Res>(_value.legality, (value) {
      return _then(_value.copyWith(legality: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TradeImplCopyWith<$Res> implements $TradeCopyWith<$Res> {
  factory _$$TradeImplCopyWith(
          _$TradeImpl value, $Res Function(_$TradeImpl) then) =
      __$$TradeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      TradeType type,
      String initiatorId,
      String initiatorRank,
      String? receiverId,
      TradeStatus status,
      TradeLeg offeredLeg,
      TradeLeg? requestedLeg,
      TradeLegality legality,
      bool isAnonymous,
      String note,
      DateTime expiresAt,
      DateTime? confirmedAt,
      DateTime createdAt});

  @override
  $TradeLegCopyWith<$Res> get offeredLeg;
  @override
  $TradeLegCopyWith<$Res>? get requestedLeg;
  @override
  $TradeLegalityCopyWith<$Res> get legality;
}

/// @nodoc
class __$$TradeImplCopyWithImpl<$Res>
    extends _$TradeCopyWithImpl<$Res, _$TradeImpl>
    implements _$$TradeImplCopyWith<$Res> {
  __$$TradeImplCopyWithImpl(
      _$TradeImpl _value, $Res Function(_$TradeImpl) _then)
      : super(_value, _then);

  /// Create a copy of Trade
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? initiatorId = null,
    Object? initiatorRank = null,
    Object? receiverId = freezed,
    Object? status = null,
    Object? offeredLeg = null,
    Object? requestedLeg = freezed,
    Object? legality = null,
    Object? isAnonymous = null,
    Object? note = null,
    Object? expiresAt = null,
    Object? confirmedAt = freezed,
    Object? createdAt = null,
  }) {
    return _then(_$TradeImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as TradeType,
      initiatorId: null == initiatorId
          ? _value.initiatorId
          : initiatorId // ignore: cast_nullable_to_non_nullable
              as String,
      initiatorRank: null == initiatorRank
          ? _value.initiatorRank
          : initiatorRank // ignore: cast_nullable_to_non_nullable
              as String,
      receiverId: freezed == receiverId
          ? _value.receiverId
          : receiverId // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as TradeStatus,
      offeredLeg: null == offeredLeg
          ? _value.offeredLeg
          : offeredLeg // ignore: cast_nullable_to_non_nullable
              as TradeLeg,
      requestedLeg: freezed == requestedLeg
          ? _value.requestedLeg
          : requestedLeg // ignore: cast_nullable_to_non_nullable
              as TradeLeg?,
      legality: null == legality
          ? _value.legality
          : legality // ignore: cast_nullable_to_non_nullable
              as TradeLegality,
      isAnonymous: null == isAnonymous
          ? _value.isAnonymous
          : isAnonymous // ignore: cast_nullable_to_non_nullable
              as bool,
      note: null == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String,
      expiresAt: null == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      confirmedAt: freezed == confirmedAt
          ? _value.confirmedAt
          : confirmedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TradeImpl implements _Trade {
  const _$TradeImpl(
      {required this.id,
      this.type = TradeType.openDrop,
      required this.initiatorId,
      this.initiatorRank = '',
      this.receiverId,
      this.status = TradeStatus.draft,
      required this.offeredLeg,
      this.requestedLeg,
      this.legality = const TradeLegality(),
      this.isAnonymous = false,
      this.note = '',
      required this.expiresAt,
      this.confirmedAt,
      required this.createdAt});

  factory _$TradeImpl.fromJson(Map<String, dynamic> json) =>
      _$$TradeImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey()
  final TradeType type;
  @override
  final String initiatorId;
  @override
  @JsonKey()
  final String initiatorRank;
  @override
  final String? receiverId;
  @override
  @JsonKey()
  final TradeStatus status;
  @override
  final TradeLeg offeredLeg;
  @override
  final TradeLeg? requestedLeg;
  @override
  @JsonKey()
  final TradeLegality legality;
  @override
  @JsonKey()
  final bool isAnonymous;
  @override
  @JsonKey()
  final String note;
  @override
  final DateTime expiresAt;
  @override
  final DateTime? confirmedAt;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'Trade(id: $id, type: $type, initiatorId: $initiatorId, initiatorRank: $initiatorRank, receiverId: $receiverId, status: $status, offeredLeg: $offeredLeg, requestedLeg: $requestedLeg, legality: $legality, isAnonymous: $isAnonymous, note: $note, expiresAt: $expiresAt, confirmedAt: $confirmedAt, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TradeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.initiatorId, initiatorId) ||
                other.initiatorId == initiatorId) &&
            (identical(other.initiatorRank, initiatorRank) ||
                other.initiatorRank == initiatorRank) &&
            (identical(other.receiverId, receiverId) ||
                other.receiverId == receiverId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.offeredLeg, offeredLeg) ||
                other.offeredLeg == offeredLeg) &&
            (identical(other.requestedLeg, requestedLeg) ||
                other.requestedLeg == requestedLeg) &&
            (identical(other.legality, legality) ||
                other.legality == legality) &&
            (identical(other.isAnonymous, isAnonymous) ||
                other.isAnonymous == isAnonymous) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.confirmedAt, confirmedAt) ||
                other.confirmedAt == confirmedAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      type,
      initiatorId,
      initiatorRank,
      receiverId,
      status,
      offeredLeg,
      requestedLeg,
      legality,
      isAnonymous,
      note,
      expiresAt,
      confirmedAt,
      createdAt);

  /// Create a copy of Trade
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TradeImplCopyWith<_$TradeImpl> get copyWith =>
      __$$TradeImplCopyWithImpl<_$TradeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TradeImplToJson(
      this,
    );
  }
}

abstract class _Trade implements Trade {
  const factory _Trade(
      {required final String id,
      final TradeType type,
      required final String initiatorId,
      final String initiatorRank,
      final String? receiverId,
      final TradeStatus status,
      required final TradeLeg offeredLeg,
      final TradeLeg? requestedLeg,
      final TradeLegality legality,
      final bool isAnonymous,
      final String note,
      required final DateTime expiresAt,
      final DateTime? confirmedAt,
      required final DateTime createdAt}) = _$TradeImpl;

  factory _Trade.fromJson(Map<String, dynamic> json) = _$TradeImpl.fromJson;

  @override
  String get id;
  @override
  TradeType get type;
  @override
  String get initiatorId;
  @override
  String get initiatorRank;
  @override
  String? get receiverId;
  @override
  TradeStatus get status;
  @override
  TradeLeg get offeredLeg;
  @override
  TradeLeg? get requestedLeg;
  @override
  TradeLegality get legality;
  @override
  bool get isAnonymous;
  @override
  String get note;
  @override
  DateTime get expiresAt;
  @override
  DateTime? get confirmedAt;
  @override
  DateTime get createdAt;

  /// Create a copy of Trade
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TradeImplCopyWith<_$TradeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TradeLeg _$TradeLegFromJson(Map<String, dynamic> json) {
  return _TradeLeg.fromJson(json);
}

/// @nodoc
mixin _$TradeLeg {
  String get legId => throw _privateConstructorUsedError;
  String get lineId => throw _privateConstructorUsedError;
  String get flightNumber => throw _privateConstructorUsedError;
  String get origin => throw _privateConstructorUsedError;
  String get destination => throw _privateConstructorUsedError;
  DateTime get departureUTC => throw _privateConstructorUsedError;

  /// Serializes this TradeLeg to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TradeLeg
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TradeLegCopyWith<TradeLeg> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TradeLegCopyWith<$Res> {
  factory $TradeLegCopyWith(TradeLeg value, $Res Function(TradeLeg) then) =
      _$TradeLegCopyWithImpl<$Res, TradeLeg>;
  @useResult
  $Res call(
      {String legId,
      String lineId,
      String flightNumber,
      String origin,
      String destination,
      DateTime departureUTC});
}

/// @nodoc
class _$TradeLegCopyWithImpl<$Res, $Val extends TradeLeg>
    implements $TradeLegCopyWith<$Res> {
  _$TradeLegCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TradeLeg
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? legId = null,
    Object? lineId = null,
    Object? flightNumber = null,
    Object? origin = null,
    Object? destination = null,
    Object? departureUTC = null,
  }) {
    return _then(_value.copyWith(
      legId: null == legId
          ? _value.legId
          : legId // ignore: cast_nullable_to_non_nullable
              as String,
      lineId: null == lineId
          ? _value.lineId
          : lineId // ignore: cast_nullable_to_non_nullable
              as String,
      flightNumber: null == flightNumber
          ? _value.flightNumber
          : flightNumber // ignore: cast_nullable_to_non_nullable
              as String,
      origin: null == origin
          ? _value.origin
          : origin // ignore: cast_nullable_to_non_nullable
              as String,
      destination: null == destination
          ? _value.destination
          : destination // ignore: cast_nullable_to_non_nullable
              as String,
      departureUTC: null == departureUTC
          ? _value.departureUTC
          : departureUTC // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TradeLegImplCopyWith<$Res>
    implements $TradeLegCopyWith<$Res> {
  factory _$$TradeLegImplCopyWith(
          _$TradeLegImpl value, $Res Function(_$TradeLegImpl) then) =
      __$$TradeLegImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String legId,
      String lineId,
      String flightNumber,
      String origin,
      String destination,
      DateTime departureUTC});
}

/// @nodoc
class __$$TradeLegImplCopyWithImpl<$Res>
    extends _$TradeLegCopyWithImpl<$Res, _$TradeLegImpl>
    implements _$$TradeLegImplCopyWith<$Res> {
  __$$TradeLegImplCopyWithImpl(
      _$TradeLegImpl _value, $Res Function(_$TradeLegImpl) _then)
      : super(_value, _then);

  /// Create a copy of TradeLeg
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? legId = null,
    Object? lineId = null,
    Object? flightNumber = null,
    Object? origin = null,
    Object? destination = null,
    Object? departureUTC = null,
  }) {
    return _then(_$TradeLegImpl(
      legId: null == legId
          ? _value.legId
          : legId // ignore: cast_nullable_to_non_nullable
              as String,
      lineId: null == lineId
          ? _value.lineId
          : lineId // ignore: cast_nullable_to_non_nullable
              as String,
      flightNumber: null == flightNumber
          ? _value.flightNumber
          : flightNumber // ignore: cast_nullable_to_non_nullable
              as String,
      origin: null == origin
          ? _value.origin
          : origin // ignore: cast_nullable_to_non_nullable
              as String,
      destination: null == destination
          ? _value.destination
          : destination // ignore: cast_nullable_to_non_nullable
              as String,
      departureUTC: null == departureUTC
          ? _value.departureUTC
          : departureUTC // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TradeLegImpl implements _TradeLeg {
  const _$TradeLegImpl(
      {required this.legId,
      required this.lineId,
      required this.flightNumber,
      required this.origin,
      required this.destination,
      required this.departureUTC});

  factory _$TradeLegImpl.fromJson(Map<String, dynamic> json) =>
      _$$TradeLegImplFromJson(json);

  @override
  final String legId;
  @override
  final String lineId;
  @override
  final String flightNumber;
  @override
  final String origin;
  @override
  final String destination;
  @override
  final DateTime departureUTC;

  @override
  String toString() {
    return 'TradeLeg(legId: $legId, lineId: $lineId, flightNumber: $flightNumber, origin: $origin, destination: $destination, departureUTC: $departureUTC)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TradeLegImpl &&
            (identical(other.legId, legId) || other.legId == legId) &&
            (identical(other.lineId, lineId) || other.lineId == lineId) &&
            (identical(other.flightNumber, flightNumber) ||
                other.flightNumber == flightNumber) &&
            (identical(other.origin, origin) || other.origin == origin) &&
            (identical(other.destination, destination) ||
                other.destination == destination) &&
            (identical(other.departureUTC, departureUTC) ||
                other.departureUTC == departureUTC));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, legId, lineId, flightNumber,
      origin, destination, departureUTC);

  /// Create a copy of TradeLeg
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TradeLegImplCopyWith<_$TradeLegImpl> get copyWith =>
      __$$TradeLegImplCopyWithImpl<_$TradeLegImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TradeLegImplToJson(
      this,
    );
  }
}

abstract class _TradeLeg implements TradeLeg {
  const factory _TradeLeg(
      {required final String legId,
      required final String lineId,
      required final String flightNumber,
      required final String origin,
      required final String destination,
      required final DateTime departureUTC}) = _$TradeLegImpl;

  factory _TradeLeg.fromJson(Map<String, dynamic> json) =
      _$TradeLegImpl.fromJson;

  @override
  String get legId;
  @override
  String get lineId;
  @override
  String get flightNumber;
  @override
  String get origin;
  @override
  String get destination;
  @override
  DateTime get departureUTC;

  /// Create a copy of TradeLeg
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TradeLegImplCopyWith<_$TradeLegImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TradeLegality _$TradeLegalityFromJson(Map<String, dynamic> json) {
  return _TradeLegality.fromJson(json);
}

/// @nodoc
mixin _$TradeLegality {
  bool get checked => throw _privateConstructorUsedError;
  DateTime? get checkedAt => throw _privateConstructorUsedError;
  LegalityResult get initiatorResult => throw _privateConstructorUsedError;
  LegalityResult get receiverResult => throw _privateConstructorUsedError;

  /// Serializes this TradeLegality to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TradeLegality
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TradeLegalityCopyWith<TradeLegality> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TradeLegalityCopyWith<$Res> {
  factory $TradeLegalityCopyWith(
          TradeLegality value, $Res Function(TradeLegality) then) =
      _$TradeLegalityCopyWithImpl<$Res, TradeLegality>;
  @useResult
  $Res call(
      {bool checked,
      DateTime? checkedAt,
      LegalityResult initiatorResult,
      LegalityResult receiverResult});

  $LegalityResultCopyWith<$Res> get initiatorResult;
  $LegalityResultCopyWith<$Res> get receiverResult;
}

/// @nodoc
class _$TradeLegalityCopyWithImpl<$Res, $Val extends TradeLegality>
    implements $TradeLegalityCopyWith<$Res> {
  _$TradeLegalityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TradeLegality
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? checked = null,
    Object? checkedAt = freezed,
    Object? initiatorResult = null,
    Object? receiverResult = null,
  }) {
    return _then(_value.copyWith(
      checked: null == checked
          ? _value.checked
          : checked // ignore: cast_nullable_to_non_nullable
              as bool,
      checkedAt: freezed == checkedAt
          ? _value.checkedAt
          : checkedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      initiatorResult: null == initiatorResult
          ? _value.initiatorResult
          : initiatorResult // ignore: cast_nullable_to_non_nullable
              as LegalityResult,
      receiverResult: null == receiverResult
          ? _value.receiverResult
          : receiverResult // ignore: cast_nullable_to_non_nullable
              as LegalityResult,
    ) as $Val);
  }

  /// Create a copy of TradeLegality
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LegalityResultCopyWith<$Res> get initiatorResult {
    return $LegalityResultCopyWith<$Res>(_value.initiatorResult, (value) {
      return _then(_value.copyWith(initiatorResult: value) as $Val);
    });
  }

  /// Create a copy of TradeLegality
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LegalityResultCopyWith<$Res> get receiverResult {
    return $LegalityResultCopyWith<$Res>(_value.receiverResult, (value) {
      return _then(_value.copyWith(receiverResult: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TradeLegalityImplCopyWith<$Res>
    implements $TradeLegalityCopyWith<$Res> {
  factory _$$TradeLegalityImplCopyWith(
          _$TradeLegalityImpl value, $Res Function(_$TradeLegalityImpl) then) =
      __$$TradeLegalityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool checked,
      DateTime? checkedAt,
      LegalityResult initiatorResult,
      LegalityResult receiverResult});

  @override
  $LegalityResultCopyWith<$Res> get initiatorResult;
  @override
  $LegalityResultCopyWith<$Res> get receiverResult;
}

/// @nodoc
class __$$TradeLegalityImplCopyWithImpl<$Res>
    extends _$TradeLegalityCopyWithImpl<$Res, _$TradeLegalityImpl>
    implements _$$TradeLegalityImplCopyWith<$Res> {
  __$$TradeLegalityImplCopyWithImpl(
      _$TradeLegalityImpl _value, $Res Function(_$TradeLegalityImpl) _then)
      : super(_value, _then);

  /// Create a copy of TradeLegality
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? checked = null,
    Object? checkedAt = freezed,
    Object? initiatorResult = null,
    Object? receiverResult = null,
  }) {
    return _then(_$TradeLegalityImpl(
      checked: null == checked
          ? _value.checked
          : checked // ignore: cast_nullable_to_non_nullable
              as bool,
      checkedAt: freezed == checkedAt
          ? _value.checkedAt
          : checkedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      initiatorResult: null == initiatorResult
          ? _value.initiatorResult
          : initiatorResult // ignore: cast_nullable_to_non_nullable
              as LegalityResult,
      receiverResult: null == receiverResult
          ? _value.receiverResult
          : receiverResult // ignore: cast_nullable_to_non_nullable
              as LegalityResult,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TradeLegalityImpl implements _TradeLegality {
  const _$TradeLegalityImpl(
      {this.checked = false,
      this.checkedAt,
      this.initiatorResult = const LegalityResult(),
      this.receiverResult = const LegalityResult()});

  factory _$TradeLegalityImpl.fromJson(Map<String, dynamic> json) =>
      _$$TradeLegalityImplFromJson(json);

  @override
  @JsonKey()
  final bool checked;
  @override
  final DateTime? checkedAt;
  @override
  @JsonKey()
  final LegalityResult initiatorResult;
  @override
  @JsonKey()
  final LegalityResult receiverResult;

  @override
  String toString() {
    return 'TradeLegality(checked: $checked, checkedAt: $checkedAt, initiatorResult: $initiatorResult, receiverResult: $receiverResult)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TradeLegalityImpl &&
            (identical(other.checked, checked) || other.checked == checked) &&
            (identical(other.checkedAt, checkedAt) ||
                other.checkedAt == checkedAt) &&
            (identical(other.initiatorResult, initiatorResult) ||
                other.initiatorResult == initiatorResult) &&
            (identical(other.receiverResult, receiverResult) ||
                other.receiverResult == receiverResult));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, checked, checkedAt, initiatorResult, receiverResult);

  /// Create a copy of TradeLegality
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TradeLegalityImplCopyWith<_$TradeLegalityImpl> get copyWith =>
      __$$TradeLegalityImplCopyWithImpl<_$TradeLegalityImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TradeLegalityImplToJson(
      this,
    );
  }
}

abstract class _TradeLegality implements TradeLegality {
  const factory _TradeLegality(
      {final bool checked,
      final DateTime? checkedAt,
      final LegalityResult initiatorResult,
      final LegalityResult receiverResult}) = _$TradeLegalityImpl;

  factory _TradeLegality.fromJson(Map<String, dynamic> json) =
      _$TradeLegalityImpl.fromJson;

  @override
  bool get checked;
  @override
  DateTime? get checkedAt;
  @override
  LegalityResult get initiatorResult;
  @override
  LegalityResult get receiverResult;

  /// Create a copy of TradeLegality
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TradeLegalityImplCopyWith<_$TradeLegalityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LegalityResult _$LegalityResultFromJson(Map<String, dynamic> json) {
  return _LegalityResult.fromJson(json);
}

/// @nodoc
mixin _$LegalityResult {
  bool get passed => throw _privateConstructorUsedError;
  List<LegalityViolation> get violations => throw _privateConstructorUsedError;
  List<LegalityViolation> get warnings => throw _privateConstructorUsedError;

  /// Serializes this LegalityResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LegalityResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LegalityResultCopyWith<LegalityResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LegalityResultCopyWith<$Res> {
  factory $LegalityResultCopyWith(
          LegalityResult value, $Res Function(LegalityResult) then) =
      _$LegalityResultCopyWithImpl<$Res, LegalityResult>;
  @useResult
  $Res call(
      {bool passed,
      List<LegalityViolation> violations,
      List<LegalityViolation> warnings});
}

/// @nodoc
class _$LegalityResultCopyWithImpl<$Res, $Val extends LegalityResult>
    implements $LegalityResultCopyWith<$Res> {
  _$LegalityResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LegalityResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? passed = null,
    Object? violations = null,
    Object? warnings = null,
  }) {
    return _then(_value.copyWith(
      passed: null == passed
          ? _value.passed
          : passed // ignore: cast_nullable_to_non_nullable
              as bool,
      violations: null == violations
          ? _value.violations
          : violations // ignore: cast_nullable_to_non_nullable
              as List<LegalityViolation>,
      warnings: null == warnings
          ? _value.warnings
          : warnings // ignore: cast_nullable_to_non_nullable
              as List<LegalityViolation>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$LegalityResultImplCopyWith<$Res>
    implements $LegalityResultCopyWith<$Res> {
  factory _$$LegalityResultImplCopyWith(_$LegalityResultImpl value,
          $Res Function(_$LegalityResultImpl) then) =
      __$$LegalityResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool passed,
      List<LegalityViolation> violations,
      List<LegalityViolation> warnings});
}

/// @nodoc
class __$$LegalityResultImplCopyWithImpl<$Res>
    extends _$LegalityResultCopyWithImpl<$Res, _$LegalityResultImpl>
    implements _$$LegalityResultImplCopyWith<$Res> {
  __$$LegalityResultImplCopyWithImpl(
      _$LegalityResultImpl _value, $Res Function(_$LegalityResultImpl) _then)
      : super(_value, _then);

  /// Create a copy of LegalityResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? passed = null,
    Object? violations = null,
    Object? warnings = null,
  }) {
    return _then(_$LegalityResultImpl(
      passed: null == passed
          ? _value.passed
          : passed // ignore: cast_nullable_to_non_nullable
              as bool,
      violations: null == violations
          ? _value._violations
          : violations // ignore: cast_nullable_to_non_nullable
              as List<LegalityViolation>,
      warnings: null == warnings
          ? _value._warnings
          : warnings // ignore: cast_nullable_to_non_nullable
              as List<LegalityViolation>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$LegalityResultImpl implements _LegalityResult {
  const _$LegalityResultImpl(
      {this.passed = true,
      final List<LegalityViolation> violations = const [],
      final List<LegalityViolation> warnings = const []})
      : _violations = violations,
        _warnings = warnings;

  factory _$LegalityResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$LegalityResultImplFromJson(json);

  @override
  @JsonKey()
  final bool passed;
  final List<LegalityViolation> _violations;
  @override
  @JsonKey()
  List<LegalityViolation> get violations {
    if (_violations is EqualUnmodifiableListView) return _violations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_violations);
  }

  final List<LegalityViolation> _warnings;
  @override
  @JsonKey()
  List<LegalityViolation> get warnings {
    if (_warnings is EqualUnmodifiableListView) return _warnings;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_warnings);
  }

  @override
  String toString() {
    return 'LegalityResult(passed: $passed, violations: $violations, warnings: $warnings)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LegalityResultImpl &&
            (identical(other.passed, passed) || other.passed == passed) &&
            const DeepCollectionEquality()
                .equals(other._violations, _violations) &&
            const DeepCollectionEquality().equals(other._warnings, _warnings));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      passed,
      const DeepCollectionEquality().hash(_violations),
      const DeepCollectionEquality().hash(_warnings));

  /// Create a copy of LegalityResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LegalityResultImplCopyWith<_$LegalityResultImpl> get copyWith =>
      __$$LegalityResultImplCopyWithImpl<_$LegalityResultImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LegalityResultImplToJson(
      this,
    );
  }
}

abstract class _LegalityResult implements LegalityResult {
  const factory _LegalityResult(
      {final bool passed,
      final List<LegalityViolation> violations,
      final List<LegalityViolation> warnings}) = _$LegalityResultImpl;

  factory _LegalityResult.fromJson(Map<String, dynamic> json) =
      _$LegalityResultImpl.fromJson;

  @override
  bool get passed;
  @override
  List<LegalityViolation> get violations;
  @override
  List<LegalityViolation> get warnings;

  /// Create a copy of LegalityResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LegalityResultImplCopyWith<_$LegalityResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LegalityViolation _$LegalityViolationFromJson(Map<String, dynamic> json) {
  return _LegalityViolation.fromJson(json);
}

/// @nodoc
mixin _$LegalityViolation {
  String get ruleId => throw _privateConstructorUsedError;
  String get ruleDescription => throw _privateConstructorUsedError;
  String get ruleDescriptionAr => throw _privateConstructorUsedError;
  double get actualValue => throw _privateConstructorUsedError;
  double get requiredValue => throw _privateConstructorUsedError;
  String get unit => throw _privateConstructorUsedError;
  LegalitySeverity get severity => throw _privateConstructorUsedError;
  List<String> get affectedLegIds => throw _privateConstructorUsedError;

  /// Serializes this LegalityViolation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LegalityViolation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LegalityViolationCopyWith<LegalityViolation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LegalityViolationCopyWith<$Res> {
  factory $LegalityViolationCopyWith(
          LegalityViolation value, $Res Function(LegalityViolation) then) =
      _$LegalityViolationCopyWithImpl<$Res, LegalityViolation>;
  @useResult
  $Res call(
      {String ruleId,
      String ruleDescription,
      String ruleDescriptionAr,
      double actualValue,
      double requiredValue,
      String unit,
      LegalitySeverity severity,
      List<String> affectedLegIds});
}

/// @nodoc
class _$LegalityViolationCopyWithImpl<$Res, $Val extends LegalityViolation>
    implements $LegalityViolationCopyWith<$Res> {
  _$LegalityViolationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LegalityViolation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? ruleId = null,
    Object? ruleDescription = null,
    Object? ruleDescriptionAr = null,
    Object? actualValue = null,
    Object? requiredValue = null,
    Object? unit = null,
    Object? severity = null,
    Object? affectedLegIds = null,
  }) {
    return _then(_value.copyWith(
      ruleId: null == ruleId
          ? _value.ruleId
          : ruleId // ignore: cast_nullable_to_non_nullable
              as String,
      ruleDescription: null == ruleDescription
          ? _value.ruleDescription
          : ruleDescription // ignore: cast_nullable_to_non_nullable
              as String,
      ruleDescriptionAr: null == ruleDescriptionAr
          ? _value.ruleDescriptionAr
          : ruleDescriptionAr // ignore: cast_nullable_to_non_nullable
              as String,
      actualValue: null == actualValue
          ? _value.actualValue
          : actualValue // ignore: cast_nullable_to_non_nullable
              as double,
      requiredValue: null == requiredValue
          ? _value.requiredValue
          : requiredValue // ignore: cast_nullable_to_non_nullable
              as double,
      unit: null == unit
          ? _value.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      severity: null == severity
          ? _value.severity
          : severity // ignore: cast_nullable_to_non_nullable
              as LegalitySeverity,
      affectedLegIds: null == affectedLegIds
          ? _value.affectedLegIds
          : affectedLegIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$LegalityViolationImplCopyWith<$Res>
    implements $LegalityViolationCopyWith<$Res> {
  factory _$$LegalityViolationImplCopyWith(_$LegalityViolationImpl value,
          $Res Function(_$LegalityViolationImpl) then) =
      __$$LegalityViolationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String ruleId,
      String ruleDescription,
      String ruleDescriptionAr,
      double actualValue,
      double requiredValue,
      String unit,
      LegalitySeverity severity,
      List<String> affectedLegIds});
}

/// @nodoc
class __$$LegalityViolationImplCopyWithImpl<$Res>
    extends _$LegalityViolationCopyWithImpl<$Res, _$LegalityViolationImpl>
    implements _$$LegalityViolationImplCopyWith<$Res> {
  __$$LegalityViolationImplCopyWithImpl(_$LegalityViolationImpl _value,
      $Res Function(_$LegalityViolationImpl) _then)
      : super(_value, _then);

  /// Create a copy of LegalityViolation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? ruleId = null,
    Object? ruleDescription = null,
    Object? ruleDescriptionAr = null,
    Object? actualValue = null,
    Object? requiredValue = null,
    Object? unit = null,
    Object? severity = null,
    Object? affectedLegIds = null,
  }) {
    return _then(_$LegalityViolationImpl(
      ruleId: null == ruleId
          ? _value.ruleId
          : ruleId // ignore: cast_nullable_to_non_nullable
              as String,
      ruleDescription: null == ruleDescription
          ? _value.ruleDescription
          : ruleDescription // ignore: cast_nullable_to_non_nullable
              as String,
      ruleDescriptionAr: null == ruleDescriptionAr
          ? _value.ruleDescriptionAr
          : ruleDescriptionAr // ignore: cast_nullable_to_non_nullable
              as String,
      actualValue: null == actualValue
          ? _value.actualValue
          : actualValue // ignore: cast_nullable_to_non_nullable
              as double,
      requiredValue: null == requiredValue
          ? _value.requiredValue
          : requiredValue // ignore: cast_nullable_to_non_nullable
              as double,
      unit: null == unit
          ? _value.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      severity: null == severity
          ? _value.severity
          : severity // ignore: cast_nullable_to_non_nullable
              as LegalitySeverity,
      affectedLegIds: null == affectedLegIds
          ? _value._affectedLegIds
          : affectedLegIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$LegalityViolationImpl implements _LegalityViolation {
  const _$LegalityViolationImpl(
      {required this.ruleId,
      required this.ruleDescription,
      required this.ruleDescriptionAr,
      required this.actualValue,
      required this.requiredValue,
      required this.unit,
      this.severity = LegalitySeverity.blocking,
      final List<String> affectedLegIds = const []})
      : _affectedLegIds = affectedLegIds;

  factory _$LegalityViolationImpl.fromJson(Map<String, dynamic> json) =>
      _$$LegalityViolationImplFromJson(json);

  @override
  final String ruleId;
  @override
  final String ruleDescription;
  @override
  final String ruleDescriptionAr;
  @override
  final double actualValue;
  @override
  final double requiredValue;
  @override
  final String unit;
  @override
  @JsonKey()
  final LegalitySeverity severity;
  final List<String> _affectedLegIds;
  @override
  @JsonKey()
  List<String> get affectedLegIds {
    if (_affectedLegIds is EqualUnmodifiableListView) return _affectedLegIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_affectedLegIds);
  }

  @override
  String toString() {
    return 'LegalityViolation(ruleId: $ruleId, ruleDescription: $ruleDescription, ruleDescriptionAr: $ruleDescriptionAr, actualValue: $actualValue, requiredValue: $requiredValue, unit: $unit, severity: $severity, affectedLegIds: $affectedLegIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LegalityViolationImpl &&
            (identical(other.ruleId, ruleId) || other.ruleId == ruleId) &&
            (identical(other.ruleDescription, ruleDescription) ||
                other.ruleDescription == ruleDescription) &&
            (identical(other.ruleDescriptionAr, ruleDescriptionAr) ||
                other.ruleDescriptionAr == ruleDescriptionAr) &&
            (identical(other.actualValue, actualValue) ||
                other.actualValue == actualValue) &&
            (identical(other.requiredValue, requiredValue) ||
                other.requiredValue == requiredValue) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.severity, severity) ||
                other.severity == severity) &&
            const DeepCollectionEquality()
                .equals(other._affectedLegIds, _affectedLegIds));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      ruleId,
      ruleDescription,
      ruleDescriptionAr,
      actualValue,
      requiredValue,
      unit,
      severity,
      const DeepCollectionEquality().hash(_affectedLegIds));

  /// Create a copy of LegalityViolation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LegalityViolationImplCopyWith<_$LegalityViolationImpl> get copyWith =>
      __$$LegalityViolationImplCopyWithImpl<_$LegalityViolationImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LegalityViolationImplToJson(
      this,
    );
  }
}

abstract class _LegalityViolation implements LegalityViolation {
  const factory _LegalityViolation(
      {required final String ruleId,
      required final String ruleDescription,
      required final String ruleDescriptionAr,
      required final double actualValue,
      required final double requiredValue,
      required final String unit,
      final LegalitySeverity severity,
      final List<String> affectedLegIds}) = _$LegalityViolationImpl;

  factory _LegalityViolation.fromJson(Map<String, dynamic> json) =
      _$LegalityViolationImpl.fromJson;

  @override
  String get ruleId;
  @override
  String get ruleDescription;
  @override
  String get ruleDescriptionAr;
  @override
  double get actualValue;
  @override
  double get requiredValue;
  @override
  String get unit;
  @override
  LegalitySeverity get severity;
  @override
  List<String> get affectedLegIds;

  /// Create a copy of LegalityViolation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LegalityViolationImplCopyWith<_$LegalityViolationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RankedLine _$RankedLineFromJson(Map<String, dynamic> json) {
  return _RankedLine.fromJson(json);
}

/// @nodoc
mixin _$RankedLine {
  FlightLine get line => throw _privateConstructorUsedError;
  double get compositeScore => throw _privateConstructorUsedError;
  double get salaryScore => throw _privateConstructorUsedError;
  double get restScore => throw _privateConstructorUsedError;
  double get destPrefScore => throw _privateConstructorUsedError;
  double get regularityScore => throw _privateConstructorUsedError;
  int get rank => throw _privateConstructorUsedError;
  String get explanation => throw _privateConstructorUsedError;
  String get explanationAr => throw _privateConstructorUsedError;

  /// Serializes this RankedLine to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RankedLine
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RankedLineCopyWith<RankedLine> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RankedLineCopyWith<$Res> {
  factory $RankedLineCopyWith(
          RankedLine value, $Res Function(RankedLine) then) =
      _$RankedLineCopyWithImpl<$Res, RankedLine>;
  @useResult
  $Res call(
      {FlightLine line,
      double compositeScore,
      double salaryScore,
      double restScore,
      double destPrefScore,
      double regularityScore,
      int rank,
      String explanation,
      String explanationAr});

  $FlightLineCopyWith<$Res> get line;
}

/// @nodoc
class _$RankedLineCopyWithImpl<$Res, $Val extends RankedLine>
    implements $RankedLineCopyWith<$Res> {
  _$RankedLineCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RankedLine
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? line = null,
    Object? compositeScore = null,
    Object? salaryScore = null,
    Object? restScore = null,
    Object? destPrefScore = null,
    Object? regularityScore = null,
    Object? rank = null,
    Object? explanation = null,
    Object? explanationAr = null,
  }) {
    return _then(_value.copyWith(
      line: null == line
          ? _value.line
          : line // ignore: cast_nullable_to_non_nullable
              as FlightLine,
      compositeScore: null == compositeScore
          ? _value.compositeScore
          : compositeScore // ignore: cast_nullable_to_non_nullable
              as double,
      salaryScore: null == salaryScore
          ? _value.salaryScore
          : salaryScore // ignore: cast_nullable_to_non_nullable
              as double,
      restScore: null == restScore
          ? _value.restScore
          : restScore // ignore: cast_nullable_to_non_nullable
              as double,
      destPrefScore: null == destPrefScore
          ? _value.destPrefScore
          : destPrefScore // ignore: cast_nullable_to_non_nullable
              as double,
      regularityScore: null == regularityScore
          ? _value.regularityScore
          : regularityScore // ignore: cast_nullable_to_non_nullable
              as double,
      rank: null == rank
          ? _value.rank
          : rank // ignore: cast_nullable_to_non_nullable
              as int,
      explanation: null == explanation
          ? _value.explanation
          : explanation // ignore: cast_nullable_to_non_nullable
              as String,
      explanationAr: null == explanationAr
          ? _value.explanationAr
          : explanationAr // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }

  /// Create a copy of RankedLine
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FlightLineCopyWith<$Res> get line {
    return $FlightLineCopyWith<$Res>(_value.line, (value) {
      return _then(_value.copyWith(line: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$RankedLineImplCopyWith<$Res>
    implements $RankedLineCopyWith<$Res> {
  factory _$$RankedLineImplCopyWith(
          _$RankedLineImpl value, $Res Function(_$RankedLineImpl) then) =
      __$$RankedLineImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {FlightLine line,
      double compositeScore,
      double salaryScore,
      double restScore,
      double destPrefScore,
      double regularityScore,
      int rank,
      String explanation,
      String explanationAr});

  @override
  $FlightLineCopyWith<$Res> get line;
}

/// @nodoc
class __$$RankedLineImplCopyWithImpl<$Res>
    extends _$RankedLineCopyWithImpl<$Res, _$RankedLineImpl>
    implements _$$RankedLineImplCopyWith<$Res> {
  __$$RankedLineImplCopyWithImpl(
      _$RankedLineImpl _value, $Res Function(_$RankedLineImpl) _then)
      : super(_value, _then);

  /// Create a copy of RankedLine
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? line = null,
    Object? compositeScore = null,
    Object? salaryScore = null,
    Object? restScore = null,
    Object? destPrefScore = null,
    Object? regularityScore = null,
    Object? rank = null,
    Object? explanation = null,
    Object? explanationAr = null,
  }) {
    return _then(_$RankedLineImpl(
      line: null == line
          ? _value.line
          : line // ignore: cast_nullable_to_non_nullable
              as FlightLine,
      compositeScore: null == compositeScore
          ? _value.compositeScore
          : compositeScore // ignore: cast_nullable_to_non_nullable
              as double,
      salaryScore: null == salaryScore
          ? _value.salaryScore
          : salaryScore // ignore: cast_nullable_to_non_nullable
              as double,
      restScore: null == restScore
          ? _value.restScore
          : restScore // ignore: cast_nullable_to_non_nullable
              as double,
      destPrefScore: null == destPrefScore
          ? _value.destPrefScore
          : destPrefScore // ignore: cast_nullable_to_non_nullable
              as double,
      regularityScore: null == regularityScore
          ? _value.regularityScore
          : regularityScore // ignore: cast_nullable_to_non_nullable
              as double,
      rank: null == rank
          ? _value.rank
          : rank // ignore: cast_nullable_to_non_nullable
              as int,
      explanation: null == explanation
          ? _value.explanation
          : explanation // ignore: cast_nullable_to_non_nullable
              as String,
      explanationAr: null == explanationAr
          ? _value.explanationAr
          : explanationAr // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RankedLineImpl implements _RankedLine {
  const _$RankedLineImpl(
      {required this.line,
      this.compositeScore = 0,
      this.salaryScore = 0,
      this.restScore = 0,
      this.destPrefScore = 0,
      this.regularityScore = 0,
      this.rank = 0,
      required this.explanation,
      required this.explanationAr});

  factory _$RankedLineImpl.fromJson(Map<String, dynamic> json) =>
      _$$RankedLineImplFromJson(json);

  @override
  final FlightLine line;
  @override
  @JsonKey()
  final double compositeScore;
  @override
  @JsonKey()
  final double salaryScore;
  @override
  @JsonKey()
  final double restScore;
  @override
  @JsonKey()
  final double destPrefScore;
  @override
  @JsonKey()
  final double regularityScore;
  @override
  @JsonKey()
  final int rank;
  @override
  final String explanation;
  @override
  final String explanationAr;

  @override
  String toString() {
    return 'RankedLine(line: $line, compositeScore: $compositeScore, salaryScore: $salaryScore, restScore: $restScore, destPrefScore: $destPrefScore, regularityScore: $regularityScore, rank: $rank, explanation: $explanation, explanationAr: $explanationAr)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RankedLineImpl &&
            (identical(other.line, line) || other.line == line) &&
            (identical(other.compositeScore, compositeScore) ||
                other.compositeScore == compositeScore) &&
            (identical(other.salaryScore, salaryScore) ||
                other.salaryScore == salaryScore) &&
            (identical(other.restScore, restScore) ||
                other.restScore == restScore) &&
            (identical(other.destPrefScore, destPrefScore) ||
                other.destPrefScore == destPrefScore) &&
            (identical(other.regularityScore, regularityScore) ||
                other.regularityScore == regularityScore) &&
            (identical(other.rank, rank) || other.rank == rank) &&
            (identical(other.explanation, explanation) ||
                other.explanation == explanation) &&
            (identical(other.explanationAr, explanationAr) ||
                other.explanationAr == explanationAr));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      line,
      compositeScore,
      salaryScore,
      restScore,
      destPrefScore,
      regularityScore,
      rank,
      explanation,
      explanationAr);

  /// Create a copy of RankedLine
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RankedLineImplCopyWith<_$RankedLineImpl> get copyWith =>
      __$$RankedLineImplCopyWithImpl<_$RankedLineImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RankedLineImplToJson(
      this,
    );
  }
}

abstract class _RankedLine implements RankedLine {
  const factory _RankedLine(
      {required final FlightLine line,
      final double compositeScore,
      final double salaryScore,
      final double restScore,
      final double destPrefScore,
      final double regularityScore,
      final int rank,
      required final String explanation,
      required final String explanationAr}) = _$RankedLineImpl;

  factory _RankedLine.fromJson(Map<String, dynamic> json) =
      _$RankedLineImpl.fromJson;

  @override
  FlightLine get line;
  @override
  double get compositeScore;
  @override
  double get salaryScore;
  @override
  double get restScore;
  @override
  double get destPrefScore;
  @override
  double get regularityScore;
  @override
  int get rank;
  @override
  String get explanation;
  @override
  String get explanationAr;

  /// Create a copy of RankedLine
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RankedLineImplCopyWith<_$RankedLineImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AIMessage _$AIMessageFromJson(Map<String, dynamic> json) {
  return _AIMessage.fromJson(json);
}

/// @nodoc
mixin _$AIMessage {
  String get id => throw _privateConstructorUsedError;
  String get role => throw _privateConstructorUsedError; // 'user' | 'assistant'
  String get content => throw _privateConstructorUsedError;
  String get intentType => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  int get responseTimeMs =>
      throw _privateConstructorUsedError; // Rich content cards
  FlightLine? get lineCard => throw _privateConstructorUsedError;
  Trade? get tradeCard => throw _privateConstructorUsedError;
  LegalityResult? get legalityCard => throw _privateConstructorUsedError;

  /// Serializes this AIMessage to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AIMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AIMessageCopyWith<AIMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AIMessageCopyWith<$Res> {
  factory $AIMessageCopyWith(AIMessage value, $Res Function(AIMessage) then) =
      _$AIMessageCopyWithImpl<$Res, AIMessage>;
  @useResult
  $Res call(
      {String id,
      String role,
      String content,
      String intentType,
      DateTime timestamp,
      int responseTimeMs,
      FlightLine? lineCard,
      Trade? tradeCard,
      LegalityResult? legalityCard});

  $FlightLineCopyWith<$Res>? get lineCard;
  $TradeCopyWith<$Res>? get tradeCard;
  $LegalityResultCopyWith<$Res>? get legalityCard;
}

/// @nodoc
class _$AIMessageCopyWithImpl<$Res, $Val extends AIMessage>
    implements $AIMessageCopyWith<$Res> {
  _$AIMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AIMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? role = null,
    Object? content = null,
    Object? intentType = null,
    Object? timestamp = null,
    Object? responseTimeMs = null,
    Object? lineCard = freezed,
    Object? tradeCard = freezed,
    Object? legalityCard = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      intentType: null == intentType
          ? _value.intentType
          : intentType // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      responseTimeMs: null == responseTimeMs
          ? _value.responseTimeMs
          : responseTimeMs // ignore: cast_nullable_to_non_nullable
              as int,
      lineCard: freezed == lineCard
          ? _value.lineCard
          : lineCard // ignore: cast_nullable_to_non_nullable
              as FlightLine?,
      tradeCard: freezed == tradeCard
          ? _value.tradeCard
          : tradeCard // ignore: cast_nullable_to_non_nullable
              as Trade?,
      legalityCard: freezed == legalityCard
          ? _value.legalityCard
          : legalityCard // ignore: cast_nullable_to_non_nullable
              as LegalityResult?,
    ) as $Val);
  }

  /// Create a copy of AIMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FlightLineCopyWith<$Res>? get lineCard {
    if (_value.lineCard == null) {
      return null;
    }

    return $FlightLineCopyWith<$Res>(_value.lineCard!, (value) {
      return _then(_value.copyWith(lineCard: value) as $Val);
    });
  }

  /// Create a copy of AIMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TradeCopyWith<$Res>? get tradeCard {
    if (_value.tradeCard == null) {
      return null;
    }

    return $TradeCopyWith<$Res>(_value.tradeCard!, (value) {
      return _then(_value.copyWith(tradeCard: value) as $Val);
    });
  }

  /// Create a copy of AIMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LegalityResultCopyWith<$Res>? get legalityCard {
    if (_value.legalityCard == null) {
      return null;
    }

    return $LegalityResultCopyWith<$Res>(_value.legalityCard!, (value) {
      return _then(_value.copyWith(legalityCard: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AIMessageImplCopyWith<$Res>
    implements $AIMessageCopyWith<$Res> {
  factory _$$AIMessageImplCopyWith(
          _$AIMessageImpl value, $Res Function(_$AIMessageImpl) then) =
      __$$AIMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String role,
      String content,
      String intentType,
      DateTime timestamp,
      int responseTimeMs,
      FlightLine? lineCard,
      Trade? tradeCard,
      LegalityResult? legalityCard});

  @override
  $FlightLineCopyWith<$Res>? get lineCard;
  @override
  $TradeCopyWith<$Res>? get tradeCard;
  @override
  $LegalityResultCopyWith<$Res>? get legalityCard;
}

/// @nodoc
class __$$AIMessageImplCopyWithImpl<$Res>
    extends _$AIMessageCopyWithImpl<$Res, _$AIMessageImpl>
    implements _$$AIMessageImplCopyWith<$Res> {
  __$$AIMessageImplCopyWithImpl(
      _$AIMessageImpl _value, $Res Function(_$AIMessageImpl) _then)
      : super(_value, _then);

  /// Create a copy of AIMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? role = null,
    Object? content = null,
    Object? intentType = null,
    Object? timestamp = null,
    Object? responseTimeMs = null,
    Object? lineCard = freezed,
    Object? tradeCard = freezed,
    Object? legalityCard = freezed,
  }) {
    return _then(_$AIMessageImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      intentType: null == intentType
          ? _value.intentType
          : intentType // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      responseTimeMs: null == responseTimeMs
          ? _value.responseTimeMs
          : responseTimeMs // ignore: cast_nullable_to_non_nullable
              as int,
      lineCard: freezed == lineCard
          ? _value.lineCard
          : lineCard // ignore: cast_nullable_to_non_nullable
              as FlightLine?,
      tradeCard: freezed == tradeCard
          ? _value.tradeCard
          : tradeCard // ignore: cast_nullable_to_non_nullable
              as Trade?,
      legalityCard: freezed == legalityCard
          ? _value.legalityCard
          : legalityCard // ignore: cast_nullable_to_non_nullable
              as LegalityResult?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AIMessageImpl implements _AIMessage {
  const _$AIMessageImpl(
      {required this.id,
      required this.role,
      required this.content,
      this.intentType = '',
      required this.timestamp,
      this.responseTimeMs = 0,
      this.lineCard,
      this.tradeCard,
      this.legalityCard});

  factory _$AIMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$AIMessageImplFromJson(json);

  @override
  final String id;
  @override
  final String role;
// 'user' | 'assistant'
  @override
  final String content;
  @override
  @JsonKey()
  final String intentType;
  @override
  final DateTime timestamp;
  @override
  @JsonKey()
  final int responseTimeMs;
// Rich content cards
  @override
  final FlightLine? lineCard;
  @override
  final Trade? tradeCard;
  @override
  final LegalityResult? legalityCard;

  @override
  String toString() {
    return 'AIMessage(id: $id, role: $role, content: $content, intentType: $intentType, timestamp: $timestamp, responseTimeMs: $responseTimeMs, lineCard: $lineCard, tradeCard: $tradeCard, legalityCard: $legalityCard)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AIMessageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.intentType, intentType) ||
                other.intentType == intentType) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.responseTimeMs, responseTimeMs) ||
                other.responseTimeMs == responseTimeMs) &&
            (identical(other.lineCard, lineCard) ||
                other.lineCard == lineCard) &&
            (identical(other.tradeCard, tradeCard) ||
                other.tradeCard == tradeCard) &&
            (identical(other.legalityCard, legalityCard) ||
                other.legalityCard == legalityCard));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, role, content, intentType,
      timestamp, responseTimeMs, lineCard, tradeCard, legalityCard);

  /// Create a copy of AIMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AIMessageImplCopyWith<_$AIMessageImpl> get copyWith =>
      __$$AIMessageImplCopyWithImpl<_$AIMessageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AIMessageImplToJson(
      this,
    );
  }
}

abstract class _AIMessage implements AIMessage {
  const factory _AIMessage(
      {required final String id,
      required final String role,
      required final String content,
      final String intentType,
      required final DateTime timestamp,
      final int responseTimeMs,
      final FlightLine? lineCard,
      final Trade? tradeCard,
      final LegalityResult? legalityCard}) = _$AIMessageImpl;

  factory _AIMessage.fromJson(Map<String, dynamic> json) =
      _$AIMessageImpl.fromJson;

  @override
  String get id;
  @override
  String get role; // 'user' | 'assistant'
  @override
  String get content;
  @override
  String get intentType;
  @override
  DateTime get timestamp;
  @override
  int get responseTimeMs; // Rich content cards
  @override
  FlightLine? get lineCard;
  @override
  Trade? get tradeCard;
  @override
  LegalityResult? get legalityCard;

  /// Create a copy of AIMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AIMessageImplCopyWith<_$AIMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CIPNotification _$CIPNotificationFromJson(Map<String, dynamic> json) {
  return _CIPNotification.fromJson(json);
}

/// @nodoc
mixin _$CIPNotification {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get titleAr => throw _privateConstructorUsedError;
  String get body => throw _privateConstructorUsedError;
  String get bodyAr => throw _privateConstructorUsedError;
  String get deepLink => throw _privateConstructorUsedError;
  bool get read => throw _privateConstructorUsedError;
  DateTime get sentAt => throw _privateConstructorUsedError;

  /// Serializes this CIPNotification to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CIPNotification
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CIPNotificationCopyWith<CIPNotification> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CIPNotificationCopyWith<$Res> {
  factory $CIPNotificationCopyWith(
          CIPNotification value, $Res Function(CIPNotification) then) =
      _$CIPNotificationCopyWithImpl<$Res, CIPNotification>;
  @useResult
  $Res call(
      {String id,
      String userId,
      String type,
      String title,
      String titleAr,
      String body,
      String bodyAr,
      String deepLink,
      bool read,
      DateTime sentAt});
}

/// @nodoc
class _$CIPNotificationCopyWithImpl<$Res, $Val extends CIPNotification>
    implements $CIPNotificationCopyWith<$Res> {
  _$CIPNotificationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CIPNotification
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? type = null,
    Object? title = null,
    Object? titleAr = null,
    Object? body = null,
    Object? bodyAr = null,
    Object? deepLink = null,
    Object? read = null,
    Object? sentAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      titleAr: null == titleAr
          ? _value.titleAr
          : titleAr // ignore: cast_nullable_to_non_nullable
              as String,
      body: null == body
          ? _value.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
      bodyAr: null == bodyAr
          ? _value.bodyAr
          : bodyAr // ignore: cast_nullable_to_non_nullable
              as String,
      deepLink: null == deepLink
          ? _value.deepLink
          : deepLink // ignore: cast_nullable_to_non_nullable
              as String,
      read: null == read
          ? _value.read
          : read // ignore: cast_nullable_to_non_nullable
              as bool,
      sentAt: null == sentAt
          ? _value.sentAt
          : sentAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CIPNotificationImplCopyWith<$Res>
    implements $CIPNotificationCopyWith<$Res> {
  factory _$$CIPNotificationImplCopyWith(_$CIPNotificationImpl value,
          $Res Function(_$CIPNotificationImpl) then) =
      __$$CIPNotificationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String userId,
      String type,
      String title,
      String titleAr,
      String body,
      String bodyAr,
      String deepLink,
      bool read,
      DateTime sentAt});
}

/// @nodoc
class __$$CIPNotificationImplCopyWithImpl<$Res>
    extends _$CIPNotificationCopyWithImpl<$Res, _$CIPNotificationImpl>
    implements _$$CIPNotificationImplCopyWith<$Res> {
  __$$CIPNotificationImplCopyWithImpl(
      _$CIPNotificationImpl _value, $Res Function(_$CIPNotificationImpl) _then)
      : super(_value, _then);

  /// Create a copy of CIPNotification
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? type = null,
    Object? title = null,
    Object? titleAr = null,
    Object? body = null,
    Object? bodyAr = null,
    Object? deepLink = null,
    Object? read = null,
    Object? sentAt = null,
  }) {
    return _then(_$CIPNotificationImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      titleAr: null == titleAr
          ? _value.titleAr
          : titleAr // ignore: cast_nullable_to_non_nullable
              as String,
      body: null == body
          ? _value.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
      bodyAr: null == bodyAr
          ? _value.bodyAr
          : bodyAr // ignore: cast_nullable_to_non_nullable
              as String,
      deepLink: null == deepLink
          ? _value.deepLink
          : deepLink // ignore: cast_nullable_to_non_nullable
              as String,
      read: null == read
          ? _value.read
          : read // ignore: cast_nullable_to_non_nullable
              as bool,
      sentAt: null == sentAt
          ? _value.sentAt
          : sentAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CIPNotificationImpl implements _CIPNotification {
  const _$CIPNotificationImpl(
      {required this.id,
      required this.userId,
      required this.type,
      required this.title,
      required this.titleAr,
      required this.body,
      required this.bodyAr,
      this.deepLink = '',
      this.read = false,
      required this.sentAt});

  factory _$CIPNotificationImpl.fromJson(Map<String, dynamic> json) =>
      _$$CIPNotificationImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String type;
  @override
  final String title;
  @override
  final String titleAr;
  @override
  final String body;
  @override
  final String bodyAr;
  @override
  @JsonKey()
  final String deepLink;
  @override
  @JsonKey()
  final bool read;
  @override
  final DateTime sentAt;

  @override
  String toString() {
    return 'CIPNotification(id: $id, userId: $userId, type: $type, title: $title, titleAr: $titleAr, body: $body, bodyAr: $bodyAr, deepLink: $deepLink, read: $read, sentAt: $sentAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CIPNotificationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.titleAr, titleAr) || other.titleAr == titleAr) &&
            (identical(other.body, body) || other.body == body) &&
            (identical(other.bodyAr, bodyAr) || other.bodyAr == bodyAr) &&
            (identical(other.deepLink, deepLink) ||
                other.deepLink == deepLink) &&
            (identical(other.read, read) || other.read == read) &&
            (identical(other.sentAt, sentAt) || other.sentAt == sentAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, userId, type, title, titleAr,
      body, bodyAr, deepLink, read, sentAt);

  /// Create a copy of CIPNotification
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CIPNotificationImplCopyWith<_$CIPNotificationImpl> get copyWith =>
      __$$CIPNotificationImplCopyWithImpl<_$CIPNotificationImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CIPNotificationImplToJson(
      this,
    );
  }
}

abstract class _CIPNotification implements CIPNotification {
  const factory _CIPNotification(
      {required final String id,
      required final String userId,
      required final String type,
      required final String title,
      required final String titleAr,
      required final String body,
      required final String bodyAr,
      final String deepLink,
      final bool read,
      required final DateTime sentAt}) = _$CIPNotificationImpl;

  factory _CIPNotification.fromJson(Map<String, dynamic> json) =
      _$CIPNotificationImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get type;
  @override
  String get title;
  @override
  String get titleAr;
  @override
  String get body;
  @override
  String get bodyAr;
  @override
  String get deepLink;
  @override
  bool get read;
  @override
  DateTime get sentAt;

  /// Create a copy of CIPNotification
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CIPNotificationImplCopyWith<_$CIPNotificationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
