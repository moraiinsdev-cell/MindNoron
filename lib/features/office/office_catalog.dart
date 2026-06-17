import 'office_sprites.dart';
import 'pixel_art.dart';

/// A buyable/placeable item in build mode. Reuses the existing furniture
/// sprites; [tw]×[th] is its tile footprint and [blocks] whether it obstructs
/// walking (decor like cushions and stools stays walk-over-able).
class CatalogItem {
  const CatalogItem(
    this.id,
    this.label,
    this.sprite, {
    required this.price,
    this.tw = 1,
    this.th = 1,
    this.blocks = true,
    this.emoji = '🪑',
  });

  final String id;
  final String label;
  final PixelSprite sprite;
  final int price;
  final int tw;
  final int th;
  final bool blocks;
  final String emoji;
}

/// The MindNoron build-mode catalog. Prices scale loosely with how much the
/// piece dresses up a room. Owning an item lets you place it any number of
/// times; placement itself is free.
final officeCatalog = <CatalogItem>[
  CatalogItem('plant', 'Potted plant', plantSprite, price: 15, emoji: '🪴'),
  CatalogItem('bonsai', 'Bonsai', bonsaiSprite, price: 25, emoji: '🌳'),
  CatalogItem('lamp', 'Floor lamp', lampSprite, price: 20, emoji: '💡'),
  CatalogItem('cushion', 'Floor cushion', cushionSprite,
      price: 12, blocks: false, emoji: '🟪'),
  CatalogItem('stool', 'Stool', stoolSprite,
      price: 12, blocks: false, emoji: '🪑'),
  CatalogItem('armchair', 'Armchair', armchairSprite, price: 40, emoji: '🛋️'),
  CatalogItem('cafeTable', 'Café table', cafeTableSprite,
      price: 30, emoji: '☕'),
  CatalogItem('loungeTable', 'Coffee table', loungeTableSprite,
      price: 28, emoji: '🛋️'),
  CatalogItem('bookshelf', 'Bookshelf', bookshelfSprite, price: 45, emoji: '📚'),
  CatalogItem('sofa', 'Sofa', sofaSprite, price: 80, tw: 2, emoji: '🛋️'),
  CatalogItem('umbrella', 'Parasol', umbrellaSprite,
      price: 50, th: 2, emoji: '⛱️'),
  CatalogItem('lounger', 'Sun lounger', loungerSprite,
      price: 55, th: 2, emoji: '🏖️'),
  CatalogItem('dumbbells', 'Dumbbell rack', dumbbellRackSprite,
      price: 60, emoji: '🏋️'),
  CatalogItem('vending', 'Vending machine', vendingSprite,
      price: 95, emoji: '🥤'),
  CatalogItem('server', 'Server rack', serverRackSprite, price: 70, emoji: '🖥️'),
  CatalogItem('safe', 'Safe', safeSprite, price: 120, emoji: '🔒'),
];

CatalogItem? catalogItem(String id) {
  for (final c in officeCatalog) {
    if (c.id == id) return c;
  }
  return null;
}
