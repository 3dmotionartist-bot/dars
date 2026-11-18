import 'dart:convert';

/// Drawing-board history sent over the call's data channel (Stage 3 B1).
///
/// A data channel message should stay under 16 KB, so the board is sent as
/// sync-begin, then any number of "sync" chunks, then sync-end. A long stroke may be
/// split over several chunks under the same id; the receiver joins the parts in order.
const int boardChunkBytes = 15000;

/// One stroke: its id and points (0..1 of the board's width / height).
typedef BoardStroke = ({String id, List<List<double>> pts});

/// Packs [strokes] into chunks whose JSON stays under [maxBytes].
List<List<Map<String, dynamic>>> boardChunks(List<BoardStroke> strokes, {int maxBytes = boardChunkBytes}) {
  const piecePoints = 200; // 200 points ≈ 3 KB of JSON (8 KB even unrounded): always fits in one chunk
  final chunks = <List<Map<String, dynamic>>>[];
  var current = <Map<String, dynamic>>[];
  var size = 20; // {"strokes":[...]} and the message wrapper
  for (final s in strokes) {
    if (s.pts.isEmpty) continue;
    for (var i = 0; i < s.pts.length; i += piecePoints) {
      final end = i + piecePoints < s.pts.length ? i + piecePoints : s.pts.length;
      final piece = <String, dynamic>{'id': s.id, 'pts': s.pts.sublist(i, end)};
      final n = utf8.encode(jsonEncode(piece)).length + 1;
      if (current.isNotEmpty && size + n > maxBytes) {
        chunks.add(current);
        current = [];
        size = 20;
      }
      current.add(piece);
      size += n;
    }
  }
  if (current.isNotEmpty) chunks.add(current);
  return chunks;
}

/// Joins received chunks back into strokes (id → points, in the order they arrived).
Map<String, List<List<double>>> joinBoardChunks(Iterable<List<dynamic>> chunks) {
  final out = <String, List<List<double>>>{};
  for (final c in chunks) {
    for (final s in c) {
      if (s is! Map) continue;
      final id = '${s['id']}';
      final pts = out.putIfAbsent(id, () => []);
      for (final p in (s['pts'] as List?) ?? const []) {
        if (p is List && p.length == 2) pts.add([(p[0] as num).toDouble(), (p[1] as num).toDouble()]);
      }
    }
  }
  return out;
}

// ---- "clear" order without clocks (phones' clocks can be minutes apart) ----
// Each board counts its clears. Clearing makes it one more than the highest count seen; a received clear
// raises it to the sender's count (an old app sends none: count it as one more). A history with a lower
// count than mine was drawn before a clear I already saw, so it is not brought back.

/// My count after I press "clear".
int nextClearCount(int mine) => mine + 1;

/// My count after the other side's "clear" carrying [theirs] (null from older apps).
int clearCountAfter(int mine, int? theirs) => theirs == null ? mine + 1 : (theirs > mine ? theirs : mine);

/// Whether a received board history (made at clear count [theirs]) is applied to mine.
bool syncWins(int theirs, int mine) => theirs >= mine;
