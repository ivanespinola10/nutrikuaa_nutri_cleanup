# NutriKuaa Nutri — Agent Instructions

## 1. Project purpose

NutriKuaa Nutri is a professional nutrition planning application for
independent nutritionists and small nutrition practices.

Its primary goal is to reduce repetitive work involved in:

- managing patients;
- creating nutrition plans;
- calculating nutritional composition;
- reusing recipes and foods;
- comparing plans with nutritional targets;
- generating professional documents.

Before making changes, read:

1. PRODUCT_SPEC.md
2. ARCHITECTURE.md

These files define the product and architectural direction.

---

## 2. Product principles

The project must remain:

- local-first;
- simple to maintain;
- modular;
- suitable for a small development team;
- usable without permanent internet access;
- compatible with a one-time purchase business model.

Do not introduce recurring infrastructure costs unless explicitly requested.

---

## 3. Forbidden assumptions

Do not assume NutriKuaa Nutri needs:

- generative AI;
- chatbots;
- Firebase;
- cloud-first architecture;
- subscriptions;
- RevenueCat;
- mandatory login;
- patient portal;
- hospital workflows;
- appointment scheduling;
- billing;
- WhatsApp integration.

These features are outside the MVP unless explicitly requested.

---

## 4. Architecture rules

Follow the architecture described in ARCHITECTURE.md.

Conceptual layers:

```text
Presentation
    ↓
Application
    ↓
Domain
    ↓
Data