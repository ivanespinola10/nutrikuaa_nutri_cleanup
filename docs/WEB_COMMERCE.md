# Web y venta única: decisión de producto

**Estado:** diseño para piloto privado. El checkout y el validador de licencias
todavía no están implementados ni publicados.

## Oferta V1

- Nutricionista independiente o consultorio pequeño: pacientes, alimentos y
  recetas propias, planes, cálculos, PDF y backup cifrado, sin límite artificial
  de pacientes.
- Pago único por profesional, propuesta de hasta dos dispositivos activados.
- Uso permanente de la versión mayor comprada y trabajo local después de la
  primera activación. Definir por escrito el plazo de soporte y la política de
  futuras versiones mayores antes de cobrar.
- La compra no exige un servicio cloud para guardar datos de pacientes.

Los precios para validar, **no configurados en el checkout**, son USD 99 para
piloto fundador y USD 149 estándar. Se revisan con entrevistas y ventas de
prueba, considerando impuestos, comisiones y soporte.

## Flujo de compra propuesto

1. Demostración con datos ficticios y prueba privada en Chrome.
2. Checkout de pago único en Lemon Squeezy desde una página propia aprobada.
3. Webhook firmado de orden pagada en un servicio mínimo de licencias, sin
   almacenar fichas, recetas ni pacientes. Confirmar también reembolsos.
4. Activación inicial por clave. El servicio verifica la clave con Lemon,
   registra el número de dispositivos y entrega un permiso firmado que la app
   puede verificar localmente. La clave privada de firma nunca entra en la app.
5. El profesional sigue trabajando sin conexión continua. Reinstalación y
   cambio de dispositivo tienen un procedimiento de recuperación claro.

La app web no puede prometer protección perfecta frente a copias del código:
la licencia gestiona el acceso comercial sin impedir el uso sin conexión. No
añadir llamadas a Lemon en cada apertura ni login obligatorio. Usar modo de
prueba de Lemon para compra, activación, reembolso y pérdida de conexión antes
de habilitar pagos reales.

## Distribución y privacidad

La app de pago necesita un origen estable con HTTPS para la persistencia de
Chrome. Los datos profesionales viven en SQLite local del navegador y el
usuario debe exportar backups cifrados regularmente; borrar datos del sitio o
usar otro navegador/dispositivo no los sincroniza. La política de privacidad,
guía de respaldo, restauración y recuperación de licencia forman parte del
lanzamiento. La página comercial pública y el checkout real requieren
aprobación del propietario.

## Puertas de salida

- Catálogo con fuente, versión, checksum y pruebas sobre el archivo distribuido.
- Editar un alimento usado crea una nueva revisión sin cambiar planes previos.
- Restauración cifrada verificada en Chrome y aviso sobre almacenamiento local.
- Prueba completa paciente → plan → PDF → actualización → restauración.
- Piloto privado observado con profesionales; soporte, términos de venta y
  activación probados antes de configurar precio público.
