# Audit "Not a class" — Synthèse Ruby + JS

Référence : règles "You're not a class if…" — pas d'instances / classe abstraite / pas de state / invalide après new / sac à données. Ajout pour cet audit : héritage purement namespacing.

Détail par langage :
- [Rapport Ruby](audit-not-a-class-ruby.md) — 79 fichiers, 9 violations
- [Rapport JS](audit-not-a-class-js.md) — 78 fichiers (42 Stimulus + 36 autres), 9 violations
- [Vérification adversariale](audit-not-a-class-verification.md) — 3 vérificateurs ont relu chaque claim contre le code réel

---

## Diagnostic global

**La codebase est saine.** Sur ~157 fichiers audités (79 Ruby + 78 JS), 13-14 cas méritent une action, la moitié étant low-effort cosmétiques. Aucun problème architectural majeur, aucune classe "god object" déguisée, pas d'héritage profond inutile.

Les patterns Rails (AR + Concerns + Helpers) sont respectés et **ne sont pas le sujet**. Les Mailers / Jobs / Controllers ont été exclus du périmètre comme "imposés par Rails", mais **attention** : la vérification adversariale a flaggé `MessageNotificationMailer#load` qui mute 7 ivars partagées entre `mention` et `activity` — c'est exactement le smell ciblé. Un audit dédié des mailers/jobs serait pertinent en seconde passe (hors scope ici).

Les violations identifiées :

- 1 code mort en Ruby (`Purchaser`) → DELETE
- 1 code mort en JS (`tom_select_controller` + dépendance npm `tom-select`) → DELETE
- 4 "command objects" Ruby instanciés une fois et jetés → modules
- 2 "command objects" JS analogues → fonctions
- 1 sous-classe Struct confuse (`Sound::Image`)
- 1 singleton JS qui pourrait être un module (`Current`)
- 3 cas ambigus à arbitrer (`Filter*`, `WebPush::Notification`)

---

## Plan d'attaque proposé

**Branche unique** `refactor/not-a-class-pass-1` avec des commits par fichier pour permettre revue/revert ciblés. À la fin : PR vers main.

### Vague A — Suppressions et low-effort (1h30-2h)

Effort cumulé réaliste **1h30-2h** (l'estimation initiale "~1h" était optimiste). Sept actions, commits séparés.

| Ordre | Fichier | Action |
|---|---|---|
| 1 | `app/models/purchaser.rb` | DELETE (code mort, vérifié exhaustivement) |
| 2 | `app/javascript/controllers/tom_select_controller.js` + dépendance npm `tom-select` dans `package.json` | DELETE après confirmation (code mort, aucun usage côté templates ni JS) |
| 3 | `app/models/first_run.rb` | Class → `module FirstRun; extend self; def create!(...) ... end` |
| 4 | `app/models/opengraph/fetch.rb` | Class → `module Opengraph::Fetch; extend self` + ajuster `location.rb:19,47` + `Opengraph::FetchTest` |
| 5 | `app/models/opengraph/metadata/fetching.rb` | Drop `Concern + ClassMethods`, devient un module plat |
| 6 | `app/javascript/lib/autocomplete/renderer.js` | Class → 2 fonctions exportées, ajuster `base_autocomplete_handler.js:87` |
| 7 | `app/javascript/lib/rich_text/unfurl/unfurler.js` | Class → `installUnfurler()`, ajuster `initializers/rich_text.js:9-10` |

### Vague B — Refactors un poil plus impactants (~1h)

| Ordre | Fichier | Action |
|---|---|---|
| 8 | `app/models/sound.rb` (`Sound::Image`) | Remplacer la sous-classe Struct par `Data.define` ou inliner le calcul de `asset_path` côté `Sound` |
| 9 | `app/models/opengraph/document.rb` | Class → méthode de classe `opengraph_attributes(html)` ou `Data.define(:html)` |

### Vague C — Décisions à arbitrer avec toi

Pas d'action sans accord, juste des questions posées :

10. **Pattern `Filter` + `Filters`** (`lib/rails_ext/filter.rb` + `filters.rb`) — Q10 et Q14 initialement séparées, **fusionnées** suite à la vérif (Q14 était un doublon partiel). Question unique : que fait-on du pattern filter ?
    - Sous-classes (`SanitizeTags`, etc.) stockent juste `@content` consommé immédiatement → passable en modules.
    - `Filters` est une seule instance globale → candidat `Data.define`.
    - **Critère de décision** : si on prévoit d'ajouter d'autres filters → garder le pattern abstrait. Si non → modules + `Data.define`.
11. **`lib/web_push/notification.rb`** — Garder l'objet ? La vérif a confirmé que la `notification` est **capturée dans la closure du thread pool** (`web_push/pool.rb:27-31`), ce qui justifie l'objet (différer `deliver` après le post au pool). Refactor possible en `WebPush.deliver(...)` si on accepte un closure equivalent. **Pencher KEEP, peut sortir de la liste.**
12. **`app/javascript/initializers/current.js` (`Current`)** — Singleton `window.Current`, getters DOM, utilisé dans 10 fichiers. Migration vers objet littéral / module exporté ? Compatible avec l'API actuelle ?

**Question retirée** :
- ~~Q13 (`call_status_refresh_controller`)~~ — Sortie de Vague C. La vérif a montré que la **fusion avec `call_banner_controller` est inappropriée** (deux DOM targets distincts : banner vs `#user_sidebar`). Soit on laisse tel quel (12 lignes ok), soit on extrait un helper Stimulus générique `refresh-frame-on-connect`. Décision à coupler avec la Vague 2 vidéo plus tard, pas un sujet "not a class".

---

## Volumétrie attendue

- **Lignes touchées** : ~80-130 lignes nettes (Vague A ~50-90, Vague B ~30). Estimation initiale de 150-200 corrigée à la baisse après vérif.
- **Tests à ajuster** : `Opengraph::FetchTest` + éventuellement tests touchant `FirstRun`, `Renderer`, `Unfurler`.
- **Risque** : low. Les changements sont mécaniques, l'API publique reste équivalente.

## Niveau de confiance après vérification adversariale

- **Ruby** : 8/9 claims confirmés + 1 nuance mineure. 0 faux positif, 0 faux négatif. Rapport SAIN, à appliquer tel quel. *(détail : `audit-not-a-class-ruby-verification.md`)*
- **JS** : 4/5 violations confirmées, 1 partiellement réfutée (la recommandation de fusion `call_status_refresh` ↔ `call_banner` est inappropriée). Imprécisions de comptage (42 vs 44 controllers). Confiance ~85%. *(détail : `audit-not-a-class-js-verification.md`)*
- **Synthèse** : plan actionnable, mais chiffres macro initialement gonflés (corrigés ci-dessus). Claim "Mailers/Jobs imposés par Rails" trop catégorique — `MessageNotificationMailer#load` est un vrai smell non audité. *(détail : `audit-not-a-class-verification.md`)*

## Conseil

**Vague A** : traitable en 1 session (1h30-2h), commit par fichier, PR direct vers main. Risque ~null après vérif.
**Vague B** : 2 items low-effort à enchaîner derrière, ~1h.
**Vague C** : 3 questions (10, 11, 12) à arbitrer ensemble avant d'agir.

**Reste à décider plus tard** (hors scope de cette branche refactor) :
- Audit dédié des Mailers / Jobs (`MessageNotificationMailer#load` notamment)
- Sort de `call_status_refresh_controller` (à coupler à la Vague 2 vidéo)

Tu veux qu'on démarre par la Vague A maintenant, ou tu préfères trancher les 3 questions de Vague C d'abord ?
