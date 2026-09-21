import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

bool get catalogIsAvailable => true;

QueryExecutor openCatalog() => driftDatabase(name: 'catalog');
