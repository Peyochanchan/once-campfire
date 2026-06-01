# Vérification adversariale — Synthèse "Not a class"

Vérifications croisées entre :
- `doc/audit-not-a-class.md` (synthèse + plan)
- `doc/audit-not-a-class-ruby.md`
- `doc/audit-not-a-class-js.md`
- code source (`app/`, `lib/`, `app/javascript/`)

## Résumé
- **Cohérence interne** : OK majoritairement. Chaque action du plan d'attaque est traçable à une violation listée dans un rapport détaillé. La cible `Sound::Image` (Vague B) n'apparaît pas dans la liste "À faire (low-effort)" du rapport Ruby mais figure bien dans la section "Autres signaux", donc la traçabilité tient.
- **Chiffres macro** : problèmes mineurs. "146 fichiers audités" donne une fausse précision. Le périmètre Ruby revendiqué (66 fichiers) ne correspond pas au dépôt réel (71 dans `app/` hors controllers/mailers/jobs/channels + 8 dans `lib/` = 79). Le périmètre JS revendiqué (80) correspond à 79 fichiers réels. L'écart Ruby s'explique probablement par l'exclusion implicite des 23 helpers, ce qui donnerait 56 ≠ 66. Aucune incidence sur le verdict, mais le chiffre devrait être tracé.
- **Plan d'attaque actionnable** : OK. Toutes les cibles existent, les callers cités (`location.rb:19,47`, `base_autocomplete_handler.js:87`, `initializers/rich_text.js:9`) sont confirmés par grep.

## Incohérences détectées
- **"18 cas méritent action"** : le diagnostic global énumère 1 + 1 + 4 + 2 + 1 + 1 + 3 = 13 cas, pas 18. Le tableau Ruby donne 9 violations + 3 ambigus = 12 (et `WebPush::Notification` est compté à la fois en DATA et en "Ambigus" — 11 dédupliqués). Le tableau JS donne 9. Plan d'attaque (Vagues A+B+C) = 7 + 2 + 5 = 14 items. Le chiffre "18" n'est confirmé nulle part.
- **Périmètre Ruby annoncé à 66 fichiers** : le rapport Ruby exclut `controllers/`, `mailers/`, `jobs/`, `channels/`. Le compte réel sous cette règle est 79. Si on retire aussi les 23 helpers, 56. Jamais 66.
- **Tableau Ruby "MODULE 4"** mentionne `(Purchaser si conservé)` — contradictoire avec le verdict DELETE primaire. Mieux : "MODULE = 3" et Purchaser uniquement en DELETE.
- **`Current`** : le rapport JS le classe en REFACTOR-OTHER et la synthèse le place en Vague C (à arbitrer), mais le diagnostic global le compte parmi les "18 méritent action" — catégorisation flottante.

## Claims fragiles
- **"Les patterns Rails (Mailers + Jobs + Controllers) sont respectés et ne sont pas le sujet"** → globalement vrai mais trop catégorique. Vérification de `MessageNotificationMailer` : la méthode `load` mute 7 ivars (`@membership`, `@user`, `@room`, `@sender`, `@app_name`, `@snippet`, `@room_url`) avec un coupling temporal entre `mention/activity` et `load`. C'est exactement le smell "sac à données + mutation" que l'audit cherche. L'exclusion du périmètre est défendable, mais "ne sont pas le sujet" minimise un cas réel qui mériterait au moins un flag.
- **"Effort cumulé : ~1h"** pour Vague A → optimiste. Item 4 (`Opengraph::Fetch`) implique 2 callers dans `location.rb` + ajustement de `Opengraph::FetchTest`. Item 5 (Concern→module) demande de vérifier les `include` et la portée. Item 7 (`Unfurler`) demande de réfléchir au scoping de `performOperation`. 7 items × 10-15 min (lecture + edit + test + commit séparé) = **1h30-2h**.
- **"Aucune classe non-Stimulus n'est jamais instanciée"** (rapport JS) → faux dans la formulation, puisque `new Renderer()` et `new Unfurler()` existent. Reformuler : "toutes les classes non-Stimulus sont instanciées au plus une fois et jetées immédiatement".
- **"~150-200 lignes nettes"** : estimation gonflée. Total réaliste **80-130 lignes**.

## Manques (violations détaillées non reprises dans le plan)
- Aucun item de rapport détaillé n'est omis du plan. La traçabilité fichier-action est complète (vérifié pour les 9 violations Ruby et 9 violations JS).
- **Manque structurel non flaggé** : `MessageNotificationMailer#load` (mutation d'ivars partagée entre 2 actions publiques) — typique du smell ciblé par l'audit. Hors périmètre revendiqué, mais la synthèse ne pose même pas la question.
- **`Sound::Image`** : non listé dans la section "À faire (low-effort)" du rapport Ruby (la liste n°5 mentionne `Sound::Image` mais celle des recommandations finales le range ailleurs). Hiérarchie un peu confuse à l'intérieur du rapport Ruby — la synthèse retombe sur ses pieds en le mettant en Vague B.

## Suggestions d'amélioration
1. **Corriger les chiffres** : remplacer "146 fichiers audités" par "~145 (79 Ruby + ~80 JS)". Remplacer "18 cas méritent action" par le décompte réel (13-14).
2. **Recadrer Vague A** : annoncer "1h30-2h" plutôt que "~1h". Le titre "1-2h" est correct, le "~1h" répété est trompeur.
3. **Préciser le claim "Mailers/Jobs imposés"** : ajouter "leur structure interne n'a pas été auditée ; certains comportent des patterns 'sac à données' (ex. `MessageNotificationMailer#load`) qui mériteraient un audit dédié".
4. **Vague C — qualité des 5 questions** :
   - **Q10 (`Filter`)** : claire, mais ajouter le critère de décision ("si on prévoit d'ajouter d'autres filters → garder le pattern abstrait, sinon → modules").
   - **Q11 (`WebPush::Notification`)** : claim "capture dans la closure du thread pool" non instruit — il manque un pointeur vers `WebPush::Pool` et l'endroit où l'objet est enqueué.
   - **Q12 (`Current`)** : bien posée.
   - **Q13 (`call_status_refresh_controller`)** : dépend de la Vague 2 vidéo (encore en cours). À sortir de Vague C, mettre en attente explicite.
   - **Q14 (`Filters`)** : doublon partiel de Q10. Les fusionner en une seule question "que fait-on du pattern filter ?".
5. **Compter `Purchaser` en DELETE uniquement** dans le tableau résumé Ruby.
6. **Reformuler le claim JS "Aucune violation pure"** pour qu'il soit cohérent avec les deux violations détaillées qui suivent.

## Verdict global
La synthèse est **honnête sur le verdict** (codebase saine) et **actionnable sur le plan** (chaque item a un fichier, un caller identifié, un verdict). C'est un bon document de travail. Points faibles :
- chiffres macro imprécis (146, 18, 150-200, 1h) qui projettent une fausse précision ;
- claim catégorique "Mailers/Jobs imposés" qui balaie un smell réel dans `MessageNotificationMailer` ;
- ambiguïtés de comptage (Purchaser DELETE+MODULE, Current action+question) ;
- Vague C contient une question (Q13) qui dépend d'une décision externe et un doublon (Q10/Q14).

**Recommandation** : exécuter la Vague A telle quelle (les fixes sont solides), allouer 2h plutôt qu'1h, fusionner Q10/Q14, sortir Q13, et corriger les chiffres macro. Le plan reste viable, c'est principalement de la précision rédactionnelle.
