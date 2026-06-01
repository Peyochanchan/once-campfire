# Audit "Not a class" — JavaScript

Périmètre : `app/javascript/**/*.js` (44 Stimulus controllers + 36 autres).
**80 fichiers audités**, **16 classes hors Stimulus** + 44 Stimulus, **9 violations identifiées**.

## Résumé

| Verdict | # | Cas |
|---|---|---|
| KEEP | ~71 | Vraies instances, vrai état, comportement riche |
| FONCTION | 2 | `Renderer`, `Unfurler` |
| OBJET_LITTERAL | 0 | (aucun pur sac à données) |
| DELETE | 1 | `tom_select_controller.js` (jamais registré) |
| REFACTOR-OTHER | 3 | `Current` (singleton → module), `call_status_refresh` (fusion), évaluation autres controllers triviaux |

---

## Violations par catégorie

### "Pas d'instances" → fonction(s) exportée(s)

Aucune classe non-Stimulus n'est jamais instanciée. Tous les `new ClassName` ont été retrouvés via grep. **Aucune violation pure.**

### "Pas de state" → fonctions pures / module

- **`app/javascript/lib/autocomplete/renderer.js` (`Renderer`)** — Aucun champ d'instance ; les 2 méthodes lisent leurs arguments et retournent du HTML. Usage unique : `base_autocomplete_handler.js:87` → `new Renderer().renderAutocompletableSuggestions(...)` (construit, appelle, jette). Recommandation : exporter `renderAutocompletableSuggestions(...)` et `renderAutocompletable(...)` comme fonctions. *Verdict : FONCTION — effort : low (~10 min).*

- **`app/javascript/initializers/current.js` (`Current`)** — 2 getters lisant le DOM, zéro champ d'instance, singleton (`window.Current = new Current()`). Recommandation : objet littéral ou module exporté. Attention : utilisé largement (`Current.user.id`, `Current.room.id` dans une dizaine de fichiers). Garder API publique identique. *Verdict : REFACTOR-OTHER — effort : low (~15 min).*

### "Sac à données"

Aucune classe pure-data trouvée. **Aucune violation.**

### "Héritage namespacing"

- `suggestion_option.js` / `suggestion_select.js` héritent `HTMLElement` : imposé par Web Components API. **KEEP.**
- `autocomplete_handler.js` / `mentions_autocomplete_handler.js` héritent de `BaseAutocompleteHandler` : la base contient ~80 lignes de vrai comportement (SuggestionController, fetch, matching). Les sous-classes appellent `super(...)`, `super.updateWithContentAndPosition`, `super.setAutocompletables`. **Vraie classe abstraite légitime. KEEP.**

**Aucune violation.**

### "Invalide après new" → factory function

- **`app/javascript/lib/rich_text/unfurl/unfurler.js` (`Unfurler`)** — Pas de constructeur, pas d'état. Pattern d'usage forcé : `new Unfurler(); unfurler.install()` (`initializers/rich_text.js:9-10`). Sans `install()`, l'instance est inerte. Recommandation : remplacer par une fonction `installUnfurler()`. *Verdict : FONCTION — effort : low (~10 min).*

### Cas spécifique Stimulus controllers triviaux

- **`app/javascript/controllers/tom_select_controller.js`** — **CODE MORT.** `controllers/index.js:38,81` commentent explicitement « loaded separately » et `application.register("tom-select", tom_select)` est commenté. Aucun chargement séparé trouvé dans `app/views`, `app/helpers`, ni ailleurs dans `app/javascript`. Aucune occurrence de `tom-select` côté templates. *Verdict : DELETE — effort : low (~5 min). À confirmer humainement (peut-être conservé pour vague mobile/admin).*

- **`app/javascript/controllers/call_status_refresh_controller.js`** — 11 lignes. Un `connect()` qui ré-assigne `src` d'un turbo-frame, aucun state. Recommandation : fusionner avec `call_banner_controller` (même contexte fonctionnel). *Verdict : REFACTOR-OTHER — effort : low (~20 min). À arbitrer avec roadmap vidéo Vague 2.*

Controllers triviaux mais idiomatiques (verdict **KEEP**, gain négligeable) :
`auto_submit_controller.js`, `element_removal_controller.js`, `scroll_into_view_controller.js`, `toggle_class_controller.js`, `turbo_streaming_controller.js`, `upload_preview_controller.js`, `form_controller.js`, `drop_target_controller.js`. Tous utilisent `data-controller`/`data-action` Stimulus de façon propre côté templates ; les transformer en helpers JS ferait perdre la lisibilité HTML sans gain réel.

---

## Fichiers analysés et OK (highlights)

- `models/client_message.js` — state via #template, instancié. **KEEP.**
- `models/file_uploader.js` — state (file, url, callback). **KEEP.**
- `models/message_formatter.js` — state (#userId, #classes, #dateFormatter). `ThreadStyle` exporté est déjà un objet littéral propre. **KEEP.**
- `models/message_paginator.js` (+ `ScrollTracker` interne) — vrais observers et `upToDate`. **KEEP.**
- `models/scroll_manager.js` — `#container` + queue d'opérations static. **KEEP.**
- `models/typing_tracker.js` — dict + timer. **KEEP.**
- `lib/autocomplete/collection.js` — collection immutable. **KEEP.**
- `lib/autocomplete/selection.js` — MutationObserver, DOM stateful. **KEEP.**
- `lib/autocomplete/suggestion_controller.js` — 350 lignes, énormément d'état. **KEEP.**
- `lib/autocomplete/suggestion_results_controller.js` — DOM stateful. **KEEP.**
- `lib/rich_text/unfurl/opengraph_embed_operation.js` — state (paste, editor, abortController). **KEEP.**
- `lib/rich_text/unfurl/paste.js` — value object + helpers. **KEEP.**
- Controllers avec vrai état/logique : `messages`, `composer`, `video_call`, `notifications`, `presence`, `refresh_room`, `typing_notifications`, `room_draft`, `rooms_list`, `read_rooms`, `rich_autocomplete`, `autocomplete`, `search_results`, `badge_dot`, `popup`, `filter`, `sorted_list`, `lightbox`, `local_time`, `maintain_scroll`, `boost_delete`, `pwa_install`, `web_share`, `sound`, `soft_keyboard`, `sessions`, `reply`, `thread_panel`, `copy_to_clipboard`, `otp_input`, `call_banner`, `turbo_frame`. **KEEP.**

---

## Cas ambigus / décisions humaines

1. **`tom_select_controller.js`** — code mort apparent. Volontairement conservé pour vague mobile/admin ? Si non → DELETE. Si oui → ajouter un mécanisme de chargement + un TODO.
2. **`Current`** (`initializers/current.js`) — singleton global utilisé partout. Migrer vers module ou garder l'alias `window.Current` ? À arbitrer.
3. **`call_status_refresh_controller.js`** — fusionner avec `call_banner_controller` ? À valider avec la roadmap Vague 2 vidéo.
4. **`Unfurler`** — refacto trivial en `installUnfurler()`. Faut-il prévoir une API `uninstall()` future ? Sinon : fonction.
5. **`Renderer`** — analogue, refacto trivial en fonctions exportées.

---

## Actions prioritaires

| # | Action | Effort | Impact | Verdict |
|---|--------|--------|--------|---------|
| 1 | Supprimer ou réactiver `tom_select_controller.js` | low | clarté | DELETE (à confirmer) |
| 2 | `Renderer` → 2 fonctions exportées | low | -1 classe inutile | FONCTION |
| 3 | `Unfurler` → fonction `installUnfurler()` | low | -1 classe trompeuse | FONCTION |
| 4 | Fusionner `call_status_refresh` dans `call_banner` | low | -1 controller trivial | REFACTOR (à valider) |
| 5 | (Optionnel) `Current` → objet littéral / module | low | code style | REFACTOR (à arbitrer) |

## Notes

- Codebase JS sain. Pas de problème structurel majeur — uniquement quelques opportunités cosmétiques + un fichier mort suspect.
- Le critère "pas d'instances" est trivialement satisfait : tous les `new <Name>` ont été retrouvés par grep dans `app/javascript`.
- `BaseAutocompleteHandler` n'est pas instancié directement mais c'est une classe abstraite **légitime** (héritage qui transporte du comportement réel), donc non flaggée.
