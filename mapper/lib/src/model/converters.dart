import 'dart:convert' show base64Decode, base64Encode;
import 'dart:convert' show JsonDecoder;
import 'dart:typed_data' show Uint8List;

import 'package:intl/intl.dart';

import 'annotations.dart';
import 'index.dart';

typedef SerializeObjectFunction = dynamic Function(Object object);
typedef DeserializeObjectFunction = dynamic Function(Object object, Type type);
typedef GetConverterFunction = ICustomConverter Function(
    JsonProperty jsonProperty, Type declarationType);
typedef GetConvertedValueFunction = dynamic Function(ICustomConverter converter,
    ConversionDirection direction, dynamic value, JsonProperty jsonProperty);

/// Abstract class for custom converters implementations
abstract class ICustomConverter<T> {
  dynamic toJSON(T object, [JsonProperty jsonProperty]);
  T fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]);
}

/// Abstract class for custom iterable converters implementations
abstract class ICustomIterableConverter {
  void setIterableInstance(Iterable instance);
}

/// Abstract class for custom map converters implementations
abstract class ICustomMapConverter {
  void setMapInstance(Map instance);
}

/// Abstract class for custom Enum converters implementations
abstract class ICustomEnumConverter {
  void setEnumValues(Iterable enumValues);
}

/// Abstract class for custom converters interested in TypeInfo
abstract class ITypeInfoConsumerConverter {
  void setTypeInfo(TypeInfo typeInfo);
}

/// Abstract class for composite converters relying on other converters
abstract class ICompositeConverter {
  void setGetConverterFunction(GetConverterFunction getConverter);
  void setGetConvertedValueFunction(
      GetConvertedValueFunction getConvertedValue);
}

/// Abstract class for custom recursive converters implementations
abstract class IRecursiveConverter {
  void setSerializeObjectFunction(SerializeObjectFunction serializeObject);
  void setDeserializeObjectFunction(
      DeserializeObjectFunction deserializeObject);
}

/// Base class for custom type converter having access to parameters provided
/// by the [JsonProperty] meta
class BaseCustomConverter {
  const BaseCustomConverter() : super();
  dynamic getConverterParameter(String name, [JsonProperty jsonProperty]) {
    return jsonProperty != null && jsonProperty.converterParams != null
        ? jsonProperty.converterParams[name]
        : null;
  }
}

const dateConverter = DateConverter();

/// Default converter for [DateTime] type
class DateConverter extends BaseCustomConverter implements ICustomConverter {
  const DateConverter() : super();

  @override
  Object fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    final format = getDateFormat(jsonProperty);

    if (jsonValue is String) {
      return format != null
          ? format.parse(jsonValue)
          : DateTime.parse(jsonValue);
    }

    return jsonValue;
  }

  @override
  dynamic toJSON(Object object, [JsonProperty jsonProperty]) {
    final format = getDateFormat(jsonProperty);
    return format != null && object != null && !(object is String)
        ? format.format(object)
        : (object is List)
            ? object.map((item) => item.toString()).toList()
            : object != null
                ? object.toString()
                : null;
  }

  DateFormat getDateFormat([JsonProperty jsonProperty]) {
    String format = getConverterParameter('format', jsonProperty);
    return format != null ? DateFormat(format) : null;
  }
}

const numberConverter = NumberConverter();

/// Default converter for [num] type
class NumberConverter extends BaseCustomConverter implements ICustomConverter {
  const NumberConverter() : super();

  @override
  Object fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    final format = getNumberFormat(jsonProperty);
    return format != null && (jsonValue is String)
        ? getNumberFormat(jsonProperty).parse(jsonValue)
        : (jsonValue is String)
            ? num.tryParse(jsonValue) ?? jsonValue
            : jsonValue;
  }

  @override
  dynamic toJSON(Object object, [JsonProperty jsonProperty]) {
    final format = getNumberFormat(jsonProperty);
    return object != null && format != null
        ? getNumberFormat(jsonProperty).format(object)
        : (object is String)
            ? num.tryParse(object)
            : object;
  }

  NumberFormat getNumberFormat([JsonProperty jsonProperty]) {
    String format = getConverterParameter('format', jsonProperty);
    return format != null ? NumberFormat(format) : null;
  }
}

final defaultEnumConverter = enumConverterShort;

final enumConverter = EnumConverter();

/// Long converter for [enum] type
class EnumConverter implements ICustomConverter, ICustomEnumConverter {
  EnumConverter() : super();

  Iterable _enumValues = [];

  @override
  Object fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    dynamic convert(value) => _enumValues.firstWhere(
        (eValue) => eValue.toString() == value.toString(),
        orElse: () => null);
    return jsonValue is Iterable
        ? jsonValue.map(convert).toList()
        : convert(jsonValue);
  }

  @override
  dynamic toJSON(Object object, [JsonProperty jsonProperty]) {
    dynamic convert(value) => value.toString();
    return (object is Iterable)
        ? object.map(convert).toList()
        : convert(object);
  }

  @override
  void setEnumValues(Iterable enumValues) {
    _enumValues = enumValues;
  }
}

final enumConverterShort = EnumConverterShort();

/// Default converter for [enum] type
class EnumConverterShort implements ICustomConverter, ICustomEnumConverter {
  EnumConverterShort() : super();

  Iterable _enumValues = [];

  @override
  Object fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    dynamic convert(value) => _enumValues.firstWhere(
        (eValue) =>
            eValue.toString().split('.').last ==
            value.toString().split('.').last,
        orElse: () => null);
    return jsonValue is Iterable
        ? jsonValue.map(convert).toList()
        : convert(jsonValue);
  }

  @override
  dynamic toJSON(Object object, [JsonProperty jsonProperty]) {
    dynamic convert(value) => value.toString().split('.').last;
    return (object is Iterable)
        ? object.map(convert).toList()
        : convert(object);
  }

  @override
  void setEnumValues(Iterable<dynamic> enumValues) {
    _enumValues = enumValues;
  }
}

const enumConverterNumeric = ConstEnumConverterNumeric();

/// Const wrapper for [EnumConverterNumeric]
class ConstEnumConverterNumeric
    implements ICustomConverter, ICustomEnumConverter {
  const ConstEnumConverterNumeric();

  @override
  Object fromJSON(jsonValue, [JsonProperty jsonProperty]) =>
      _enumConverterNumeric.fromJSON(jsonValue, jsonProperty);

  @override
  dynamic toJSON(object, [JsonProperty jsonProperty]) =>
      _enumConverterNumeric.toJSON(object, jsonProperty);

  @override
  void setEnumValues(Iterable<dynamic> enumValues) {
    _enumConverterNumeric.setEnumValues(enumValues);
  }
}

final _enumConverterNumeric = EnumConverterNumeric();

/// Numeric index based converter for [enum] type
class EnumConverterNumeric implements ICustomConverter, ICustomEnumConverter {
  EnumConverterNumeric() : super();

  var _enumValues = [];

  @override
  Object fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    return jsonValue is int ? _enumValues[jsonValue] : jsonValue;
  }

  @override
  dynamic toJSON(Object object, [JsonProperty jsonProperty]) {
    return _enumValues.indexOf(object);
  }

  @override
  void setEnumValues(Iterable<dynamic> enumValues) {
    _enumValues = enumValues;
  }
}

const symbolConverter = SymbolConverter();

/// Default converter for [Symbol] type
class SymbolConverter implements ICustomConverter {
  const SymbolConverter() : super();

  @override
  Object fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    return jsonValue is String ? Symbol(jsonValue) : jsonValue;
  }

  @override
  dynamic toJSON(Object object, [JsonProperty jsonProperty]) {
    return object != null
        ? RegExp('"(.+)"').allMatches(object.toString()).first.group(1)
        : null;
  }
}

const durationConverter = DurationConverter();

/// DurationConverter converter for [Duration] type
class DurationConverter implements ICustomConverter<Duration> {
  const DurationConverter() : super();

  @override
  Duration fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    return jsonValue is num ? Duration(microseconds: jsonValue) : jsonValue;
  }

  @override
  dynamic toJSON(Duration object, [JsonProperty jsonProperty]) {
    return object != null ? object.inMicroseconds : null;
  }
}

const uint8ListConverter = Uint8ListConverter();

/// [Uint8List] converter to base64 and back
class Uint8ListConverter implements ICustomConverter {
  const Uint8ListConverter() : super();

  @override
  Object fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    return jsonValue is String ? base64Decode(jsonValue) : jsonValue;
  }

  @override
  dynamic toJSON(Object object, [JsonProperty jsonProperty]) {
    return object is Uint8List ? base64Encode(object) : object;
  }
}

const bigIntConverter = BigIntConverter();

/// [BigInt] converter
class BigIntConverter implements ICustomConverter {
  const BigIntConverter() : super();

  @override
  Object fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    return jsonValue is String ? BigInt.tryParse(jsonValue) : jsonValue;
  }

  @override
  dynamic toJSON(Object object, [JsonProperty jsonProperty]) {
    return object is BigInt ? object.toString() : object;
  }
}

final mapConverter = MapConverter();

/// [Map<K, V>] converter
class MapConverter
    implements
        ICustomConverter<Map>,
        IRecursiveConverter,
        ICustomMapConverter,
        ITypeInfoConsumerConverter {
  MapConverter() : super();

  SerializeObjectFunction _serializeObject;
  DeserializeObjectFunction _deserializeObject;
  TypeInfo _typeInfo;
  Map _instance;
  final _jsonDecoder = JsonDecoder();

  @override
  Map fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    var result = jsonValue;
    if (jsonValue is String) {
      result = _jsonDecoder.convert(jsonValue);
    }
    if (_typeInfo != null && result is Map) {
      if (_instance != null && _instance is Map || _instance == null) {
        result = result.map((key, value) => MapEntry(
            _deserializeObject(key, _typeInfo.parameters.first),
            _deserializeObject(value, _typeInfo.parameters.last)));
      }
      if (_instance != null && _instance is Map) {
        result.forEach((key, value) => _instance[key] = value);
        result = _instance;
      }
    }
    return result;
  }

  @override
  dynamic toJSON(Map object, [JsonProperty jsonProperty]) =>
      object.map((key, value) =>
          MapEntry(_serializeObject(key).toString(), _serializeObject(value)));

  @override
  void setSerializeObjectFunction(SerializeObjectFunction serializeObject) {
    _serializeObject = serializeObject;
  }

  @override
  void setDeserializeObjectFunction(
      DeserializeObjectFunction deserializeObject) {
    _deserializeObject = deserializeObject;
  }

  @override
  void setMapInstance(Map instance) {
    _instance = instance;
  }

  @override
  void setTypeInfo(TypeInfo typeInfo) {
    _typeInfo = typeInfo;
  }
}

final defaultIterableConverter = DefaultIterableConverter();

/// Default Iterable converter
class DefaultIterableConverter
    implements
        ICustomConverter,
        ICustomIterableConverter,
        ICompositeConverter,
        ITypeInfoConsumerConverter {
  DefaultIterableConverter() : super();

  Iterable _instance;
  GetConverterFunction _getConverter;
  GetConvertedValueFunction _getConvertedValue;
  TypeInfo _typeInfo;

  @override
  dynamic fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    dynamic convert(item) => _getConvertedValue(
        _getConverter(jsonProperty, _typeInfo.scalarType),
        ConversionDirection.fromJson,
        item,
        jsonProperty);

    if (_instance != null && jsonValue is Iterable && jsonValue != _instance) {
      if (_instance is List) {
        (_instance as List).clear();
        jsonValue.forEach((item) => (_instance as List).add(convert(item)));
      }
      if (_instance is Set) {
        (_instance as Set).clear();
        jsonValue.forEach((item) => (_instance as Set).add(convert(item)));
      }
      return _instance;
    }
    return jsonValue;
  }

  @override
  dynamic toJSON(dynamic object, [JsonProperty jsonProperty]) {
    return object;
  }

  @override
  void setIterableInstance(Iterable instance) {
    _instance = instance;
  }

  @override
  void setGetConverterFunction(GetConverterFunction getConverter) {
    _getConverter = getConverter;
  }

  @override
  void setGetConvertedValueFunction(
      GetConvertedValueFunction getConvertedValue) {
    _getConvertedValue = getConvertedValue;
  }

  @override
  void setTypeInfo(TypeInfo typeInfo) {
    _typeInfo = typeInfo;
  }
}

const uriConverter = UriConverter();

/// Uri converter
class UriConverter implements ICustomConverter<Uri> {
  const UriConverter() : super();

  @override
  Uri fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) =>
      jsonValue is String ? Uri.tryParse(jsonValue) : jsonValue;

  @override
  String toJSON(Uri object, [JsonProperty jsonProperty]) => object.toString();
}

const regExpConverter = RegExpConverter();

/// RegExp converter
class RegExpConverter implements ICustomConverter<RegExp> {
  const RegExpConverter() : super();

  @override
  RegExp fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) =>
      jsonValue is String ? RegExp(jsonValue) : jsonValue;

  @override
  dynamic toJSON(RegExp object, [JsonProperty jsonProperty]) => object.pattern;
}

const defaultConverter = DefaultConverter();

/// Default converter for all types
class DefaultConverter implements ICustomConverter {
  const DefaultConverter() : super();

  @override
  Object fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) => jsonValue;

  @override
  dynamic toJSON(Object object, [JsonProperty jsonProperty]) => object;
}
