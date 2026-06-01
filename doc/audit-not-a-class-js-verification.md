# Vérification adversariale — audit "Not a class" JS

Vérification ligne par ligne du rapport `doc/audit-not-a-class-js.md` contre le code source réel. Default = "réfuté" sans preuve.

## Métriques globales du rapport

| Claim | Vérification | Verdict |
|---|---|---|
| « 44 Stimulus controllers » | `find … -name "*_controller.js"` → **42** controllers. `application.js` et `index.js` ne sont pas des controllers. | **PARTIELLEMENT RÉFUTÉ** — léger gonflage |
| « 36 autres » | `find -not -path "*/controllers/*"` → 36 ✓ | **CONFIRMÉ** |
| « 80 fichiers audités » | 42 + 36 = 78. Rapport arrondi. | **APPROXIMATIF** |
| « 16 classes hors Stimulus » | `grep -l "class …"` → **21 fichiers** contenant `class` (et `message_paginator.js` en a 2, donc ≥22 classes). | **RÉFUTÉ** — sous-estimé |

Conclusion : chiffres macro imprécis mais sans impact sur les verdicts individuels.

---

## Violation 1 — `Renderer` (`lib/autocomplete/renderer.js`)

1. « Aucun champ d'instance » — **CONFIRMÉ.** Pas de constructor, pas de `this.xxx = …`, juste 2 méthodes.
2. « Les 2 méthodes lisent leurs arguments et retournent du HTML » — **CONFIRMÉ** avec nuance : `renderAutocompletableSuggestions` appelle `this.renderAutocompletable(...)` (ligne 18) ; `this` sert au dispatch interne, pas au stockage.
3. « Usage unique : `base_autocomplete_handler.js:87` » — **CONFIRMÉ.** Une seule instanciation, jetée immédiatement.

**Verdict : FONCTION — CONFIRMÉ.**

---

## Violation 2 — `Current` (`initializers/current.js`)

1. « 2 getters lisant le DOM, zéro champ d'instance » — **CONFIRMÉ.**
2. « Singleton `window.Current = new Current()` » — **CONFIRMÉ** (ligne 23).
3. « Utilisé largement » — **CONFIRMÉ.** 11 occurrences dans 10 fichiers.

**Verdict : REFACTOR-OTHER — CONFIRMÉ.**

---

## Violation 3 — `Unfurler` (`lib/rich_text/unfurl/unfurler.js`)

1. « Pas de constructeur, pas d'état » — **CONFIRMÉ.** Les méthodes utilisent `this.#methodName.bind(this)` uniquement pour le dispatch.
2. « Pattern d'usage forcé : `new Unfurler(); unfurler.install()` » — **CONFIRMÉ.**
3. « Sans `install()`, l'instance est inerte » — **CONFIRMÉ.**

**Verdict : FONCTION — CONFIRMÉ.**

---

## Violation 4 — `tom_select_controller.js` (CODE MORT)

1. Commentaires "loaded separately" — **CONFIRMÉ.**
2. `application.register("tom-select", tom_select)` commenté — **CONFIRMÉ.**
3. Aucun chargement séparé — **CONFIRMÉ.**
4. Aucune occurrence côté templates — **CONFIRMÉ.**

**Note ajoutée par la vérif** : `package.json` contient toujours `"tom-select": "^2.5.2"`. Si on supprime le controller, la dépendance npm peut probablement aussi disparaître.

**Verdict : DELETE — CONFIRMÉ.**

---

## Violation 5 — `call_status_refresh_controller.js`

1. « 11 lignes » — **PRESQUE.** Fichier réel : 12 lignes.
2. « Un `connect()` qui ré-assigne `src` d'un turbo-frame, aucun state » — **CONFIRMÉ.**
3. « Recommandation : fusionner avec `call_banner_controller` » — **CLAIM DOUTEUX.**
   - `call_banner_controller.js` toggle joinBtn/leaveBtn, joue un son selon participants. Attaché au banner.
   - `call_status_refresh` rafraîchit `#user_sidebar` (un autre turbo-frame).
   - Fusionner les deux briserait le SRP ou exigerait que `call_banner` soit attaché au sidebar OU dupliquerait du code.

**Verdict : PARTIELLEMENT RÉFUTÉ.** Le constat (trivial, sans state) est correct ; la fusion est inappropriée. Une refactor "helper Stimulus refresh-frame-on-connect" serait plus juste.

---

## Section "Héritage namespacing"

1. `suggestion_option.js` / `suggestion_select.js` héritent `HTMLElement` — **CONFIRMÉ.**
2. `BaseAutocompleteHandler` contient ~80 lignes de vrai comportement — **CONFIRMÉ avec nuance.** Le fichier fait 128 lignes (pas ~80). Les claims sur `SuggestionController`, `fetch`, `matching` sont confirmés.
3. Les sous-classes appellent `super(...)`, `super.updateWithContentAndPosition`, `super.setAutocompletables` — **PARTIELLEMENT CONFIRMÉ.**
   - `autocomplete_handler.js` : `super(element, url)`, `super.updateWithContentAndPosition`, `super.setAutocompletables` ✓
   - `mentions_autocomplete_handler.js` : **aucun `super.xxx()` direct.** Il override seulement.

**Verdict : KEEP — CONFIRMÉ.**

---

## Section "Pas d'instances"

Phrase « Aucune classe non-Stimulus n'est jamais instanciée » contradictoire avec le reste. Lecture charitable : aucune classe orpheline. Vérifié : tous les `new ClassName` ont au moins un caller. **Confirmé sur le fond, formulation maladroite.**

---

## Section "Sac à données"

« Aucune classe pure-data trouvée. » — **CONFIRMÉ.**

---

## Vérification "5 controllers KEEP" échantillonnés

| Controller | State | Méthodes non-triviales | KEEP justifié ? |
|---|---|---|---|
| `badge_dot_controller.js` | targets+classes | `update()` + Badge API + 2 getters privés | **OUI** |
| `copy_to_clipboard_controller.js` | values+classes | `copy()` async, `reset()`, `#forceReflow()` | **OUI** |
| `local_time_controller.js` | targets | 3 formatters Intl stockés + `#formatTime` + 3 target connectors | **OUI** — vraie state |
| `popup_controller.js` | targets+classes | `#orient()` + 3 getters de positionnement DOM | **OUI** |
| `typing_notifications_controller.js` | targets+classes | ActionCable channel + TypingTracker + throttle + connect/disconnect | **OUI** — gros comportement stateful |

**Aucun faux négatif** dans l'échantillon.

---

## Faux positifs / négatifs détectés

1. **Recommandation de fusion `call_status_refresh` + `call_banner`** — inappropriée (deux DOM elements distincts).
2. **Imprécisions quantitatives** : 42 vs 44 controllers, 21+ vs 16 classes non-Stimulus, 128 vs ~80 lignes pour `BaseAutocompleteHandler`.
3. **Claim sur `mentions_autocomplete_handler.js` appelant `super.xxx()`** — inexact. N'affecte pas le verdict KEEP.

---

## Synthèse adversariale

| Violation rapport | Verdict après vérif |
|---|---|
| 1. `Renderer` → FONCTION | **CONFIRMÉ** |
| 2. `Current` → REFACTOR-OTHER | **CONFIRMÉ** |
| 3. `Unfurler` → FONCTION | **CONFIRMÉ** |
| 4. `tom_select_controller` → DELETE | **CONFIRMÉ** (vérifier suppression dépendance npm `tom-select`) |
| 5. `call_status_refresh` → REFACTOR (fusion) | **PARTIELLEMENT RÉFUTÉ** — constat OK, fusion inappropriée |

**Rapport globalement fiable** : les 4 vraies violations principales (Renderer, Current, Unfurler, tom_select) sont confirmées par lecture du code source. Les controllers KEEP échantillonnés sont effectivement non-triviaux. Les imprécisions sont quantitatives et ne changent pas les recommandations.

**Niveau de confiance global : ~85%.** Actions 1-3 et 5 peuvent être suivies sans risque. Action 4 (fusion) demande un design review.
