import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart' as app_exceptions;
import '../../../../main.dart';

/// Local SQLite database manager
class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  static Database? _database;
  
  factory AppDatabase() => _instance;
  
  AppDatabase._internal();

  /// Get database instance
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    try {
      logger.d('Initializing SQLite database...');
      
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, AppConfig.databaseName);
      
      logger.d('Database path: $path');
      
      return await openDatabase(
        path,
        version: AppConfig.databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: _onOpen,
      );
    } catch (e) {
      logger.e('Failed to initialize database: $e');
      throw const app_exceptions.DatabaseException('Failed to initialize database');
    }
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    logger.i('Creating database tables...');
    
    try {
      // Create receipts table
      await db.execute('''
        CREATE TABLE receipts (
          id TEXT PRIMARY KEY,
          original_image_path TEXT NOT NULL,
          processed_image_path TEXT,
          raw_ocr_text TEXT,
          
          -- Extracted data
          merchant_name TEXT,
          purchase_date INTEGER,
          total_amount REAL,
          subtotal_amount REAL,
          tax_amount REAL,
          payment_method TEXT,
          currency TEXT DEFAULT 'EUR',
          
          -- Metadata
          confidence_score REAL DEFAULT 0.0,
          detected_language TEXT,
          created_at INTEGER NOT NULL,
          modified_at INTEGER,
          status TEXT DEFAULT 'pending',
          is_verified INTEGER DEFAULT 0,
          receipt_number TEXT,
          notes TEXT
        )
      ''');

      // Create receipt_items table
      await db.execute('''
        CREATE TABLE receipt_items (
          id TEXT PRIMARY KEY,
          receipt_id TEXT NOT NULL,
          name TEXT NOT NULL,
          quantity INTEGER DEFAULT 1,
          unit_price REAL,
          total_price REAL NOT NULL,
          category TEXT,
          tax_rate REAL,
          description TEXT,
          sku TEXT,
          barcode TEXT,
          
          FOREIGN KEY (receipt_id) REFERENCES receipts(id) ON DELETE CASCADE
        )
      ''');

      // Create processing_history table
      await db.execute('''
        CREATE TABLE processing_history (
          id TEXT PRIMARY KEY,
          receipt_id TEXT NOT NULL,
          processing_step TEXT NOT NULL,
          duration_ms INTEGER NOT NULL,
          success INTEGER NOT NULL,
          error_message TEXT,
          applied_transformations TEXT,
          confidence_score REAL,
          created_at INTEGER NOT NULL,
          
          FOREIGN KEY (receipt_id) REFERENCES receipts(id) ON DELETE CASCADE
        )
      ''');

      // Create indexes for better performance
      await db.execute('CREATE INDEX idx_receipts_created_at ON receipts(created_at)');
      await db.execute('CREATE INDEX idx_receipts_status ON receipts(status)');
      await db.execute('CREATE INDEX idx_receipts_merchant ON receipts(merchant_name)');
      await db.execute('CREATE INDEX idx_receipt_items_receipt_id ON receipt_items(receipt_id)');
      await db.execute('CREATE INDEX idx_processing_history_receipt_id ON processing_history(receipt_id)');

      logger.i('Database tables created successfully');
    } catch (e) {
      logger.e('Failed to create database tables: $e');
      throw app_exceptions.DatabaseException('Failed to create database tables: $e');
    }
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    logger.i('Upgrading database from version $oldVersion to $newVersion');
    
    // Add migration logic here for future versions
    if (oldVersion < 2) {
      // Example migration for future version 2
      // await db.execute('ALTER TABLE receipts ADD COLUMN new_field TEXT');
    }
  }

  /// Called when database is opened
  Future<void> _onOpen(Database db) async {
    logger.d('Database opened successfully');
    
    // Enable foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON');
    
    // Set journal mode for better performance
    await db.execute('PRAGMA journal_mode = WAL');
  }

  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      logger.d('Database connection closed');
    }
  }

  /// Clear all data (for testing or reset)
  Future<void> clearAllData() async {
    try {
      final db = await database;
      
      await db.transaction((txn) async {
        await txn.delete('processing_history');
        await txn.delete('receipt_items');
        await txn.delete('receipts');
      });
      
      logger.w('All database data cleared');
    } catch (e) {
      logger.e('Failed to clear database: $e');
      throw app_exceptions.DatabaseException('Failed to clear database: $e');
    }
  }

  /// Get database statistics
  Future<Map<String, int>> getStatistics() async {
    try {
      final db = await database;
      
      final receiptsCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM receipts'),
      ) ?? 0;
      
      final itemsCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM receipt_items'),
      ) ?? 0;
      
      final processingCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM processing_history'),
      ) ?? 0;
      
      return {
        'receipts': receiptsCount,
        'items': itemsCount,
        'processing_records': processingCount,
      };
    } catch (e) {
      logger.e('Failed to get database statistics: $e');
      throw app_exceptions.DatabaseException('Failed to get database statistics: $e');
    }
  }
}