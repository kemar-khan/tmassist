/// The outcome of [SubcategoryDetector.detect].
class SubcategoryResult {
  const SubcategoryResult({
    required this.subcategory,
    required this.confidence,
    required this.score,
    required this.matchedTerms,
  });

  /// One of the knowledge-base subcategories, or `general` when nothing
  /// matched.
  final String subcategory;

  /// `high`, `medium` or `low` (`low` only for the `general` fallback).
  final String confidence;

  /// Sum of the weights of the matched terms, plus the category bonus.
  final int score;

  /// The terms of the winning subcategory that were found in the text.
  final List<String> matchedTerms;
}

/// A keyword and how strongly it points to a subcategory.
class _Term {
  const _Term(this.text, this.weight, {this.wholeWord = false});
  final String text;
  final int weight;

  /// Match as a whole word even though the term is longer than 4 characters
  /// (for example "voice", which must not match inside "invoice").
  final bool wholeWord;
}

/// Finds the issue type of a ticket from its words. Pure Dart: no Firebase and
/// no Gemini. Every subcategory has weighted keywords; the one with the highest
/// score wins.
class SubcategoryDetector {
  SubcategoryDetector._();

  /// Order used to break a tie between two subcategories with the same score:
  /// the more specific, more distinctive service faults come first, and the
  /// broad connectivity and Wi-Fi symptoms come last.
  static const tiePriority = <String>[
    'onu_auth_failure',
    'voip_issue',
    'ont_failure',
    'vlan_config',
    'dns_issue',
    'pppoe_auth',
    'intermittent',
    'fiber_loss',
    'speed_degradation',
    'cable_damage',
    'router_failure',
    'wifi_issue',
  ];

  /// Subcategories that belong to each Gemini category. The category is only
  /// a hint (+1), never a gate.
  static const _categorySubcategories = <String, Set<String>>{
    'network': {
      'fiber_loss',
      'onu_auth_failure',
      'speed_degradation',
      'intermittent',
      'wifi_issue',
    },
    'hardware': {'ont_failure', 'cable_damage', 'router_failure'},
    'software': {'vlan_config', 'voip_issue', 'pppoe_auth', 'dns_issue'},
  };

  /// A device that is dead or has no power is an ONT fault whatever else the
  /// text says. "dead" alone is not here: "internet is dead" is a network
  /// fault.
  static const _powerFaultTerms = <String>[
    'not turning on',
    'no power',
    'not powering',
    'power led',
    'power adapter',
  ];

  // Weight 3: distinctive service terms and power faults.
  // Weight 2: clear symptoms.
  // Weight 1: weak words that appear in many kinds of tickets.
  static const _table = <String, List<_Term>>{
    'onu_auth_failure': [
      _Term('onu password', 3),
      _Term('auth led', 3),
      _Term('auth light', 3),
      _Term('not authenticated', 3),
    ],
    'voip_issue': [
      _Term('voip', 3),
      _Term('telephone', 3),
      _Term('landline', 3),
      _Term('dial tone', 3),
      _Term('tel1', 3),
      _Term('tel2', 3),
      _Term('home phone', 3),
      _Term('phone line', 3),
      _Term('voice', 1, wholeWord: true),
      // Malay
      _Term('telefon rumah', 3),
      _Term('talian telefon', 3),
      _Term('nada dail', 3),
      _Term('tak boleh buat panggilan', 3),
    ],
    'ont_failure': [
      _Term('not turning on', 3),
      _Term('no power', 3),
      _Term('not powering', 3),
      _Term('power led', 3),
      _Term('power adapter', 3),
      _Term('ont', 2),
      _Term('onu', 2),
      _Term('no light', 2),
      // Malay
      _Term('tak hidup', 3),
      _Term('tidak menyala', 3),
      _Term('tiada kuasa', 3),
      _Term('adapter rosak', 3),
    ],
    'vlan_config': [
      _Term('vlan', 3),
      _Term('iptv', 3),
      _Term('hypptv', 3),
      _Term('tv box', 3),
      _Term('tv channel', 3),
      _Term('set top box', 3),
      _Term('set-top', 3),
      _Term('misconfigured', 3),
      _Term('tv', 3),
      _Term('configuration', 2),
      _Term('setup', 1),
      // Malay
      _Term('siaran', 2),
      _Term('saluran', 2),
      _Term('stb', 2),
    ],
    'dns_issue': [
      _Term('dns', 3),
      _Term('cannot open', 2),
      _Term('domain', 2),
      _Term('website', 1),
      _Term('browsing', 1),
      _Term('ping', 1),
      // Malay
      _Term('tak boleh buka website', 2),
      _Term('laman web', 1),
    ],
    'pppoe_auth': [
      _Term('pppoe', 3),
      _Term('password', 2),
      _Term('authentication', 2),
      _Term('login', 2),
      _Term('log in', 2),
      _Term('credential', 2),
      _Term('username', 2),
    ],
    'intermittent': [
      _Term('intermittent', 3),
      _Term('disconnect', 2),
      _Term('dropping', 2),
      _Term('unstable', 2),
      _Term('not stable', 2),
      _Term('keeps cutting', 2),
      _Term('on and off', 2),
      _Term('cuts off', 2),
      _Term('cut off', 2),
      _Term('random', 1),
      _Term('comes back', 1),
      // Malay
      _Term('kejap ada kejap tak ada', 3),
      _Term('putus-putus', 2),
      _Term('terputus', 2),
      _Term('selalu putus', 2),
      _Term('tak stabil', 2),
    ],
    'fiber_loss': [
      _Term('los', 2),
      _Term('fiber', 2),
      _Term('fibre', 2),
      _Term('no internet', 2),
      _Term('red light', 2),
      _Term('no connection', 2),
      _Term('signal loss', 2),
      _Term('completely down', 2),
      _Term('total outage', 2),
      _Term('link led', 2),
      _Term('internet is dead', 2),
      _Term('internet dead', 2),
      _Term('no signal', 1),
      // Malay
      _Term('line putus', 3),
      _Term('tiada internet', 2),
      _Term('tak ada internet', 2),
      _Term('tak dapat internet', 2),
      _Term('lampu merah', 2),
    ],
    'speed_degradation': [
      _Term('buffering', 2),
      _Term('lagging', 2),
      _Term('low speed', 2),
      _Term('slow', 1),
      _Term('slower', 1),
      _Term('speed', 1),
      _Term('mbps', 1),
      // Malay
      _Term('lambat', 1),
      _Term('perlahan', 1),
      _Term('kelajuan', 1),
    ],
    'cable_damage': [
      _Term('cable', 2),
      _Term('loose', 2),
      _Term('damaged', 2),
      _Term('broken', 2),
      _Term('connector', 2),
      _Term('patch cord', 2),
      _Term('bent', 2),
      _Term('port', 1),
      // Malay
      _Term('kabel rosak', 3),
      _Term('wayar putus', 3),
      _Term('kabel longgar', 3),
    ],
    'router_failure': [
      _Term('router', 2),
      _Term('ethernet', 2),
      _Term('admin page', 2),
      _Term('lan', 1),
      _Term('cannot access', 1),
    ],
    'wifi_issue': [
      _Term('weak signal', 2),
      _Term('cannot connect', 2),
      _Term('no wifi', 2),
      _Term('wifi', 1),
      _Term('wi-fi', 1),
      _Term('wireless', 1),
      // Malay
      _Term('wifi lemah', 2),
      _Term('isyarat lemah', 2),
      _Term('tak boleh sambung wifi', 2),
    ],
  };

  /// Whether [term] is in [text] (already lowercase). Terms of 4 characters or
  /// fewer, and terms marked [wholeWord], match whole words (with an optional
  /// s, ed, ing or ly); other longer terms match anywhere.
  static bool termMatches(String text, String term, {bool wholeWord = false}) {
    if (wholeWord || term.length <= 4) {
      return RegExp(
        '\\b${RegExp.escape(term)}(s|ed|ing|ly)?\\b',
      ).hasMatch(text);
    }
    return text.contains(term);
  }

  static SubcategoryResult detect({
    required String category,
    required String title,
    required String description,
  }) {
    final text = '$title $description'.toLowerCase();

    // A power fault beats everything else, unless the text also has an ONU
    // authentication term: "power LED on but auth LED red" is an auth fault.
    final power = [
      for (final t in _powerFaultTerms)
        if (termMatches(text, t)) t,
    ];
    final authMatched = _table['onu_auth_failure']!.any(
      (t) => termMatches(text, t.text, wholeWord: t.wholeWord),
    );
    if (power.isNotEmpty && !authMatched) {
      return SubcategoryResult(
        subcategory: 'ont_failure',
        confidence: 'high',
        score: power.length * 3,
        matchedTerms: power,
      );
    }

    // The power override was skipped because of an auth term: the category
    // hint then helps only onu_auth_failure, so it cannot push a power
    // subcategory (ont_failure) past the explicit auth term.
    final authOnlyBonus = power.isNotEmpty && authMatched;

    final hinted =
        _categorySubcategories[category.trim().toLowerCase()] ??
        const <String>{};

    final scored = <_Scored>[];
    _table.forEach((subcategory, terms) {
      final matched = [
        for (final t in terms)
          if (termMatches(text, t.text, wholeWord: t.wholeWord)) t,
      ];
      if (matched.isEmpty) return;
      var score = matched.fold<int>(0, (sum, t) => sum + t.weight);
      // The category only adds to a subcategory that already has a match.
      if (hinted.contains(subcategory) &&
          (!authOnlyBonus || subcategory == 'onu_auth_failure')) {
        score += 1;
      }
      scored.add(
        _Scored(subcategory, score, [for (final t in matched) t.text]),
      );
    });

    if (scored.isEmpty) {
      return const SubcategoryResult(
        subcategory: 'general',
        confidence: 'low',
        score: 0,
        matchedTerms: [],
      );
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return tiePriority
          .indexOf(a.subcategory)
          .compareTo(tiePriority.indexOf(b.subcategory));
    });

    final top = scored.first;
    final runnerUp = scored.length > 1 ? scored[1] : null;
    final clear = runnerUp == null || top.score - runnerUp.score >= 1;
    final confidence = top.score >= 3 && clear ? 'high' : 'medium';

    return SubcategoryResult(
      subcategory: top.subcategory,
      confidence: confidence,
      score: top.score,
      matchedTerms: top.matched,
    );
  }
}

class _Scored {
  _Scored(this.subcategory, this.score, this.matched);
  final String subcategory;
  final int score;
  final List<String> matched;
}
