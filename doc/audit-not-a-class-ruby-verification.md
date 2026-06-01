# Vérification adversariale — Audit Ruby

Document source vérifié : `doc/audit-not-a-class-ruby.md`
Méthode : lecture du code source + greps exhaustifs (excluant `node_modules`, `.git`, `tmp`, `log`, `vendor/bundle`).

## Résumé

- **9 claims principaux testés** (7 violations + 2 cas ambigus pertinents)
- **8 confirmés**
- **0 réfutés**
- **1 nuance** (`Opengraph::Document` — la classe a un `@opengraph_attributes` memoizé en plus du `@html`)
- **5 fichiers "OK" échantillonnés** : tous confirmés OK
- **1 imprécision comptable** : 79 fichiers `.rb` réels dans le périmètre, pas 66
- **0 faux négatif détecté** (aucune autre violation trouvée)
- **0 faux positif détecté**

## Détail par claim

### Violation #1 — `Purchaser` (DELETE)
- **Claim** : "Aucune référence externe (grep `Purchaser` ne renvoie que le fichier). Code mort."
- **Vérif** :
  - `grep -rn "Purchaser\|purchased_by" .` → seules occurrences = `app/models/purchaser.rb` + lignes du rapport audit.
  - `find . -name "purchased_by*"` → 0 résultat.
- **Verdict** : **CONFIRMÉ**. Pas même de `config/purchased_by.yml` : la classe ne pourrait pas charger quoi que ce soit même si instanciée.

### Violation #2 — `FirstRun` (MODULE)
- **Claim** : "Aucun `FirstRun.new`, seule API : `FirstRun.create!(user_params)`. Pas d'`@ivar`."
- **Vérif** : 16 lignes, 1 méthode de classe `self.create!`, aucune `@ivar`. `grep` → 3 hits `FirstRun.create!` (controller, test, populate). Aucun `.new`.
- **Verdict** : **CONFIRMÉ**.

### Violation #3 — `Opengraph::Fetch` (MODULE via `extend self`)
- **Claim** : "Instancié uniquement via `Opengraph::Fetch.new.fetch_…` à 2 endroits dans `location.rb`."
- **Vérif** : 2 instanciations prod (`location.rb:19,47`), 1 dans le test. 79 lignes, aucune `@ivar`.
- **Verdict** : **CONFIRMÉ**.

### Violation #4 — `Opengraph::Metadata::Fetching` (MODULE plat)
- **Claim** : "Concern qui n'ajoute QUE des `ClassMethods`, aucun `included do`, aucun callback."
- **Vérif** : 68 lignes : `extend ActiveSupport::Concern` + `module ClassMethods` UNIQUEMENT. Inclus dans `Opengraph::Metadata` (`metadata.rb:6`).
- **Verdict** : **CONFIRMÉ**.

### Violation #5 — `Opengraph::Document`
- **Claim** : "`attr_accessor :html` + une méthode publique mémoizée."
- **Vérif** : 2 instanciations prod (`fetching.rb:26,32`), toutes deux suivies de `.opengraph_attributes`. **Nuance** : la classe a DEUX `@ivar` (`@html` + `@opengraph_attributes` memoizé), pas une — mais le second est juste de la memoization triviale.
- **Verdict** : **CONFIRMÉ avec nuance mineure**.

### Violation #6 — `WebPush::Notification` (refactor possible)
- **Claim** : "7 attrs figés + une méthode publique `deliver`. Borderline command object."
- **Vérif** : 29 lignes. 1 instanciation prod (`push/subscription.rb#notification`). Lecture `lib/web_push/pool.rb` : la `notification` est créée hors thread puis **capturée dans la closure du thread pool** (lignes 27-31). C'est la raison d'être de l'objet : différer `deliver` après le post au pool.
- **Verdict** : **CONFIRMÉ comme cas ambigu/borderline**. Correctement classé en cas ambigu par l'audit.

### Violation #7 — `Sound::Image`
- **Claim** : Pattern Struct + initialize redéfini.
- **Vérif** : `sound.rb:2-6` exactement le pattern décrit.
- **Verdict** : **CONFIRMÉ**.

### Cas ambigu #1 — `ActionText::Content::Filter`
- **Vérif** : 24 lignes, NotImplementedError, factory `self.apply`, `@content` lu uniquement via `attr_reader :content` privé. Sous-classes consomment immédiatement.
- **Verdict** : **CONFIRMÉ comme ambigu**.

### Cas ambigu #2 — `ActionText::Content::Filters`
- **Vérif** : 12 lignes, `@filters` posé une fois. Unique instanciation : `content_filters.rb:2`.
- **Verdict** : **CONFIRMÉ comme ambigu**.

---

## Échantillon vérification "OK" (5 fichiers)

1. **`app/models/current.rb`** — `< ActiveSupport::CurrentAttributes`. → **OK confirmé**.
2. **`app/models/opengraph/location.rb`** — `@resolved_ip` et `@parsed_url` partagés entre 5+ méthodes. Inclut `ActiveModel::Validations`. → **OK confirmé**.
3. **`app/models/room/message_pusher.rb`** — `@room`/`@message` lus dans 6+ méthodes privées. → **OK confirmé**.
4. **`app/models/application_platform.rb`** — Hérite de `user_agent`/`match?` réellement utilisés. → **OK confirmé**.
5. **`app/helpers/messages/attachment_presentation.rb`** — `@message` et `@context` lus dans 8+ méthodes privées. → **OK confirmé**.

Bonus vérifs : `lib/rails_ext/string.rb`, `actiontext_opengraph_embeds.rb`, `private_network_guard.rb` → tous OK.

---

## Imprécision périmètre (mineure)

Le rapport annonce **66 fichiers audités** mais `find app/models app/helpers lib -name "*.rb"` retourne **79 fichiers**. Aucun fichier n'a été oublié sur le fond.

---

## Faux négatifs détectés

**Aucun.** J'ai inspecté les modules/sous-classes restants — toutes des structures propres.

## Faux positifs détectés

**Aucun.** Les 7 violations + 2 cas ambigus sont tous justifiés.

---

## Conclusion

**Qualité globale du rapport original : SAIN**, à publier tel quel.

- Tous les claims factuels vérifiés tiennent.
- Les cas ambigus sont correctement étiquetés.
- Le rapport est conservateur (il ne sur-flag pas — `WebPush::Notification` et les `Filter*` sont marqués ambigus, pas violations fermes).
- Seul ajustement éditorial : préciser que `Opengraph::Document` a aussi un `@opengraph_attributes` memoizé.
- L'imprécision "66 fichiers" vs 79 réels est cosmétique.

**Recommandation : appliquer les 5 refactors low-effort listés** sans hésitation.
