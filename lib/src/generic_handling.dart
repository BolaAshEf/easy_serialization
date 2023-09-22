part of 'easy_serialization_base.dart';

enum _TypeClass { list }

const _propTypeClassIMarkupName = "\$type#class#i";
const _propHaveNullMarkupName = "\$have#null";
const _propNodeConfigIDMarkupName = "\$node#config#id";
const _propNodeMarkupPropName = "\$child#node";

sealed class _TypeNode with SerializableMixin {
  abstract final TypeProvider _typeProv;
  bool haveNull = false;

  _TypeNode? _node;
  _TypeNode? get node => _node;
  set node(_TypeNode? n) {
    if (n == null) {
      return;
    }

    if (_node == null) {
      _node = n;
      return;
    }

    // replace if it is a super type.
    final canReplace = n._typeProv.provType(
      <N>() => _typeProv.provType(
        <O>() => isSubtype<O, N>(),
      ),
    );
    if (canReplace) {
      _node = n;
      return;
    } else {
      final isChild = n._typeProv.provType(
        <N>() => _typeProv.provType(
          <O>() => isSubtype<N, O>(),
        ),
      );
      if (!isChild) {
        final copy = _node!.copy();

        final depthResult = depthComparison(copy, n);
        if (!depthResult.same) {
          copy.haveNull = copy.haveNull || n.haveNull;
          copy._config = SerializationConfig._objectConfig;
        } else {
          final myLeafNode = depthResult.o1!;
          final newLeafNode = depthResult.o2!;
          if (myLeafNode.config == null || newLeafNode.config == null) {
            // null here means that it only have nulls.
            myLeafNode.haveNull = true;
            myLeafNode.config ??= newLeafNode.config;
          } else {
            myLeafNode.haveNull = myLeafNode.haveNull || newLeafNode.haveNull;
            myLeafNode.config = newLeafNode.config;
          }
        }

        _node = copy;
      }
    }
  }

  SerializationConfig? _config;
  SerializationConfig? get config => _config;
  set config(SerializationConfig? config) {
    if (config == null) {
      return;
    }

    if (_config == null) {
      _config = config;
      return;
    }

    if (config.isParentTo(_config!)) {
      _config = config;
      return;
    } else {
      if (!config.isChildTo(_config!)) {
        // this means that the types are in different leafs.
        _SerializationNode? currentNode = _serializationNodes[_config!.typeID]!;
        _SerializationNode? parentNode = _serializationNodes[config.typeID]!;
        while (!(parentNode?.isParentTo(currentNode) ?? true)) {
          parentNode = parentNode?.parent;
        }

        _config = parentNode?.config;
        return;
      }
    }
  }

  _TypeNode();

  _TypeNode copy();

  @override
  MarkupObj toMarkupObj() => {
        _propTypeClassIMarkupName: switch (this) {
          _ListTypeNode() => _TypeClass.list.index,
        },
        _propHaveNullMarkupName: haveNull,
        _propNodeConfigIDMarkupName: _config?.typeID.toMarkupObj(),
        _propNodeMarkupPropName: _node?.toMarkupObj(),
      };

  _TypeNode._fromMarkup(MarkupObj markup)
      : haveNull = markup[_propHaveNullMarkupName],
        _node = _TypeNode.fromMarkupByType(markup[_propNodeMarkupPropName]) {
    final configID = markup[_propNodeConfigIDMarkupName];
    if (configID != null) {
      _config = _serializationNodes[TypeID.fromMarkup(configID)]?.config;
    }
  }

  static _TypeNode? fromMarkupByType(dynamic markup) {
    if (markup == null) {
      return null;
    }

    final typeClassI = markup[_propTypeClassIMarkupName];
    if (typeClassI == null) {
      return null;
    }

    final typeClass = _TypeClass.values[typeClassI];
    switch (typeClass) {
      case _TypeClass.list:
        return _ListTypeNode._fromMarkup(markup);
    }
  }

  static ({bool same, _TypeNode? o1, _TypeNode? o2}) depthComparison(
      _TypeNode a, _TypeNode b) {
    _TypeNode? n1 = a;
    _TypeNode? n2 = b;
    while (n1?.node != null && n2?.node != null) {
      n1 = n1?.node;
      n2 = n2?.node;
    }

    if (n1?.node == null && n2?.node == null) {
      final o1 = n1!;
      final o2 = n2!;
      return (
        same: true,
        o1: o1,
        o2: o2,
      );
    }

    return (
      same: false,
      o1: null,
      o2: null,
    );
  }
}

class _ListTypeNode extends _TypeNode {
  _ListTypeNode();

  _ListTypeNode._fromMarkup(MarkupObj markup) : super._fromMarkup(markup);

  @override
  TypeProvider get _typeProv {
    return _internalTypeProv
        .provType(<INT_TYPE>() => TypeProvider<List<INT_TYPE>>());
  }

  TypeProvider get _internalTypeProv {
    if (_node == null && _config != null) {
      // have actual types only.
      return _config!.provType(<CONFIG_TYPE>() {
        return TypeProvider<CONFIG_TYPE>().setNullability(haveNull);
      });
    } else if (_node != null && _config == null) {
      // have generic types only.
      return _node!._typeProv.provType(<NODE_TYPE>() {
        return TypeProvider<NODE_TYPE>().setNullability(haveNull);
      });
    } else if (_node == null && _config == null) {
      // there is neither.
      return const TypeProvider<Null>();
    } else {
      // there is both.
      return (const TypeProvider<Object>()).setNullability(haveNull);
    }
  }

  @override
  _ListTypeNode copy() => _ListTypeNode()
    .._node = _node?.copy()
    .._config = _config
    ..haveNull = haveNull;
}

List? _castDynamically(Object? obj, [_ListTypeNode? recTypeData]) {
  if (obj is List) {
    final listData = _ListTypeNode();
    for (final element in obj) {
      _castDynamically(element, listData);
    }
    recTypeData?.node = listData;

    return listData._internalTypeProv.provType(<LIST_TYPE>() {
      return obj.cast<LIST_TYPE>();
    });
  }

  final listTypeData = recTypeData as _ListTypeNode;
  if (obj == null) {
    listTypeData.haveNull = true;
    return null;
  }

  if (obj is Enum) {
    final specificEnumConfig = SerializationConfig._getMostSpecificConfig(obj);
    if (specificEnumConfig is EnumSerializationConfig) {
      listTypeData.config = specificEnumConfig;
      return null;
    }
  }

  final specificConfig = SerializationConfig._getMostSpecificConfig(obj);
  listTypeData.config = specificConfig;
  return null;
}

List castDynamically(List list) => _castDynamically(list.withoutEmpties())!;
