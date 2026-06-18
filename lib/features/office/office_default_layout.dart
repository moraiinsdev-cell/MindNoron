import 'office_economy.dart';

/// The furniture every new campus ships with — so MindNoron Inc. looks like a
/// fully built-out, "MAX level" office out of the box instead of bare floors,
/// without the player having to earn coins or decorate by hand.
///
/// These pieces seed the build-mode layout the same way [defaultStaff] seeds
/// the roster: they are a fallback the repository returns when the player has
/// never saved a layout. The moment the player edits anything in build mode the
/// full effective set is persisted, so decorating stays fully optional.
///
/// Items use the regular [officeCatalog] ids and are placed on open floor,
/// clear of the static furniture, walls, the pool and the front door.
List<PlacedItem> defaultLayout() => const [
      // --- TASKS bullpen: greenery down the side aisles -------------------
      PlacedItem(itemId: 'bonsai', tx: 16, ty: 3),
      PlacedItem(itemId: 'lamp', tx: 2, ty: 6),
      PlacedItem(itemId: 'plant', tx: 16, ty: 6),
      PlacedItem(itemId: 'lamp', tx: 2, ty: 10),
      PlacedItem(itemId: 'plant', tx: 16, ty: 10),
      PlacedItem(itemId: 'plant', tx: 2, ty: 14),
      PlacedItem(itemId: 'plant', tx: 16, ty: 14),

      // --- ANALYTICS / CALENDAR: meeting-area dressing --------------------
      PlacedItem(itemId: 'plant', tx: 21, ty: 5),
      PlacedItem(itemId: 'bonsai', tx: 23, ty: 5),
      PlacedItem(itemId: 'plant', tx: 27, ty: 7),
      PlacedItem(itemId: 'bonsai', tx: 25, ty: 7),
      PlacedItem(itemId: 'plant', tx: 33, ty: 7),
      PlacedItem(itemId: 'plant', tx: 35, ty: 8),

      // --- FINANCE vault: tidy the counting room --------------------------
      PlacedItem(itemId: 'plant', tx: 29, ty: 16),
      PlacedItem(itemId: 'bonsai', tx: 31, ty: 16),
      PlacedItem(itemId: 'plant', tx: 36, ty: 16),

      // --- FOCUS room: a calmer, greener quiet space ----------------------
      PlacedItem(itemId: 'lamp', tx: 8, ty: 20),
      PlacedItem(itemId: 'plant', tx: 2, ty: 21),
      PlacedItem(itemId: 'plant', tx: 8, ty: 21),
      PlacedItem(itemId: 'cushion', tx: 4, ty: 20),
      PlacedItem(itemId: 'cushion', tx: 6, ty: 20),

      // --- LIBRARY: more shelves + a second reading nook ------------------
      PlacedItem(itemId: 'bookshelf', tx: 17, ty: 16),
      PlacedItem(itemId: 'bookshelf', tx: 18, ty: 16),
      PlacedItem(itemId: 'armchair', tx: 17, ty: 19),
      PlacedItem(itemId: 'lamp', tx: 16, ty: 21),
      PlacedItem(itemId: 'plant', tx: 12, ty: 21),
      PlacedItem(itemId: 'plant', tx: 19, ty: 21),

      // --- INBOX mailroom -------------------------------------------------
      PlacedItem(itemId: 'plant', tx: 22, ty: 20),
      PlacedItem(itemId: 'bonsai', tx: 26, ty: 20),

      // --- LOUNGE conversation pit ----------------------------------------
      PlacedItem(itemId: 'loungeTable', tx: 33, ty: 24),
      PlacedItem(itemId: 'plant', tx: 37, ty: 25),
      PlacedItem(itemId: 'cushion', tx: 32, ty: 24),
      PlacedItem(itemId: 'cushion', tx: 34, ty: 24),

      // --- GYM: more iron + greenery --------------------------------------
      PlacedItem(itemId: 'dumbbells', tx: 9, ty: 28),
      PlacedItem(itemId: 'dumbbells', tx: 3, ty: 33),
      PlacedItem(itemId: 'plant', tx: 12, ty: 24),
      PlacedItem(itemId: 'bonsai', tx: 2, ty: 26),
      PlacedItem(itemId: 'plant', tx: 11, ty: 33),

      // --- CAFÉ: extra seating + plants -----------------------------------
      PlacedItem(itemId: 'cafeTable', tx: 25, ty: 29),
      PlacedItem(itemId: 'plant', tx: 15, ty: 28),
      PlacedItem(itemId: 'plant', tx: 26, ty: 33),

      // --- Reception / entrance hall --------------------------------------
      PlacedItem(itemId: 'plant', tx: 33, ty: 28),
      PlacedItem(itemId: 'bonsai', tx: 35, ty: 30),
      PlacedItem(itemId: 'plant', tx: 29, ty: 33),
      PlacedItem(itemId: 'plant', tx: 36, ty: 33),

      // --- GARDEN north: greenery between the windows and the pool --------
      PlacedItem(itemId: 'bonsai', tx: 44, ty: 3),
      PlacedItem(itemId: 'plant', tx: 48, ty: 4),
      PlacedItem(itemId: 'bonsai', tx: 52, ty: 4),

      // --- POOLSIDE: a proper sun deck ------------------------------------
      PlacedItem(itemId: 'lounger', tx: 45, ty: 19),
      PlacedItem(itemId: 'lounger', tx: 47, ty: 19),
      PlacedItem(itemId: 'umbrella', tx: 50, ty: 19),
      PlacedItem(itemId: 'plant', tx: 40, ty: 18),

      // --- ENTERTAINMENT wing: removable extras dressing the new rooms ----
      // (the arcade cabinets, pool table, cinema screen and bar counter are
      // permanent fixtures in office_map.dart; these are the soft decor.)
      PlacedItem(itemId: 'plant', tx: 40, ty: 26), // arcade
      PlacedItem(itemId: 'bonsai', tx: 39, ty: 30), // cinema corner
      PlacedItem(itemId: 'cushion', tx: 43, ty: 34), // cinema floor seating
      PlacedItem(itemId: 'cushion', tx: 45, ty: 34),
      PlacedItem(itemId: 'stool', tx: 50, ty: 32), // bar stools
      PlacedItem(itemId: 'stool', tx: 53, ty: 32),
      PlacedItem(itemId: 'plant', tx: 53, ty: 33), // bar

      // --- Second pass: denser greenery & props to fill the open floors ---
      PlacedItem(itemId: 'plant', tx: 16, ty: 8), // tasks aisle
      // GYM
      PlacedItem(itemId: 'plant', tx: 2, ty: 28),
      PlacedItem(itemId: 'plant', tx: 2, ty: 30),
      PlacedItem(itemId: 'plant', tx: 12, ty: 28),
      PlacedItem(itemId: 'bonsai', tx: 8, ty: 26),
      PlacedItem(itemId: 'dumbbells', tx: 8, ty: 33),
      // CAFÉ
      PlacedItem(itemId: 'plant', tx: 15, ty: 30),
      PlacedItem(itemId: 'plant', tx: 26, ty: 30),
      PlacedItem(itemId: 'plant', tx: 17, ty: 34),
      PlacedItem(itemId: 'plant', tx: 24, ty: 34),
      // FOCUS / LIBRARY / INBOX
      PlacedItem(itemId: 'cushion', tx: 2, ty: 20),
      PlacedItem(itemId: 'cushion', tx: 8, ty: 18),
      PlacedItem(itemId: 'bonsai', tx: 19, ty: 21),
      PlacedItem(itemId: 'plant', tx: 22, ty: 18),
      // LOUNGE
      PlacedItem(itemId: 'cushion', tx: 30, ty: 24),
      PlacedItem(itemId: 'cushion', tx: 36, ty: 24),
      // GARDEN north + sides
      PlacedItem(itemId: 'bonsai', tx: 41, ty: 3),
      PlacedItem(itemId: 'plant', tx: 45, ty: 3),
      PlacedItem(itemId: 'bonsai', tx: 50, ty: 3),
      PlacedItem(itemId: 'plant', tx: 54, ty: 5),
      PlacedItem(itemId: 'plant', tx: 39, ty: 16),
      PlacedItem(itemId: 'bonsai', tx: 54, ty: 16),
      PlacedItem(itemId: 'plant', tx: 40, ty: 20),
      PlacedItem(itemId: 'plant', tx: 53, ty: 20),
      // POOLSIDE extras
      PlacedItem(itemId: 'lounger', tx: 41, ty: 19),
      PlacedItem(itemId: 'umbrella', tx: 43, ty: 21),
    ];
