/// All artwork for MindNoron Inc. — hand-drawn in code as pixel grids.
///
/// Character sprites are a 12x17 chibi template assembled from a head
/// (hair style x facing) and a body (facing x animation frame). Semantic
/// palette characters (H hair, S skin, T shirt...) get recolored per
/// employee, so one template yields a whole cast.
library;

import 'package:flutter/painting.dart';

import 'pixel_art.dart';

// ---------------------------------------------------------------------------
// Shared palette characters for characters
// ---------------------------------------------------------------------------
// H hair        h hair shadow
// S skin        s skin shadow     E eye
// T shirt       t shirt shadow
// P pants       F shoes
const characterBasePalette = <String, Color>{
  'H': Color(0xFF2E2A28),
  'h': Color(0xFF1F1C1B),
  'S': Color(0xFFF2C9A0),
  's': Color(0xFFD9A877),
  'E': Color(0xFF2A2226),
  'T': Color(0xFF3E7CB8),
  't': Color(0xFF2F5E8C),
  'P': Color(0xFF3A4254),
  'F': Color(0xFF24262C),
};

/// Selectable colors used to give each employee a unique look.
const skinTones = <Color>[
  Color(0xFFF2C9A0),
  Color(0xFFE3B58A),
  Color(0xFFC68E5E),
  Color(0xFF9C6B42),
];

const hairColors = <Color>[
  Color(0xFF2E2A28), // black
  Color(0xFF6B4A2F), // brown
  Color(0xFFC7903B), // blond
  Color(0xFFB6452C), // ginger
  Color(0xFF7A4A8C), // purple
  Color(0xFF4E6E8C), // blue-gray
  Color(0xFF3E6B4F), // green
];

const shirtColors = <Color>[
  Color(0xFFB8533F), // brick
  Color(0xFF3E7CB8), // blue
  Color(0xFF4D9E68), // green
  Color(0xFFC9A227), // mustard
  Color(0xFF8C5BA8), // violet
  Color(0xFFD27D9C), // pink
  Color(0xFF5BAA9E), // teal
  Color(0xFF6B7280), // slate
];

const pantsColors = <Color>[
  Color(0xFF3A4254), // navy
  Color(0xFF5A4632), // khaki
  Color(0xFF2F3338), // charcoal
];

Color _darken(Color c, [double f = 0.72]) => Color.fromARGB(
      255,
      ((c.r * 255.0) * f).round(),
      ((c.g * 255.0) * f).round(),
      ((c.b * 255.0) * f).round(),
    );

/// Builds the palette for a specific employee look.
Map<String, Color> paletteForLook({
  required int skin,
  required int hairColor,
  required int shirt,
  required int pants,
}) {
  final skinC = skinTones[skin % skinTones.length];
  final hairC = hairColors[hairColor % hairColors.length];
  final shirtC = shirtColors[shirt % shirtColors.length];
  final pantsC = pantsColors[pants % pantsColors.length];
  return {
    ...characterBasePalette,
    'S': skinC,
    's': _darken(skinC, 0.82),
    'H': hairC,
    'h': _darken(hairC, 0.68),
    'T': shirtC,
    't': _darken(shirtC, 0.74),
    'P': pantsC,
  };
}

// ---------------------------------------------------------------------------
// Character heads: 8 rows x 12 cols, per hair style and facing
// ---------------------------------------------------------------------------

const hairStyleCount = 3; // 0 short, 1 bob, 2 spiky

List<String> _headDown(int style) => switch (style % hairStyleCount) {
      0 => const [
          '...HHHHHH...',
          '..HHHHHHHH..',
          '.HHHHHHHHHH.',
          '.HHhhhhhhHH.',
          '.hSSSSSSSSh.',
          '.SSESSSSESS.',
          '..SSSSSSSS..',
          '...ssSSss...',
        ],
      1 => const [
          '...HHHHHH...',
          '..HHHHHHHH..',
          '.HHHHHHHHHH.',
          '.HHhhhhhhHH.',
          '.HSSSSSSSSH.',
          'HHSESSSSESHH',
          'HH.SSSSSS.HH',
          '.H..ssss..H.',
        ],
      _ => const [
          '..H.HHHH.H..',
          '..HHHHHHHH..',
          '.HHHHHHHHHH.',
          '.HhHhhhhHhH.',
          '.hSSSSSSSSh.',
          '.SSESSSSESS.',
          '..SSSSSSSS..',
          '...ssSSss...',
        ],
    };

List<String> _headUp(int style) => switch (style % hairStyleCount) {
      0 => const [
          '...HHHHHH...',
          '..HHHHHHHH..',
          '.HHHHHHHHHH.',
          '.HHHHHHHHHH.',
          '.HHHHHHHHHH.',
          '.hHHHHHHHHh.',
          '..hHHHHHHh..',
          '...hhhhhh...',
        ],
      1 => const [
          '...HHHHHH...',
          '..HHHHHHHH..',
          '.HHHHHHHHHH.',
          '.HHHHHHHHHH.',
          'HHHHHHHHHHHH',
          'HHhHHHHHHhHH',
          'HH.hHHHHh.HH',
          '.H..hhhh..H.',
        ],
      _ => const [
          '..H.HHHH.H..',
          '..HHHHHHHH..',
          '.HHHHHHHHHH.',
          '.HHHHHHHHHH.',
          '.HHHHHHHHHH.',
          '.hHHHHHHHHh.',
          '..hHHHHHHh..',
          '...hhhhhh...',
        ],
    };

/// Right-facing profile; left is the X-flip.
List<String> _headSide(int style) => switch (style % hairStyleCount) {
      0 => const [
          '...HHHHHH...',
          '..HHHHHHHH..',
          '.HHHHHHHHHH.',
          '.HHHhhhhSSS.',
          '.HHhSSSSSES.',
          '.HHhSSSSSSS.',
          '..HhSSSSss..',
          '...hssss....',
        ],
      1 => const [
          '...HHHHHH...',
          '..HHHHHHHH..',
          '.HHHHHHHHHH.',
          '.HHHhhhhSSS.',
          'HHHhSSSSSES.',
          'HHHhSSSSSSS.',
          'HH.hSSSSss..',
          '.H..ssss....',
        ],
      _ => const [
          '..H.HHHH.H..',
          '..HHHHHHHH..',
          '.HHHHHHHHHH.',
          '.HHHhhhhSSS.',
          '.HHhSSSSSES.',
          '.HHhSSSSSSS.',
          '..HhSSSSss..',
          '...hssss....',
        ],
    };

// ---------------------------------------------------------------------------
// Character bodies: 9 rows x 12 cols (rows 8..16 of the figure)
// ---------------------------------------------------------------------------

const _bodyDownIdle = [
  '..TTTTTTTT..',
  '.TTTTTTTTTT.',
  '.TtTTTTTTtT.',
  '.SsTTTTTTsS.',
  '..tTTTTTTt..',
  '...PPPPPP...',
  '...PP..PP...',
  '...PP..PP...',
  '..FFF..FFF..',
];

const _bodyDownWalkA = [
  '..TTTTTTTT..',
  '.TTTTTTTTTT.',
  '.TtTTTTTTtT.',
  '.SsTTTTTTsS.',
  '..tTTTTTTt..',
  '...PPPPPP...',
  '..PPP..PP...',
  '..FF...PP...',
  '.......FFF..',
];

const _bodyDownWalkB = [
  '..TTTTTTTT..',
  '.TTTTTTTTTT.',
  '.TtTTTTTTtT.',
  '.SsTTTTTTsS.',
  '..tTTTTTTt..',
  '...PPPPPP...',
  '...PP..PPP..',
  '...PP...FF..',
  '..FFF.......',
];

const _bodySideIdle = [
  '...TTTTTT...',
  '..TTTTTTTT..',
  '..TTTTTtsT..',
  '..tTTTTTTT..',
  '..TTTTTTt...',
  '....PPPP....',
  '....PPPP....',
  '....PP.P....',
  '....FFF.....',
];

const _bodySideWalkA = [
  '...TTTTTT...',
  '..TTTTTTTT..',
  '..TTTTTtsT..',
  '..tTTTTTTT..',
  '..TTTTTTt...',
  '....PPPP....',
  '...PP.PP....',
  '...FF..PP...',
  '.......FF...',
];

const _bodySideWalkB = [
  '...TTTTTT...',
  '..TTTTTTTT..',
  '..TTTTTtsT..',
  '..tTTTTTTT..',
  '..TTTTTTt...',
  '....PPPP....',
  '....PP.PP...',
  '....PP..FF..',
  '...FF.......',
];

/// Seated torso (used at desks, drawn over a chair; legs hidden by the desk).
const _bodySitBack = [
  '..TTTTTTTT..',
  '.TTTTTTTTTT.',
  '.TtTTTTTTtT.',
  '.SsTTTTTTsS.',
  '..tttttttt..',
];

/// Seated facing the viewer (sofa): lap + bent legs.
const _bodySitFront = [
  '..TTTTTTTT..',
  '.TTTTTTTTTT.',
  '.TtTTTTTTtT.',
  '.SsTTTTTTsS.',
  '..PPPPPPPP..',
  '..PP....PP..',
  '..FFF..FFF..',
];

/// Character animation frames.
enum CharFrame {
  downIdle,
  downWalkA,
  downWalkB,
  upIdle,
  upWalkA,
  upWalkB,
  sideIdle, // right-facing; flip for left
  sideWalkA,
  sideWalkB,
  sitBack, // typing at a desk, seen from behind
  sitFront, // lounging on the sofa
}

/// Assembles the 12-wide pixel grid for [frame] with hair [style].
List<String> characterRows(CharFrame frame, int style) {
  switch (frame) {
    case CharFrame.downIdle:
      return [..._headDown(style), ..._bodyDownIdle];
    case CharFrame.downWalkA:
      return [..._headDown(style), ..._bodyDownWalkA];
    case CharFrame.downWalkB:
      return [..._headDown(style), ..._bodyDownWalkB];
    case CharFrame.upIdle:
      return [..._headUp(style), ..._bodyDownIdle];
    case CharFrame.upWalkA:
      return [..._headUp(style), ..._bodyDownWalkA];
    case CharFrame.upWalkB:
      return [..._headUp(style), ..._bodyDownWalkB];
    case CharFrame.sideIdle:
      return [..._headSide(style), ..._bodySideIdle];
    case CharFrame.sideWalkA:
      return [..._headSide(style), ..._bodySideWalkA];
    case CharFrame.sideWalkB:
      return [..._headSide(style), ..._bodySideWalkB];
    case CharFrame.sitBack:
      return [..._headUp(style), ..._bodySitBack];
    case CharFrame.sitFront:
      return [..._headDown(style), ..._bodySitFront];
  }
}

PixelSprite characterSprite(
  CharFrame frame, {
  required int style,
  required Map<String, Color> palette,
}) {
  return PixelSprite(characterRows(frame, style), palette);
}

// ---------------------------------------------------------------------------
// Furniture sprites
// ---------------------------------------------------------------------------

const _wood = Color(0xFFC89B66);
const _woodDark = Color(0xFF8A6240);
const _woodEdge = Color(0xFF4A3A30);

/// Work desk, 32x20. Monitor screen pixels use 's'; the painter draws an
/// animated glow on top so screens flicker while someone works.
final deskSprite = PixelSprite(const [
  '....nnnnnnnnnnnn................',
  '....nssssssssssn................',
  '....nszzsssszssn................',
  '....nsssszzssssn................',
  '....nszzsssszssn................',
  '....nnnnnnnnnnnn................',
  'oooooooonnoooooooooooooooooooooo',
  'owwwwwwwnnwwwwwwwwwwqqqqqqqwwwwo',
  'owwwwwwnnnnwwwwwwwwwqlqllqqwuuwo',
  'owwwwwwwwwwwwwwwwwwwqqqqlqqwuuwo',
  'owwwkkkkkkkkkkwwwwwwqlqqqqqwwwwo',
  'owwwkjkjkjkjkkwwwwwwqqqlqqqwwwwo',
  'owwwkkkkkkkkkkwwwwwwqqqqqqqwwwwo',
  'owwwwwwwwwwwwwwwwwwwwwwwwwwwwwwo',
  'oooooooooooooooooooooooooooooooo',
  'odddddddddddddddddddddddddddddoo',
  'odddddddddddddddddddddddddddddoo',
  '.oooooooooooooooooooooooooooooo.',
  '..oo..........................oo',
  '..oo..........................oo',
], const {
  'n': Color(0xFF20242C), // monitor frame
  's': Color(0xFF9FD2E8), // screen
  'z': Color(0xFF5E8CA8), // screen detail
  'o': _woodEdge,
  'w': _wood,
  'd': _woodDark,
  'k': Color(0xFF4E4A46), // keyboard base
  'j': Color(0xFF6A6660), // key caps
  'q': Color(0xFFF5F2EA), // paper
  'l': Color(0xFFAEBCCE), // paper lines
  'u': Color(0xFFC96A4A), // mug
});

/// Office chair, 16x14 (drawn under the seated character).
final chairSprite = PixelSprite(const [
  '....oooooooo....',
  '...oBBBBBBBBo...',
  '...oBBBBBBBBo...',
  '...oBBBBBBBBo...',
  '...oBBBBBBBBo...',
  '....oBBBBBBo....',
  '....obbbbbbo....',
  '...obbbbbbbbo...',
  '...obbbbbbbbo...',
  '....obbbbbbo....',
  '......o..o......',
  '.......oo.......',
  '.....o.oo.o.....',
  '....oo.oo.oo....',
], const {
  'o': Color(0xFF23252E),
  'B': Color(0xFF3E4250),
  'b': Color(0xFF565B6C),
});

/// Potted plant, 16x22.
final plantSprite = PixelSprite(const [
  '......GG..G.....',
  '..G..GGGGGG.....',
  '.GGG.GGgGGGG.G..',
  '.GgGGGgGGGgGGG..',
  '..GGgGGGGGGGgG..',
  '.GGgGGGgGGgGGG..',
  '.GgGGGGGGGGGg...',
  '..GGgGGgGGGG....',
  '...GGGGGGgG.....',
  '....gGGGg.......',
  '......G.G.......',
  '......G.........',
  '....ttttttt.....',
  '....tTTTTTt.....',
  '.....tTTTt......',
  '.....tTTTt......',
  '.....ttttt......',
], const {
  'G': Color(0xFF5FA052),
  'g': Color(0xFF3F7A3C),
  'T': Color(0xFFB06A4A),
  't': Color(0xFF7E4A33),
});

/// Water cooler, 14x22.
final waterCoolerSprite = PixelSprite(const [
  '...wwwwwww....',
  '..wWWbbbWWw...',
  '..wWbbbbbWw...',
  '..wWbbbbbWw...',
  '..wWWbbbWWw...',
  '..wwwwwwwww...',
  '..cCCCCCCCc...',
  '..cCCCCCCCc...',
  '..cCmCCCmCc...',
  '..cCCCCCCCc...',
  '..cCCCCCCCc...',
  '..cCCCCCCCc...',
  '..cCCCCCCCc...',
  '..ccccccccc...',
  '...c.....c....',
], const {
  'w': Color(0xFF7FB6D0),
  'W': Color(0xFFA8D4E8),
  'b': Color(0xFF5FA8D4),
  'C': Color(0xFFE8E6E0),
  'c': Color(0xFFA8A6A0),
  'm': Color(0xFF4A6E8C), // taps
});

/// Kitchen counter with coffee machine, 32x22.
final coffeeCounterSprite = PixelSprite(const [
  '......aaaaaaaaaa................',
  '......aAAAAAAAAa................',
  '......aArAAAAAAa................',
  '......aaaaaaaaaa................',
  '......aA.AAAA.Aa................',
  '......aA.uuuu.Aa................',
  '......aA.uuuu.Aa................',
  '......aaaaaaaaaa....mm..mm..mm..',
  'oooooooooooooooooooommoommoommoo',
  'occccccccccccccccccccccccccccco.',
  'occccccccccccccccccccccccccccco.',
  'oCCCCCCCCCCCCCCCCCCCCCCCCCCCCCo.',
  'oCCCCCCCCCCCCCCCCCCCCCCCCCCCCCo.',
  'oCCdCCCCCCCCCCCCCCCCCCCCdCCCCCo.',
  'oCCCCCCCCCCCCCCCCCCCCCCCCCCCCCo.',
  'oCCCCCCCCCCCCCCCCCCCCCCCCCCCCCo.',
  'ooooooooooooooooooooooooooooooo.',
], const {
  'a': Color(0xFF33333B), // coffee machine body
  'A': Color(0xFF4A4A55),
  'r': Color(0xFFD24A3E), // power light
  'u': Color(0xFF7A4A33), // carafe / coffee
  'm': Color(0xFFE8E6E0), // mugs on the counter
  'o': Color(0xFF6E6258),
  'c': Color(0xFFD8D4CC), // counter top
  'C': Color(0xFFB8B2A8), // cabinet front
  'd': Color(0xFF8A8278), // handles
});

/// Sofa (faces down), 32x18.
final sofaSprite = PixelSprite(const [
  '.oooooooooooooooooooooooooooooo.',
  'oSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSo',
  'oSSSSSSSSSSSSSSSdSSSSSSSSSSSSSSo',
  'oSSSSSSSSSSSSSSSdSSSSSSSSSSSSSSo',
  'oSSSSSSSSSSSSSSSdSSSSSSSSSSSSSSo',
  'oossssssssssssssssssssssssssssoo',
  'oCCsssssssssssssssssssssssssCCCo',
  'oCCsSSSSSSSSSSSSdSSSSSSSSSSsCCCo',
  'oCCsSSSSSSSSSSSSdSSSSSSSSSSsCCCo',
  'oCCsSSSSSSSSSSSSdSSSSSSSSSSsCCCo',
  'oCCssssssssssssssssssssssssssCCo',
  'oCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCo',
  '.oooooooooooooooooooooooooooooo.',
  '.oo...........................oo',
], const {
  'o': Color(0xFF2E3A3C),
  'S': Color(0xFF5E8B87),
  's': Color(0xFF46706C),
  'C': Color(0xFF537E7A),
  'd': Color(0xFF3A5C58), // cushion seam
});

/// Bookshelf, 16x26 — colored spines give the wall life.
final bookshelfSprite = PixelSprite(const [
  'oooooooooooooooo',
  'owwwwwwwwwwwwwwo',
  'owrrbbggyywwppwo',
  'owrrbbggyywwppwo',
  'owrrbbggyywwppwo',
  'owwwwwwwwwwwwwwo',
  'oooooooooooooooo',
  'owwwwwwwwwwwwwwo',
  'owggyyrrwwbbggwo',
  'owggyyrrwwbbggwo',
  'owggyyrrwwbbggwo',
  'owwwwwwwwwwwwwwo',
  'oooooooooooooooo',
  'owwwwwwwwwwwwwwo',
  'owbbwwppyyrrwwwo',
  'owbbwwppyyrrwwwo',
  'owbbwwppyyrrwwwo',
  'owwwwwwwwwwwwwwo',
  'oooooooooooooooo',
], const {
  'o': Color(0xFF4A3A30),
  'w': Color(0xFF8A6240),
  'r': Color(0xFFB8533F),
  'b': Color(0xFF3E7CB8),
  'g': Color(0xFF4D9E68),
  'y': Color(0xFFC9A227),
  'p': Color(0xFF8C5BA8),
});

/// Vending machine, 16x26.
final vendingSprite = PixelSprite(const [
  '.oooooooooooooo.',
  '.oRRRRRRRRRRRRo.',
  '.oRwwwwwwwwwRRo.',
  '.oRwrygbrygwRRo.',
  '.oRwwwwwwwwwRRo.',
  '.oRwgbryggbwRRo.',
  '.oRwwwwwwwwwRRo.',
  '.oRwybgrybgwRRo.',
  '.oRwwwwwwwwwRRo.',
  '.oRRRRRRRRRRRRo.',
  '.oRRRRRddRRRRRo.',
  '.oRRRRRddRRRRRo.',
  '.oRRnnnnnnnRRRo.',
  '.oRRnnnnnnnRRRo.',
  '.oooooooooooooo.',
  '..oo.........oo.',
], const {
  'o': Color(0xFF2A2D33),
  'R': Color(0xFFC0473A),
  'w': Color(0xFFDDE8EC), // lit window
  'r': Color(0xFFD24A3E),
  'y': Color(0xFFC9A227),
  'g': Color(0xFF4D9E68),
  'b': Color(0xFF3E7CB8),
  'd': Color(0xFF8A8278), // coin slot
  'n': Color(0xFF1C1E22), // dispenser
});

/// Wall whiteboard, 28x14 (drawn on the top wall).
final whiteboardSprite = PixelSprite(const [
  'oooooooooooooooooooooooooooo',
  'owwwwwwwwwwwwwwwwwwwwwwwwwwo',
  'owrrwwwwbbbwwwwwwwggwwwwwwwo',
  'owrrwwwwbbbwwwwwgggggwwwwwwo',
  'owwwwwwwwwwwwwgggwwgggwwwwwo',
  'owbbbbwwwwwwgggwwwwwwggwwwwo',
  'owwwwwwwwwggwwwwwwwwwwwwwwwo',
  'owrrrrrwwwwwwwwwwwwbbwwwwwwo',
  'owwwwwwwwwwwwwwwwwwwwwwwwwwo',
  'oooooooooooooooooooooooooooo',
  '............oo..............',
], const {
  'o': Color(0xFF5A554E),
  'w': Color(0xFFF2F0EA),
  'r': Color(0xFFD24A3E),
  'b': Color(0xFF3E7CB8),
  'g': Color(0xFF4D9E68),
});

/// Pop-art poster (a nod to the four-color office painting), 14x12.
final posterSprite = PixelSprite(const [
  'oooooooooooooo',
  'owwwwwwwwwwwwo',
  'owrrrrwwbbbbwo',
  'owrRrrwwbBbbwo',
  'owrrrrwwbbbbwo',
  'owwwwwwwwwwwwo',
  'owggggwwyyyywo',
  'owgGggwwyYyywo',
  'owggggwwyyyywo',
  'owwwwwwwwwwwwo',
  'oooooooooooooo',
], const {
  'o': Color(0xFF3A3340),
  'w': Color(0xFFF2F0EA),
  'r': Color(0xFFE06A8C),
  'R': Color(0xFFF2A0B8),
  'b': Color(0xFF4D8CD0),
  'B': Color(0xFF8CB8E8),
  'g': Color(0xFF4DAE68),
  'G': Color(0xFF8CD0A0),
  'y': Color(0xFFE0A03A),
  'Y': Color(0xFFF2C878),
});

/// Window on the top wall, 16x12 — warm sky.
final windowSprite = PixelSprite(const [
  'oooooooooooooooo',
  'obbbbbbbobbbbbbo',
  'obbbcbbbobbbbbbo',
  'obccbbbbobbccbbo',
  'obbbbbbbobbbbbbo',
  'oooooooooooooooo',
  'obbbbbbbobbbbbbo',
  'obbbbcbbobcbbbbo',
  'obbbbbbbobbbbbbo',
  'oooooooooooooooo',
], const {
  'o': Color(0xFF7E7468),
  'b': Color(0xFFA8D4E8),
  'c': Color(0xFFE8F2F5), // clouds
});

/// Printer on a small stand, 16x18.
final printerSprite = PixelSprite(const [
  '...pppppppppp...',
  '...pPPPPPPPPp...',
  '..ppPPPPPPPPpp..',
  '..pPPPPPPPPPPp..',
  '..pPPrPPPPPPPp..',
  '..pppqqqqqqppp..',
  '..ppppppppppp...',
  'oooooooooooooooo',
  'owwwwwwwwwwwwwwo',
  'odddddddddddddoo',
  '.oooooooooooooo.',
  '..oo........oo..',
], const {
  'p': Color(0xFF9A958C),
  'P': Color(0xFFC4BFB5),
  'r': Color(0xFF4DAE68), // status light
  'q': Color(0xFFF5F2EA), // paper out tray
  'o': _woodEdge,
  'w': _wood,
  'd': _woodDark,
});

/// Meeting table, 40x22.
final meetingTableSprite = PixelSprite(const [
  '....oooooooooooooooooooooooooooooooo....',
  '...owwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwo...',
  '..owwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwo..',
  '..owwwwwwwqqqqqwwwwwwwwwwlllwwwwwwwwwwo.',
  '..owwwwwwwqqqqqwwwwwwwwwwlllwwwwwwwwwwo.',
  '..owwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwo.',
  '..owwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwo..',
  '...owwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwo...',
  '....oooooooooooooooooooooooooooooooo....',
  '....odddddddddddddddddddddddddddddoo....',
  '.....oooooooooooooooooooooooooooooo.....',
  '......oo........................oo......',
], const {
  'o': _woodEdge,
  'w': Color(0xFFD8B886),
  'd': Color(0xFFA8855C),
  'q': Color(0xFFF5F2EA),
  'l': Color(0xFF7A9CC0), // laptop
});

/// Low lounge table, 18x12.
final loungeTableSprite = PixelSprite(const [
  '..oooooooooooo..',
  '.owwwwwwwwwwwwo.',
  '.owwwuuwwwwwwwo.',
  '.owwwuuwwqqwwwo.',
  '.owwwwwwwqqwwwo.',
  '.owwwwwwwwwwwwo.',
  '..oooooooooooo..',
  '...oo......oo...',
  '...oo......oo...',
], const {
  'o': _woodEdge,
  'w': _wood,
  'u': Color(0xFFC96A4A), // mug
  'q': Color(0xFFF5F2EA), // magazine
});

/// Wall clock, 10x10.
final clockSprite = PixelSprite(const [
  '...oooo...',
  '..owwwwo..',
  '.owwmwwwo.',
  'owwwmwwwwo',
  'owwwmmwwwo',
  'owwwwwwwwo',
  '.owwwwwwo.',
  '..owwwwo..',
  '...oooo...',
], const {
  'o': Color(0xFF3A3340),
  'w': Color(0xFFF2F0EA),
  'm': Color(0xFF2A2D33),
});

/// Fridge, 16x24.
final fridgeSprite = PixelSprite(const [
  '.oooooooooooooo.',
  '.oCCCCCCCCCCCCo.',
  '.oCCCCCCCCCCdCo.',
  '.oCCCCCCCCCCdCo.',
  '.oCCCCCCCCCCCCo.',
  '.oooooooooooooo.',
  '.oCCCCCCCCCCCCo.',
  '.oCCCCCCCCCCdCo.',
  '.oCCCCCCCCCCdCo.',
  '.oCCCCCCCCCCdCo.',
  '.oCCCCCCCCCCCCo.',
  '.oCCCCCCCCCCCCo.',
  '.oCCCCCCCCCCCCo.',
  '.occcccccccccco.',
  '.oooooooooooooo.',
  '..oo........oo..',
], const {
  'o': Color(0xFF8A8680),
  'C': Color(0xFFE8E6E0),
  'c': Color(0xFFC8C4BC),
  'd': Color(0xFF6E6A64),
});

/// Kitchen table, 32x12 — mugs and a fruit bowl.
final kitchenTableSprite = PixelSprite(const [
  '..oooooooooooooooooooooooooooo..',
  '.owwwwwwwwwwwwwwwwwwwwwwwwwwwwo.',
  '.owwwuuwwwwwwbbbbwwwwwwwuuwwwwo.',
  '.owwwuuwwwwwbrgybbwwwwwwuuwwwwo.',
  '.owwwwwwwwwwwbbbbwwwwwwwwwwwwwo.',
  '.owwwwwwwwwwwwwwwwwwwwwwwwwwwwo.',
  '..oooooooooooooooooooooooooooo..',
  '..oddddddddddddddddddddddddddo..',
  '...oo......................oo...',
  '...oo......................oo...',
], const {
  'o': _woodEdge,
  'w': Color(0xFFD8B886),
  'd': Color(0xFFA8855C),
  'u': Color(0xFFC96A4A), // mugs
  'b': Color(0xFF8A6240), // bowl
  'r': Color(0xFFD24A3E), // fruit
  'g': Color(0xFF4D9E68),
  'y': Color(0xFFC9A227),
});

/// Kitchen stool, 10x9.
final stoolSprite = PixelSprite(const [
  '..oooooo..',
  '.oSSSSSSo.',
  '.oSSSSSSo.',
  '..oooooo..',
  '...o..o...',
  '...o..o...',
  '..oo..oo..',
], const {
  'o': Color(0xFF5C3A28),
  'S': Color(0xFFC9A24B),
});

/// Armchair (faces down), 18x12 — rust-colored single seat.
final armchairSprite = PixelSprite(const [
  '.oooooooooooooooo.',
  'oSSSSSSSSSSSSSSSSo',
  'oSSSSSSSSSSSSSSSSo',
  'oosssssssssssssoo.',
  'oCCsSSSSSSSSSsCCo.',
  'oCCsSSSSSSSSSsCCo.',
  'oCCsssssssssssCCo.',
  'oCCCCCCCCCCCCCCCo.',
  '.oooooooooooooooo.',
  '.oo............oo.',
], const {
  'o': Color(0xFF5C3A28),
  'S': Color(0xFFC98455),
  's': Color(0xFFA8663E),
  'C': Color(0xFFB5754A),
});

/// Filing cabinet, 14x18.
final filingCabinetSprite = PixelSprite(const [
  '.oooooooooooo.',
  '.oCCCCCCCCCCo.',
  '.oCCCdddCCCCo.',
  '.oCCCCCCCCCCo.',
  '.oooooooooooo.',
  '.oCCCCCCCCCCo.',
  '.oCCCdddCCCCo.',
  '.oCCCCCCCCCCo.',
  '.oooooooooooo.',
  '.oCCCCCCCCCCo.',
  '.oCCCdddCCCCo.',
  '.oCCCCCCCCCCo.',
  '.oooooooooooo.',
  '..oo......oo..',
], const {
  'o': Color(0xFF4A4E55),
  'C': Color(0xFF9AA0A8),
  'd': Color(0xFF3A3E44),
});

/// Server rack, 16x24 — green/amber status lights.
final serverRackSprite = PixelSprite(const [
  'oooooooooooooooo',
  'oNNNNNNNNNNNNNNo',
  'oNggNNNNNNNNrrNo',
  'oNNNNNNNNNNNNNNo',
  'onnnnnnnnnnnnnno',
  'oNNNNNNNNNNNNNNo',
  'oNggNNNNNNNNggNo',
  'oNNNNNNNNNNNNNNo',
  'onnnnnnnnnnnnnno',
  'oNNNNNNNNNNNNNNo',
  'oNrrNNNNNNNNggNo',
  'oNNNNNNNNNNNNNNo',
  'onnnnnnnnnnnnnno',
  'oNNNNNNNNNNNNNNo',
  'oNggNNNNNNNNggNo',
  'oNNNNNNNNNNNNNNo',
  'oooooooooooooooo',
  '.oo..........oo.',
], const {
  'o': Color(0xFF1A1D22),
  'N': Color(0xFF2A2E36),
  'n': Color(0xFF383E48),
  'g': Color(0xFF5BD06A),
  'r': Color(0xFFE0A548),
});

/// Cardboard box, 14x11.
final boxSprite = PixelSprite(const [
  '..oooooooooo..',
  '.obbbbttbbbbo.',
  '.obbbbttbbbbo.',
  '.oBBBBttBBBBo.',
  '.oBBBBBBBBBBo.',
  '.oBBBBBBBBBBo.',
  '.oBBlaBBBBBBo.',
  '.oBBBBBBBBBBo.',
  '..oooooooooo..',
], const {
  'o': Color(0xFF7E5C38),
  'b': Color(0xFFC9A36A),
  'B': Color(0xFFB58E55),
  't': Color(0xFFE0D0A0), // tape
  'l': Color(0xFFF5F2EA), // shipping label
  'a': Color(0xFF3E7CB8),
});

/// Stack of papers / clutter, 12x10 (desk-area filler).
final paperStackSprite = PixelSprite(const [
  '..qqqqqqqq..',
  '.qqqqqqqqqq.',
  '.qllqqqlqqq.',
  '.qqqqqqqqqq.',
  '.aqqqqqqqqa.',
  '.aqlqqqqlqa.',
  '.aqqqqqqqqa.',
  '.aaaaaaaaaa.',
], const {
  'q': Color(0xFFF5F2EA),
  'l': Color(0xFFAEBCCE),
  'a': Color(0xFFE0DCD0),
});

// ---------------------------------------------------------------------------
// Campus props: gym, pool, café, finance, library, zen
// ---------------------------------------------------------------------------

/// Treadmill (seen from above, belt facing down), 16x26.
final treadmillSprite = PixelSprite(const [
  '...oooooooooo...',
  '..oCCCCCCCCCCo..',
  '..oCrrCCCCggCo..',
  '..oCCCCCCCCCCo..',
  '...oooooooooo...',
  '....oo....oo....',
  '..oooooooooooo..',
  '..oBBBBBBBBBBo..',
  '..oBbbbbbbbbBo..',
  '..oBBBBBBBBBBo..',
  '..oBbbbbbbbbBo..',
  '..oBBBBBBBBBBo..',
  '..oBbbbbbbbbBo..',
  '..oBBBBBBBBBBo..',
  '..oBbbbbbbbbBo..',
  '..oBBBBBBBBBBo..',
  '..oooooooooooo..',
], const {
  'o': Color(0xFF23252E),
  'C': Color(0xFF565B6C), // console
  'r': Color(0xFFE05548),
  'g': Color(0xFF5BD06A),
  'B': Color(0xFF3A3E48), // belt frame
  'b': Color(0xFF2A2D36), // belt
});

/// Dumbbell rack, 16x16.
final dumbbellRackSprite = PixelSprite(const [
  'oooooooooooooooo',
  'oWWooWWooWWooWWo',
  'oWWooWWooWWooWWo',
  'oooooooooooooooo',
  'oWWWooWWWooWWWoo',
  'oWWWooWWWooWWWoo',
  'oooooooooooooooo',
  '.oo..........oo.',
  '.oo..........oo.',
], const {
  'o': Color(0xFF2A2D33),
  'W': Color(0xFF6A7080), // weights
});

/// Yoga mat (flat on the floor, walk-on-able), 14x20.
final yogaMatSprite = PixelSprite(const [
  '.mmmmmmmmmmmm.',
  'mMMMMMMMMMMMMm',
  'mMMMMMMMMMMMMm',
  'mMMMMMMMMMMMMm',
  'mMMMMMMMMMMMMm',
  'mMMMMMMMMMMMMm',
  'mMMMMMMMMMMMMm',
  'mMMMMMMMMMMMMm',
  'mMMMMMMMMMMMMm',
  'mMMMMMMMMMMMMm',
  'mMMMMMMMMMMMMm',
  '.mmmmmmmmmmmm.',
], const {
  'm': Color(0xFF6B5B95),
  'M': Color(0xFF8C7BB8),
});

/// Pool-side lounger (deck chair facing down), 16x26.
final loungerSprite = PixelSprite(const [
  '..oooooooooooo..',
  '.oWWWWWWWWWWWWo.',
  '.oWWWWWWWWWWWWo.',
  '.oWwwwwwwwwwWWo.',
  '.oWWWWWWWWWWWWo.',
  '.oWwwwwwwwwwWWo.',
  '.oWWWWWWWWWWWWo.',
  '.oWwwwwwwwwwWWo.',
  '.oWWWWWWWWWWWWo.',
  '.oWwwwwwwwwwWWo.',
  '.oWWWWWWWWWWWWo.',
  '..oooooooooooo..',
  '...oo......oo...',
], const {
  'o': Color(0xFF8A6240),
  'W': Color(0xFF5BAAC8), // canvas stripes
  'w': Color(0xFFE8F2F5),
});

/// Parasol table, 22x30 — big umbrella over a small table.
final umbrellaSprite = PixelSprite(const [
  '.........uuuu.........',
  '......uuuUUUUuuu......',
  '....uuUUUUuuUUUUuu....',
  '...uUUUuuUUUUuuUUUu...',
  '..uUUUUUUUUUUUUUUUUu..',
  '..uuuuuuuuuuuuuuuuuu..',
  '.........pp...........',
  '.........pp...........',
  '.........pp...........',
  '......oooooooo........',
  '.....owwwwwwwwo.......',
  '.....owwuuwwwwo.......',
  '.....owwwwwwwwo.......',
  '......oooooooo........',
  '.......oo..oo.........',
], const {
  'u': Color(0xFFE05548), // canopy red
  'U': Color(0xFFF2F0EA), // canopy white
  'p': Color(0xFF8A8278), // pole
  'o': Color(0xFF4A3A30),
  'w': Color(0xFFC89B66),
});

/// Round café table, 14x14.
final cafeTableSprite = PixelSprite(const [
  '...oooooooo...',
  '..owwwwwwwwo..',
  '.owwuuwwwqwwo.',
  '.owwuuwwqqwwo.',
  '.owwwwwwwwwwo.',
  '..owwwwwwwwo..',
  '...oooooooo...',
  '......oo......',
  '......oo......',
  '.....oooo.....',
], const {
  'o': Color(0xFF4A3A30),
  'w': Color(0xFFD8B886),
  'u': Color(0xFFC96A4A), // cup
  'q': Color(0xFFF5F2EA), // saucer
});

/// Standing menu board, 14x18.
final menuBoardSprite = PixelSprite(const [
  '.oooooooooooo.',
  '.obbbbbbbbbbo.',
  '.obwwbbbbbbbo.',
  '.obbbbbwwwbbo.',
  '.obwwwbbbbbbo.',
  '.obbbbbwwbbbo.',
  '.obwwwwbbbbbo.',
  '.obbbbbbbbbbo.',
  '.oooooooooooo.',
  '..o........o..',
  '.o..........o.',
], const {
  'o': Color(0xFF5C3A28),
  'b': Color(0xFF2E3A34), // chalkboard
  'w': Color(0xFFE8E2D0), // chalk
});

/// Vault safe, 16x20.
final safeSprite = PixelSprite(const [
  'oooooooooooooooo',
  'oGGGGGGGGGGGGGGo',
  'oGGGGGGGGGGGGGGo',
  'oGGGGddddGGGGGGo',
  'oGGGdDDDDdGGGhGo',
  'oGGGdDddDdGGGhGo',
  'oGGGdDDDDdGGGGGo',
  'oGGGGddddGGGGGGo',
  'oGGGGGGGGGGGGGGo',
  'oGGGGGGGGGGGGGGo',
  'oGGGGGGGGGGGGGGo',
  'oooooooooooooooo',
  '.oo..........oo.',
], const {
  'o': Color(0xFF1F2A26),
  'G': Color(0xFF3E5C50), // vault green
  'd': Color(0xFF2A3E36),
  'D': Color(0xFF8A9C94), // dial
  'h': Color(0xFFC9A227), // handle
});

/// Pile of gold & cash, 14x10.
final moneyPileSprite = PixelSprite(const [
  '....gg..gg....',
  '...gGGggGGg...',
  '..ggGGggGGgg..',
  '.cccccccccc...',
  '.cCCCCCCCCcc..',
  '.cccccccccccc.',
  '.cCCCCCCCCCCc.',
  '.cccccccccccc.',
], const {
  'g': Color(0xFFA8841F),
  'G': Color(0xFFE0C04A), // gold
  'c': Color(0xFF3E7C50),
  'C': Color(0xFF5BAA6E), // cash
});

/// Mail pigeonholes, 16x22 — some slots have letters.
final mailShelfSprite = PixelSprite(const [
  'oooooooooooooooo',
  'owwoowwoowwoowwo',
  'owqoowwoowqoowwo',
  'oooooooooooooooo',
  'owwoowqoowwoowwo',
  'owwoowwoowwoowqo',
  'oooooooooooooooo',
  'owqoowwoowwoowwo',
  'owwoowwoowqoowwo',
  'oooooooooooooooo',
  '.oo..........oo.',
], const {
  'o': Color(0xFF4A3A30),
  'w': Color(0xFF6E5640), // empty slot
  'q': Color(0xFFF5F2EA), // letter
});

/// Meditation cushion (zafu) — sit-on-able, 12x8.
final cushionSprite = PixelSprite(const [
  '..cccccccc..',
  '.cCCCCCCCCc.',
  'cCCCCCCCCCCc',
  'cCCCCCCCCCCc',
  '.cCCCCCCCCc.',
  '..cccccccc..',
], const {
  'c': Color(0xFF8C4A3E),
  'C': Color(0xFFB86A5A),
});

/// Bonsai on a stand, 12x16.
final bonsaiSprite = PixelSprite(const [
  '...GGgG.....',
  '..GGGGGG....',
  '..gGGgGGG...',
  '...GgGG.....',
  '....t.......',
  '...tt.......',
  '..tttttt....',
  '..tTTTTt....',
  '...tttt.....',
  '..oooooo....',
  '..owwwwo....',
  '...o..o.....',
], const {
  'G': Color(0xFF5FA052),
  'g': Color(0xFF3F7A3C),
  't': Color(0xFF7E4A33),
  'T': Color(0xFFB06A4A),
  'o': Color(0xFF4A3A30),
  'w': Color(0xFF8A6240),
});

/// Floor lamp with a warm shade, 10x20.
final lampSprite = PixelSprite(const [
  '..LLLLLL..',
  '.LllllllL.',
  '.LllllllL.',
  '..LLLLLL..',
  '....pp....',
  '....pp....',
  '....pp....',
  '....pp....',
  '....pp....',
  '...oooo...',
  '..oooooo..',
], const {
  'L': Color(0xFFC9A227),
  'l': Color(0xFFF2DC9C), // glow
  'p': Color(0xFF4A4E55),
  'o': Color(0xFF2A2D33),
});

/// Wall calendar, 14x14 (wall decor).
final wallCalendarSprite = PixelSprite(const [
  'oooooooooooooo',
  'orrrrrrrrrrrro',
  'owwwwwwwwwwwwo',
  'owmwmwmwmwmwwo',
  'owwwwwwwwwwwwo',
  'owmwmwrwmwmwwo',
  'owwwwwwwwwwwwo',
  'owmwmwmwmwwwwo',
  'owwwwwwwwwwwwo',
  'oooooooooooooo',
], const {
  'o': Color(0xFF3A3340),
  'r': Color(0xFFD24A3E),
  'w': Color(0xFFF2F0EA),
  'm': Color(0xFF8A8694),
});

// ---------------------------------------------------------------------------
// Entertainment props: arcade, jukebox, pool table, cinema screen, bar
// ---------------------------------------------------------------------------

/// Arcade cabinet (1 tile), 16x17 — lit screen, button panel, speaker grille.
final arcadeCabinetSprite = PixelSprite(const [
  '..oooooooooooo..',
  '.oRRRRRRRRRRRRo.',
  '.oRssssssssssRo.',
  '.oRsSSSSSSSSsRo.',
  '.oRsSyyrSgSSsRo.',
  '.oRsSSbSSyySsRo.',
  '.oRsSSSSSSSSsRo.',
  '.oRssssssssssRo.',
  '.oRRRRRRRRRRRRo.',
  '.oRRBBBBBBBBRRo.',
  '.oRRBgyrbygBRRo.',
  '.oRRBBBBBBBBRRo.',
  '.oRRRRRRRRRRRRo.',
  '.oRRRwwwwwwRRRo.',
  '.oRRRRRRRRRRRRo.',
  '.oooooooooooooo.',
  '..oo........oo..',
], const {
  'o': Color(0xFF15131A),
  'R': Color(0xFF4A2E8C), // purple cabinet
  's': Color(0xFF0C0C14), // bezel
  'S': Color(0xFF1F2B5C), // screen
  'y': Color(0xFFE8C84A),
  'r': Color(0xFFE05548),
  'g': Color(0xFF5BD06A),
  'b': Color(0xFF5B8AD0),
  'B': Color(0xFF2A2440), // button panel
  'w': Color(0xFF7A7490), // speaker grille
});

/// Retro jukebox (1 tile), 14x13 — glowing arch, speaker, light buttons.
final jukeboxSprite = PixelSprite(const [
  '....oooooo....',
  '..ooGGGGGGoo..',
  '.oGGyrgbyrGGo.',
  '.oGGGGGGGGGGo.',
  '.oRRRRRRRRRRo.',
  '.oRwwwwwwwwRo.',
  '.oRwSSSSSSwRo.',
  '.oRwwwwwwwwRo.',
  '.oRRRRRRRRRRo.',
  '.oRyrgbyrgbRo.',
  '.oRRRRRRRRRRo.',
  '.oooooooooooo.',
  '..oo......oo..',
], const {
  'o': Color(0xFF2A1C30),
  'G': Color(0xFFE8C84A), // arch glow
  'y': Color(0xFFE8C84A),
  'r': Color(0xFFE05548),
  'g': Color(0xFF5BD06A),
  'b': Color(0xFF5B8AD0),
  'R': Color(0xFF8C3A4A), // red body
  'w': Color(0xFF3A2A40), // speaker frame
  'S': Color(0xFF6A5A80), // speaker mesh
});

/// Billiards table (2 tiles wide), 32x12 — felt, corner pockets, racked balls.
final poolTableSprite = PixelSprite(const [
  '.oooooooooooooooooooooooooooooo.',
  'oWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWo',
  'oWpffffffffffffffffffffffffffpWo',
  'oWffffffffffffffffffffffffffffWo',
  'oWffffffrffffffffffffyffffffffWo',
  'oWfffffffffffffffwffffffffffffWo',
  'oWfffffffbffffffffffffffffffffWo',
  'oWffffffffffffffffffffffffffffWo',
  'oWpffffffffffffffffffffffffffpWo',
  'oWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWo',
  '.oooooooooooooooooooooooooooooo.',
  '..oo......................oo....',
], const {
  'o': Color(0xFF2A1C12),
  'W': Color(0xFF7A4E2C), // wood rail
  'f': Color(0xFF2E8D4E), // felt
  'p': Color(0xFF120F0C), // pocket
  'r': Color(0xFFE05548),
  'y': Color(0xFFE8C84A),
  'b': Color(0xFF5B8AD0),
  'w': Color(0xFFF2EDE0), // cue ball
});

/// Big cinema screen (2 tiles wide), 32x13 — a colorful frame still on a stand.
final tvScreenSprite = PixelSprite(const [
  'oooooooooooooooooooooooooooooooo',
  'oSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSo',
  'oSSSSyySSSSSSSSSSSSSSSSSSwwSSSSo',
  'oSSSyyySSSSSSrrSSSSSSSSSwwwwSSSo',
  'oSSSSSSSSSSrrrrSSSSSSSSSSSwwSSSo',
  'oSSSSSSSSSSrrSSSSggSSSSSSSSSSSSo',
  'oSSSSSSSSSSSSSgggggSSSSSSSSSSSSo',
  'oSSbbSSSSSSSSSSSSSSSSSSSSbbSSSSo',
  'oSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSo',
  'oooooooooooooooooooooooooooooooo',
  '..............oooo..............',
  '...........oooooooooo...........',
], const {
  'o': Color(0xFF15151C),
  'S': Color(0xFF243466), // screen
  'y': Color(0xFFE8C84A),
  'r': Color(0xFFE05548),
  'g': Color(0xFF5BD06A),
  'b': Color(0xFF5B8AD0),
  'w': Color(0xFFF2EDE0),
});

/// Bar counter (2 tiles wide), 32x11 — back shelf of bottles + a wood counter.
final barCounterSprite = PixelSprite(const [
  'oooooooooooooooooooooooooooooooo',
  'okkkkkkkkkkkkkkkkkkkkkkkkkkkkkko',
  'okrkgkbkykrkgkbkykrkgkbkykrkgkbo',
  'okkkkkkkkkkkkkkkkkkkkkkkkkkkkkko',
  'oWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWo',
  'oWwwwwwwwwwwwwwwwwwwwwwwwwwwwwWo',
  'oWwwwwwwGwwwwwwwwwwwwwwGwwwwwwWo',
  'oWwwwwwwwwwwwwwwwwwwwwwwwwwwwwWo',
  'oWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWo',
  '.oooooooooooooooooooooooooooooo.',
  '..oo......................oo....',
], const {
  'o': Color(0xFF1C120A),
  'k': Color(0xFF2A1E14), // back shelf
  'r': Color(0xFFD24A3E),
  'g': Color(0xFF5BD06A),
  'b': Color(0xFF5B8AD0),
  'y': Color(0xFFE8C84A),
  'W': Color(0xFF7A4E2C), // counter wood
  'w': Color(0xFF9A6A3A), // counter face
  'G': Color(0xFFC9A227), // brass trim
});

// ---------------------------------------------------------------------------
// Pixel the office cat (orange tabby)
// ---------------------------------------------------------------------------

const _catPalette = <String, Color>{
  'C': Color(0xFFE0913F), // coat
  'c': Color(0xFFB86F28), // stripes / shadow
  'w': Color(0xFFF2E3C8), // chest / muzzle
  'E': Color(0xFF2A2226), // eye
  'p': Color(0xFFD96A8C), // nose / inner ear
};

/// Cat walking, side view facing right (flip for left), 14x10.
final catWalkASprite = PixelSprite(const [
  '.c.........CC.',
  '.c........CCCC',
  '.cc..CCCCCCECw',
  '..cCCCcCCCCCww',
  '...CCCCcCCCCp.',
  '...CCCCCCCCw..',
  '...Cc..CCc....',
  '...C....C.....',
  '..cC....Cc....',
], _catPalette);

final catWalkBSprite = PixelSprite(const [
  '.c.........CC.',
  '.c........CCCC',
  '.cc..CCCCCCECw',
  '..cCCCcCCCCCww',
  '...CCCCcCCCCp.',
  '...CCCCCCCCw..',
  '....cC.CCc....',
  '....C...cC....',
  '....Cc...C....',
], _catPalette);

/// Cat sitting, facing the viewer, 10x11.
final catSitSprite = PixelSprite(const [
  '.C......C.',
  '.CC....CC.',
  '.CpC..CpC.',
  '.CCCCCCCC.',
  '.CECCCCEC.',
  '.CCCpCCCC.',
  '..CwwwCC..',
  '..CCCCCC..',
  '.cCCCCCCc.',
  '.cCCCCCCc.',
  '..cc..cc..',
], _catPalette);

/// Cat curled up asleep, 12x8.
final catSleepSprite = PixelSprite(const [
  '...CCCCCC...',
  '..CCccCCCC..',
  '.CCCCCCcCCC.',
  '.CcCCCCCCCC.',
  '.CCCCcCCCcC.',
  '.cCCCCCCCC..',
  '..cCCCCCc...',
  '....ccc.....',
], _catPalette);

/// Pool ladder (drawn over the water edge), 10x12.
final poolLadderSprite = PixelSprite(const [
  '.ss....ss.',
  '.ss....ss.',
  '.ssssssss.',
  '.ss....ss.',
  '.ssssssss.',
  '.ss....ss.',
  '.ss....ss.',
], const {
  's': Color(0xFFD8DCE0), // steel
});
