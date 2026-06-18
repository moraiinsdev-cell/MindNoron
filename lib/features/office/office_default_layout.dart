import 'office_economy.dart';

/// The furniture every new campus ships with — so MindNoron Inc. looks like a
/// finished, "MAX level" office out of the box instead of bare floors, without
/// the player having to earn coins or decorate by hand.
///
/// Curated like a real fit-out: a few intentional accent pieces per room
/// (lamps, a bonsai, a reading nook, poolside loungers) rather than plants on
/// every tile. Room *structure* comes from the walls in office_map.dart; this
/// is just the soft dressing.
///
/// Seeds the build-mode layout the same way [defaultStaff] seeds the roster: a
/// fallback the repository returns until the player saves their own layout, so
/// decorating stays fully optional.
List<PlacedItem> defaultLayout() => const [
      // --- TASKS bullpen: a couple of corner lamps -----------------------
      PlacedItem(itemId: 'lamp', tx: 2, ty: 6),
      PlacedItem(itemId: 'lamp', tx: 16, ty: 12),
      PlacedItem(itemId: 'bonsai', tx: 16, ty: 3),

      // --- CALENDAR / ANALYTICS: a little greenery by the meeting table --
      PlacedItem(itemId: 'bonsai', tx: 25, ty: 7),
      PlacedItem(itemId: 'plant', tx: 36, ty: 7),

      // --- FINANCE vault -------------------------------------------------
      PlacedItem(itemId: 'bonsai', tx: 31, ty: 16),

      // --- FOCUS room: lamp + meditation cushions ------------------------
      PlacedItem(itemId: 'lamp', tx: 8, ty: 20),
      PlacedItem(itemId: 'cushion', tx: 4, ty: 20),
      PlacedItem(itemId: 'cushion', tx: 6, ty: 20),

      // --- LIBRARY: more shelves + a reading nook ------------------------
      PlacedItem(itemId: 'bookshelf', tx: 17, ty: 16),
      PlacedItem(itemId: 'bookshelf', tx: 18, ty: 16),
      PlacedItem(itemId: 'armchair', tx: 17, ty: 19),
      PlacedItem(itemId: 'lamp', tx: 16, ty: 21),

      // --- INBOX ---------------------------------------------------------
      PlacedItem(itemId: 'plant', tx: 26, ty: 20),

      // --- LOUNGE conversation pit ---------------------------------------
      PlacedItem(itemId: 'loungeTable', tx: 33, ty: 24),
      PlacedItem(itemId: 'cushion', tx: 32, ty: 24),
      PlacedItem(itemId: 'cushion', tx: 34, ty: 24),

      // --- GYM: extra iron -----------------------------------------------
      PlacedItem(itemId: 'dumbbells', tx: 9, ty: 28),
      PlacedItem(itemId: 'dumbbells', tx: 8, ty: 33),
      PlacedItem(itemId: 'bonsai', tx: 2, ty: 26),

      // --- CAFÉ: one more table ------------------------------------------
      PlacedItem(itemId: 'cafeTable', tx: 25, ty: 29),
      PlacedItem(itemId: 'plant', tx: 15, ty: 28),

      // --- Reception / entrance hall -------------------------------------
      PlacedItem(itemId: 'plant', tx: 33, ty: 28),
      PlacedItem(itemId: 'bonsai', tx: 35, ty: 30),

      // --- GARDEN north --------------------------------------------------
      PlacedItem(itemId: 'bonsai', tx: 44, ty: 3),
      PlacedItem(itemId: 'plant', tx: 50, ty: 3),

      // --- POOLSIDE sun deck ---------------------------------------------
      PlacedItem(itemId: 'lounger', tx: 45, ty: 19),
      PlacedItem(itemId: 'lounger', tx: 47, ty: 19),
      PlacedItem(itemId: 'umbrella', tx: 50, ty: 19),
      PlacedItem(itemId: 'plant', tx: 40, ty: 18),

      // --- ENTERTAINMENT wing: soft seating around the fixtures ----------
      PlacedItem(itemId: 'cushion', tx: 43, ty: 34), // cinema
      PlacedItem(itemId: 'cushion', tx: 45, ty: 34),
      PlacedItem(itemId: 'stool', tx: 50, ty: 32), // bar
      PlacedItem(itemId: 'stool', tx: 53, ty: 32),
      PlacedItem(itemId: 'bonsai', tx: 53, ty: 30),
    ];
