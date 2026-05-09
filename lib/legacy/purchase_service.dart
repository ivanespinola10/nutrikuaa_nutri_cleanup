import 'dart:io';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchaseService {
  // Singleton: Para que el servicio sea único en toda la App
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  // ⚠️ AQUÍ PONDREMOS LA CLAVE QUE TE DARÁ LA WEB DE REVENUECAT
  // Por ahora dejamos este placeholder.
  final String _apiKeyAndroid = 'goog_TU_API_KEY_AQUI';

  // Variable para saber si es VIP
  bool isPro = false;

  // 1. INICIALIZAR EL SERVICIO
  Future<void> init() async {
    // Solo activamos logs en modo debug para ver qué pasa
    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration configuration;
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(_apiKeyAndroid);
    } else {
      return; // Si es web o iOS (por ahora) no hacemos nada
    }

    await Purchases.configure(configuration);
    await checkSubscription(); // Verificamos nada más abrir la app
  }

  // 2. VERIFICAR ESTADO (¿Ya pagó?)
  Future<void> checkSubscription() async {
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      // "pro_access" es el identificador estándar que usaremos en la web
      if (customerInfo.entitlements.all["pro_access"]?.isActive == true) {
        isPro = true;
      } else {
        isPro = false;
      }
    } catch (e) {
      print("Error verificando suscripción: $e");
      isPro = false;
    }
  }

  // 3. TRAER LOS PRECIOS DE LA TIENDA
  Future<List<Package>> getOfferings() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null &&
          offerings.current!.availablePackages.isNotEmpty) {
        return offerings.current!.availablePackages;
      }
    } catch (e) {
      print("Error trayendo precios: $e");
    }
    return []; // Retorna lista vacía si hay error o no hay internet
  }

  // 4. EJECUTAR LA COMPRA
  Future<bool> purchasePackage(Package package) async {
    try {
      CustomerInfo customerInfo = await Purchases.purchasePackage(package);
      if (customerInfo.entitlements.all["pro_access"]?.isActive == true) {
        isPro = true;
        return true; // ¡Compra exitosa!
      }
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        print("Error en compra: $e"); // El usuario canceló o falló la tarjeta
      }
    }
    return false;
  }

  // 5. RESTAURAR COMPRAS (Obligatorio si cambian de celular)
  Future<void> restorePurchases() async {
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      if (customerInfo.entitlements.all["pro_access"]?.isActive == true) {
        isPro = true;
      }
    } catch (e) {
      print("Error restaurando: $e");
    }
  }
}
