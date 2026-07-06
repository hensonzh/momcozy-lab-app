import 'agent_stream_client.dart';
import 'agent_stream_run_state.dart';

class AgentStreamRunner {
  const AgentStreamRunner(this.client);

  final AgentStreamClient client;

  Stream<AgentStreamRunState> run(
    AgentStreamRequest request, {
    AgentStreamRunState? initialState,
  }) async* {
    var state = initialState ?? const AgentStreamRunState().start();
    yield state;

    try {
      await for (final event in client.stream(request)) {
        state = state.applyEvent(event);
        yield state;
      }

      if (state.isActive) {
        yield state.markDisconnected(
          StateError('Agent stream ended before a terminal event.'),
        );
      }
    } catch (error) {
      yield state.markDisconnected(error);
    }
  }
}
