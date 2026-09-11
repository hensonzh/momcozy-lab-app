import 'package:http/http.dart' as http;
import '../../core/auth/auth_token_store.dart';
import '../../core/auth/momcozy_auth_device_id.dart';
import '../../core/network/api_json_transport.dart';
import '../../core/network/http_api_json_transport.dart';
import '../../core/network/refreshing_json_transport.dart';
import '../../modules/ibclc/auth/application/workbench_auth_controller.dart';
import '../../services/ibclc/workbench_api_repository.dart';

/// Independent expert session and HTTP client; no maternal account or selected
/// baby is synthesized while bootstrapping the workbench.
class WorkbenchRuntime {
  WorkbenchRuntime({
    required Uri baseUri,
    http.Client? client,
    AuthTokenStore? tokenStore,
    MomCozyAuthDeviceIdStore? deviceStore,
  }) : _client = client ?? http.Client() {
    ApiJsonTransport create(String? token) => HttpApiJsonTransport(
      baseUri: baseUri,
      client: _client,
      accessToken: token,
    );
    transport = RefreshingJsonTransport(
      transportFactory: create,
      accessToken: () => auth.accessToken,
      sessionGeneration: () => auth.generation,
      refresh: (token) => auth.refresh(token),
    );
    auth = WorkbenchAuthController(
      gateway: WorkbenchAuthApiGateway(
        anonymous: create(null),
        authenticated: transport,
      ),
      store:
          tokenStore ??
          const SecureAuthTokenStore(key: 'momcozy.ibclc.tokens.v1'),
      devices:
          deviceStore ??
          const FlutterSecureMomCozyAuthDeviceIdStore(
            key: 'momcozy.ibclc.device.v1',
          ),
    );
    repository = WorkbenchApiRepository(transport: transport);
  }
  final http.Client _client;
  late final ApiJsonTransport transport;
  late final WorkbenchAuthController auth;
  late final WorkbenchApiRepository repository;
  void dispose() {
    auth.dispose();
    _client.close();
  }
}
