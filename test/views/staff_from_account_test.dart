import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/auth_client.dart';
import 'package:ringdrill/models/staff.dart';
import 'package:ringdrill/services/auth_service.dart';
import 'package:ringdrill/views/widgets/staff_from_account_picker.dart';

/// Putting yourself, and the people you share a plan with, on the roster.
///
/// The roster is not the account: most rows are markører recruited for a day,
/// typed in by hand, with no RingDrill account and no prospect of one. These
/// rules decide the minority of rows that *do* come from an account, and each
/// one is a distinct way to get it subtly wrong.
///
/// A roster can reach an account at all because of ADR-0072: the privacy
/// boundary is the public catalog, not the device — a plan owned by an account
/// is stored whole, roster included, so the co-coordinator running the same
/// exercise has the same phone list.

const _user = AuthUser(
  id: 'u_kari',
  displayName: 'Kari Nordmann',
  email: 'kari@example.com',
);

AccountMember _member(
  String id, {
  String? name,
  String? email,
  String state = 'accepted',
}) => AccountMember(
  userId: id,
  displayName: name,
  email: email,
  role: 'member',
  state: state,
);

Staff _staff(String uuid, String name, {String? userId}) =>
    Staff(uuid: uuid, realName: name, userId: userId);

void main() {
  group('who is offered', () {
    test('you are first, and offered even with no account at all', () {
      // Adding yourself must not depend on a round trip: the case this exists
      // for is a coordinator on a hill setting up their own roster.
      final candidates = buildStaffCandidates(
        user: _user,
        members: const [],
        roster: const [],
      );

      expect(candidates, hasLength(1));
      expect(candidates.single.isSelf, isTrue);
      expect(candidates.single.name, 'Kari Nordmann');
      expect(candidates.single.userId, 'u_kari');
    });

    test('your own membership is not a second row', () {
      final candidates = buildStaffCandidates(
        user: _user,
        members: [_member('u_kari', name: 'Kari Nordmann')],
        roster: const [],
      );

      expect(candidates, hasLength(1));
      expect(candidates.single.isSelf, isTrue);
    });

    test('a pending invitation is not a person yet', () {
      // Mail sent to an address is not somebody who has agreed to anything,
      // and it has no user id to link a roster row to.
      final candidates = buildStaffCandidates(
        user: _user,
        members: [
          _member('u_ola', name: 'Ola Nordmann'),
          _member('', email: 'nobody@example.com', state: 'invited'),
        ],
        roster: const [],
      );

      expect(candidates.map((c) => c.name), ['Kari Nordmann', 'Ola Nordmann']);
    });

    test('a member with no name is shown by address, never by id', () {
      final candidates = buildStaffCandidates(
        user: _user,
        members: [_member('u_ola', name: '  ', email: 'ola@example.com')],
        roster: const [],
      );

      expect(candidates.last.name, 'ola@example.com');
    });
  });

  group('who is already on', () {
    test('matches the link, so a second you is not offered', () {
      final candidates = buildStaffCandidates(
        user: _user,
        members: [_member('u_ola', name: 'Ola Nordmann')],
        roster: [_staff('s_1', 'Kari Nordmann', userId: 'u_kari')],
      );

      expect(candidates.first.alreadyOnRoster, isTrue, reason: 'you');
      expect(candidates.last.alreadyOnRoster, isFalse, reason: 'not Ola');
    });

    test('never matches on the name', () {
      // Two people called Kari Nordmann are two people. A name typed by hand
      // proves nothing about who it refers to, so the row stays unlinked and
      // the candidate is still offered — ending in two rows, which is the
      // honest outcome rather than a guess.
      final candidates = buildStaffCandidates(
        user: _user,
        members: const [],
        roster: [_staff('s_1', 'Kari Nordmann')],
      );

      expect(candidates.single.alreadyOnRoster, isFalse);
    });
  });

  group('the link on a Staff record', () {
    test('survives a JSON round trip', () {
      final saved = Staff.fromJson(
        _staff('s_1', 'Kari Nordmann', userId: 'u_kari').toJson(),
      );
      expect(saved.userId, 'u_kari');
    });

    test('is absent on a record written before it existed', () {
      // Additive and nullable: every roster in the field predates this, and
      // most rows will never have one — a markør has no account.
      final legacy = Staff.fromJson({'uuid': 's_1', 'realName': 'Ola'});
      expect(legacy.userId, isNull);
    });
  });
}
