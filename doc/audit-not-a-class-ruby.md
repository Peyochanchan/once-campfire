# Audit "Not a class" — Ruby

Périmètre : `app/**/*.rb` (hors `controllers/`, `mailers/`, `jobs/`, `channels/`) + `lib/**/*.rb`.
**66 fichiers audités**, **9 violations réelles**, **3 cas ambigus**.

## Résumé

| Verdict | # | Détail |
|---|---|---|
| KEEP | ~52 | AR + concerns + helpers + presenters + objets stateful |
| MODULE | 4 | `FirstRun`, `Opengraph::Fetch`, `Opengraph::Metadata::Fetching`, (`Purchaser` si conservé) |
| DATA / refactor | 3 | `Opengraph::Document`, `WebPush::Notification`, `Sound::Image` |
| DELETE | 1 | `Purchaser` (mort) |
| Ambigus | 3 | `ActionText::Content::Filter`, `…::Filters`, `WebPush::Notification` |

---

## Violations par catégorie

### "Pas d'instances" → MODULE

- **`app/models/first_run.rb` (`FirstRun`)** — Aucun `FirstRun.new` nulle part, seule API : `FirstRun.create!(user_params)`. Pas d'`@ivar`. *Effort : low (<15 min).*
- **`app/models/opengraph/fetch.rb` (`Opengraph::Fetch`)** — Instancié uniquement via `Opengraph::Fetch.new.fetch_…` à 2 endroits dans `location.rb`. Aucune `@ivar` partagée entre méthodes. Conversion en `module Opengraph::Fetch; extend self`. *Effort : low (<30 min, ajuster aussi `Opengraph::FetchTest`).*
- **`app/models/purchaser.rb` (`Purchaser`)** — Aucune référence externe (grep `Purchaser` ne renvoie que le fichier). Code mort. **Verdict primaire : DELETE.** *Effort : low (<5 min).*

### "Héritage namespacing" → MODULE plat

- **`app/models/opengraph/metadata/fetching.rb` (`Opengraph::Metadata::Fetching`)** — Concern qui n'ajoute QUE des `ClassMethods`, aucun `included do`, aucun callback. Le `extend ActiveSupport::Concern + module ClassMethods` ne sert à rien : on peut soit appeler `Opengraph::Metadata::Fetching.from_url(...)`, soit inliner directement dans `Opengraph::Metadata`. *Effort : low (<15 min).*

### "Sac à données" / objet jetable → Data.define ou fonction de module

- **`app/models/opengraph/document.rb` (`Opengraph::Document`)** — `attr_accessor :html` + une méthode publique mémoizée. L'instance ne sert qu'à porter `@html`. Refactor : méthode de classe `Opengraph::Document.opengraph_attributes(html)` ou `Data.define(:html) do … end`. *Effort : low (<30 min).*
- **`lib/web_push/notification.rb` (`WebPush::Notification`)** — 7 attrs figés + une méthode publique `deliver`. Borderline "command object". Refactor possible vers `WebPush.deliver(title:, body:, …, connection:)`. *Effort : low, mais à discuter.*

### Autres signaux

- **`app/models/sound.rb::Image` (`Sound::Image < Struct.new(...)`)** — Hérite de `Struct.new(:asset_path, :width, :height)` mais redéfinit `initialize(name:, width:, height:)` pour préfixer `sounds/`. Mélange Struct positionnel + initializer kwargs, confusant. Refactor : `Data.define(:asset_path, :width, :height)` + factory, ou calculer `asset_path` côté `Sound` et supprimer la sous-classe. *Effort : low (<20 min).*

---

## Cas ambigus (décision humaine)

1. **`lib/rails_ext/filter.rb` (`ActionText::Content::Filter`)** — Classe abstraite (`apply`/`applicable?` lèvent `NotImplementedError`). Le seul `new` est dans `self.apply` (factory class method) ; les sous-classes (`SanitizeTags`, `RemoveSoloUnfurledLinkText`, `StyleUnfurledTwitterAvatars`) sont des instances jetables qui stockent juste `@content` consommé immédiatement. On *pourrait* tout passer en modules avec `applicable?(content)` / `apply(content)` purs, mais le pattern "filter object" actuel est lisible. **À arbitrer.**

2. **`lib/rails_ext/filters.rb` (`ActionText::Content::Filters`)** — Une seule instance globale (`TextMessagePresentationFilters`), `@filters` figé. Candidat naturel pour `Data.define(:filters)`. Gain marginal.

3. **`WebPush::Notification`** (déjà cité ci-dessus) — Garder l'objet pour capture des params dans la closure du thread pool, ou passer à une fonction de module ? Pas de gain net évident.

---

## Fichiers analysés mais OK (non-violations)

### Modèles ActiveRecord — KEEP (instances + state + validations)
`account.rb`, `ban.rb`, `boost.rb`, `call_participant.rb`, `invitation.rb`, `membership.rb`, `message.rb`, `push/subscription.rb`, `room.rb`, `rooms/{closed,direct,open}.rb`, `search.rb`, `session.rb`, `user.rb`, `webhook.rb`. Les sous-classes STI `Rooms::Open|Closed|Direct` apportent du comportement (`default_involvement`, `grant_access_to_all_users`, `find_or_create_for`) → héritage utile.

### Concerns (`ActiveSupport::Concern`) — KEEP
`account/joinable`, `call_participant/token_generation`, `membership/connectable`, `message/{attachment,broadcasts,mentionee,pagination,searchable}`, `user/{avatar,bannable,bot,mentionable,role,transferable}`, `push.rb`. Forme idiomatique.

### Helpers (`module *Helper`) — KEEP
Tous les fichiers `app/helpers/**/*.rb` qui définissent un `module FooHelper` (23 fichiers) — forme imposée par Rails.

### Autres KEEP justifiés
- `app/models/current.rb` (`< ActiveSupport::CurrentAttributes`) — état per-request, forme Rails
- `app/models/application_record.rb` — `primary_abstract_class`
- `app/models/application_platform.rb` (`< PlatformAgent`) — instanciée dans `SetPlatform`, hérite `user_agent`/`match?` de la gem
- `app/models/opengraph/location.rb` — vrais `@ivar` partagées (`@resolved_ip`, `@parsed_url`) + validations ActiveModel
- `app/models/opengraph/metadata.rb` — ActiveModel avec sanitization + validations
- `app/models/room/message_pusher.rb` — "command object" instancié par le job, état `@room`/`@message` lus dans 6+ méthodes privées
- `app/helpers/messages/attachment_presentation.rb` (`Messages::AttachmentPresentation`) — presenter avec `context` (view helpers) injecté, état réel
- `app/helpers/content_filters.rb` — déjà un module
- `lib/rails_ext/string.rb`, `actiontext_opengraph_embeds.rb`, `action_text_attachables.rb` — monkey-patches Rails
- `lib/restricted_http/private_network_guard.rb` — déjà `module … extend self`
- `lib/web_push/pool.rb` — état long-lived réel (thread pools + connection HTTP persistante), singleton dans `Rails.configuration.x.web_push_pool`

---

## Recommandations actionnables (tri rapide en 5 min)

**À faire (low-effort, gain clair)**
1. Supprimer `Purchaser` (code mort)
2. `FirstRun` → module + méthode unique
3. `Opengraph::Fetch` → `extend self` (supprime les `.new` parasites)
4. `Opengraph::Metadata::Fetching` → module plat (drop `Concern`)
5. `Sound::Image` → `Data.define` ou inline dans `Sound`

**À discuter**
6. `Opengraph::Document` → méthode de classe
7. `WebPush::Notification` → fonction de module vs objet
8. Pattern `ActionText::Content::Filter` (+ sous-classes)

**Ne pas toucher** : tous les modèles AR + leurs concerns, tous les `*Helper`, `Current`, `ApplicationPlatform`, `Room::MessagePusher`, `Messages::AttachmentPresentation`, `WebPush::Pool`, `Opengraph::Location`, `Opengraph::Metadata`.
