# Nutrikuaa Nutri 1.0 — Release Readiness

Nutrikuaa Nutri 1.0 is feature-frozen.

## Gate 1 — RC cleanup
- One visible version: RC · 1.0.0.
- UTF-8/mojibake cleanup.
- Internal assistant markers hidden and no longer written.
- USDA ranking: Foundation, then SR Legacy, then FNDDS.
- Nutri IA excludes fast-food-like/prepared matches as default building blocks.
- Energy is normalized again after protein boosting.
- Extreme energy/macronutrient deviations block applying a draft.
- Imported/professional Spanish and Portuguese foods can be found from the
  assistant's English search terms.
- Patient-facing USDA names use curated translations only.
- Windows product identity is Nutrikuaa Nutri.
- Firebase CLI cache is ignored.

## Gate 2 — before real clinical data
- Definitive patient deletion with related local records: implemented in RC1.
- Commercial privacy/terms dialog: implemented as product draft; legal review by market remains.
- Firebase/tester runtime removed from the commercial release branch.
- Protect the active Windows database at rest: pending.
- Test encrypted backup/restore on a clean Windows install: pending.
- Review runtime network traffic and dependencies: pending.

## Gate 3 — before payment
- Production build without tester/Firebase gate.
- Lemon Squeezy activation/validation/deactivation.
- Secure local license state.
- Normal offline use after activation.

## Gate 4 — release
- Windows installer/signing strategy.
- Clean-PC install.
- Lemon Squeezy Test Mode E2E.
- Offline restart, PDF, backup and restore.
- Tag v1.0.0.
