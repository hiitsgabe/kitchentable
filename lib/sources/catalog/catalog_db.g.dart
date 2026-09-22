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
  static const VerificationMeta _imageLargeMeta = const VerificationMeta(
    'imageLarge',
  );
  @override
  late final GeneratedColumn<String> imageLarge = GeneratedColumn<String>(
    'image_large',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageBackMeta = const VerificationMeta(
    'imageBack',
  );
  @override
  late final GeneratedColumn<String> imageBack = GeneratedColumn<String>(
    'image_back',
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
    imageLarge,
    imageBack,
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
    if (data.containsKey('image_large')) {
      context.handle(
        _imageLargeMeta,
        imageLarge.isAcceptableOrUnknown(data['image_large']!, _imageLargeMeta),
      );
    }
    if (data.containsKey('image_back')) {
      context.handle(
        _imageBackMeta,
        imageBack.isAcceptableOrUnknown(data['image_back']!, _imageBackMeta),
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
      imageLarge: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_large'],
      ),
      imageBack: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_back'],
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
  final String? imageLarge;
  final String? imageBack;
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
    this.imageLarge,
    this.imageBack,
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
    if (!nullToAbsent || imageLarge != null) {
      map['image_large'] = Variable<String>(imageLarge);
    }
    if (!nullToAbsent || imageBack != null) {
      map['image_back'] = Variable<String>(imageBack);
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
      imageLarge: imageLarge == null && nullToAbsent
          ? const Value.absent()
          : Value(imageLarge),
      imageBack: imageBack == null && nullToAbsent
          ? const Value.absent()
          : Value(imageBack),
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
      imageLarge: serializer.fromJson<String?>(json['imageLarge']),
      imageBack: serializer.fromJson<String?>(json['imageBack']),
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
      'imageLarge': serializer.toJson<String?>(imageLarge),
      'imageBack': serializer.toJson<String?>(imageBack),
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
    Value<String?> imageLarge = const Value.absent(),
    Value<String?> imageBack = const Value.absent(),
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
    imageLarge: imageLarge.present ? imageLarge.value : this.imageLarge,
    imageBack: imageBack.present ? imageBack.value : this.imageBack,
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
      imageLarge: data.imageLarge.present
          ? data.imageLarge.value
          : this.imageLarge,
      imageBack: data.imageBack.present ? data.imageBack.value : this.imageBack,
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
          ..write('imageNormal: $imageNormal, ')
          ..write('imageLarge: $imageLarge, ')
          ..write('imageBack: $imageBack')
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
    imageLarge,
    imageBack,
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
          other.imageNormal == this.imageNormal &&
          other.imageLarge == this.imageLarge &&
          other.imageBack == this.imageBack);
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
  final Value<String?> imageLarge;
  final Value<String?> imageBack;
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
    this.imageLarge = const Value.absent(),
    this.imageBack = const Value.absent(),
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
    this.imageLarge = const Value.absent(),
    this.imageBack = const Value.absent(),
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
    Expression<String>? imageLarge,
    Expression<String>? imageBack,
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
      if (imageLarge != null) 'image_large': imageLarge,
      if (imageBack != null) 'image_back': imageBack,
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
    Value<String?>? imageLarge,
    Value<String?>? imageBack,
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
      imageLarge: imageLarge ?? this.imageLarge,
      imageBack: imageBack ?? this.imageBack,
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
    if (imageLarge.present) {
      map['image_large'] = Variable<String>(imageLarge.value);
    }
    if (imageBack.present) {
      map['image_back'] = Variable<String>(imageBack.value);
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
          ..write('imageLarge: $imageLarge, ')
          ..write('imageBack: $imageBack, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DecksTable extends Decks with TableInfo<$DecksTable, DeckRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DecksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gameMeta = const VerificationMeta('game');
  @override
  late final GeneratedColumn<String> game = GeneratedColumn<String>(
    'game',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('magic'),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, format, game, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'decks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeckRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('game')) {
      context.handle(
        _gameMeta,
        game.isAcceptableOrUnknown(data['game']!, _gameMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeckRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeckRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      game: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DecksTable createAlias(String alias) {
    return $DecksTable(attachedDatabase, alias);
  }
}

class DeckRow extends DataClass implements Insertable<DeckRow> {
  final String id;
  final String name;
  final String format;
  final String game;
  final DateTime updatedAt;
  const DeckRow({
    required this.id,
    required this.name,
    required this.format,
    required this.game,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['format'] = Variable<String>(format);
    map['game'] = Variable<String>(game);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DecksCompanion toCompanion(bool nullToAbsent) {
    return DecksCompanion(
      id: Value(id),
      name: Value(name),
      format: Value(format),
      game: Value(game),
      updatedAt: Value(updatedAt),
    );
  }

  factory DeckRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeckRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      format: serializer.fromJson<String>(json['format']),
      game: serializer.fromJson<String>(json['game']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'format': serializer.toJson<String>(format),
      'game': serializer.toJson<String>(game),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DeckRow copyWith({
    String? id,
    String? name,
    String? format,
    String? game,
    DateTime? updatedAt,
  }) => DeckRow(
    id: id ?? this.id,
    name: name ?? this.name,
    format: format ?? this.format,
    game: game ?? this.game,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DeckRow copyWithCompanion(DecksCompanion data) {
    return DeckRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      format: data.format.present ? data.format.value : this.format,
      game: data.game.present ? data.game.value : this.game,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeckRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('format: $format, ')
          ..write('game: $game, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, format, game, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeckRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.format == this.format &&
          other.game == this.game &&
          other.updatedAt == this.updatedAt);
}

class DecksCompanion extends UpdateCompanion<DeckRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> format;
  final Value<String> game;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DecksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.format = const Value.absent(),
    this.game = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DecksCompanion.insert({
    required String id,
    required String name,
    required String format,
    this.game = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       format = Value(format),
       updatedAt = Value(updatedAt);
  static Insertable<DeckRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? format,
    Expression<String>? game,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (format != null) 'format': format,
      if (game != null) 'game': game,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DecksCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? format,
    Value<String>? game,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DecksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      format: format ?? this.format,
      game: game ?? this.game,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (game.present) {
      map['game'] = Variable<String>(game.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DecksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('format: $format, ')
          ..write('game: $game, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeckCardsTable extends DeckCards
    with TableInfo<$DeckCardsTable, DeckCardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeckCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deckIdMeta = const VerificationMeta('deckId');
  @override
  late final GeneratedColumn<String> deckId = GeneratedColumn<String>(
    'deck_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
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
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sideboardMeta = const VerificationMeta(
    'sideboard',
  );
  @override
  late final GeneratedColumn<bool> sideboard = GeneratedColumn<bool>(
    'sideboard',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sideboard" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _commanderMeta = const VerificationMeta(
    'commander',
  );
  @override
  late final GeneratedColumn<bool> commander = GeneratedColumn<bool>(
    'commander',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("commander" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    deckId,
    oracleId,
    quantity,
    sideboard,
    commander,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deck_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeckCardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('deck_id')) {
      context.handle(
        _deckIdMeta,
        deckId.isAcceptableOrUnknown(data['deck_id']!, _deckIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deckIdMeta);
    }
    if (data.containsKey('oracle_id')) {
      context.handle(
        _oracleIdMeta,
        oracleId.isAcceptableOrUnknown(data['oracle_id']!, _oracleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_oracleIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('sideboard')) {
      context.handle(
        _sideboardMeta,
        sideboard.isAcceptableOrUnknown(data['sideboard']!, _sideboardMeta),
      );
    }
    if (data.containsKey('commander')) {
      context.handle(
        _commanderMeta,
        commander.isAcceptableOrUnknown(data['commander']!, _commanderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deckId, oracleId, sideboard};
  @override
  DeckCardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeckCardRow(
      deckId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deck_id'],
      )!,
      oracleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}oracle_id'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      sideboard: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sideboard'],
      )!,
      commander: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}commander'],
      )!,
    );
  }

  @override
  $DeckCardsTable createAlias(String alias) {
    return $DeckCardsTable(attachedDatabase, alias);
  }
}

class DeckCardRow extends DataClass implements Insertable<DeckCardRow> {
  final String deckId;
  final String oracleId;
  final int quantity;
  final bool sideboard;
  final bool commander;
  const DeckCardRow({
    required this.deckId,
    required this.oracleId,
    required this.quantity,
    required this.sideboard,
    required this.commander,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['deck_id'] = Variable<String>(deckId);
    map['oracle_id'] = Variable<String>(oracleId);
    map['quantity'] = Variable<int>(quantity);
    map['sideboard'] = Variable<bool>(sideboard);
    map['commander'] = Variable<bool>(commander);
    return map;
  }

  DeckCardsCompanion toCompanion(bool nullToAbsent) {
    return DeckCardsCompanion(
      deckId: Value(deckId),
      oracleId: Value(oracleId),
      quantity: Value(quantity),
      sideboard: Value(sideboard),
      commander: Value(commander),
    );
  }

  factory DeckCardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeckCardRow(
      deckId: serializer.fromJson<String>(json['deckId']),
      oracleId: serializer.fromJson<String>(json['oracleId']),
      quantity: serializer.fromJson<int>(json['quantity']),
      sideboard: serializer.fromJson<bool>(json['sideboard']),
      commander: serializer.fromJson<bool>(json['commander']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deckId': serializer.toJson<String>(deckId),
      'oracleId': serializer.toJson<String>(oracleId),
      'quantity': serializer.toJson<int>(quantity),
      'sideboard': serializer.toJson<bool>(sideboard),
      'commander': serializer.toJson<bool>(commander),
    };
  }

  DeckCardRow copyWith({
    String? deckId,
    String? oracleId,
    int? quantity,
    bool? sideboard,
    bool? commander,
  }) => DeckCardRow(
    deckId: deckId ?? this.deckId,
    oracleId: oracleId ?? this.oracleId,
    quantity: quantity ?? this.quantity,
    sideboard: sideboard ?? this.sideboard,
    commander: commander ?? this.commander,
  );
  DeckCardRow copyWithCompanion(DeckCardsCompanion data) {
    return DeckCardRow(
      deckId: data.deckId.present ? data.deckId.value : this.deckId,
      oracleId: data.oracleId.present ? data.oracleId.value : this.oracleId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      sideboard: data.sideboard.present ? data.sideboard.value : this.sideboard,
      commander: data.commander.present ? data.commander.value : this.commander,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeckCardRow(')
          ..write('deckId: $deckId, ')
          ..write('oracleId: $oracleId, ')
          ..write('quantity: $quantity, ')
          ..write('sideboard: $sideboard, ')
          ..write('commander: $commander')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(deckId, oracleId, quantity, sideboard, commander);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeckCardRow &&
          other.deckId == this.deckId &&
          other.oracleId == this.oracleId &&
          other.quantity == this.quantity &&
          other.sideboard == this.sideboard &&
          other.commander == this.commander);
}

class DeckCardsCompanion extends UpdateCompanion<DeckCardRow> {
  final Value<String> deckId;
  final Value<String> oracleId;
  final Value<int> quantity;
  final Value<bool> sideboard;
  final Value<bool> commander;
  final Value<int> rowid;
  const DeckCardsCompanion({
    this.deckId = const Value.absent(),
    this.oracleId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.sideboard = const Value.absent(),
    this.commander = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeckCardsCompanion.insert({
    required String deckId,
    required String oracleId,
    required int quantity,
    this.sideboard = const Value.absent(),
    this.commander = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : deckId = Value(deckId),
       oracleId = Value(oracleId),
       quantity = Value(quantity);
  static Insertable<DeckCardRow> custom({
    Expression<String>? deckId,
    Expression<String>? oracleId,
    Expression<int>? quantity,
    Expression<bool>? sideboard,
    Expression<bool>? commander,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deckId != null) 'deck_id': deckId,
      if (oracleId != null) 'oracle_id': oracleId,
      if (quantity != null) 'quantity': quantity,
      if (sideboard != null) 'sideboard': sideboard,
      if (commander != null) 'commander': commander,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeckCardsCompanion copyWith({
    Value<String>? deckId,
    Value<String>? oracleId,
    Value<int>? quantity,
    Value<bool>? sideboard,
    Value<bool>? commander,
    Value<int>? rowid,
  }) {
    return DeckCardsCompanion(
      deckId: deckId ?? this.deckId,
      oracleId: oracleId ?? this.oracleId,
      quantity: quantity ?? this.quantity,
      sideboard: sideboard ?? this.sideboard,
      commander: commander ?? this.commander,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deckId.present) {
      map['deck_id'] = Variable<String>(deckId.value);
    }
    if (oracleId.present) {
      map['oracle_id'] = Variable<String>(oracleId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (sideboard.present) {
      map['sideboard'] = Variable<bool>(sideboard.value);
    }
    if (commander.present) {
      map['commander'] = Variable<bool>(commander.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeckCardsCompanion(')
          ..write('deckId: $deckId, ')
          ..write('oracleId: $oracleId, ')
          ..write('quantity: $quantity, ')
          ..write('sideboard: $sideboard, ')
          ..write('commander: $commander, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CatalogDb extends GeneratedDatabase {
  _$CatalogDb(QueryExecutor e) : super(e);
  $CatalogDbManager get managers => $CatalogDbManager(this);
  late final $CardsTable cards = $CardsTable(this);
  late final $DecksTable decks = $DecksTable(this);
  late final $DeckCardsTable deckCards = $DeckCardsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [cards, decks, deckCards];
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
  Value<String?> imageLarge,
  Value<String?> imageBack,
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
  Value<String?> imageLarge,
  Value<String?> imageBack,
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

  ColumnFilters<String> get imageLarge => $composableBuilder(
    column: $table.imageLarge,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageBack => $composableBuilder(
    column: $table.imageBack,
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

  ColumnOrderings<String> get imageLarge => $composableBuilder(
    column: $table.imageLarge,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageBack => $composableBuilder(
    column: $table.imageBack,
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

  GeneratedColumn<String> get imageLarge => $composableBuilder(
    column: $table.imageLarge,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageBack =>
      $composableBuilder(column: $table.imageBack, builder: (column) => column);
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
                Value<String?> imageLarge = const Value.absent(),
                Value<String?> imageBack = const Value.absent(),
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
                imageLarge: imageLarge,
                imageBack: imageBack,
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
                Value<String?> imageLarge = const Value.absent(),
                Value<String?> imageBack = const Value.absent(),
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
                imageLarge: imageLarge,
                imageBack: imageBack,
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
typedef $$DecksTableCreateCompanionBuilder = DecksCompanion Function({
  required String id,
  required String name,
  required String format,
  Value<String> game,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$DecksTableUpdateCompanionBuilder = DecksCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> format,
  Value<String> game,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$DecksTableFilterComposer extends Composer<_$CatalogDb, $DecksTable> {
  $$DecksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get game => $composableBuilder(
    column: $table.game,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DecksTableOrderingComposer extends Composer<_$CatalogDb, $DecksTable> {
  $$DecksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get game => $composableBuilder(
    column: $table.game,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DecksTableAnnotationComposer
    extends Composer<_$CatalogDb, $DecksTable> {
  $$DecksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get game =>
      $composableBuilder(column: $table.game, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DecksTableTableManager
    extends
        RootTableManager<
          _$CatalogDb,
          $DecksTable,
          DeckRow,
          $$DecksTableFilterComposer,
          $$DecksTableOrderingComposer,
          $$DecksTableAnnotationComposer,
          $$DecksTableCreateCompanionBuilder,
          $$DecksTableUpdateCompanionBuilder,
          (DeckRow, BaseReferences<_$CatalogDb, $DecksTable, DeckRow>),
          DeckRow,
          PrefetchHooks Function()
        > {
  $$DecksTableTableManager(_$CatalogDb db, $DecksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DecksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DecksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DecksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String> game = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DecksCompanion(
                id: id,
                name: name,
                format: format,
                game: game,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String format,
                Value<String> game = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DecksCompanion.insert(
                id: id,
                name: name,
                format: format,
                game: game,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DecksTable, DeckRow>(table),
                  BaseReferences<_$CatalogDb, $DecksTable, DeckRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DecksTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDb,
      $DecksTable,
      DeckRow,
      $$DecksTableFilterComposer,
      $$DecksTableOrderingComposer,
      $$DecksTableAnnotationComposer,
      $$DecksTableCreateCompanionBuilder,
      $$DecksTableUpdateCompanionBuilder,
      (DeckRow, BaseReferences<_$CatalogDb, $DecksTable, DeckRow>),
      DeckRow,
      PrefetchHooks Function()
    >;
typedef $$DeckCardsTableCreateCompanionBuilder = DeckCardsCompanion Function({
  required String deckId,
  required String oracleId,
  required int quantity,
  Value<bool> sideboard,
  Value<bool> commander,
  Value<int> rowid,
});
typedef $$DeckCardsTableUpdateCompanionBuilder = DeckCardsCompanion Function({
  Value<String> deckId,
  Value<String> oracleId,
  Value<int> quantity,
  Value<bool> sideboard,
  Value<bool> commander,
  Value<int> rowid,
});

class $$DeckCardsTableFilterComposer
    extends Composer<_$CatalogDb, $DeckCardsTable> {
  $$DeckCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deckId => $composableBuilder(
    column: $table.deckId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oracleId => $composableBuilder(
    column: $table.oracleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get sideboard => $composableBuilder(
    column: $table.sideboard,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get commander => $composableBuilder(
    column: $table.commander,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeckCardsTableOrderingComposer
    extends Composer<_$CatalogDb, $DeckCardsTable> {
  $$DeckCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deckId => $composableBuilder(
    column: $table.deckId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oracleId => $composableBuilder(
    column: $table.oracleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get sideboard => $composableBuilder(
    column: $table.sideboard,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get commander => $composableBuilder(
    column: $table.commander,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeckCardsTableAnnotationComposer
    extends Composer<_$CatalogDb, $DeckCardsTable> {
  $$DeckCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deckId =>
      $composableBuilder(column: $table.deckId, builder: (column) => column);

  GeneratedColumn<String> get oracleId =>
      $composableBuilder(column: $table.oracleId, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<bool> get sideboard =>
      $composableBuilder(column: $table.sideboard, builder: (column) => column);

  GeneratedColumn<bool> get commander =>
      $composableBuilder(column: $table.commander, builder: (column) => column);
}

class $$DeckCardsTableTableManager
    extends
        RootTableManager<
          _$CatalogDb,
          $DeckCardsTable,
          DeckCardRow,
          $$DeckCardsTableFilterComposer,
          $$DeckCardsTableOrderingComposer,
          $$DeckCardsTableAnnotationComposer,
          $$DeckCardsTableCreateCompanionBuilder,
          $$DeckCardsTableUpdateCompanionBuilder,
          (
            DeckCardRow,
            BaseReferences<_$CatalogDb, $DeckCardsTable, DeckCardRow>,
          ),
          DeckCardRow,
          PrefetchHooks Function()
        > {
  $$DeckCardsTableTableManager(_$CatalogDb db, $DeckCardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeckCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeckCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeckCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> deckId = const Value.absent(),
                Value<String> oracleId = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<bool> sideboard = const Value.absent(),
                Value<bool> commander = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeckCardsCompanion(
                deckId: deckId,
                oracleId: oracleId,
                quantity: quantity,
                sideboard: sideboard,
                commander: commander,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deckId,
                required String oracleId,
                required int quantity,
                Value<bool> sideboard = const Value.absent(),
                Value<bool> commander = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeckCardsCompanion.insert(
                deckId: deckId,
                oracleId: oracleId,
                quantity: quantity,
                sideboard: sideboard,
                commander: commander,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DeckCardsTable, DeckCardRow>(table),
                  BaseReferences<_$CatalogDb, $DeckCardsTable, DeckCardRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeckCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDb,
      $DeckCardsTable,
      DeckCardRow,
      $$DeckCardsTableFilterComposer,
      $$DeckCardsTableOrderingComposer,
      $$DeckCardsTableAnnotationComposer,
      $$DeckCardsTableCreateCompanionBuilder,
      $$DeckCardsTableUpdateCompanionBuilder,
      (DeckCardRow, BaseReferences<_$CatalogDb, $DeckCardsTable, DeckCardRow>),
      DeckCardRow,
      PrefetchHooks Function()
    >;

class $CatalogDbManager {
  final _$CatalogDb _db;
  $CatalogDbManager(this._db);
  $$CardsTableTableManager get cards =>
      $$CardsTableTableManager(_db, _db.cards);
  $$DecksTableTableManager get decks =>
      $$DecksTableTableManager(_db, _db.decks);
  $$DeckCardsTableTableManager get deckCards =>
      $$DeckCardsTableTableManager(_db, _db.deckCards);
}
