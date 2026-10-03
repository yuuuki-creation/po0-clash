// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../po0_firewall.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Po0TokenEntry {

 String get token; String get name;
/// Create a copy of Po0TokenEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Po0TokenEntryCopyWith<Po0TokenEntry> get copyWith => _$Po0TokenEntryCopyWithImpl<Po0TokenEntry>(this as Po0TokenEntry, _$identity);

  /// Serializes this Po0TokenEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Po0TokenEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Po0TokenEntry&&(identical(other.token, _this.token) || other.token == _this.token)&&(identical(other.name, _this.name) || other.name == _this.name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Po0TokenEntry;
  return Object.hash(runtimeType,_this.token,_this.name);
}

@override
String toString() {
  final _this = this as Po0TokenEntry;
  return 'Po0TokenEntry(token: ${_this.token}, name: ${_this.name})';
}


}

/// @nodoc
abstract mixin class $Po0TokenEntryCopyWith<$Res>  {
  factory $Po0TokenEntryCopyWith(Po0TokenEntry value, $Res Function(Po0TokenEntry) _then) = _$Po0TokenEntryCopyWithImpl;
@useResult
$Res call({
 String token, String name
});




}
/// @nodoc
class _$Po0TokenEntryCopyWithImpl<$Res>
    implements $Po0TokenEntryCopyWith<$Res> {
  _$Po0TokenEntryCopyWithImpl(this._self, this._then);

  final Po0TokenEntry _self;
  final $Res Function(Po0TokenEntry) _then;

/// Create a copy of Po0TokenEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? token = null,Object? name = null,}) {
  return _then(Po0TokenEntry(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Po0TokenEntry].
extension Po0TokenEntryPatterns on Po0TokenEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Po0TokenEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Po0TokenEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Po0TokenEntry value)  $default,){
final _that = this;
switch (_that) {
case _Po0TokenEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Po0TokenEntry value)?  $default,){
final _that = this;
switch (_that) {
case _Po0TokenEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String token,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Po0TokenEntry() when $default != null:
return $default(_that.token,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String token,  String name)  $default,) {final _that = this;
switch (_that) {
case _Po0TokenEntry():
return $default(_that.token,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String token,  String name)?  $default,) {final _that = this;
switch (_that) {
case _Po0TokenEntry() when $default != null:
return $default(_that.token,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Po0TokenEntry implements Po0TokenEntry {
  const _Po0TokenEntry({required this.token, this.name = ''});
  factory _Po0TokenEntry.fromJson(Map<String, dynamic> json) => _$Po0TokenEntryFromJson(json);

@override final  String token;
@override@JsonKey() final  String name;

/// Create a copy of Po0TokenEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$Po0TokenEntryCopyWith<_Po0TokenEntry> get copyWith => __$Po0TokenEntryCopyWithImpl<_Po0TokenEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$Po0TokenEntryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Po0TokenEntry&&(identical(other.token, token) || other.token == token)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,token,name);
}

@override
String toString() {
    return 'Po0TokenEntry(token: $token, name: $name)';
}


}

/// @nodoc
abstract mixin class _$Po0TokenEntryCopyWith<$Res> implements $Po0TokenEntryCopyWith<$Res> {
  factory _$Po0TokenEntryCopyWith(_Po0TokenEntry value, $Res Function(_Po0TokenEntry) _then) = __$Po0TokenEntryCopyWithImpl;
@override @useResult
$Res call({
 String token, String name
});




}
/// @nodoc
class __$Po0TokenEntryCopyWithImpl<$Res>
    implements _$Po0TokenEntryCopyWith<$Res> {
  __$Po0TokenEntryCopyWithImpl(this._self, this._then);

  final _Po0TokenEntry _self;
  final $Res Function(_Po0TokenEntry) _then;

/// Create a copy of Po0TokenEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? token = null,Object? name = null,}) {
  return _then(_Po0TokenEntry(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$Po0FirewallProps {

 bool get enable; List<Po0TokenEntry> get tokenEntries; int get pollSeconds; bool get ggyEnable; List<Po0TokenEntry> get ggyEntries;
/// Create a copy of Po0FirewallProps
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Po0FirewallPropsCopyWith<Po0FirewallProps> get copyWith => _$Po0FirewallPropsCopyWithImpl<Po0FirewallProps>(this as Po0FirewallProps, _$identity);

  /// Serializes this Po0FirewallProps to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Po0FirewallProps;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Po0FirewallProps&&(identical(other.enable, _this.enable) || other.enable == _this.enable)&&const DeepCollectionEquality().equals(other.tokenEntries, _this.tokenEntries)&&(identical(other.pollSeconds, _this.pollSeconds) || other.pollSeconds == _this.pollSeconds)&&(identical(other.ggyEnable, _this.ggyEnable) || other.ggyEnable == _this.ggyEnable)&&const DeepCollectionEquality().equals(other.ggyEntries, _this.ggyEntries));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Po0FirewallProps;
  return Object.hash(runtimeType,_this.enable,const DeepCollectionEquality().hash(_this.tokenEntries),_this.pollSeconds,_this.ggyEnable,const DeepCollectionEquality().hash(_this.ggyEntries));
}

@override
String toString() {
  final _this = this as Po0FirewallProps;
  return 'Po0FirewallProps(enable: ${_this.enable}, tokenEntries: ${_this.tokenEntries}, pollSeconds: ${_this.pollSeconds}, ggyEnable: ${_this.ggyEnable}, ggyEntries: ${_this.ggyEntries})';
}


}

/// @nodoc
abstract mixin class $Po0FirewallPropsCopyWith<$Res>  {
  factory $Po0FirewallPropsCopyWith(Po0FirewallProps value, $Res Function(Po0FirewallProps) _then) = _$Po0FirewallPropsCopyWithImpl;
@useResult
$Res call({
 bool enable, List<Po0TokenEntry> tokenEntries, int pollSeconds, bool ggyEnable, List<Po0TokenEntry> ggyEntries
});




}
/// @nodoc
class _$Po0FirewallPropsCopyWithImpl<$Res>
    implements $Po0FirewallPropsCopyWith<$Res> {
  _$Po0FirewallPropsCopyWithImpl(this._self, this._then);

  final Po0FirewallProps _self;
  final $Res Function(Po0FirewallProps) _then;

/// Create a copy of Po0FirewallProps
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enable = null,Object? tokenEntries = null,Object? pollSeconds = null,Object? ggyEnable = null,Object? ggyEntries = null,}) {
  return _then(Po0FirewallProps(
enable: null == enable ? _self.enable : enable // ignore: cast_nullable_to_non_nullable
as bool,tokenEntries: null == tokenEntries ? _self.tokenEntries : tokenEntries // ignore: cast_nullable_to_non_nullable
as List<Po0TokenEntry>,pollSeconds: null == pollSeconds ? _self.pollSeconds : pollSeconds // ignore: cast_nullable_to_non_nullable
as int,ggyEnable: null == ggyEnable ? _self.ggyEnable : ggyEnable // ignore: cast_nullable_to_non_nullable
as bool,ggyEntries: null == ggyEntries ? _self.ggyEntries : ggyEntries // ignore: cast_nullable_to_non_nullable
as List<Po0TokenEntry>,
  ));
}

}


/// Adds pattern-matching-related methods to [Po0FirewallProps].
extension Po0FirewallPropsPatterns on Po0FirewallProps {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Po0FirewallProps value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Po0FirewallProps() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Po0FirewallProps value)  $default,){
final _that = this;
switch (_that) {
case _Po0FirewallProps():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Po0FirewallProps value)?  $default,){
final _that = this;
switch (_that) {
case _Po0FirewallProps() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enable,  List<Po0TokenEntry> tokenEntries,  int pollSeconds,  bool ggyEnable,  List<Po0TokenEntry> ggyEntries)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Po0FirewallProps() when $default != null:
return $default(_that.enable,_that.tokenEntries,_that.pollSeconds,_that.ggyEnable,_that.ggyEntries);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enable,  List<Po0TokenEntry> tokenEntries,  int pollSeconds,  bool ggyEnable,  List<Po0TokenEntry> ggyEntries)  $default,) {final _that = this;
switch (_that) {
case _Po0FirewallProps():
return $default(_that.enable,_that.tokenEntries,_that.pollSeconds,_that.ggyEnable,_that.ggyEntries);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enable,  List<Po0TokenEntry> tokenEntries,  int pollSeconds,  bool ggyEnable,  List<Po0TokenEntry> ggyEntries)?  $default,) {final _that = this;
switch (_that) {
case _Po0FirewallProps() when $default != null:
return $default(_that.enable,_that.tokenEntries,_that.pollSeconds,_that.ggyEnable,_that.ggyEntries);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Po0FirewallProps implements Po0FirewallProps {
  const _Po0FirewallProps({this.enable = false,  List<Po0TokenEntry> tokenEntries = const [], this.pollSeconds = 5, this.ggyEnable = false,  List<Po0TokenEntry> ggyEntries = const []}): _tokenEntries = tokenEntries,_ggyEntries = ggyEntries;
  factory _Po0FirewallProps.fromJson(Map<String, dynamic> json) => _$Po0FirewallPropsFromJson(json);

@override@JsonKey() final  bool enable;
 final  List<Po0TokenEntry> _tokenEntries;
@override@JsonKey() List<Po0TokenEntry> get tokenEntries {
  if (_tokenEntries is EqualUnmodifiableListView) return _tokenEntries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tokenEntries);
}

@override@JsonKey() final  int pollSeconds;
@override@JsonKey() final  bool ggyEnable;
 final  List<Po0TokenEntry> _ggyEntries;
@override@JsonKey() List<Po0TokenEntry> get ggyEntries {
  if (_ggyEntries is EqualUnmodifiableListView) return _ggyEntries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_ggyEntries);
}


/// Create a copy of Po0FirewallProps
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$Po0FirewallPropsCopyWith<_Po0FirewallProps> get copyWith => __$Po0FirewallPropsCopyWithImpl<_Po0FirewallProps>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$Po0FirewallPropsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Po0FirewallProps&&(identical(other.enable, enable) || other.enable == enable)&&const DeepCollectionEquality().equals(other.tokenEntries, _tokenEntries)&&(identical(other.pollSeconds, pollSeconds) || other.pollSeconds == pollSeconds)&&(identical(other.ggyEnable, ggyEnable) || other.ggyEnable == ggyEnable)&&const DeepCollectionEquality().equals(other.ggyEntries, _ggyEntries));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,enable,const DeepCollectionEquality().hash(_tokenEntries),pollSeconds,ggyEnable,const DeepCollectionEquality().hash(_ggyEntries));
}

@override
String toString() {
    return 'Po0FirewallProps(enable: $enable, tokenEntries: $tokenEntries, pollSeconds: $pollSeconds, ggyEnable: $ggyEnable, ggyEntries: $ggyEntries)';
}


}

/// @nodoc
abstract mixin class _$Po0FirewallPropsCopyWith<$Res> implements $Po0FirewallPropsCopyWith<$Res> {
  factory _$Po0FirewallPropsCopyWith(_Po0FirewallProps value, $Res Function(_Po0FirewallProps) _then) = __$Po0FirewallPropsCopyWithImpl;
@override @useResult
$Res call({
 bool enable, List<Po0TokenEntry> tokenEntries, int pollSeconds, bool ggyEnable, List<Po0TokenEntry> ggyEntries
});




}
/// @nodoc
class __$Po0FirewallPropsCopyWithImpl<$Res>
    implements _$Po0FirewallPropsCopyWith<$Res> {
  __$Po0FirewallPropsCopyWithImpl(this._self, this._then);

  final _Po0FirewallProps _self;
  final $Res Function(_Po0FirewallProps) _then;

/// Create a copy of Po0FirewallProps
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enable = null,Object? tokenEntries = null,Object? pollSeconds = null,Object? ggyEnable = null,Object? ggyEntries = null,}) {
  return _then(_Po0FirewallProps(
enable: null == enable ? _self.enable : enable // ignore: cast_nullable_to_non_nullable
as bool,tokenEntries: null == tokenEntries ? _self._tokenEntries : tokenEntries // ignore: cast_nullable_to_non_nullable
as List<Po0TokenEntry>,pollSeconds: null == pollSeconds ? _self.pollSeconds : pollSeconds // ignore: cast_nullable_to_non_nullable
as int,ggyEnable: null == ggyEnable ? _self.ggyEnable : ggyEnable // ignore: cast_nullable_to_non_nullable
as bool,ggyEntries: null == ggyEntries ? _self._ggyEntries : ggyEntries // ignore: cast_nullable_to_non_nullable
as List<Po0TokenEntry>,
  ));
}


}

/// @nodoc
mixin _$Po0WhitelistEntry {

 String get ip; int? get slot;
/// Create a copy of Po0WhitelistEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Po0WhitelistEntryCopyWith<Po0WhitelistEntry> get copyWith => _$Po0WhitelistEntryCopyWithImpl<Po0WhitelistEntry>(this as Po0WhitelistEntry, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Po0WhitelistEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Po0WhitelistEntry&&(identical(other.ip, _this.ip) || other.ip == _this.ip)&&(identical(other.slot, _this.slot) || other.slot == _this.slot));
}


@override
int get hashCode {
  final _this = this as Po0WhitelistEntry;
  return Object.hash(runtimeType,_this.ip,_this.slot);
}

@override
String toString() {
  final _this = this as Po0WhitelistEntry;
  return 'Po0WhitelistEntry(ip: ${_this.ip}, slot: ${_this.slot})';
}


}

/// @nodoc
abstract mixin class $Po0WhitelistEntryCopyWith<$Res>  {
  factory $Po0WhitelistEntryCopyWith(Po0WhitelistEntry value, $Res Function(Po0WhitelistEntry) _then) = _$Po0WhitelistEntryCopyWithImpl;
@useResult
$Res call({
 String ip, int? slot
});




}
/// @nodoc
class _$Po0WhitelistEntryCopyWithImpl<$Res>
    implements $Po0WhitelistEntryCopyWith<$Res> {
  _$Po0WhitelistEntryCopyWithImpl(this._self, this._then);

  final Po0WhitelistEntry _self;
  final $Res Function(Po0WhitelistEntry) _then;

/// Create a copy of Po0WhitelistEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ip = null,Object? slot = freezed,}) {
  return _then(Po0WhitelistEntry(
ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,slot: freezed == slot ? _self.slot : slot // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [Po0WhitelistEntry].
extension Po0WhitelistEntryPatterns on Po0WhitelistEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Po0WhitelistEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Po0WhitelistEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Po0WhitelistEntry value)  $default,){
final _that = this;
switch (_that) {
case _Po0WhitelistEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Po0WhitelistEntry value)?  $default,){
final _that = this;
switch (_that) {
case _Po0WhitelistEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ip,  int? slot)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Po0WhitelistEntry() when $default != null:
return $default(_that.ip,_that.slot);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ip,  int? slot)  $default,) {final _that = this;
switch (_that) {
case _Po0WhitelistEntry():
return $default(_that.ip,_that.slot);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ip,  int? slot)?  $default,) {final _that = this;
switch (_that) {
case _Po0WhitelistEntry() when $default != null:
return $default(_that.ip,_that.slot);case _:
  return null;

}
}

}

/// @nodoc


class _Po0WhitelistEntry implements Po0WhitelistEntry {
  const _Po0WhitelistEntry({required this.ip, this.slot});
  

@override final  String ip;
@override final  int? slot;

/// Create a copy of Po0WhitelistEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$Po0WhitelistEntryCopyWith<_Po0WhitelistEntry> get copyWith => __$Po0WhitelistEntryCopyWithImpl<_Po0WhitelistEntry>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Po0WhitelistEntry&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.slot, slot) || other.slot == slot));
}


@override
int get hashCode {
    return Object.hash(runtimeType,ip,slot);
}

@override
String toString() {
    return 'Po0WhitelistEntry(ip: $ip, slot: $slot)';
}


}

/// @nodoc
abstract mixin class _$Po0WhitelistEntryCopyWith<$Res> implements $Po0WhitelistEntryCopyWith<$Res> {
  factory _$Po0WhitelistEntryCopyWith(_Po0WhitelistEntry value, $Res Function(_Po0WhitelistEntry) _then) = __$Po0WhitelistEntryCopyWithImpl;
@override @useResult
$Res call({
 String ip, int? slot
});




}
/// @nodoc
class __$Po0WhitelistEntryCopyWithImpl<$Res>
    implements _$Po0WhitelistEntryCopyWith<$Res> {
  __$Po0WhitelistEntryCopyWithImpl(this._self, this._then);

  final _Po0WhitelistEntry _self;
  final $Res Function(_Po0WhitelistEntry) _then;

/// Create a copy of Po0WhitelistEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ip = null,Object? slot = freezed,}) {
  return _then(_Po0WhitelistEntry(
ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,slot: freezed == slot ? _self.slot : slot // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$Po0TokenResult {

 String get label; String? get name; Po0ResultType get type; String? get currentIp; List<Po0WhitelistEntry> get whitelist; int? get limit; String? get message;
/// Create a copy of Po0TokenResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Po0TokenResultCopyWith<Po0TokenResult> get copyWith => _$Po0TokenResultCopyWithImpl<Po0TokenResult>(this as Po0TokenResult, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Po0TokenResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Po0TokenResult&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.currentIp, _this.currentIp) || other.currentIp == _this.currentIp)&&const DeepCollectionEquality().equals(other.whitelist, _this.whitelist)&&(identical(other.limit, _this.limit) || other.limit == _this.limit)&&(identical(other.message, _this.message) || other.message == _this.message));
}


@override
int get hashCode {
  final _this = this as Po0TokenResult;
  return Object.hash(runtimeType,_this.label,_this.name,_this.type,_this.currentIp,const DeepCollectionEquality().hash(_this.whitelist),_this.limit,_this.message);
}

@override
String toString() {
  final _this = this as Po0TokenResult;
  return 'Po0TokenResult(label: ${_this.label}, name: ${_this.name}, type: ${_this.type}, currentIp: ${_this.currentIp}, whitelist: ${_this.whitelist}, limit: ${_this.limit}, message: ${_this.message})';
}


}

/// @nodoc
abstract mixin class $Po0TokenResultCopyWith<$Res>  {
  factory $Po0TokenResultCopyWith(Po0TokenResult value, $Res Function(Po0TokenResult) _then) = _$Po0TokenResultCopyWithImpl;
@useResult
$Res call({
 String label, String? name, Po0ResultType type, String? currentIp, List<Po0WhitelistEntry> whitelist, int? limit, String? message
});




}
/// @nodoc
class _$Po0TokenResultCopyWithImpl<$Res>
    implements $Po0TokenResultCopyWith<$Res> {
  _$Po0TokenResultCopyWithImpl(this._self, this._then);

  final Po0TokenResult _self;
  final $Res Function(Po0TokenResult) _then;

/// Create a copy of Po0TokenResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? label = null,Object? name = freezed,Object? type = null,Object? currentIp = freezed,Object? whitelist = null,Object? limit = freezed,Object? message = freezed,}) {
  return _then(Po0TokenResult(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as Po0ResultType,currentIp: freezed == currentIp ? _self.currentIp : currentIp // ignore: cast_nullable_to_non_nullable
as String?,whitelist: null == whitelist ? _self.whitelist : whitelist // ignore: cast_nullable_to_non_nullable
as List<Po0WhitelistEntry>,limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Po0TokenResult].
extension Po0TokenResultPatterns on Po0TokenResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Po0TokenResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Po0TokenResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Po0TokenResult value)  $default,){
final _that = this;
switch (_that) {
case _Po0TokenResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Po0TokenResult value)?  $default,){
final _that = this;
switch (_that) {
case _Po0TokenResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String label,  String? name,  Po0ResultType type,  String? currentIp,  List<Po0WhitelistEntry> whitelist,  int? limit,  String? message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Po0TokenResult() when $default != null:
return $default(_that.label,_that.name,_that.type,_that.currentIp,_that.whitelist,_that.limit,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String label,  String? name,  Po0ResultType type,  String? currentIp,  List<Po0WhitelistEntry> whitelist,  int? limit,  String? message)  $default,) {final _that = this;
switch (_that) {
case _Po0TokenResult():
return $default(_that.label,_that.name,_that.type,_that.currentIp,_that.whitelist,_that.limit,_that.message);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String label,  String? name,  Po0ResultType type,  String? currentIp,  List<Po0WhitelistEntry> whitelist,  int? limit,  String? message)?  $default,) {final _that = this;
switch (_that) {
case _Po0TokenResult() when $default != null:
return $default(_that.label,_that.name,_that.type,_that.currentIp,_that.whitelist,_that.limit,_that.message);case _:
  return null;

}
}

}

/// @nodoc


class _Po0TokenResult implements Po0TokenResult {
  const _Po0TokenResult({required this.label, this.name, required this.type, this.currentIp,  List<Po0WhitelistEntry> whitelist = const [], this.limit, this.message}): _whitelist = whitelist;
  

@override final  String label;
@override final  String? name;
@override final  Po0ResultType type;
@override final  String? currentIp;
 final  List<Po0WhitelistEntry> _whitelist;
@override@JsonKey() List<Po0WhitelistEntry> get whitelist {
  if (_whitelist is EqualUnmodifiableListView) return _whitelist;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_whitelist);
}

@override final  int? limit;
@override final  String? message;

/// Create a copy of Po0TokenResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$Po0TokenResultCopyWith<_Po0TokenResult> get copyWith => __$Po0TokenResultCopyWithImpl<_Po0TokenResult>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Po0TokenResult&&(identical(other.label, label) || other.label == label)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.currentIp, currentIp) || other.currentIp == currentIp)&&const DeepCollectionEquality().equals(other.whitelist, _whitelist)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,label,name,type,currentIp,const DeepCollectionEquality().hash(_whitelist),limit,message);
}

@override
String toString() {
    return 'Po0TokenResult(label: $label, name: $name, type: $type, currentIp: $currentIp, whitelist: $whitelist, limit: $limit, message: $message)';
}


}

/// @nodoc
abstract mixin class _$Po0TokenResultCopyWith<$Res> implements $Po0TokenResultCopyWith<$Res> {
  factory _$Po0TokenResultCopyWith(_Po0TokenResult value, $Res Function(_Po0TokenResult) _then) = __$Po0TokenResultCopyWithImpl;
@override @useResult
$Res call({
 String label, String? name, Po0ResultType type, String? currentIp, List<Po0WhitelistEntry> whitelist, int? limit, String? message
});




}
/// @nodoc
class __$Po0TokenResultCopyWithImpl<$Res>
    implements _$Po0TokenResultCopyWith<$Res> {
  __$Po0TokenResultCopyWithImpl(this._self, this._then);

  final _Po0TokenResult _self;
  final $Res Function(_Po0TokenResult) _then;

/// Create a copy of Po0TokenResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? label = null,Object? name = freezed,Object? type = null,Object? currentIp = freezed,Object? whitelist = null,Object? limit = freezed,Object? message = freezed,}) {
  return _then(_Po0TokenResult(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as Po0ResultType,currentIp: freezed == currentIp ? _self.currentIp : currentIp // ignore: cast_nullable_to_non_nullable
as String?,whitelist: null == whitelist ? _self._whitelist : whitelist // ignore: cast_nullable_to_non_nullable
as List<Po0WhitelistEntry>,limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$Po0FirewallState {

 bool get isRunning; DateTime? get lastRunAt; Po0RunKind get lastRunKind; List<Po0TokenResult> get results;
/// Create a copy of Po0FirewallState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Po0FirewallStateCopyWith<Po0FirewallState> get copyWith => _$Po0FirewallStateCopyWithImpl<Po0FirewallState>(this as Po0FirewallState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Po0FirewallState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Po0FirewallState&&(identical(other.isRunning, _this.isRunning) || other.isRunning == _this.isRunning)&&(identical(other.lastRunAt, _this.lastRunAt) || other.lastRunAt == _this.lastRunAt)&&(identical(other.lastRunKind, _this.lastRunKind) || other.lastRunKind == _this.lastRunKind)&&const DeepCollectionEquality().equals(other.results, _this.results));
}


@override
int get hashCode {
  final _this = this as Po0FirewallState;
  return Object.hash(runtimeType,_this.isRunning,_this.lastRunAt,_this.lastRunKind,const DeepCollectionEquality().hash(_this.results));
}

@override
String toString() {
  final _this = this as Po0FirewallState;
  return 'Po0FirewallState(isRunning: ${_this.isRunning}, lastRunAt: ${_this.lastRunAt}, lastRunKind: ${_this.lastRunKind}, results: ${_this.results})';
}


}

/// @nodoc
abstract mixin class $Po0FirewallStateCopyWith<$Res>  {
  factory $Po0FirewallStateCopyWith(Po0FirewallState value, $Res Function(Po0FirewallState) _then) = _$Po0FirewallStateCopyWithImpl;
@useResult
$Res call({
 bool isRunning, DateTime? lastRunAt, Po0RunKind lastRunKind, List<Po0TokenResult> results
});




}
/// @nodoc
class _$Po0FirewallStateCopyWithImpl<$Res>
    implements $Po0FirewallStateCopyWith<$Res> {
  _$Po0FirewallStateCopyWithImpl(this._self, this._then);

  final Po0FirewallState _self;
  final $Res Function(Po0FirewallState) _then;

/// Create a copy of Po0FirewallState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isRunning = null,Object? lastRunAt = freezed,Object? lastRunKind = null,Object? results = null,}) {
  return _then(Po0FirewallState(
isRunning: null == isRunning ? _self.isRunning : isRunning // ignore: cast_nullable_to_non_nullable
as bool,lastRunAt: freezed == lastRunAt ? _self.lastRunAt : lastRunAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastRunKind: null == lastRunKind ? _self.lastRunKind : lastRunKind // ignore: cast_nullable_to_non_nullable
as Po0RunKind,results: null == results ? _self.results : results // ignore: cast_nullable_to_non_nullable
as List<Po0TokenResult>,
  ));
}

}


/// Adds pattern-matching-related methods to [Po0FirewallState].
extension Po0FirewallStatePatterns on Po0FirewallState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Po0FirewallState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Po0FirewallState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Po0FirewallState value)  $default,){
final _that = this;
switch (_that) {
case _Po0FirewallState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Po0FirewallState value)?  $default,){
final _that = this;
switch (_that) {
case _Po0FirewallState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isRunning,  DateTime? lastRunAt,  Po0RunKind lastRunKind,  List<Po0TokenResult> results)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Po0FirewallState() when $default != null:
return $default(_that.isRunning,_that.lastRunAt,_that.lastRunKind,_that.results);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isRunning,  DateTime? lastRunAt,  Po0RunKind lastRunKind,  List<Po0TokenResult> results)  $default,) {final _that = this;
switch (_that) {
case _Po0FirewallState():
return $default(_that.isRunning,_that.lastRunAt,_that.lastRunKind,_that.results);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isRunning,  DateTime? lastRunAt,  Po0RunKind lastRunKind,  List<Po0TokenResult> results)?  $default,) {final _that = this;
switch (_that) {
case _Po0FirewallState() when $default != null:
return $default(_that.isRunning,_that.lastRunAt,_that.lastRunKind,_that.results);case _:
  return null;

}
}

}

/// @nodoc


class _Po0FirewallState implements Po0FirewallState {
  const _Po0FirewallState({this.isRunning = false, this.lastRunAt, this.lastRunKind = Po0RunKind.poll,  List<Po0TokenResult> results = const []}): _results = results;
  

@override@JsonKey() final  bool isRunning;
@override final  DateTime? lastRunAt;
@override@JsonKey() final  Po0RunKind lastRunKind;
 final  List<Po0TokenResult> _results;
@override@JsonKey() List<Po0TokenResult> get results {
  if (_results is EqualUnmodifiableListView) return _results;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_results);
}


/// Create a copy of Po0FirewallState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$Po0FirewallStateCopyWith<_Po0FirewallState> get copyWith => __$Po0FirewallStateCopyWithImpl<_Po0FirewallState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Po0FirewallState&&(identical(other.isRunning, isRunning) || other.isRunning == isRunning)&&(identical(other.lastRunAt, lastRunAt) || other.lastRunAt == lastRunAt)&&(identical(other.lastRunKind, lastRunKind) || other.lastRunKind == lastRunKind)&&const DeepCollectionEquality().equals(other.results, _results));
}


@override
int get hashCode {
    return Object.hash(runtimeType,isRunning,lastRunAt,lastRunKind,const DeepCollectionEquality().hash(_results));
}

@override
String toString() {
    return 'Po0FirewallState(isRunning: $isRunning, lastRunAt: $lastRunAt, lastRunKind: $lastRunKind, results: $results)';
}


}

/// @nodoc
abstract mixin class _$Po0FirewallStateCopyWith<$Res> implements $Po0FirewallStateCopyWith<$Res> {
  factory _$Po0FirewallStateCopyWith(_Po0FirewallState value, $Res Function(_Po0FirewallState) _then) = __$Po0FirewallStateCopyWithImpl;
@override @useResult
$Res call({
 bool isRunning, DateTime? lastRunAt, Po0RunKind lastRunKind, List<Po0TokenResult> results
});




}
/// @nodoc
class __$Po0FirewallStateCopyWithImpl<$Res>
    implements _$Po0FirewallStateCopyWith<$Res> {
  __$Po0FirewallStateCopyWithImpl(this._self, this._then);

  final _Po0FirewallState _self;
  final $Res Function(_Po0FirewallState) _then;

/// Create a copy of Po0FirewallState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isRunning = null,Object? lastRunAt = freezed,Object? lastRunKind = null,Object? results = null,}) {
  return _then(_Po0FirewallState(
isRunning: null == isRunning ? _self.isRunning : isRunning // ignore: cast_nullable_to_non_nullable
as bool,lastRunAt: freezed == lastRunAt ? _self.lastRunAt : lastRunAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastRunKind: null == lastRunKind ? _self.lastRunKind : lastRunKind // ignore: cast_nullable_to_non_nullable
as Po0RunKind,results: null == results ? _self._results : results // ignore: cast_nullable_to_non_nullable
as List<Po0TokenResult>,
  ));
}


}

// dart format on
