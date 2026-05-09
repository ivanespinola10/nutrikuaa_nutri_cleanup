import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:csv/csv.dart';
import '../../models/insumo_model.dart';
import '../../models/proyecto_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('nutrikuaa_industrial.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 3,
      // ACTIVA LLAVES FORÁNEAS: Crucial para la integridad de fórmulas
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // 1. Tabla de Ingredientes (Mapeo industrial de 22 columnas)
    await db.execute('''
      CREATE TABLE ingredientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        alimento TEXT, 
        nombre TEXT NOT NULL, 
        grupo TEXT, 
        pais TEXT,
        calorias REAL, proteinas REAL, hidratos REAL, fibra REAL,
        lipidos REAL, saturados REAL, monoinsat REAL, poliinsat REAL,
        colesterol REAL, retinol REAL, calcio REAL, hierro REAL,
        sodio REAL, zinc REAL, azucares_anadidos_g REAL,
        precio_por_kg REAL DEFAULT 0, 
        es_propio INTEGER DEFAULT 0 
      )
    ''');

    // 2. Tabla de Proyectos (Cabeceras de I+D)
    await db.execute('''
      CREATE TABLE proyectos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        region TEXT,
        merma_total REAL,
        porcion_sugerida REAL,
        fecha TEXT
      )
    ''');

    // 3. Tabla de Items (La unión para tus recetas)
    await db.execute('''
      CREATE TABLE proyecto_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        proyecto_id INTEGER,
        insumo_id INTEGER,
        cantidad_g REAL,
        FOREIGN KEY (proyecto_id) REFERENCES proyectos (id) ON DELETE CASCADE,
        FOREIGN KEY (insumo_id) REFERENCES ingredientes (id)
      )
    ''');
  }

  // --- SECCIÓN: BIBLIOTECA DE INGREDIENTES ---

  Future<int> insertarInsumo(InsumoModel insumo) async {
    final db = await instance.database;
    return await db.insert('ingredientes', insumo.toMap());
  }

  Future<int> actualizarInsumo(InsumoModel insumo) async {
    final db = await instance.database;
    return await db.update(
      'ingredientes',
      insumo.toMap(),
      where: 'id = ?',
      whereArgs: [insumo.id],
    );
  }

  Future<List<InsumoModel>> buscarInsumosPro({
    required String query,
    String? paisFiltro,
    bool soloPropios = false,
  }) async {
    final db = await instance.database;
    String where = 'nombre LIKE ?';
    List<dynamic> args = ['%$query%'];

    if (soloPropios) {
      where += ' AND es_propio = 1';
    } else if (paisFiltro != null && paisFiltro != "Todos") {
      where += ' AND pais = ?';
      args.add(paisFiltro);
    }

    final res = await db.query(
      'ingredientes',
      where: where,
      whereArgs: args,
      limit: 50,
    );
    return res.map((json) => InsumoModel.fromMap(json)).toList();
  }

  Future<List<String>> getPaisesExistentes() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT DISTINCT pais FROM ingredientes WHERE pais IS NOT NULL AND pais != "" ORDER BY pais ASC',
    );
    return result.map((row) => row['pais'] as String).toList();
  }

  // --- SECCIÓN: MEZCLADOR DE PROYECTOS I+D ---

  Future<int> guardarProyecto(ProyectoModel p) async {
    final db = await instance.database;
    return await db.insert('proyectos', p.toMap());
  }

  // Este es el método que conecta con tu pantalla de detalle
  Future<List<Map<String, dynamic>>> getItemsDelProyecto(int proyectoId) async {
    final db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT 
        pi.id, pi.cantidad_g, 
        i.nombre, i.calorias, i.proteinas, i.hidratos, i.lipidos, i.sodio, i.precio_por_kg
      FROM proyecto_items pi
      JOIN ingredientes i ON pi.insumo_id = i.id
      WHERE pi.proyecto_id = ?
    ''',
      [proyectoId],
    );
  }

  // --- IMPORTACIÓN Y LIMPIEZA ---

  Future<void> importarCSV() async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM ingredientes WHERE es_propio = 0',
      ),
    );
    if (count != null && count > 0) return;

    try {
      final csvData = await rootBundle.loadString('assets/ingredients.csv');
      List<List<dynamic>> rows = const CsvToListConverter(
        fieldDelimiter: ';',
        eol: '\n',
      ).convert(csvData);

      Batch batch = db.batch();
      for (var r in rows.skip(1)) {
        if (r.length < 21) continue;
        batch.insert('ingredientes', {
          'alimento': r[1].toString(),
          'nombre': r[2].toString(),
          'pais': r[5].toString(),
          'calorias': _clean(r[8]),
          'proteinas': _clean(r[9]),
          'hidratos': _clean(r[10]),
          'fibra': _clean(r[11]),
          'lipidos': _clean(r[12]),
          'saturados': _clean(r[13]),
          'monoinsat': _clean(r[14]),
          'poliinsat': _clean(r[15]),
          'colesterol': _clean(r[16]),
          'retinol': _clean(r[17]),
          'calcio': _clean(r[18]),
          'hierro': _clean(r[19]),
          'sodio': _clean(r[20]),
          'zinc': _clean(r[21]),
          'es_propio': 0,
        });
      }
      await batch.commit(noResult: true);
    } catch (e) {
      print("Error CSV Industrial: $e");
    }
  }

  dynamic _clean(dynamic v) {
    if (v == -1 || v == null || v == '' || v == 'nan') return 0.0;
    if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
    return v.toDouble();
  }

  Future _upgradeDB(Database db, int oldV, int newV) async {
    if (oldV < 3) {
      await db.execute('DROP TABLE IF EXISTS ingredientes');
      await _createDB(db, newV);
    }
  }
}
