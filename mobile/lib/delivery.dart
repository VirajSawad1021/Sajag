// "Did it arrive?" — one place for the answer, whether it comes from a notification button or the in-app card.
import 'package:flutter/material.dart';

import 'models.dart';
import 'screens/case_screen.dart';
import 'screens/recovery_screen.dart';
import 'store.dart';

/// Verified deadlines whose date has arrived (today or earlier) on a case that is still open.
List<Map<String, dynamic>> dueDeadlines(SajagCase c) {
  if (c.status == CaseStatus.resolved || c.recovery.containsKey('delivery_answered')) return const [];
  final today = DateTime.now();
  final endOfToday = DateTime(today.year, today.month, today.day, 23, 59);
  return (c.latest?.a.deadlines ?? const <Map<String, dynamic>>[]).where((d) {
    final due = DateTime.tryParse('${d['due'] ?? ''}');
    return d['grounded'] == true && due != null && !due.isAfter(endOfToday);
  }).toList();
}

/// Yes → the case is resolved. Not yet → the purchase is treated as paid and recovery opens.
Future<void> answerDelivery(NavigatorState nav, SajagCase c, {required bool arrived}) async {
  c.recovery['delivery_answered'] = DateTime.now().toIso8601String();
  if (arrived) {
    c.status = CaseStatus.resolved;
    await store.save(c);
    nav.push(MaterialPageRoute(builder: (_) => CaseScreen(caseId: c.id)));
  } else {
    c.stage = 'after_payment';
    c.status = CaseStatus.recovery;
    await store.save(c);
    nav.push(MaterialPageRoute(builder: (_) => RecoveryScreen(caseId: c.id)));
  }
}
