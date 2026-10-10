// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../whitelist_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WhitelistEntryStatus {

 WhitelistService get service; Po0TokenEntry get entry; Po0Token get token; Po0TokenResult? get result;
/// Create a copy of WhitelistEntryStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WhitelistEntryStatusCopyWith<WhitelistEntryStatus> get copyWith => _$WhitelistEntryStatusCopyWithImpl<WhitelistEntryStatus>(this as WhitelistEntryStatus, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as WhitelistEntryStatus;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WhitelistEntryStatus&&(identical(other.service, _this.service) || other.service == _this.service)&&(identical(other.entry, _this.entry) || other.entry == _this.entry)&&(identical(other.token, _this.token) || other.token == _this.token)&&(identical(other.result, _this.result) || other.result == _this.result));
}


@override
int get hashCode {
  final _this = this as WhitelistEntryStatus;
  return Object.hash(runtimeType,_this.service,_this.entry,_this.token,_this.result);
}



}

/// @nodoc
abstract mixin class $WhitelistEntryStatusCopyWith<$Res>  {
  factory $WhitelistEntryStatusCopyWith(WhitelistEntryStatus value, $Res Function(WhitelistEntryStatus) _then) = _$WhitelistEntryStatusCopyWithImpl;
@useResult
$Res call({
 WhitelistService service, Po0TokenEntry entry, Po0Token token, Po0TokenResult? result
});


$Po0TokenEntryCopyWith<$Res> get entry;$Po0TokenResultCopyWith<$Res>? get result;

}
/// @nodoc
class _$WhitelistEntryStatusCopyWithImpl<$Res>
    implements $WhitelistEntryStatusCopyWith<$Res> {
  _$WhitelistEntryStatusCopyWithImpl(this._self, this._then);

  final WhitelistEntryStatus _self;
  final $Res Function(WhitelistEntryStatus) _then;

/// Create a copy of WhitelistEntryStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? service = null,Object? entry = null,Object? token = null,Object? result = freezed,}) {
  return _then(WhitelistEntryStatus(
service: null == service ? _self.service : service // ignore: cast_nullable_to_non_nullable
as WhitelistService,entry: null == entry ? _self.entry : entry // ignore: cast_nullable_to_non_nullable
as Po0TokenEntry,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as Po0Token,result: freezed == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as Po0TokenResult?,
  ));
}
/// Create a copy of WhitelistEntryStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$Po0TokenEntryCopyWith<$Res> get entry {
  
  return $Po0TokenEntryCopyWith<$Res>(_self.entry, (value) {
    return _then(_self.copyWith(entry: value));
  });
}/// Create a copy of WhitelistEntryStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$Po0TokenResultCopyWith<$Res>? get result {
    if (_self.result == null) {
    return null;
  }

  return $Po0TokenResultCopyWith<$Res>(_self.result!, (value) {
    return _then(_self.copyWith(result: value));
  });
}
}


/// Adds pattern-matching-related methods to [WhitelistEntryStatus].
extension WhitelistEntryStatusPatterns on WhitelistEntryStatus {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WhitelistEntryStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WhitelistEntryStatus() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WhitelistEntryStatus value)  $default,){
final _that = this;
switch (_that) {
case _WhitelistEntryStatus():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WhitelistEntryStatus value)?  $default,){
final _that = this;
switch (_that) {
case _WhitelistEntryStatus() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WhitelistService service,  Po0TokenEntry entry,  Po0Token token,  Po0TokenResult? result)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WhitelistEntryStatus() when $default != null:
return $default(_that.service,_that.entry,_that.token,_that.result);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WhitelistService service,  Po0TokenEntry entry,  Po0Token token,  Po0TokenResult? result)  $default,) {final _that = this;
switch (_that) {
case _WhitelistEntryStatus():
return $default(_that.service,_that.entry,_that.token,_that.result);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WhitelistService service,  Po0TokenEntry entry,  Po0Token token,  Po0TokenResult? result)?  $default,) {final _that = this;
switch (_that) {
case _WhitelistEntryStatus() when $default != null:
return $default(_that.service,_that.entry,_that.token,_that.result);case _:
  return null;

}
}

}

/// @nodoc


class _WhitelistEntryStatus implements WhitelistEntryStatus {
  const _WhitelistEntryStatus({required this.service, required this.entry, required this.token, this.result});
  

@override final  WhitelistService service;
@override final  Po0TokenEntry entry;
@override final  Po0Token token;
@override final  Po0TokenResult? result;

/// Create a copy of WhitelistEntryStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WhitelistEntryStatusCopyWith<_WhitelistEntryStatus> get copyWith => __$WhitelistEntryStatusCopyWithImpl<_WhitelistEntryStatus>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WhitelistEntryStatus&&(identical(other.service, service) || other.service == service)&&(identical(other.entry, entry) || other.entry == entry)&&(identical(other.token, token) || other.token == token)&&(identical(other.result, result) || other.result == result));
}


@override
int get hashCode {
    return Object.hash(runtimeType,service,entry,token,result);
}



}

/// @nodoc
abstract mixin class _$WhitelistEntryStatusCopyWith<$Res> implements $WhitelistEntryStatusCopyWith<$Res> {
  factory _$WhitelistEntryStatusCopyWith(_WhitelistEntryStatus value, $Res Function(_WhitelistEntryStatus) _then) = __$WhitelistEntryStatusCopyWithImpl;
@override @useResult
$Res call({
 WhitelistService service, Po0TokenEntry entry, Po0Token token, Po0TokenResult? result
});


@override $Po0TokenEntryCopyWith<$Res> get entry;@override $Po0TokenResultCopyWith<$Res>? get result;

}
/// @nodoc
class __$WhitelistEntryStatusCopyWithImpl<$Res>
    implements _$WhitelistEntryStatusCopyWith<$Res> {
  __$WhitelistEntryStatusCopyWithImpl(this._self, this._then);

  final _WhitelistEntryStatus _self;
  final $Res Function(_WhitelistEntryStatus) _then;

/// Create a copy of WhitelistEntryStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? service = null,Object? entry = null,Object? token = null,Object? result = freezed,}) {
  return _then(_WhitelistEntryStatus(
service: null == service ? _self.service : service // ignore: cast_nullable_to_non_nullable
as WhitelistService,entry: null == entry ? _self.entry : entry // ignore: cast_nullable_to_non_nullable
as Po0TokenEntry,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as Po0Token,result: freezed == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as Po0TokenResult?,
  ));
}

/// Create a copy of WhitelistEntryStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$Po0TokenEntryCopyWith<$Res> get entry {
  
  return $Po0TokenEntryCopyWith<$Res>(_self.entry, (value) {
    return _then(_self.copyWith(entry: value));
  });
}/// Create a copy of WhitelistEntryStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$Po0TokenResultCopyWith<$Res>? get result {
    if (_self.result == null) {
    return null;
  }

  return $Po0TokenResultCopyWith<$Res>(_self.result!, (value) {
    return _then(_self.copyWith(result: value));
  });
}
}

/// @nodoc
mixin _$WhitelistSummary {

 bool get enabled; int get total; int get applied; int get waiting; bool get isRunning; DateTime? get lastPo0At; DateTime? get lastGgyAt; String? get po0Exit; String? get ggyExit; List<WhitelistEntryStatus> get entries;
/// Create a copy of WhitelistSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WhitelistSummaryCopyWith<WhitelistSummary> get copyWith => _$WhitelistSummaryCopyWithImpl<WhitelistSummary>(this as WhitelistSummary, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as WhitelistSummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WhitelistSummary&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled)&&(identical(other.total, _this.total) || other.total == _this.total)&&(identical(other.applied, _this.applied) || other.applied == _this.applied)&&(identical(other.waiting, _this.waiting) || other.waiting == _this.waiting)&&(identical(other.isRunning, _this.isRunning) || other.isRunning == _this.isRunning)&&(identical(other.lastPo0At, _this.lastPo0At) || other.lastPo0At == _this.lastPo0At)&&(identical(other.lastGgyAt, _this.lastGgyAt) || other.lastGgyAt == _this.lastGgyAt)&&(identical(other.po0Exit, _this.po0Exit) || other.po0Exit == _this.po0Exit)&&(identical(other.ggyExit, _this.ggyExit) || other.ggyExit == _this.ggyExit)&&const DeepCollectionEquality().equals(other.entries, _this.entries));
}


@override
int get hashCode {
  final _this = this as WhitelistSummary;
  return Object.hash(runtimeType,_this.enabled,_this.total,_this.applied,_this.waiting,_this.isRunning,_this.lastPo0At,_this.lastGgyAt,_this.po0Exit,_this.ggyExit,const DeepCollectionEquality().hash(_this.entries));
}



}

/// @nodoc
abstract mixin class $WhitelistSummaryCopyWith<$Res>  {
  factory $WhitelistSummaryCopyWith(WhitelistSummary value, $Res Function(WhitelistSummary) _then) = _$WhitelistSummaryCopyWithImpl;
@useResult
$Res call({
 bool enabled, int total, int applied, int waiting, bool isRunning, DateTime? lastPo0At, DateTime? lastGgyAt, String? po0Exit, String? ggyExit, List<WhitelistEntryStatus> entries
});




}
/// @nodoc
class _$WhitelistSummaryCopyWithImpl<$Res>
    implements $WhitelistSummaryCopyWith<$Res> {
  _$WhitelistSummaryCopyWithImpl(this._self, this._then);

  final WhitelistSummary _self;
  final $Res Function(WhitelistSummary) _then;

/// Create a copy of WhitelistSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? total = null,Object? applied = null,Object? waiting = null,Object? isRunning = null,Object? lastPo0At = freezed,Object? lastGgyAt = freezed,Object? po0Exit = freezed,Object? ggyExit = freezed,Object? entries = null,}) {
  return _then(WhitelistSummary(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,applied: null == applied ? _self.applied : applied // ignore: cast_nullable_to_non_nullable
as int,waiting: null == waiting ? _self.waiting : waiting // ignore: cast_nullable_to_non_nullable
as int,isRunning: null == isRunning ? _self.isRunning : isRunning // ignore: cast_nullable_to_non_nullable
as bool,lastPo0At: freezed == lastPo0At ? _self.lastPo0At : lastPo0At // ignore: cast_nullable_to_non_nullable
as DateTime?,lastGgyAt: freezed == lastGgyAt ? _self.lastGgyAt : lastGgyAt // ignore: cast_nullable_to_non_nullable
as DateTime?,po0Exit: freezed == po0Exit ? _self.po0Exit : po0Exit // ignore: cast_nullable_to_non_nullable
as String?,ggyExit: freezed == ggyExit ? _self.ggyExit : ggyExit // ignore: cast_nullable_to_non_nullable
as String?,entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as List<WhitelistEntryStatus>,
  ));
}

}


/// Adds pattern-matching-related methods to [WhitelistSummary].
extension WhitelistSummaryPatterns on WhitelistSummary {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WhitelistSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WhitelistSummary() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WhitelistSummary value)  $default,){
final _that = this;
switch (_that) {
case _WhitelistSummary():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WhitelistSummary value)?  $default,){
final _that = this;
switch (_that) {
case _WhitelistSummary() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled,  int total,  int applied,  int waiting,  bool isRunning,  DateTime? lastPo0At,  DateTime? lastGgyAt,  String? po0Exit,  String? ggyExit,  List<WhitelistEntryStatus> entries)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WhitelistSummary() when $default != null:
return $default(_that.enabled,_that.total,_that.applied,_that.waiting,_that.isRunning,_that.lastPo0At,_that.lastGgyAt,_that.po0Exit,_that.ggyExit,_that.entries);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled,  int total,  int applied,  int waiting,  bool isRunning,  DateTime? lastPo0At,  DateTime? lastGgyAt,  String? po0Exit,  String? ggyExit,  List<WhitelistEntryStatus> entries)  $default,) {final _that = this;
switch (_that) {
case _WhitelistSummary():
return $default(_that.enabled,_that.total,_that.applied,_that.waiting,_that.isRunning,_that.lastPo0At,_that.lastGgyAt,_that.po0Exit,_that.ggyExit,_that.entries);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled,  int total,  int applied,  int waiting,  bool isRunning,  DateTime? lastPo0At,  DateTime? lastGgyAt,  String? po0Exit,  String? ggyExit,  List<WhitelistEntryStatus> entries)?  $default,) {final _that = this;
switch (_that) {
case _WhitelistSummary() when $default != null:
return $default(_that.enabled,_that.total,_that.applied,_that.waiting,_that.isRunning,_that.lastPo0At,_that.lastGgyAt,_that.po0Exit,_that.ggyExit,_that.entries);case _:
  return null;

}
}

}

/// @nodoc


class _WhitelistSummary extends WhitelistSummary {
  const _WhitelistSummary({this.enabled = false, this.total = 0, this.applied = 0, this.waiting = 0, this.isRunning = false, this.lastPo0At, this.lastGgyAt, this.po0Exit, this.ggyExit,  List<WhitelistEntryStatus> entries = const []}): _entries = entries,super._();
  

@override@JsonKey() final  bool enabled;
@override@JsonKey() final  int total;
@override@JsonKey() final  int applied;
@override@JsonKey() final  int waiting;
@override@JsonKey() final  bool isRunning;
@override final  DateTime? lastPo0At;
@override final  DateTime? lastGgyAt;
@override final  String? po0Exit;
@override final  String? ggyExit;
 final  List<WhitelistEntryStatus> _entries;
@override@JsonKey() List<WhitelistEntryStatus> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}


/// Create a copy of WhitelistSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WhitelistSummaryCopyWith<_WhitelistSummary> get copyWith => __$WhitelistSummaryCopyWithImpl<_WhitelistSummary>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WhitelistSummary&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.total, total) || other.total == total)&&(identical(other.applied, applied) || other.applied == applied)&&(identical(other.waiting, waiting) || other.waiting == waiting)&&(identical(other.isRunning, isRunning) || other.isRunning == isRunning)&&(identical(other.lastPo0At, lastPo0At) || other.lastPo0At == lastPo0At)&&(identical(other.lastGgyAt, lastGgyAt) || other.lastGgyAt == lastGgyAt)&&(identical(other.po0Exit, po0Exit) || other.po0Exit == po0Exit)&&(identical(other.ggyExit, ggyExit) || other.ggyExit == ggyExit)&&const DeepCollectionEquality().equals(other.entries, _entries));
}


@override
int get hashCode {
    return Object.hash(runtimeType,enabled,total,applied,waiting,isRunning,lastPo0At,lastGgyAt,po0Exit,ggyExit,const DeepCollectionEquality().hash(_entries));
}



}

/// @nodoc
abstract mixin class _$WhitelistSummaryCopyWith<$Res> implements $WhitelistSummaryCopyWith<$Res> {
  factory _$WhitelistSummaryCopyWith(_WhitelistSummary value, $Res Function(_WhitelistSummary) _then) = __$WhitelistSummaryCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, int total, int applied, int waiting, bool isRunning, DateTime? lastPo0At, DateTime? lastGgyAt, String? po0Exit, String? ggyExit, List<WhitelistEntryStatus> entries
});




}
/// @nodoc
class __$WhitelistSummaryCopyWithImpl<$Res>
    implements _$WhitelistSummaryCopyWith<$Res> {
  __$WhitelistSummaryCopyWithImpl(this._self, this._then);

  final _WhitelistSummary _self;
  final $Res Function(_WhitelistSummary) _then;

/// Create a copy of WhitelistSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? total = null,Object? applied = null,Object? waiting = null,Object? isRunning = null,Object? lastPo0At = freezed,Object? lastGgyAt = freezed,Object? po0Exit = freezed,Object? ggyExit = freezed,Object? entries = null,}) {
  return _then(_WhitelistSummary(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,applied: null == applied ? _self.applied : applied // ignore: cast_nullable_to_non_nullable
as int,waiting: null == waiting ? _self.waiting : waiting // ignore: cast_nullable_to_non_nullable
as int,isRunning: null == isRunning ? _self.isRunning : isRunning // ignore: cast_nullable_to_non_nullable
as bool,lastPo0At: freezed == lastPo0At ? _self.lastPo0At : lastPo0At // ignore: cast_nullable_to_non_nullable
as DateTime?,lastGgyAt: freezed == lastGgyAt ? _self.lastGgyAt : lastGgyAt // ignore: cast_nullable_to_non_nullable
as DateTime?,po0Exit: freezed == po0Exit ? _self.po0Exit : po0Exit // ignore: cast_nullable_to_non_nullable
as String?,ggyExit: freezed == ggyExit ? _self.ggyExit : ggyExit // ignore: cast_nullable_to_non_nullable
as String?,entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<WhitelistEntryStatus>,
  ));
}


}

// dart format on
