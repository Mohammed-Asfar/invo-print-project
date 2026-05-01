import '../../../../core/firebase/customer_firestore_rest_client.dart';
import '../../domain/entities/product_service.dart';
import '../models/product_service_model.dart';

class ProductRepository {
  ProductRepository(this._firestore);

  final CustomerFirestoreRestClient _firestore;

  Future<List<ProductService>> fetchProducts() async {
    final documents = await _firestore.listDocuments('products');
    final products =
        documents
            .map(
              (document) =>
                  ProductServiceModel.fromMap(document.id, document.data),
            )
            .where((product) => product.isActive)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return products;
  }

  Future<void> saveProduct(ProductService product) {
    final now = DateTime.now();
    final id = product.id.isEmpty
        ? 'prod_${now.microsecondsSinceEpoch}'
        : product.id;
    final model = ProductServiceModel.fromEntity(
      ProductService(
        id: id,
        name: product.name,
        description: product.description,
        type: product.type,
        unit: product.unit,
        defaultRate: product.defaultRate,
        hsnSac: product.hsnSac,
        gstRate: product.gstRate,
        isActive: product.isActive,
        createdAt: product.id.isEmpty ? now : product.createdAt,
        updatedAt: now,
      ),
    );
    return _firestore.setDocument('products', id, model.toMap());
  }

  Future<void> archiveProduct(ProductService product) {
    final archived = ProductService(
      id: product.id,
      name: product.name,
      description: product.description,
      type: product.type,
      unit: product.unit,
      defaultRate: product.defaultRate,
      hsnSac: product.hsnSac,
      gstRate: product.gstRate,
      isActive: false,
      createdAt: product.createdAt,
      updatedAt: DateTime.now(),
    );
    return _firestore.setDocument(
      'products',
      product.id,
      ProductServiceModel.fromEntity(archived).toMap(),
    );
  }
}
