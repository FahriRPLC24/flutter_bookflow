/// Model data buku. Satu objek [Book] mewakili satu baris tabel `books`.
class Book {
  final int? id;
  final String code;
  final String title;
  final String author;
  final String publisher;
  final String category;
  final int? year;
  final String shelf;
  final int totalStock;
  final int availableStock;
  /// Diisi oleh query laporan (top books). Null jika bukan hasil query itu.
  final int? borrowedTotal;

  const Book({
    this.id,
    required this.code,
    required this.title,
    this.author = '',
    this.publisher = '',
    this.category = '',
    this.year,
    this.shelf = '',
    required this.totalStock,
    required this.availableStock,
    this.borrowedTotal,
  });

  factory Book.fromMap(Map<String, Object?> map) {
    return Book(
      id: map['id'] as int?,
      code: map['code'] as String,
      title: map['title'] as String,
      author: (map['author'] as String?) ?? '',
      publisher: (map['publisher'] as String?) ?? '',
      category: (map['category'] as String?) ?? '',
      year: (map['year'] as num?)?.toInt(),
      shelf: (map['shelf'] as String?) ?? '',
      totalStock: (map['total_stock'] as num).toInt(),
      availableStock: (map['available_stock'] as num).toInt(),
      borrowedTotal: (map['borrowed_total'] as num?)?.toInt(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'code': code,
      'title': title,
      'author': author,
      'publisher': publisher,
      'category': category,
      'year': year,
      'shelf': shelf,
      'total_stock': totalStock,
      'available_stock': availableStock,
    };
  }

  int get borrowedCount => totalStock - availableStock;
}