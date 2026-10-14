import 'package:flutter/material.dart';

class BarcodeEncoder {
  static const List<String> _patterns = [
    "212222", // 0: ' '
    "222122", // 1: '!'
    "222221", // 2: '"'
    "121223", // 3: '#'
    "121322", // 4: '$'
    "131222", // 5: '%'
    "122213", // 6: '&'
    "122312", // 7: '\''
    "132212", // 8: '('
    "221213", // 9: ')'
    "221312", // 10: '*'
    "231212", // 11: '+'
    "112232", // 12: ','
    "122132", // 13: '-'
    "122231", // 14: '.'
    "113222", // 15: '/'
    "123122", // 16: '0'
    "123221", // 17: '1'
    "223211", // 18: '2'
    "221132", // 19: '3'
    "221231", // 20: '4'
    "213212", // 21: '5'
    "223112", // 22: '6'
    "312131", // 23: '7'
    "311222", // 24: '8'
    "321122", // 25: '9'
    "321221", // 26: ':'
    "312212", // 27: ';'
    "322112", // 28: '<'
    "322211", // 29: '='
    "212123", // 30: '>'
    "212321", // 31: '?'
    "232121", // 32: '@'
    "111323", // 33: 'A'
    "131123", // 34: 'B'
    "131321", // 35: 'C'
    "112313", // 36: 'D'
    "132113", // 37: 'E'
    "132311", // 38: 'F'
    "211313", // 39: 'G'
    "231113", // 40: 'H'
    "231311", // 41: 'I'
    "112133", // 42: 'J'
    "112331", // 43: 'K'
    "132131", // 44: 'L'
    "113123", // 45: 'M'
    "113321", // 46: 'N'
    "133121", // 47: 'O'
    "313121", // 48: 'P'
    "211331", // 49: 'Q'
    "231131", // 50: 'R'
    "213113", // 51: 'S'
    "213311", // 52: 'T'
    "213131", // 53: 'U'
    "311123", // 54: 'V'
    "311321", // 55: 'W'
    "331121", // 56: 'X'
    "312113", // 57: 'Y'
    "312311", // 58: 'Z'
    "332111", // 59: '['
    "314111", // 60: '\\'
    "221411", // 61: ']'
    "431111", // 62: '^'
    "111224", // 63: '_'
    "111422", // 64: '`'
    "121124", // 65: 'a'
    "121421", // 66: 'b'
    "141122", // 67: 'c'
    "141221", // 68: 'd'
    "112214", // 69: 'e'
    "112412", // 70: 'f'
    "122114", // 71: 'g'
    "122411", // 72: 'h'
    "142112", // 73: 'i'
    "142211", // 74: 'j'
    "241211", // 75: 'k'
    "221114", // 76: 'l'
    "413111", // 77: 'm'
    "241112", // 78: 'n'
    "134111", // 79: 'o'
    "111242", // 80: 'p'
    "121142", // 81: 'q'
    "121241", // 82: 'r'
    "114212", // 83: 's'
    "124112", // 84: 't'
    "124211", // 85: 'u'
    "411212", // 86: 'v'
    "421112", // 87: 'w'
    "421211", // 88: 'x'
    "212141", // 89: 'y'
    "214121", // 90: 'z'
    "412121", // 91: '{'
    "111143", // 92: '|'
    "111341", // 93: '}'
    "131141", // 94: '~'
    "114113", // 95: DEL
    "114311", // 96: FNC 3
    "411113", // 97: FNC 2
    "411311", // 98: SHIFT
    "113141", // 99: CODE C
    "114131", // 100: CODE B
    "311141", // 101: FNC 4
    "411131", // 102: FNC 1
    "211412", // 103: START A
    "211214", // 104: START B
    "211232", // 105: START C
    "2331112" // 106: STOP
  ];

  /// Encode une chaîne ASCII en une liste de booléens (true = barre noire, false = espace blanc)
  static List<bool> encodeCode128B(String data) {
    if (data.isEmpty) data = "EMPTY";

    // Start Code B = 104
    final List<int> values = [104];
    int checksum = 104;

    for (int i = 0; i < data.length; i++) {
      int code = data.codeUnitAt(i);
      int val = code - 32;
      if (val < 0 || val > 95) {
        // Remplacer caractères non ASCII standard par '?'
        val = 63 - 32;
      }
      values.add(val);
      checksum += val * (i + 1);
    }

    final int checkValue = checksum % 103;
    values.add(checkValue);
    values.add(106); // Stop pattern

    final List<bool> modules = [];
    // Quiet zone initiale (10 modules blancs)
    for (int i = 0; i < 10; i++) {
      modules.add(false);
    }

    for (int val in values) {
      final String pattern = _patterns[val];
      for (int p = 0; p < pattern.length; p++) {
        final int width = int.parse(pattern[p]);
        final bool isBar = (p % 2 == 0);
        for (int w = 0; w < width; w++) {
          modules.add(isBar);
        }
      }
    }

    // Quiet zone finale (10 modules blancs)
    for (int i = 0; i < 10; i++) {
      modules.add(false);
    }

    return modules;
  }
}

class BarcodeCustomPainter extends CustomPainter {
  final List<bool> modules;
  final Color barColor;

  BarcodeCustomPainter({required this.modules, this.barColor = Colors.black});

  @override
  void paint(Canvas canvas, Size size) {
    if (modules.isEmpty) return;

    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    final double moduleWidth = size.width / modules.length;

    for (int i = 0; i < modules.length; i++) {
      if (modules[i]) {
        final double left = i * moduleWidth;
        canvas.drawRect(
          Rect.fromLTWH(left, 0, moduleWidth + 0.1, size.height),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant BarcodeCustomPainter oldDelegate) {
    return oldDelegate.modules != modules || oldDelegate.barColor != barColor;
  }
}

class BarcodeWidget extends StatelessWidget {
  final String data;
  final double height;
  final double? width;
  final bool showText;
  final TextStyle? textStyle;
  final Color barColor;

  const BarcodeWidget({
    super.key,
    required this.data,
    this.height = 55,
    this.width,
    this.showText = true,
    this.textStyle,
    this.barColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    final modules = BarcodeEncoder.encodeCode128B(data);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: height,
          width: width ?? (modules.length * 1.6),
          child: CustomPaint(
            painter: BarcodeCustomPainter(modules: modules, barColor: barColor),
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 4),
          Text(
            data,
            style: textStyle ??
                const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: Colors.black87,
                ),
          ),
        ],
      ],
    );
  }
}
