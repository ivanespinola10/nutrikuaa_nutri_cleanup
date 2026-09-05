# NutriKuaa Nutri — Architecture

**Versión:** 0.1  
**Estado:** Arquitectura inicial

---

## 1. Objetivo arquitectónico

NutriKuaa Nutri debe ser una aplicación:

- local-first;
- modular;
- fácil de mantener;
- apta para desarrollo asistido por agentes de IA;
- con lógica de negocio separada de la interfaz;
- con cálculos nutricionales testeables;
- preparada para incorporar sincronización opcional en el futuro.

La arquitectura debe priorizar claridad y bajo mantenimiento sobre complejidad innecesaria.

---

## 2. Principio principal

La interfaz de usuario no debe contener directamente:

- consultas SQL;
- cálculos nutricionales complejos;
- reglas de negocio;
- lógica de licencia;
- generación de PDF;
- sincronización futura.

Cada responsabilidad debe estar separada.

---

## 3. Capas

La aplicación se organizará conceptualmente en las siguientes capas:

```text
Presentation
     ↓
Application
     ↓
Domain
     ↓
Data