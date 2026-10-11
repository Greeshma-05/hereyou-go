import 'product_model.dart';

class CartItem {
  const CartItem(this.product, this.quantity);
  final Product product;
  final int quantity;
  int get subtotalPaise => product.pricePaise * quantity;
}
