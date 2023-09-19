// TODO : handle map and mixed (List and map) cases.
// TODO : add compilation to check channel function and speed-up.
// TODO : add ability to disable the configuration system and just send object directly(in case same-code isolate).


part of 'easy_serialization_base.dart';


const _propConfigIdMarkupPropName = "\$config#id";
const _propObjPropName = "\$obj"; // single piece of data
const _propDataMarkupPropName = "\$data"; // all data
const _propActualListMarkupName = "\$actual#list";
const _propListTypeDataPropName = "\$list#type#data";

/// Property that uses [SerializationConfig]s to serialize data.
/// 
/// * You can use it inside [toMarkupObj] of [SerializationMixin].
/// 
/// * Currently we do NOT support [Map], [Set] or any other **special** generic type.
class Prop<T extends Object?>{
  final String? debugName;
  bool _haveFallbackValue = false;
  T? _fallbackValue;
  late T data;
  final T? _emptyList;

  Prop.all({
    this.debugName,
    T? emptyList,
    EnumSerializationConfig? enumConfig,
  }) : _emptyList = emptyList{
    _ensureRegisteringPrimitives();

    if(enumConfig != null){
      Prop.registerSerializationConfigs([enumConfig]);
    }
  }

  static V valueFromMarkup<V extends Object?>(MarkupObj markup, {
    String? debugName,
    V? emptyList,
    EnumSerializationConfig? enumConfig,
  }) => 
    Prop<V>.all(
      debugName: debugName,
      emptyList: emptyList,
      enumConfig: enumConfig,
    ).fromMarkup(markup);

  static MarkupObj valueToMarkup<V extends Object?>(V value, {
    String? debugName,
    V? emptyList,
    EnumSerializationConfig? enumConfig,
  }) => (Prop<V>.all(
      debugName: debugName,
      emptyList: emptyList,
      enumConfig: enumConfig,
    )..data = value).toMarkup();

  /// The [data] will be late initialized at first.
  ///
  /// * Use [Prop.enumerated] in case [data] is of type -unregistered- [enum].
  ///
  /// * You must provide a empty list instance in case [data] is of type [List] use [Prop.list] or [Prop.listWithEnumerated].
  ///
  /// * Use [setFallbackValue] method to provide fallback value just-in-case some error occurs.
  factory Prop([String? debugName]) => Prop.all(
    debugName: debugName,
  );

  /// use [setFallbackValue] method to provide fallback value just-in-case some error occurs.
  factory Prop.enumerated(EnumSerializationConfig enumConfig, [String? debugName])=> Prop.all(
    debugName: debugName,
    enumConfig: enumConfig,
  );

  /// use [setFallbackValue] method to provide fallback value just-in-case some error occurs.
  factory Prop.list(T empty, [String? debugName]){
    assert(isSubtype<T, List?>());
    assert(empty != null);
    assert((empty as List).isEmpty);

    return Prop.all(
      debugName: debugName,
      emptyList: empty,
    );
  }

  /// use [setFallbackValue] method to provide fallback value just-in-case some error occurs.
  factory Prop.listWithEnumerated(T empty, EnumSerializationConfig enumConfig, [String? debugName]){
    assert(isSubtype<T, List?>());
    assert(empty != null);
    assert((empty as List).isEmpty);

    return Prop.all(
      debugName: debugName,
      enumConfig: enumConfig,
      emptyList: empty,
    );
  }

  void setFallbackValue(T value){
    _haveFallbackValue = true;
    _fallbackValue = value;
  }

  void resetFallbackValue(){
    _haveFallbackValue = false;
    _fallbackValue = null;
  }


  /// returns [AnyObj] because it can be a [List].
  AnyObj _parseObj(Object? obj, [_TypeNode? recTypeData]) {
    if(obj is List){
      final listData = _ListTypeNode();
      final list = obj.map((e) => _parseObj(e, listData)).toList();
      recTypeData?.node = listData;
      return {
        _propListTypeDataPropName : listData.toMarkupObj(),
        _propActualListMarkupName : list,
      };
    }

    final listTypeData = recTypeData as _ListTypeNode?;
    if(obj == null){
      listTypeData?.haveNull = true;
      return {
        _propObjPropName : null,
        _propConfigIdMarkupPropName : _nullConfigId.toMarkupObj(),
      };
    }

    if(obj is Enum){
      final specificEnumConfig = SerializationConfig._getMostSpecificConfig(obj);
      if(specificEnumConfig is EnumSerializationConfig){
        listTypeData?.config = specificEnumConfig;
        return {
          _propObjPropName : specificEnumConfig._toMarkupObj(obj),
          _propConfigIdMarkupPropName : specificEnumConfig.typeID.toMarkupObj(),
        };
      }
    }

    final specificConfig = SerializationConfig._getMostSpecificConfig(obj);
    listTypeData?.config = specificConfig;
    return {
      _propObjPropName : specificConfig._toMarkupObj(obj),
      _propConfigIdMarkupPropName : specificConfig.typeID.toMarkupObj(),
    };
  }

  AnyObj _unParseObj(AnyObj dataMarkup,){
    final listMarkup = dataMarkup[_propActualListMarkupName];
    if(listMarkup != null){
      late final List outList;
      final list = listMarkup as List;
      final listData = _ListTypeNode._fromMarkup(dataMarkup[_propListTypeDataPropName]);
      listData._internalTypeProv.provType(<LIST_TYPE>(){
        outList = list.map<LIST_TYPE>((e) => _unParseObj(e),).toList();
      });

      return outList;
    }

    final obj = dataMarkup[_propObjPropName] as MarkupObj?;
    final configId = TypeID.fromMarkup(dataMarkup[_propConfigIdMarkupPropName]);
    if(obj == null || configId == _nullConfigId){
      return null;
    }

    return _serializationNodes[configId]!.config._fromMarkupObj(obj);
  }

  MarkupObj _valueToMarkup(T value){
    final outValue = value is List ? value.withoutEmpties() : value;
    return {
      _propDataMarkupPropName : _parseObj(outValue),
    };
  }

  MarkupObj toMarkup() => _valueToMarkup(data);

  /// also sets [data].
  T fromMarkup(MarkupObj markup){
    final dataMarkup = markup[_propDataMarkupPropName] as AnyObj;

    AnyObj serializedValue = _unParseObj(dataMarkup);
    if(serializedValue is List && serializedValue.isEmpty){
      if(_emptyList != null){
        serializedValue = _emptyList;
      }else{
        throw const SerializationError("Please use provide empty list instance to serialize List data.");
      }
    }

    if(serializedValue is T){
      return data = serializedValue;
    }else{
      if(_haveFallbackValue){
        return data = _fallbackValue as T;
      }else{
        throw const SerializationError("Cannot decode this markup and there is NO fallback value provided.");
      }
    }
  }

  static void _ensureRegisteringPrimitives(){
    if(_primitivesAdded) {return;}

    _registerSerializationConfigs(_primitivesSerializableObjects);

    _primitivesAdded = true;
  }

  static void registerSerializationConfigs(List<SerializationConfig> configs){
    _ensureRegisteringPrimitives();
    _registerSerializationConfigs(configs);
  }

  static void _registerSerializationConfigs(List<SerializationConfig> configs){
    for(final config in configs){
      if(_serializationNodes.values.any((node) => node.config.equalInType(config))){continue;}

      final createdNode = _SerializationNode(config);
      final createdNodeParent = _SerializationNode.getParentNode(createdNode);

      final parentChildren = [...createdNodeParent.children];
      for(final parentChildNode in parentChildren){
        if(createdNode.isParentTo(parentChildNode)){
          parentChildNode.parent = createdNode;
          createdNode.children.add(parentChildNode);
          createdNodeParent.children.remove(parentChildNode);
        }
      }
      createdNode.parent = createdNodeParent;
      createdNodeParent.children.add(createdNode);

      _serializationNodes.addAll({config.typeID : createdNode,});
    }
  }
}
