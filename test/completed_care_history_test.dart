// Completed Care History (per pet) + health/checkup note edit/delete.
//
// The aggregation is a pure function of (pet, reminders, filter), and the
// note edit/delete rules are pure list transforms behind
// PetProfileProvider.updateHealthRecord/deleteHealthRecord, so everything
// here runs without Firebase. The persistence test uses real Hive with a
// fresh read (simulating an app restart), the same way the provider stores
// profiles (a JSON string per pet in 'full_pet_profiles').
//
// What the provider then does with those lists (notify, Hive write,
// Firestore upload) is shared, already-existing updateDetails code and was
// verified by code review — PetProfileProvider itself touches Firebase and is
// not constructible under plain `flutter test`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:persipal_app/models/pet_extended_models.dart';
import 'package:persipal_app/models/reminder_item_model.dart';
import 'package:persipal_app/providers/pet_profile_provider.dart';
import 'package:persipal_app/services/completed_care_history.dart';
import 'package:persipal_app/widgets/date_filter_control.dart';

// Thursday, 24 Sep 2026 12:00 — the fixed "now" every filter is evaluated at.
final _now = DateTime(2026, 9, 24, 12);

FullPetProfile _pet(
  String id, {
  List<HealthRecord> notes = const [],
  List<VaccinationRecord> vaccines = const [],
}) =>
    FullPetProfile.create(id: id, name: 'Pet $id').copyWith(
      healthRecords: notes,
      vaccinations: vaccines,
    );

ReminderItem _rem(
  String id, {
  required String petId,
  String type = 'Feeding',
  bool done = true,
  DateTime? scheduledAt,
  DateTime? completedAt,
  String? linkedVaccinationId,
}) =>
    ReminderItem(
      id: id,
      title: 'Reminder $id',
      type: type,
      scheduledAt: scheduledAt ?? DateTime(2026, 9, 1, 8),
      isDone: done,
      petId: petId,
      completedAt: completedAt,
      linkedVaccinationId: linkedVaccinationId,
    );

VaccinationRecord _vax(
  String id, {
  required DateTime date,
  String status = 'completed',
  DateTime? next,
}) =>
    VaccinationRecord(
      id: id,
      vaccineName: 'Vax $id',
      completedDate: date,
      status: status,
      nextSchedule: next,
    );

CompletedCareHistory _build(
  FullPetProfile pet,
  List<ReminderItem> reminders, [
  DateFilterSelection filter = const DateFilterSelection.allDates(),
]) =>
    buildCompletedCareHistory(
        pet: pet, reminders: reminders, filter: filter, now: _now);

List<String> _ids(List<CompletedCareEntry> e) => e.map((x) => x.id).toList();

void main() {
  group('checkup note edit / delete (pure list rules)', () {
    final a = HealthRecord(id: 'a', date: DateTime(2026, 5, 1), notes: 'A');
    final b = HealthRecord(id: 'b', date: DateTime(2026, 6, 1), notes: 'B');

    test('edit replaces the note in place — same id, no duplicate', () {
      final out = PetProfileProvider.applyHealthRecordEdit(
          [a, b], b.copyWith(notes: 'B edited'))!;
      expect(out, hasLength(2));
      expect(out.where((r) => r.id == 'b'), hasLength(1));
      expect(out.firstWhere((r) => r.id == 'b').notes, 'B edited');
      expect(out.firstWhere((r) => r.id == 'a').notes, 'A');
    });

    test('edit can move the date and the list stays date-sorted', () {
      final out = PetProfileProvider.applyHealthRecordEdit(
          [a, b], a.copyWith(date: DateTime(2026, 7, 1)))!;
      expect(out.map((r) => r.id), ['b', 'a']);
    });

    test('editing an id that is not in the list changes nothing (null)', () {
      expect(
        PetProfileProvider.applyHealthRecordEdit(
            [a], HealthRecord(id: 'zzz', date: _dummy, notes: 'x')),
        isNull,
      );
    });

    test('delete removes only that note', () {
      final out = PetProfileProvider.applyHealthRecordDelete([a, b], 'a');
      expect(out.map((r) => r.id), ['b']);
    });

    test('delete of an unknown id leaves the list intact', () {
      expect(PetProfileProvider.applyHealthRecordDelete([a, b], 'nope'),
          hasLength(2));
    });

    test('edit on one pet\'s list can never touch another pet\'s note', () {
      final petA = _pet('A', notes: [a]);
      final petB = _pet('B', notes: [a]); // same note id, different pet
      final editedA = PetProfileProvider.applyHealthRecordEdit(
          petA.healthRecords, a.copyWith(notes: 'only A'))!;
      expect(editedA.single.notes, 'only A');
      expect(petB.healthRecords.single.notes, 'A');
    });
  });

  group('completed history — what is included', () {
    test('completed reminder is included, filed under Completed Reminders', () {
      final h = _build(_pet('p1'), [
        _rem('r1', petId: 'p1', completedAt: DateTime(2026, 9, 2, 9)),
      ]);
      expect(_ids(h.reminders), ['r1']);
      expect(h.vetVisits, isEmpty);
      expect(h.vaccinations, isEmpty);
    });

    test('pending, overdue and upcoming reminders are excluded', () {
      final h = _build(_pet('p1'), [
        _rem('upcoming',
            petId: 'p1',
            done: false,
            scheduledAt: _now.add(const Duration(days: 3))),
        _rem('overdue',
            petId: 'p1',
            done: false,
            scheduledAt: _now.subtract(const Duration(days: 3))),
        _rem('vetPending', petId: 'p1', type: 'Vet Visit', done: false),
      ]);
      expect(h.isEmpty, isTrue);
    });

    test('a reset reminder (pending again) leaves the history', () {
      final done = _rem('r', petId: 'p1', completedAt: DateTime(2026, 9, 2));
      expect(_build(_pet('p1'), [done]).total, 1);
      final reset = done.copyWith(isDone: false, completedAt: null);
      expect(_build(_pet('p1'), [reset]).total, 0);
    });

    test('completed vaccination is included; planned (pending) is not', () {
      final h = _build(
        _pet('p1', vaccines: [
          _vax('given', date: DateTime(2026, 9, 3)),
          _vax('planned', date: DateTime(2026, 10, 3), status: 'upcoming'),
          _vax('overduePlanned',
              date: DateTime(2026, 9, 1), status: 'upcoming'),
        ]),
        const [],
      );
      expect(_ids(h.vaccinations), ['given']);
    });

    test('a completed dose carrying a next-dose date is still a given dose',
        () {
      final h = _build(
        _pet('p1', vaccines: [
          _vax('d', date: DateTime(2026, 9, 3), next: DateTime(2027, 9, 3)),
        ]),
        const [],
      );
      expect(_ids(h.vaccinations), ['d']);
    });

    test('completed vet visit reminder and checkup note are Veterinary Visits',
        () {
      final h = _build(
        _pet('p1', notes: [
          HealthRecord(id: 'n1', date: DateTime(2026, 9, 5), notes: 'ok'),
        ]),
        [
          _rem('v1',
              petId: 'p1',
              type: 'Vet Visit',
              completedAt: DateTime(2026, 9, 10)),
        ],
      );
      expect(_ids(h.vetVisits), ['v1', 'n1']); // newest first
      expect(h.reminders, isEmpty);
    });

    test('a vaccination-linked reminder is not listed again (no duplicate)',
        () {
      final h = _build(
        _pet('p1', vaccines: [_vax('v', date: DateTime(2026, 9, 3))]),
        [
          _rem('linked',
              petId: 'p1',
              type: 'Vet Visit',
              linkedVaccinationId: 'v',
              completedAt: DateTime(2026, 9, 3)),
        ],
      );
      expect(h.total, 1);
      expect(_ids(h.vaccinations), ['v']);
    });

    test('a deleted note is gone from history', () {
      final n = HealthRecord(id: 'n', date: DateTime(2026, 9, 5), notes: 'x');
      final before = _pet('p1', notes: [n]);
      expect(_build(before, const []).vetVisits, hasLength(1));
      final after = before.copyWith(
          healthRecords:
              PetProfileProvider.applyHealthRecordDelete(before.healthRecords, 'n'));
      expect(_build(after, const []).vetVisits, isEmpty);
    });

    test('an edited note shows its new text/date (no second entry)', () {
      final n = HealthRecord(id: 'n', date: DateTime(2026, 9, 5), notes: 'old');
      final edited = PetProfileProvider.applyHealthRecordEdit(
          [n], n.copyWith(notes: 'new', date: DateTime(2026, 9, 6)))!;
      final h = _build(_pet('p1', notes: edited), const []);
      expect(h.vetVisits, hasLength(1));
      expect(h.vetVisits.single.notes, 'new');
      expect(h.vetVisits.single.date, DateTime(2026, 9, 6));
    });
  });

  group('completed history — pet isolation', () {
    test('Pet A and Pet B each see only their own completed care', () {
      final petA = _pet('A', vaccines: [_vax('vA', date: DateTime(2026, 9, 3))]);
      final petB = _pet('B', notes: [
        HealthRecord(id: 'nB', date: DateTime(2026, 9, 4), notes: 'b'),
      ]);
      final reminders = [
        _rem('rA', petId: 'A', completedAt: DateTime(2026, 9, 2)),
        _rem('rB', petId: 'B', completedAt: DateTime(2026, 9, 2)),
        _rem('rNone', petId: 'A').copyWith(petId: null, completedAt: DateTime(2026, 9, 2)),
      ];

      final a = _build(petA, reminders);
      final b = _build(petB, reminders);

      expect([..._ids(a.all)]..sort(), ['rA', 'vA']);
      expect([..._ids(b.all)]..sort(), ['nB', 'rB']);
    });
  });

  group('completed history — date filtering', () {
    // One completed item on each side of every boundary.
    final pet = _pet('p1', vaccines: [
      _vax('thisWeek', date: DateTime(2026, 9, 22)), // Tue, this week
      _vax('thisMonthEarly', date: DateTime(2026, 9, 2)),
      _vax('lastMonth', date: DateTime(2026, 8, 15)),
      _vax('thisYearOld', date: DateTime(2026, 2, 1)),
      _vax('lastYear', date: DateTime(2025, 6, 1)),
      _vax('older', date: DateTime(2024, 1, 1)),
    ]);

    List<String> ids(DateFilterSelection f) =>
        _ids(_build(pet, const [], f).vaccinations)..sort();

    test('All Dates lists everything', () {
      expect(ids(const DateFilterSelection.allDates()), hasLength(6));
    });

    test('This Week (Mon 21 – Sun 27 Sep)', () {
      expect(ids(const DateFilterSelection.thisWeek()), ['thisWeek']);
    });

    test('This Month', () {
      expect(ids(const DateFilterSelection.thisMonth()),
          ['thisMonthEarly', 'thisWeek']);
    });

    test('Last Month', () {
      expect(ids(const DateFilterSelection.lastMonth()), ['lastMonth']);
    });

    test('This Year', () {
      expect(ids(const DateFilterSelection.thisYear()),
          ['lastMonth', 'thisMonthEarly', 'thisWeek', 'thisYearOld']);
    });

    test('Last Year', () {
      expect(ids(const DateFilterSelection.lastYear()), ['lastYear']);
    });

    test('Custom Date Range — end date is inclusive of the whole day', () {
      final f = DateFilterSelection.custom(DateTimeRange(
          start: DateTime(2026, 8, 15), end: DateTime(2026, 9, 2)));
      expect(ids(f), ['lastMonth', 'thisMonthEarly']);
    });

    test('reminders filter by completedAt, NOT scheduledAt', () {
      // Scheduled Sept 1 (this month) but completed last year.
      final r = _rem('r',
          petId: 'p1',
          scheduledAt: DateTime(2026, 9, 1, 8),
          completedAt: DateTime(2025, 12, 31, 20));
      final p = _pet('p1');
      expect(_ids(_build(p, [r], const DateFilterSelection.thisMonth()).reminders),
          isEmpty);
      expect(_ids(_build(p, [r], const DateFilterSelection.lastYear()).reminders),
          ['r']);
    });

    test('a legacy completed reminder without completedAt falls back to '
        'scheduledAt instead of vanishing', () {
      final r = _rem('legacy', petId: 'p1', scheduledAt: DateTime(2026, 9, 2));
      expect(_build(_pet('p1'), [r]).reminders, hasLength(1));
      expect(
          _build(_pet('p1'), [r], const DateFilterSelection.thisMonth())
              .reminders,
          hasLength(1));
    });

    test('checkup notes filter by their visit date', () {
      final p = _pet('p1', notes: [
        HealthRecord(id: 'n1', date: DateTime(2026, 9, 10), notes: ''),
        HealthRecord(id: 'n2', date: DateTime(2026, 1, 10), notes: ''),
      ]);
      expect(_ids(_build(p, const [], const DateFilterSelection.thisMonth()).vetVisits),
          ['n1']);
    });

    test('filtering never mutates the underlying records', () {
      final p = _pet('p1', vaccines: [_vax('a', date: DateTime(2024, 1, 1))]);
      final r = _rem('r', petId: 'p1', completedAt: DateTime(2024, 1, 2));
      _build(p, [r], const DateFilterSelection.thisWeek());
      expect(p.vaccinations, hasLength(1));
      expect(r.isDone, isTrue);
      expect(r.completedAt, DateTime(2024, 1, 2));
    });
  });

  group('pending vaccination doses (dashboard)', () {
    test('planned doses and completed records with a next date, this pet only',
        () {
      final pet = _pet('p1', vaccines: [
        _vax('given', date: DateTime(2026, 9, 3)),
        _vax('planned', date: DateTime(2026, 11, 1), status: 'upcoming'),
        _vax('nextDue',
            date: DateTime(2026, 8, 1), next: DateTime(2026, 9, 1)),
      ]);
      final pending = pendingVaccinationsFor(pet);
      expect(pending.map((p) => p.record.id), ['nextDue', 'planned']);
      expect(pending.first.isOverdueAt(_now), isTrue);
      expect(pending.last.isOverdueAt(_now), isFalse);
    });
  });

  group('persistence round-trip (real Hive, fresh read)', () {
    late Directory dir;

    setUpAll(() async {
      dir = Directory.systemTemp.createTempSync('persipal_completed_hist');
      Hive.init(dir.path);
      await Hive.openBox<String>('full_pet_profiles');
    });

    tearDownAll(() async {
      await Hive.close();
      dir.deleteSync(recursive: true);
    });

    FullPetProfile reload(String id) {
      final raw = Hive.box<String>('full_pet_profiles').get(id)!;
      return FullPetProfile.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    }

    Future<void> save(FullPetProfile p) => Hive.box<String>('full_pet_profiles')
        .put(p.id, jsonEncode(p.toMap()));

    test('edited and deleted notes and completed doses survive a reload',
        () async {
      final n1 = HealthRecord(id: 'n1', date: DateTime(2026, 9, 1), notes: 'one');
      final n2 = HealthRecord(id: 'n2', date: DateTime(2026, 9, 2), notes: 'two');
      var pet = _pet('persist', notes: [n1, n2], vaccines: [
        _vax('v', date: DateTime(2026, 9, 3)),
      ]);
      await save(pet);

      // Edit n1, delete n2 — exactly the transforms the provider applies.
      pet = pet.copyWith(
        healthRecords: PetProfileProvider.applyHealthRecordDelete(
          PetProfileProvider.applyHealthRecordEdit(
              pet.healthRecords, n1.copyWith(notes: 'one edited'))!,
          'n2',
        ),
      );
      await save(pet);

      final back = reload('persist');
      expect(back.healthRecords.map((r) => (r.id, r.notes)),
          [('n1', 'one edited')]);
      final h = buildCompletedCareHistory(
          pet: back, reminders: const [], now: _now);
      expect(_ids(h.vetVisits), ['n1']);
      expect(_ids(h.vaccinations), ['v']);
    });

    test('two pets stored side by side stay separate after a reload', () async {
      await save(_pet('one', notes: [
        HealthRecord(id: 'x', date: DateTime(2026, 9, 1), notes: 'for one'),
      ]));
      await save(_pet('two'));
      expect(reload('one').healthRecords, hasLength(1));
      expect(reload('two').healthRecords, isEmpty);
    });
  });
}

final DateTime _dummy = DateTime(2026, 1, 1);
