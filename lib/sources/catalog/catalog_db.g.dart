// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_db.dart';

// ignore_for_file: type=lint
class $CardsTable extends Cards with TableInfo<$CardsTable, Card> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _oracleIdMeta = const VerificationMeta(
    'oracleId',
  );
  @override
  late final GeneratedColumn<String> oracleId = GeneratedColumn<String>(
    'oracle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameFoldedMeta = const VerificationMeta(
    'nameFolded',
  );
  @override
  late final GeneratedColumn<String> nameFolded = GeneratedColumn<String>(
    'name_folded',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeLineMeta = const VerificationMeta(
    'typeLine',
  );
  @override
  late final GeneratedColumn<String> typeLine = GeneratedColumn<String>(
    'type_line',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cmcMeta = const VerificationMeta('cmc');
  @override
  late final GeneratedColumn<double> cmc = GeneratedColumn<double>(
    'cmc',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _manaCostMeta = const VerificationMeta(
    'manaCost',
  );
  @override
  late final GeneratedColumn<String> manaCost = GeneratedColumn<String>(
    'mana_cost',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _oracleTextMeta = const VerificationMeta(
    'oracleText',
  );
  @override
  late final GeneratedColumn<String> oracleText = GeneratedColumn<String>(
    'oracle_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _powerMeta = const VerificationMeta('power');
  @override
  late final GeneratedColumn<String> power = GeneratedColumn<String>(
    'power',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toughnessMeta = const VerificationMeta(
    'toughness',
  );
  @override
  late final GeneratedColumn<String> toughness = GeneratedColumn<String>(
    'toughness',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorIdentityMeta = const VerificationMeta(
    'colorIdentity',
  );
  @override
  late final GeneratedColumn<String> colorIdentity = GeneratedColumn<String>(
    'color_identity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rarityMeta = const VerificationMeta('rarity');
  @override
  late final GeneratedColumn<String> rarity = GeneratedColumn<String>(
    'rarity',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _setCodeMeta = const VerificationMeta(
    'setCode',
  );
  @override
  late final GeneratedColumn<String> setCode = GeneratedColumn<String>(
    'set_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _legalitiesMeta = const VerificationMeta(
    'legalities',
  );
  @override
  late final GeneratedColumn<String> legalities = GeneratedColumn<String>(
    'legalities',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageSmallMeta = const VerificationMeta(
    'imageSmall',
  );
  @override
  late final GeneratedColumn<String> imageSmall = GeneratedColumn<String>(
    'image_small',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageNormalMeta = const VerificationMeta(
    'imageNormal',
  );
  @override
  late final GeneratedColumn<String> imageNormal = GeneratedColumn<String>(
    'image_normal',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    oracleId,
    name,
    nameFolded,
    typeLine,
    cmc,
    manaCost,
    oracleText,
    power,
    toughness,
    colorIdentity,
    rarity,
    setCode,
    legalities,
    imageSmall,
    imageNormal,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<Card> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('oracle_id')) {
      context.handle(
        _oracleIdMeta,
        oracleId.isAcceptableOrUnknown(data['oracle_id']!, _oracleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_oracleIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('name_folded')) {
      context.handle(
        _nameFoldedMeta,
        nameFolded.isAcceptableOrUnknown(data['name_folded']!, _nameFoldedMeta),
      );
    } else if (isInserting) {
      context.missing(_nameFoldedMeta);
    }
    if (data.containsKey('type_line')) {
      context.handle(
        _typeLineMeta,
        typeLine.isAcceptableOrUnknown(data['type_line']!, _typeLineMeta),
      );
    } else if (isInserting) {
      context.missing(_typeLineMeta);
    }
    if (data.containsKey('cmc')) {
      context.handle(
        _cmcMeta,
        cmc.isAcceptableOrUnknown(data['cmc']!, _cmcMeta),
      );
    } else if (isInserting) {
      context.missing(_cmcMeta);
    }
    if (data.containsKey('mana_cost')) {
      context.handle(
        _manaCostMeta,
        manaCost.isAcceptableOrUnknown(data['mana_cost']!, _manaCostMeta),
      );
    }
    if (data.containsKey('oracle_text')) {
      context.handle(
        _oracleTextMeta,
        oracleText.isAcceptableOrUnknown(data['oracle_text']!, _oracleTextMeta),
      );
    }
    if (data.containsKey('power')) {
      context.handle(
        _powerMeta,
        power.isAcceptableOrUnknown(data['power']!, _powerMeta),
      );
    }
    if (data.containsKey('toughness')) {
      context.handle(
        _toughnessMeta,
        toughness.isAcceptableOrUnknown(data['toughness']!, _toughnessMeta),
      );
    }
    if (data.containsKey('color_identity')) {
      context.handle(
        _colorIdentityMeta,
        colorIdentity.isAcceptableOrUnknown(
          data['color_identity']!,
          _colorIdentityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_colorIdentityMeta);
    }
    if (data.containsKey('rarity')) {
      context.handle(
        _rarityMeta,
        rarity.isAcceptableOrUnknown(data['rarity']!, _rarityMeta),
      );
    }
    if (data.containsKey('set_code')) {
      context.handle(
        _setCodeMeta,
        setCode.isAcceptableOrUnknown(data['set_code']!, _setCodeMeta),
      );
    }
    if (data.containsKey('legalities')) {
      context.handle(
        _legalitiesMeta,
        legalities.isAcceptableOrUnknown(data['legalities']!, _legalitiesMeta),
      );
    } else if (isInserting) {
      context.missing(_legalitiesMeta);
    }
    if (data.containsKey('image_small')) {
      context.handle(
        _imageSmallMeta,
        imageSmall.isAcceptableOrUnknown(data['image_small']!, _imageSmallMeta),
      );
    }
    if (data.containsKey('image_normal')) {
      context.handle(
        _imageNormalMeta,
        imageNormal.isAcceptableOrUnknown(
          data['image_normal']!,
          _imageNormalMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {oracleId};
  @override
  Card map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Card(
      oracleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}oracle_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nameFolded: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_folded'],
      )!,
      typeLine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type_line'],
      )!,
      cmc: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cmc'],
      )!,
      manaCost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mana_cost'],
      ),
      oracleText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}oracle_text'],
      ),
      power: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}power'],
      ),
      toughness: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}toughness'],
      ),
      colorIdentity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_identity'],
      )!,
      rarity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rarity'],
      ),
      setCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}set_code'],
      ),
      legalities: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}legalities'],
      )!,
      imageSmall: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_small'],
      ),
      imageNormal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_normal'],
      ),
    );
  }

  @override
  $CardsTable createAlias(String alias) {
    return $CardsTable(attachedDatabase, alias);
  }
}

class Card extends DataClass implements Insertable<Card> {
  final String oracleId;
  final String name;
  final String nameFolded;
  final String typeLine;
  final double cmc;
  final String? manaCost;
  final String? oracleText;
  final String? power;
  final String? toughness;
  final String colorIdentity;
  final String? rarity;
  final String? setCode;
  final String legalities;
  final String? imageSmall;
  final String? imageNormal;
  const Card({
    required this.oracleId,
    required this.name,
    required this.nameFolded,
    required this.typeLine,
    required this.cmc,
    this.manaCost,
    this.oracleText,
    this.power,
    this.toughness,
    required this.colorIdentity,
    this.rarity,
    this.setCode,
    required this.legalities,
    this.imageSmall,
    this.imageNormal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['oracle_id'] = Variable<String>(oracleId);
    map['name'] = Variable<String>(name);
    map['name_folded'] = Variable<String>(nameFolded);
    map['type_line'] = Variable<String>(typeLine);
    map['cmc'] = Variable<double>(cmc);
    if (!nullToAbsent || manaCost != null) {
      map['mana_cost'] = Variable<String>(manaCost);
    }
    if (!nullToAbsent || oracleText != null) {
      map['oracle_text'] = Variable<String>(oracleText);
    }
    if (!nullToAbsent || power != null) {
      map['power'] = Variable<String>(power);
    }
    if (!nullToAbsent || toughness != null) {
      map['toughness'] = Variable<String>(toughness);
    }
    map['color_identity'] = Variable<String>(colorIdentity);
    if (!nullToAbsent || rarity != null) {
      map['rarity'] = Variable<String>(rarity);
    }
    if (!nullToAbsent || setCode != null) {
      map['set_code'] = Variable<String>(setCode);
    }
    map['legalities'] = Variable<String>(legalities);
    if (!nullToAbsent || imageSmall != null) {
      map['image_small'] = Variable<String>(imageSmall);
    }
    if (!nullToAbsent || imageNormal != null) {
      map['image_normal'] = Variable<String>(imageNormal);
    }
    return map;
  }

  CardsCompanion toCompanion(bool nullToAbsent) {
    return CardsCompanion(
      oracleId: Value(oracleId),
      name: Value(name),
      nameFolded: Value(nameFolded),
      typeLine: Value(typeLine),
      cmc: Value(cmc),
      manaCost: manaCost == null && nullToAbsent
          ? const Value.absent()
          : Value(manaCost),
      oracleText: oracleText == null && nullToAbsent
          ? const Value.absent()
          : Value(oracleText),
      power: power == null && nullToAbsent
          ? const Value.absent()
          : Value(power),
      toughness: toughness == null && nullToAbsent
          ? const Value.absent()
          : Value(toughness),
      colorIdentity: Value(colorIdentity),
      rarity: rarity == null && nullToAbsent
          ? const Value.absent()
          : Value(rarity),
      setCode: setCode == null && nullToAbsent
          ? const Value.absent()
          : Value(setCode),
      legalities: Value(legalities),
      imageSmall: imageSmall == null && nullToAbsent
          ? const Value.absent()
          : Value(imageSmall),
      imageNormal: imageNormal == null && nullToAbsent
          ? const Value.absent()
          : Value(imageNormal),
    );
  }

  factory Card.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Card(
      oracleId: serializer.fromJson<String>(json['oracleId']),
      name: serializer.fromJson<String>(json['name']),
      nameFolded: serializer.fromJson<String>(json['nameFolded']),
      typeLine: serializer.fromJson<String>(json['typeLine']),
      cmc: serializer.fromJson<double>(json['cmc']),
      manaCost: serializer.fromJson<String?>(json['manaCost']),
      oracleText: serializer.fromJson<String?>(json['oracleText']),
      power: serializer.fromJson<String?>(json['power']),
      toughness: serializer.fromJson<String?>(json['toughness']),
      colorIdentity: serializer.fromJson<String>(json['colorIdentity']),
      rarity: serializer.fromJson<String?>(json['rarity']),
      setCode: serializer.fromJson<String?>(json['setCode']),
      legalities: serializer.fromJson<String>(json['legalities']),
      imageSmall: serializer.fromJson<String?>(json['imageSmall']),
      imageNormal: serializer.fromJson<String?>(json['imageNormal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'oracleId': serializer.toJson<String>(oracleId),
      'name': serializer.toJson<String>(name),
      'nameFolded': serializer.toJson<String>(nameFolded),
      'typeLine': serializer.toJson<String>(typeLine),
      'cmc': serializer.toJson<double>(cmc),
      'manaCost': serializer.toJson<String?>(manaCost),
      'oracleText': serializer.toJson<String?>(oracleText),
      'power': serializer.toJson<String?>(power),
      'toughness': serializer.toJson<String?>(toughness),
      'colorIdentity': serializer.toJson<String>(colorIdentity),
      'rarity': serializer.toJson<String?>(rarity),
      'setCode': serializer.toJson<String?>(setCode),
      'legalities': serializer.toJson<String>(legalities),
      'imageSmall': serializer.toJson<String?>(imageSmall),
      'imageNormal': serializer.toJson<String?>(imageNormal),
    };
  }

  Card copyWith({
    String? oracleId,
    String? name,
    String? nameFolded,
    String? typeLine,
    double? cmc,
    Value<String?> manaCost = const Value.absent(),
    Value<String?> oracleText = const Value.absent(),
    Value<String?> power = const Value.absent(),
    Value<String?> toughness = const Value.absent(),
    String? colorIdentity,
    Value<String?> rarity = const Value.absent(),
    Value<String?> setCode = const Value.absent(),
    String? legalities,
    Value<String?> imageSmall = const Value.absent(),
    Value<String?> imageNormal = const Value.absent(),
  }) => Card(
    oracleId: oracleId ?? this.oracleId,
    name: name ?? this.name,
    nameFolded: nameFolded ?? this.nameFolded,
    typeLine: typeLine ?? this.typeLine,
    cmc: cmc ?? this.cmc,
    manaCost: manaCost.present ? manaCost.value : this.manaCost,
    oracleText: oracleText.present ? oracleText.value : this.oracleText,
    power: power.present ? power.value : this.power,
    toughness: toughness.present ? toughness.value : this.toughness,
    colorIdentity: colorIdentity ?? this.colorIdentity,
    rarity: rarity.present ? rarity.value : this.rarity,
    setCode: setCode.present ? setCode.value : this.setCode,
    legalities: legalities ?? this.legalities,
    imageSmall: imageSmall.present ? imageSmall.value : this.imageSmall,
    imageNormal: imageNormal.present ? imageNormal.value : this.imageNormal,
  );
  Card copyWithCompanion(CardsCompanion data) {
    return Card(
      oracleId: data.oracleId.present ? data.oracleId.value : this.oracleId,
      name: data.name.present ? data.name.value : this.name,
      nameFolded: data.nameFolded.present
          ? data.nameFolded.value
          : this.nameFolded,
      typeLine: data.typeLine.present ? data.typeLine.value : this.typeLine,
      cmc: data.cmc.present ? data.cmc.value : this.cmc,
      manaCost: data.manaCost.present ? data.manaCost.value : this.manaCost,
      oracleText: data.oracleText.present
          ? data.oracleText.value
          : this.oracleText,
      power: data.power.present ? data.power.value : this.power,
      toughness: data.toughness.present ? data.toughness.value : this.toughness,
      colorIdentity: data.colorIdentity.present
          ? data.colorIdentity.value
          : this.colorIdentity,
      rarity: data.rarity.present ? data.rarity.value : this.rarity,
      setCode: data.setCode.present ? data.setCode.value : this.setCode,
      legalities: data.legalities.present
          ? data.legalities.value
          : this.legalities,
      imageSmall: data.imageSmall.present
          ? data.imageSmall.value
          : this.imageSmall,
      imageNormal: data.imageNormal.present
          ? data.imageNormal.value
          : this.imageNormal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Card(')
          ..write('oracleId: $oracleId, ')
          ..write('name: $name, ')
          ..write('nameFolded: $nameFolded, ')
          ..write('typeLine: $typeLine, ')
          ..write('cmc: $cmc, ')
          ..write('manaCost: $manaCost, ')
          ..write('oracleText: $oracleText, ')
          ..write('power: $power, ')
          ..write('toughness: $toughness, ')
          ..write('colorIdentity: $colorIdentity, ')
          ..write('rarity: $rarity, ')
          ..write('setCode: $setCode, ')
          ..write('legalities: $legalities, ')
          ..write('imageSmall: $imageSmall, ')
          ..write('imageNormal: $imageNormal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    oracleId,
    name,
    nameFolded,
    typeLine,
    cmc,
    manaCost,
    oracleText,
    power,
    toughness,
    colorIdentity,
    rarity,
    setCode,
    legalities,
    imageSmall,
    imageNormal,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Card &&
          other.oracleId == this.oracleId &&
          other.name == this.name &&
          other.nameFolded == this.nameFolded &&
          other.typeLine == this.typeLine &&
          other.cmc == this.cmc &&
          other.manaCost == this.manaCost &&
          other.oracleText == this.oracleText &&
          other.power == this.power &&
          other.toughness == this.toughness &&
          other.colorIdentity == this.colorIdentity &&
          other.rarity == this.rarity &&
          other.setCode == this.setCode &&
          other.legalities == this.legalities &&
          other.imageSmall == this.imageSmall &&
          other.imageNormal == this.imageNormal);
}

class CardsCompanion extends UpdateCompanion<Card> {
  final Value<String> oracleId;
  final Value<String> name;
  final Value<String> nameFolded;
  final Value<String> typeLine;
  final Value<double> cmc;
  final Value<String?> manaCost;
  final Value<String?> oracleText;
  final Value<String?> power;
  final Value<String?> toughness;
  final Value<String> colorIdentity;
  final Value<String?> rarity;
  final Value<String?> setCode;
  final Value<String> legalities;
  final Value<String?> imageSmall;
  final Value<String?> imageNormal;
  final Value<int> rowid;
  const CardsCompanion({
    this.oracleId = const Value.absent(),
    this.name = const Value.absent(),
    this.nameFolded = const Value.absent(),
    this.typeLine = const Value.absent(),
    this.cmc = const Value.absent(),
    this.manaCost = const Value.absent(),
    this.oracleText = const Value.absent(),
    this.power = const Value.absent(),
    this.toughness = const Value.absent(),
    this.colorIdentity = const Value.absent(),
    this.rarity = const Value.absent(),
    this.setCode = const Value.absent(),
    this.legalities = const Value.absent(),
    this.imageSmall = const Value.absent(),
    this.imageNormal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardsCompanion.insert({
    required String oracleId,
    required String name,
    required String nameFolded,
    required String typeLine,
    required double cmc,
    this.manaCost = const Value.absent(),
    this.oracleText = const Value.absent(),
    this.power = const Value.absent(),
    this.toughness = const Value.absent(),
    required String colorIdentity,
    this.rarity = const Value.absent(),
    this.setCode = const Value.absent(),
    required String legalities,
    this.imageSmall = const Value.absent(),
    this.imageNormal = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : oracleId = Value(oracleId),
       name = Value(name),
       nameFolded = Value(nameFolded),
       typeLine = Value(typeLine),
       cmc = Value(cmc),
       colorIdentity = Value(colorIdentity),
       legalities = Value(legalities);
  static Insertable<Card> custom({
    Expression<String>? oracleId,
    Expression<String>? name,
    Expression<String>? nameFolded,
    Expression<String>? typeLine,
    Expression<double>? cmc,
    Expression<String>? manaCost,
    Expression<String>? oracleText,
    Expression<String>? power,
    Expression<String>? toughness,
    Expression<String>? colorIdentity,
    Expression<String>? rarity,
    Expression<String>? setCode,
    Expression<String>? legalities,
    Expression<String>? imageSmall,
    Expression<String>? imageNormal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (oracleId != null) 'oracle_id': oracleId,
      if (name != null) 'name': name,
      if (nameFolded != null) 'name_folded': nameFolded,
      if (typeLine != null) 'type_line': typeLine,
      if (cmc != null) 'cmc': cmc,
      if (manaCost != null) 'mana_cost': manaCost,
      if (oracleText != null) 'oracle_text': oracleText,
      if (power != null) 'power': power,
      if (toughness != null) 'toughness': toughness,
      if (colorIdentity != null) 'color_identity': colorIdentity,
      if (rarity != null) 'rarity': rarity,
      if (setCode != null) 'set_code': setCode,
      if (legalities != null) 'legalities': legalities,
      if (imageSmall != null) 'image_small': imageSmall,
      if (imageNormal != null) 'image_normal': imageNormal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardsCompanion copyWith({
    Value<String>? oracleId,
    Value<String>? name,
    Value<String>? nameFolded,
    Value<String>? typeLine,
    Value<double>? cmc,
    Value<String?>? manaCost,
    Value<String?>? oracleText,
    Value<String?>? power,
    Value<String?>? toughness,
    Value<String>? colorIdentity,
    Value<String?>? rarity,
    Value<String?>? setCode,
    Value<String>? legalities,
    Value<String?>? imageSmall,
    Value<String?>? imageNormal,
    Value<int>? rowid,
  }) {
    return CardsCompanion(
      oracleId: oracleId ?? this.oracleId,
      name: name ?? this.name,
      nameFolded: nameFolded ?? this.nameFolded,
      typeLine: typeLine ?? this.typeLine,
      cmc: cmc ?? this.cmc,
      manaCost: manaCost ?? this.manaCost,
      oracleText: oracleText ?? this.oracleText,
      power: power ?? this.power,
      toughness: toughness ?? this.toughness,
      colorIdentity: colorIdentity ?? this.colorIdentity,
      rarity: rarity ?? this.rarity,
      setCode: setCode ?? this.setCode,
      legalities: legalities ?? this.legalities,
      imageSmall: imageSmall ?? this.imageSmall,
      imageNormal: imageNormal ?? this.imageNormal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (oracleId.present) {
      map['oracle_id'] = Variable<String>(oracleId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameFolded.present) {
      map['name_folded'] = Variable<String>(nameFolded.value);
    }
    if (typeLine.present) {
      map['type_line'] = Variable<String>(typeLine.value);
    }
    if (cmc.present) {
      map['cmc'] = Variable<double>(cmc.value);
    }
    if (manaCost.present) {
      map['mana_cost'] = Variable<String>(manaCost.value);
    }
    if (oracleText.present) {
      map['oracle_text'] = Variable<String>(oracleText.value);
    }
    if (power.present) {
      map['power'] = Variable<String>(power.value);
    }
    if (toughness.present) {
      map['toughness'] = Variable<String>(toughness.value);
    }
    if (colorIdentity.present) {
      map['color_identity'] = Variable<String>(colorIdentity.value);
    }
    if (rarity.present) {
      map['rarity'] = Variable<String>(rarity.value);
    }
    if (setCode.present) {
      map['set_code'] = Variable<String>(setCode.value);
    }
    if (legalities.present) {
      map['legalities'] = Variable<String>(legalities.value);
    }
    if (imageSmall.present) {
      map['image_small'] = Variable<String>(imageSmall.value);
    }
    if (imageNormal.present) {
      map['image_normal'] = Variable<String>(imageNormal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardsCompanion(')
          ..write('oracleId: $oracleId, ')
          ..write('name: $name, ')
          ..write('nameFolded: $nameFolded, ')
          ..write('typeLine: $typeLine, ')
          ..write('cmc: $cmc, ')
          ..write('manaCost: $manaCost, ')
          ..write('oracleText: $oracleText, ')
          ..write('power: $power, ')
          ..write('toughness: $toughness, ')
          ..write('colorIdentity: $colorIdentity, ')
          ..write('rarity: $rarity, ')
          ..write('setCode: $setCode, ')
          ..write('legalities: $legalities, ')
          ..write('imageSmall: $imageSmall, ')
          ..write('imageNormal: $imageNormal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CatalogDb extends GeneratedDatabase {
  _$CatalogDb(QueryExecutor e) : super(e);
  $CatalogDbManager get managers => $CatalogDbManager(this);
  late final $CardsTable cards = $CardsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [cards];
}

typedef $$CardsTableCreateCompanionBuilder = CardsCompanion Function({
  required String oracleId,
  required String name,
  required String nameFolded,
  required String typeLine,
  required double cmc,
  Value<String?> manaCost,
  Value<String?> oracleText,
  Value<String?> power,
  Value<String?> toughness,
  required String colorIdentity,
  Value<String?> rarity,
  Value<String?> setCode,
  required String legalities,
  Value<String?> imageSmall,
  Value<String?> imageNormal,
  Value<int> rowid,
});
typedef $$CardsTableUpdateCompanionBuilder = CardsCompanion Function({
  Value<String> oracleId,
  Value<String> name,
  Value<String> nameFolded,
  Value<String> typeLine,
  Value<double> cmc,
  Value<String?> manaCost,
  Value<String?> oracleText,
  Value<String?> power,
  Value<String?> toughness,
  Value<String> colorIdentity,
  Value<String?> rarity,
  Value<String?> setCode,
  Value<String> legalities,
  Value<String?> imageSmall,
  Value<String?> imageNormal,
  Value<int> rowid,
});

class $$CardsTableFilterComposer extends Composer<_$CatalogDb, $CardsTable> {
  $$CardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get oracleId => $composableBuilder(
    column: $table.oracleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameFolded => $composableBuilder(
    column: $table.nameFolded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get typeLine => $composableBuilder(
    column: $table.typeLine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cmc => $composableBuilder(
    column: $table.cmc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manaCost => $composableBuilder(
    column: $table.manaCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oracleText => $composableBuilder(
    column: $table.oracleText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get power => $composableBuilder(
    column: $table.power,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toughness => $composableBuilder(
    column: $table.toughness,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorIdentity => $composableBuilder(
    column: $table.colorIdentity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rarity => $composableBuilder(
    column: $table.rarity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get setCode => $composableBuilder(
    column: $table.setCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get legalities => $composableBuilder(
    column: $table.legalities,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageSmall => $composableBuilder(
    column: $table.imageSmall,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageNormal => $composableBuilder(
    column: $table.imageNormal,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CardsTableOrderingComposer extends Composer<_$CatalogDb, $CardsTable> {
  $$CardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get oracleId => $composableBuilder(
    column: $table.oracleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameFolded => $composableBuilder(
    column: $table.nameFolded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get typeLine => $composableBuilder(
    column: $table.typeLine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cmc => $composableBuilder(
    column: $table.cmc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manaCost => $composableBuilder(
    column: $table.manaCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oracleText => $composableBuilder(
    column: $table.oracleText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get power => $composableBuilder(
    column: $table.power,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toughness => $composableBuilder(
    column: $table.toughness,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorIdentity => $composableBuilder(
    column: $table.colorIdentity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rarity => $composableBuilder(
    column: $table.rarity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get setCode => $composableBuilder(
    column: $table.setCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get legalities => $composableBuilder(
    column: $table.legalities,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageSmall => $composableBuilder(
    column: $table.imageSmall,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageNormal => $composableBuilder(
    column: $table.imageNormal,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CardsTableAnnotationComposer
    extends Composer<_$CatalogDb, $CardsTable> {
  $$CardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get oracleId =>
      $composableBuilder(column: $table.oracleId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nameFolded => $composableBuilder(
    column: $table.nameFolded,
    builder: (column) => column,
  );

  GeneratedColumn<String> get typeLine =>
      $composableBuilder(column: $table.typeLine, builder: (column) => column);

  GeneratedColumn<double> get cmc =>
      $composableBuilder(column: $table.cmc, builder: (column) => column);

  GeneratedColumn<String> get manaCost =>
      $composableBuilder(column: $table.manaCost, builder: (column) => column);

  GeneratedColumn<String> get oracleText => $composableBuilder(
    column: $table.oracleText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get power =>
      $composableBuilder(column: $table.power, builder: (column) => column);

  GeneratedColumn<String> get toughness =>
      $composableBuilder(column: $table.toughness, builder: (column) => column);

  GeneratedColumn<String> get colorIdentity => $composableBuilder(
    column: $table.colorIdentity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rarity =>
      $composableBuilder(column: $table.rarity, builder: (column) => column);

  GeneratedColumn<String> get setCode =>
      $composableBuilder(column: $table.setCode, builder: (column) => column);

  GeneratedColumn<String> get legalities => $composableBuilder(
    column: $table.legalities,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageSmall => $composableBuilder(
    column: $table.imageSmall,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageNormal => $composableBuilder(
    column: $table.imageNormal,
    builder: (column) => column,
  );
}

class $$CardsTableTableManager
    extends
        RootTableManager<
          _$CatalogDb,
          $CardsTable,
          Card,
          $$CardsTableFilterComposer,
          $$CardsTableOrderingComposer,
          $$CardsTableAnnotationComposer,
          $$CardsTableCreateCompanionBuilder,
          $$CardsTableUpdateCompanionBuilder,
          (Card, BaseReferences<_$CatalogDb, $CardsTable, Card>),
          Card,
          PrefetchHooks Function()
        > {
  $$CardsTableTableManager(_$CatalogDb db, $CardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> oracleId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> nameFolded = const Value.absent(),
                Value<String> typeLine = const Value.absent(),
                Value<double> cmc = const Value.absent(),
                Value<String?> manaCost = const Value.absent(),
                Value<String?> oracleText = const Value.absent(),
                Value<String?> power = const Value.absent(),
                Value<String?> toughness = const Value.absent(),
                Value<String> colorIdentity = const Value.absent(),
                Value<String?> rarity = const Value.absent(),
                Value<String?> setCode = const Value.absent(),
                Value<String> legalities = const Value.absent(),
                Value<String?> imageSmall = const Value.absent(),
                Value<String?> imageNormal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardsCompanion(
                oracleId: oracleId,
                name: name,
                nameFolded: nameFolded,
                typeLine: typeLine,
                cmc: cmc,
                manaCost: manaCost,
                oracleText: oracleText,
                power: power,
                toughness: toughness,
                colorIdentity: colorIdentity,
                rarity: rarity,
                setCode: setCode,
                legalities: legalities,
                imageSmall: imageSmall,
                imageNormal: imageNormal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String oracleId,
                required String name,
                required String nameFolded,
                required String typeLine,
                required double cmc,
                Value<String?> manaCost = const Value.absent(),
                Value<String?> oracleText = const Value.absent(),
                Value<String?> power = const Value.absent(),
                Value<String?> toughness = const Value.absent(),
                required String colorIdentity,
                Value<String?> rarity = const Value.absent(),
                Value<String?> setCode = const Value.absent(),
                required String legalities,
                Value<String?> imageSmall = const Value.absent(),
                Value<String?> imageNormal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardsCompanion.insert(
                oracleId: oracleId,
                name: name,
                nameFolded: nameFolded,
                typeLine: typeLine,
                cmc: cmc,
                manaCost: manaCost,
                oracleText: oracleText,
                power: power,
                toughness: toughness,
                colorIdentity: colorIdentity,
                rarity: rarity,
                setCode: setCode,
                legalities: legalities,
                imageSmall: imageSmall,
                imageNormal: imageNormal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CardsTable, Card>(table),
                  BaseReferences<_$CatalogDb, $CardsTable, Card>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CardsTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDb,
      $CardsTable,
      Card,
      $$CardsTableFilterComposer,
      $$CardsTableOrderingComposer,
      $$CardsTableAnnotationComposer,
      $$CardsTableCreateCompanionBuilder,
      $$CardsTableUpdateCompanionBuilder,
      (Card, BaseReferences<_$CatalogDb, $CardsTable, Card>),
      Card,
      PrefetchHooks Function()
    >;

class $CatalogDbManager {
  final _$CatalogDb _db;
  $CatalogDbManager(this._db);
  $$CardsTableTableManager get cards =>
      $$CardsTableTableManager(_db, _db.cards);
}
