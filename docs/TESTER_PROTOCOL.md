# Protocolo: sesión de 15 minutos con nutricionistas

**Estado:** listo para conducir una vez habilitada la beta privada; no se han
realizado entrevistas ni pruebas observadas con profesionales.

## Preparación

Invitar individualmente a 5–8 profesionales independientes que ejerzan en
Paraguay; registrar especialidad y familiaridad previa con software de planes,
sin pacientes ni información clínica. Confirmar consentimiento para observar,
tomar notas y, opcionalmente, conservar el PDF ficticio. Chrome de escritorio,
perfil limpio, enlace protegido; comprobar disponibilidad del catálogo. Crear
un registro por sesión usando `docs/tester_results_template.csv` en un espacio
privado. No escribir nombres de pacientes reales; usar alias de participante.

## Guion leído al participante

«Durante 15 minutos, trabaja con una ficha **ficticia**. Crea a Ana Prueba,
define una meta diaria de 1800 kcal y 90 g de proteínas como datos de ensayo,
crea una semana, compón lunes, martes y miércoles con alimentos o recetas de
tu elección, corrige la cantidad de uno de ellos y revisa el documento.
Guarda el PDF y muéstrame cómo lo compartirías sin enviarlo a una persona real.
Si algo te confunde, dilo en voz alta. No estoy evaluando tus decisiones
nutricionales.»

La meta es un valor ficticio de navegación, no una recomendación clínica. No
guiar los clics. Si la persona solicita ayuda, registrar momento y contenido
de la intervención. Detener el reloj a los 15 minutos, dejar constancia de la
etapa y preguntar qué faltó. Preguntar después: «¿Qué no quedó claro?» y
«¿Qué palabra de alimento o medida cambiarías?»; conservar texto literal
breve con consentimiento.

## Registro y criterios

Marcar tiempos acumulados desde el inicio hasta: ficha+objetivos, tres días
compuestos, cantidad corregida, PDF guardado, explicación del compartir. Un
error es una acción que necesita deshacerse o corrección; anotar ubicación y
consecuencia. `abandono` = no puede o decide no completar una etapa; registrar
causa referida por el tester. `terminó_en_15m` sólo si completó todos los hitos
sin ayuda operativa y con PDF correcto para el caso ficticio. Registrar
incidentes técnicos separados de errores de navegación. Observar además si
notó días vacíos, fuente del alimento, revisión energética y lista de compras.

Tras las sesiones, calcular mediana de tiempo por hito, tasa de finalización
y errores por etapa; listar patrones de abandono y reformular UI. No llamar a
esto validación clínica. Cualquier filtro por restricciones requiere revisión
separada de datos y seguridad.
