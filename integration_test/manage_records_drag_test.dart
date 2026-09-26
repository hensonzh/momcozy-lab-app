import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:momcozy_flutter_app/modules/mom/application/me_controller.dart';
import 'package:momcozy_flutter_app/modules/mom/domain/me_experience.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_manage_records.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'drag the handle on device and save the new order',
    (tester) async {
      final repository = _RecordsRepository();
      final controller = MeController(
        repository: repository,
        now: () => DateTime(2026, 9, 25),
        state: repository.state,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MeManageRecords(controller: controller),
                    ),
                  ),
                  child: const Text('Manage records'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Manage records'));
      await tester.pumpAndSettle();

      final handle = find.byIcon(Icons.drag_handle).at(1);
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await gesture.moveBy(const Offset(0, 115));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('Energy today')).dy,
        greaterThan(tester.getTopLeft(find.text('Sleep last night')).dy),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repository.savedOrder, isNotNull);
      expect(
        repository.savedOrder!.indexOf(MeMetric.energy),
        greaterThan(repository.savedOrder!.indexOf(MeMetric.sleep)),
      );
      expect(find.text('Manage records'), findsOneWidget);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _RecordsRepository implements MeRepository {
  MeState state = const MeState(profile: {'preferred_name': 'Mia'});
  List<MeMetric>? savedOrder;

  @override
  Future<MeState> load(DateTime _) async => state;

  @override
  Future<Map<String, Object?>> saveProfile(Map<String, Object?> value) =>
      throw UnimplementedError();

  @override
  Future<MeConcern> saveConcern(MeConcern value) => throw UnimplementedError();

  @override
  Future<List<MeMetric>> saveOrder(List<MeMetric> value) async {
    savedOrder = List.of(value);
    state = state.copyWith(order: value);
    return value;
  }

  @override
  Future<MeObservation> saveRecord(MeObservation value) =>
      throw UnimplementedError();
}
