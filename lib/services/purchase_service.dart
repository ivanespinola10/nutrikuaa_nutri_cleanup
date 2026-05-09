import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb; // <--- VITAL PARA LA WEB
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseService {
  // --- CONFIGURACIÓN ---
  final String _apiKeyGoogle = "goog_tu_api_key_aqui";

  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  bool _isPro = false;
  bool get isPro => _isPro;

  Future<void> init() async {
    // 1. SI ESTAMOS EN LA WEB, SALIMOS: RevenueCat no soporta Web con este plugin
    if (kIsWeb) {
      print(
        "NutriKuaa: Modo Web detectado. Saltando configuración de compras.",
      );
      await _checkStatus(); // Solo revisamos el estado local (caché)
      return;
    }

    // 2. CONFIGURACIÓN PARA MÓVIL
    try {
      await Purchases.setLogLevel(LogLevel.debug);

      PurchasesConfiguration? configuration;
      if (Platform.isAndroid) {
        configuration = PurchasesConfiguration(_apiKeyGoogle);
      }

      if (configuration != null) {
        await Purchases.configure(configuration);
        await _checkStatus();
      }
    } catch (e) {
      print("Error inicializando RevenueCat: $e");
    }
  }

  Future<List<Package>> getOfferings() async {
    if (kIsWeb) return []; // No hay ofertas en web por ahora
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      return current != null ? current.availablePackages : [];
    } on PlatformException catch (_) {
      return [];
    }
  }

  Future<bool> purchasePackage(Package package) async {
    if (kIsWeb) return false;
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      final isProActive =
          customerInfo.entitlements.all["pro"]?.isActive ?? false;

      if (isProActive) {
        _isPro = true;
        await _guardarEstadoLocal(true);
      }
      return isProActive;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        print("Error de compra: $e");
      }
      return false;
    }
  }

  Future<void> restorePurchases() async {
    if (kIsWeb) return;
    try {
      final customerInfo = await Purchases.restorePurchases();
      _isPro = customerInfo.entitlements.all["pro"]?.isActive ?? false;
      await _guardarEstadoLocal(_isPro);
    } on PlatformException catch (_) {
      // Error al restaurar
    }
  }

  Future<void> _checkStatus() async {
    // Primero intentamos la caché local (más rápido y funciona en Web)
    final prefs = await SharedPreferences.getInstance();
    _isPro = prefs.getBool('es_vip') ?? false;

    // Si no estamos en Web, intentamos validar con el servidor de RevenueCat
    if (!kIsWeb) {
      try {
        final customerInfo = await Purchases.getCustomerInfo();
        _isPro = customerInfo.entitlements.all["pro"]?.isActive ?? false;
        await _guardarEstadoLocal(_isPro);
      } catch (_) {
        // Si falla internet, mantenemos lo que diga la caché local
      }
    }
  }

  Future<void> _guardarEstadoLocal(bool estado) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('es_vip', estado);
  }
}
