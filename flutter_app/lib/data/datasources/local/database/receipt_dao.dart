import 'package:sqflite/sqflite.dart';

import '../../../../core/errors/exceptions.dart' as app_exceptions;
import '../../../../data/models/receipt.dart';
import '../../../../data/models/receipt_item.dart';
import '../../../../main.dart';
import 'database.dart';

/// Data Access Object for Receipt operations
class ReceiptDao {
  final AppDatabase _database = AppDatabase();

  /// Insert a new receipt with its items
  Future<void> insertReceipt(Receipt receipt) async {
    try {
      final db = await _database.database;
      
      await db.transaction((txn) async {
        // Insert receipt
        await txn.insert(
          'receipts',
          _receiptToMap(receipt),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        
        // Insert receipt items
        for (final item in receipt.items) {
          await txn.insert(
            'receipt_items',
            _receiptItemToMap(item, receipt.id),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      
      logger.d('Receipt inserted: ${receipt.id}');
    } catch (e) {
      logger.e('Failed to insert receipt: $e');
      throw app_exceptions.DatabaseException('Failed to insert receipt: $e');
    }
  }

  /// Update an existing receipt
  Future<void> updateReceipt(Receipt receipt) async {
    try {
      final db = await _database.database;
      
      await db.transaction((txn) async {
        // Update receipt
        final updatedCount = await txn.update(
          'receipts',
          _receiptToMap(receipt),
          where: 'id = ?',
          whereArgs: [receipt.id],
        );
        
        if (updatedCount == 0) {
          throw app_exceptions.DatabaseException('Receipt not found: ${receipt.id}');
        }
        
        // Delete existing items
        await txn.delete(
          'receipt_items',
          where: 'receipt_id = ?',
          whereArgs: [receipt.id],
        );
        
        // Insert updated items
        for (final item in receipt.items) {
          await txn.insert(
            'receipt_items',
            _receiptItemToMap(item, receipt.id),
          );
        }
      });
      
      logger.d('Receipt updated: ${receipt.id}');
    } catch (e) {
      logger.e('Failed to update receipt: $e');
      throw app_exceptions.DatabaseException('Failed to update receipt: $e');
    }
  }

  /// Get a receipt by ID
  Future<Receipt?> getReceiptById(String id) async {
    try {
      final db = await _database.database;
      
      // Get receipt data
      final receiptMaps = await db.query(
        'receipts',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (receiptMaps.isEmpty) {
        return null;
      }
      
      // Get receipt items
      final itemMaps = await db.query(
        'receipt_items',
        where: 'receipt_id = ?',
        whereArgs: [id],
      );
      
      final items = itemMaps.map(_mapToReceiptItem).toList();
      
      return _mapToReceipt(receiptMaps.first, items);
    } catch (e) {
      logger.e('Failed to get receipt by ID: $e');
      throw app_exceptions.DatabaseException('Failed to get receipt by ID: $e');
    }
  }

  /// Get all receipts with optional filters
  Future<List<Receipt>> getReceipts({
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? merchantName,
    int? limit,
    int? offset,
  }) async {
    try {
      final db = await _database.database;
      
      // Build query conditions
      final whereConditions = <String>[];
      final whereArgs = <dynamic>[];
      
      if (status != null) {
        whereConditions.add('status = ?');
        whereArgs.add(status);
      }
      
      if (startDate != null) {
        whereConditions.add('created_at >= ?');
        whereArgs.add(startDate.millisecondsSinceEpoch);
      }
      
      if (endDate != null) {
        whereConditions.add('created_at <= ?');
        whereArgs.add(endDate.millisecondsSinceEpoch);
      }
      
      if (merchantName != null) {
        whereConditions.add('merchant_name LIKE ?');
        whereArgs.add('%$merchantName%');
      }
      
      // Execute query
      final receiptMaps = await db.query(
        'receipts',
        where: whereConditions.isNotEmpty ? whereConditions.join(' AND ') : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'created_at DESC',
        limit: limit,
        offset: offset,
      );
      
      // Get items for all receipts
      final receipts = <Receipt>[];
      for (final receiptMap in receiptMaps) {
        final receiptId = receiptMap['id'] as String;
        final itemMaps = await db.query(
          'receipt_items',
          where: 'receipt_id = ?',
          whereArgs: [receiptId],
        );
        
        final items = itemMaps.map(_mapToReceiptItem).toList();
        receipts.add(_mapToReceipt(receiptMap, items));
      }
      
      logger.d('Retrieved ${receipts.length} receipts');
      return receipts;
    } catch (e) {
      logger.e('Failed to get receipts: $e');
      throw app_exceptions.DatabaseException('Failed to get receipts: $e');
    }
  }

  /// Delete a receipt and its items
  Future<void> deleteReceipt(String id) async {
    try {
      final db = await _database.database;
      
      final deletedCount = await db.delete(
        'receipts',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (deletedCount == 0) {
        throw app_exceptions.DatabaseException('Receipt not found: $id');
      }
      
      logger.d('Receipt deleted: $id');
    } catch (e) {
      logger.e('Failed to delete receipt: $e');
      throw app_exceptions.DatabaseException('Failed to delete receipt: $e');
    }
  }

  /// Search receipts by text
  Future<List<Receipt>> searchReceipts(String searchText) async {
    try {
      final db = await _database.database;
      
      final receiptMaps = await db.rawQuery('''
        SELECT * FROM receipts 
        WHERE merchant_name LIKE ? 
           OR receipt_number LIKE ? 
           OR notes LIKE ?
           OR raw_ocr_text LIKE ?
        ORDER BY created_at DESC
      ''', ['%$searchText%', '%$searchText%', '%$searchText%', '%$searchText%']);
      
      final receipts = <Receipt>[];
      for (final receiptMap in receiptMaps) {
        final receiptId = receiptMap['id'] as String;
        final itemMaps = await db.query(
          'receipt_items',
          where: 'receipt_id = ?',
          whereArgs: [receiptId],
        );
        
        final items = itemMaps.map(_mapToReceiptItem).toList();
        receipts.add(_mapToReceipt(receiptMap, items));
      }
      
      logger.d('Search found ${receipts.length} receipts for: $searchText');
      return receipts;
    } catch (e) {
      logger.e('Failed to search receipts: $e');
      throw app_exceptions.DatabaseException('Failed to search receipts: $e');
    }
  }

  /// Get receipt statistics
  Future<Map<String, dynamic>> getReceiptStatistics() async {
    try {
      final db = await _database.database;
      
      final totalCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM receipts'),
      ) ?? 0;
      
      final totalAmount = await db.rawQuery(
        'SELECT SUM(total_amount) as total FROM receipts WHERE total_amount IS NOT NULL',
      );
      
      final statusCounts = await db.rawQuery('''
        SELECT status, COUNT(*) as count 
        FROM receipts 
        GROUP BY status
      ''');
      
      final currencyCounts = await db.rawQuery('''
        SELECT currency, COUNT(*) as count 
        FROM receipts 
        GROUP BY currency
      ''');
      
      return {
        'total_receipts': totalCount,
        'total_amount': totalAmount.first['total'] ?? 0.0,
        'status_breakdown': Map.fromEntries(
          statusCounts.map((row) => MapEntry(row['status'], row['count'])),
        ),
        'currency_breakdown': Map.fromEntries(
          currencyCounts.map((row) => MapEntry(row['currency'], row['count'])),
        ),
      };
    } catch (e) {
      logger.e('Failed to get receipt statistics: $e');
      throw app_exceptions.DatabaseException('Failed to get receipt statistics: $e');
    }
  }

  /// Convert Receipt to Map for database storage
  Map<String, dynamic> _receiptToMap(Receipt receipt) {
    return {
      'id': receipt.id,
      'original_image_path': receipt.originalImagePath,
      'processed_image_path': receipt.processedImagePath,
      'raw_ocr_text': receipt.rawOcrText,
      'merchant_name': receipt.merchantName,
      'purchase_date': receipt.purchaseDate?.millisecondsSinceEpoch,
      'total_amount': receipt.totalAmount,
      'subtotal_amount': receipt.subtotalAmount,
      'tax_amount': receipt.taxAmount,
      'payment_method': receipt.paymentMethod?.name,
      'currency': receipt.currency.code,
      'confidence_score': receipt.confidence,
      'detected_language': receipt.detectedLanguage,
      'created_at': receipt.createdAt.millisecondsSinceEpoch,
      'modified_at': receipt.modifiedAt?.millisecondsSinceEpoch,
      'status': receipt.status.name,
      'is_verified': receipt.isVerified ? 1 : 0,
      'receipt_number': receipt.receiptNumber,
      'notes': receipt.notes,
    };
  }

  /// Convert ReceiptItem to Map for database storage
  Map<String, dynamic> _receiptItemToMap(ReceiptItem item, String receiptId) {
    return {
      'id': item.id,
      'receipt_id': receiptId,
      'name': item.name,
      'quantity': item.quantity,
      'unit_price': item.unitPrice,
      'total_price': item.totalPrice,
      'category': item.category,
      'tax_rate': item.taxRate,
      'description': item.description,
      'sku': item.sku,
      'barcode': item.barcode,
    };
  }

  /// Convert database Map to Receipt
  Receipt _mapToReceipt(Map<String, dynamic> map, List<ReceiptItem> items) {
    return Receipt(
      id: map['id'],
      originalImagePath: map['original_image_path'],
      processedImagePath: map['processed_image_path'],
      rawOcrText: map['raw_ocr_text'],
      merchantName: map['merchant_name'],
      purchaseDate: map['purchase_date'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['purchase_date'])
          : null,
      totalAmount: map['total_amount']?.toDouble(),
      subtotalAmount: map['subtotal_amount']?.toDouble(),
      taxAmount: map['tax_amount']?.toDouble(),
      paymentMethod: map['payment_method'] != null
          ? PaymentMethod.values.firstWhere(
              (pm) => pm.name == map['payment_method'],
              orElse: () => PaymentMethod.unknown,
            )
          : null,
      currency: Currency.fromCode(map['currency'] ?? 'EUR'),
      items: items,
      confidence: map['confidence_score']?.toDouble() ?? 0.0,
      detectedLanguage: map['detected_language'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      modifiedAt: map['modified_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['modified_at'])
          : null,
      status: ReceiptStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => ReceiptStatus.pending,
      ),
      isVerified: map['is_verified'] == 1,
      receiptNumber: map['receipt_number'],
      notes: map['notes'],
    );
  }

  /// Convert database Map to ReceiptItem
  ReceiptItem _mapToReceiptItem(Map<String, dynamic> map) {
    return ReceiptItem(
      id: map['id'],
      name: map['name'],
      quantity: map['quantity'],
      unitPrice: map['unit_price']?.toDouble(),
      totalPrice: map['total_price'].toDouble(),
      category: map['category'],
      taxRate: map['tax_rate']?.toDouble(),
      description: map['description'],
      sku: map['sku'],
      barcode: map['barcode'],
    );
  }
}