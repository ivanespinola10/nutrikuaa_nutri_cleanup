import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/tester_access_policy.dart';
import '../config/tester_firebase_options.dart';
import '../data/app_settings_repository.dart';
import '../data/database_platform.dart';
import '../localization/nutri_i18n.dart';
import 'nutri_main_shell.dart';

/// The browser database is opened only after the account and current policy
/// have been checked. Hosting assets themselves remain publicly downloadable.
class TesterAccessGate extends StatefulWidget {
  const TesterAccessGate({super.key});

  @override
  State<TesterAccessGate> createState() => _TesterAccessGateState();
}

class _TesterAccessGateState extends State<TesterAccessGate> {
  Future<void>? _activation;
  String? _activeUid;

  Future<void> _activate(User user) async {
    final profile = await SharedPreferences.getInstance();
    final previous = profile.getString('nutri_tester_browser_uid');
    if (previous != null && previous != user.uid) {
      throw StateError(
        'Este perfil de Chrome ya contiene datos locales de otro tester. '
        'Abre un perfil de Chrome distinto para evitar mezclar fichas.',
      );
    }
    await configureDatabasePlatform();
    final settings = await AppSettingsRepository().load();
    NutriI18n.setLanguage(settings.languageCode);
    await profile.setString('nutri_tester_browser_uid', user.uid);
    await FirebaseFirestore.instance.collection('tester_activity').doc(user.uid).set({
      'email': user.email,
      'lastSeenAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, auth) {
        if (auth.hasError) return _message('No se pudo verificar la sesión.');
        if (!auth.hasData) {
          _activeUid = null;
          _activation = null;
          return const TesterLoginPage();
        }
        final user = auth.data!;
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('testers').doc(user.uid).snapshots(),
          builder: (context, access) {
            if (access.hasError) {
              return _message('No se pudo comprobar la invitación. Comprueba la conexión y las reglas de acceso.');
            }
            if (!access.hasData) return const _AccessLoading();
            if (access.data!.data()?['approved'] != true) {
              return _message('Esta cuenta no está habilitada para la beta. Contacta al responsable de la invitación.');
            }
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('tester_consents')
                  .doc(user.uid)
                  .collection('versions')
                  .doc(TesterAccessPolicy.version)
                  .snapshots(),
              builder: (context, consent) {
                if (consent.hasError) return _message('No se pudo consultar la aceptación de políticas.');
                if (!consent.hasData) return const _AccessLoading();
                if (!consent.data!.exists) return TesterConsentPage(user: user);
                if (_activeUid != user.uid) {
                  _activeUid = user.uid;
                  _activation = _activate(user);
                }
                return FutureBuilder<void>(
                  future: _activation,
                  builder: (context, ready) {
                    if (ready.hasError) return _message(ready.error.toString());
                    if (ready.connectionState != ConnectionState.done) return const _AccessLoading();
                    return NutriMainShell(onSignOut: () => FirebaseAuth.instance.signOut());
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _message(String message) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 36),
                    const SizedBox(height: 16),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _AccessLoading extends StatelessWidget {
  const _AccessLoading();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}

void showTesterPolicy(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(TesterAccessPolicy.title),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: SelectableText(
            '${TesterAccessPolicy.privacy}\n\nContacto: ${TesterFirebaseOptions.contact}\n\n'
            '${TesterAccessPolicy.terms}\n\nVersión: ${TesterAccessPolicy.version}',
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
    ),
  );
}

class TesterLoginPage extends StatefulWidget {
  const TesterLoginPage({super.key});

  @override
  State<TesterLoginPage> createState() => _TesterLoginPageState();
}

class _TesterLoginPageState extends State<TesterLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit({bool reset = false}) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final email = _email.text.trim();
      if (email.isEmpty) throw StateError('Escribe tu correo.');
      if (reset) {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email, password: _password.text,
        );
      }
      if (mounted && reset) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Si la cuenta existe, recibirás instrucciones de recuperación.')),
        );
      }
    } on FirebaseAuthException {
      if (mounted) setState(() => _error = 'No se pudo iniciar sesión. Revisa tus credenciales o contacta a Nutrikuaa.');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.eco_outlined, size: 48, color: Color(0xFF176B57)),
                      const SizedBox(height: 12),
                      Text('Nutrikuaa Nutri', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                      const SizedBox(height: 6),
                      const Text('Acceso a la prueba por invitación', textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      TextField(controller: _email, keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'Correo electrónico')),
                      const SizedBox(height: 12),
                      TextField(controller: _password, obscureText: true,
                        autofillHints: const [AutofillHints.password], decoration: const InputDecoration(labelText: 'Contraseña'),
                        onSubmitted: (_) => _submit()),
                      if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                      const SizedBox(height: 18),
                      FilledButton(onPressed: _busy ? null : _submit, child: const Text('Entrar')),
                      TextButton(onPressed: _busy ? null : () => _submit(reset: true), child: const Text('Recuperar acceso')),
                      TextButton(onPressed: () => showTesterPolicy(context), child: const Text('Privacidad y condiciones de prueba')),
                      const Text('Sólo para pruebas con pacientes ficticios. El trabajo se guarda en este navegador.', textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class TesterConsentPage extends StatefulWidget {
  const TesterConsentPage({required this.user, super.key});
  final User user;

  @override
  State<TesterConsentPage> createState() => _TesterConsentPageState();
}

class _TesterConsentPageState extends State<TesterConsentPage> {
  bool _checked = false;
  bool _busy = false;
  String? _error;

  Future<void> _accept() async {
    setState(() { _busy = true; _error = null; });
    try {
      await FirebaseFirestore.instance
          .collection('tester_consents')
          .doc(widget.user.uid)
          .collection('versions')
          .doc(TesterAccessPolicy.version)
          .set({
        'email': widget.user.email,
        'version': TesterAccessPolicy.version,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo registrar la aceptación. Comprueba tu conexión.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Condiciones de la prueba')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Antes de comenzar, lee las condiciones y el tratamiento de datos de esta prueba.'),
                const SizedBox(height: 16),
                Card(child: Padding(padding: const EdgeInsets.all(20), child: SelectableText(
                  '${TesterAccessPolicy.privacy}\n\nContacto: ${TesterFirebaseOptions.contact}\n\n${TesterAccessPolicy.terms}\n\nVersión: ${TesterAccessPolicy.version}',
                ))),
                CheckboxListTile(
                  value: _checked,
                  onChanged: _busy ? null : (value) => setState(() => _checked = value ?? false),
                  title: const Text('Leí y acepto estas condiciones para participar en la beta cerrada.'),
                ),
                if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                FilledButton(onPressed: _checked && !_busy ? _accept : null, child: const Text('Aceptar y continuar')),
                TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('No acepto; cerrar sesión')),
              ],
            ),
          ),
        ),
      );
}
