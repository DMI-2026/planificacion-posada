/// Fallas de autenticación que ve la app. El ViewModel nunca recibe una
/// excepción de Firebase, solo una [AuthFailure].
sealed class AuthFailure implements Exception {
  const AuthFailure();
}

class CredencialesInvalidas extends AuthFailure {
  const CredencialesInvalidas();
}

class CorreoYaRegistrado extends AuthFailure {
  const CorreoYaRegistrado();
}

class ContrasenaDebil extends AuthFailure {
  const ContrasenaDebil();
}

class DemasiadosIntentos extends AuthFailure {
  const DemasiadosIntentos();
}

class SinConexion extends AuthFailure {
  const SinConexion();
}

class AuthDesconocida extends AuthFailure {
  const AuthDesconocida();
}
