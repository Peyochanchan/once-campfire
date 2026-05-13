# Plan de refonte vidéo — Vague "Visio v2"

Statut : proposition, à valider avant de couper les branches.
Contexte : la Vague 1 a livré spotlight, PiP, blur, screen share, mais le ressenti utilisateur n'est pas au niveau Teams/Zoom/Meet — il manque un **sas d'entrée** (preview), le **PiP** ne fait pas ce qu'on attend, et plusieurs polissages de Phase 5 restent en suspens.

Cette vague vient **avant** la Vague 2 (modération visio) prévue dans la roadmap, ou la remplace en l'intégrant (la roadmap actuelle a déjà `preflight-devices` et `active-speaker` dans Vague 2 — on les regroupe ici).

---

## Objectifs

1. **Pré-join lobby** : un sas avant de rejoindre l'appel, type Meet/Zoom, pour vérifier caméra/micro/blur/devices.
2. **PiP utile** : remplacer le PiP navigateur "vidéo seule" par un PiP de fenêtre Document (cross-tabs, multi-tuiles).
3. **Polish Phase 5** : finir les bugs résiduels (spotlight visuel à 2, PiP comportement attendu, a11y).
4. **Robustesse signalisation** : notifs/sonneries d'appel entrant **hors-room** (pour l'instant la sonnerie ne marche que si l'invité est déjà sur la bonne room).

---

## 1. Sas d'entrée (pre-join lobby)

### Pattern visé (Meet/Zoom/Teams)

Au clic sur le bouton 📞 d'une room, **avant** de se connecter à LiveKit :

- Modale plein-écran (ou drawer) avec :
  - Preview caméra locale (miroir) sur la moitié de l'écran
  - Sélecteur de **caméra**, **micro**, **haut-parleur** (`navigator.mediaDevices.enumerateDevices`)
  - VU-mètre micro (niveau audio en direct) pour vérifier qu'on parle bien
  - Toggle **caméra ON/OFF** et **micro ON/OFF**
  - Toggle **flou d'arrière-plan** appliqué en preview
  - Nom du participant à droite + bouton **"Rejoindre maintenant"** (gros, primaire)
  - Bouton **"Annuler"** (texte, gris)
- Si la room a déjà des participants : afficher leurs avatars + texte "X est déjà dans l'appel"
- Si problème de permission caméra/micro : afficher un état d'erreur explicite avec lien vers les paramètres navigateur

### Implémentation technique

- Côté JS : nouveau Stimulus controller `prejoin_controller.js` (ouvert via Turbo modal au clic sur le bouton call).
- On instancie des `LocalVideoTrack` + `LocalAudioTrack` LiveKit *avant* `room.connect()` :
  ```js
  const camTrack = await createLocalVideoTrack({ deviceId: selectedCamId })
  const micTrack = await createLocalAudioTrack({ deviceId: selectedMicId })
  ```
- Le flou est appliqué sur le track preview avec le `BackgroundProcessor` déjà câblé.
- Au clic "Rejoindre" : on passe ces tracks (+ leur état muted) à la connexion LiveKit existante :
  ```js
  await room.connect(url, token, { tracks: [camTrack, micTrack] })
  ```
- Préférences device persistées en localStorage (`campfire:devices` → `{ camId, micId, spkId, blurOn }`).

### Découpage proposé

- Branche : `feat/prejoin-lobby`
- Étapes :
  1. Modale + preview caméra (sans device picker)
  2. Sélecteurs de devices + persistance
  3. VU-mètre micro
  4. Toggle flou en preview
  5. Affichage des participants déjà dans l'appel

---

## 2. PiP — clarification + Document PiP

### Ce que **ne fait pas** le PiP navigateur classique

L'API Picture-in-Picture standard (`requestPictureInPicture()` sur un `<video>`) :

- Détache **uniquement** un élément `<video>` dans une mini-fenêtre flottante **hors du navigateur** (au-dessus des autres apps macOS).
- Pas conçue pour rester actif quand on change d'onglet : le navigateur **suspend** souvent les onglets en arrière-plan, donc la vidéo se pause (variable selon Chrome/Safari).
- Affiche **une seule vidéo**, pas la grille ni les contrôles.

→ C'est pour ça que Pierre a l'impression que "le PiP ne marche pas" : il s'attend à un mini-Campfire flottant cross-tab, pas à une vignette macOS au-dessus de Finder.

### Ce qui marcherait mieux : Document Picture-in-Picture

API plus récente (Chrome 116+, pas Safari) : **`documentPictureInPicture.requestWindow()`**.

Permet de détacher **n'importe quel bout du DOM** (donc la grille des tuiles + barre de contrôles complète) dans une fenêtre flottante OS — qui reste vivante même quand l'onglet Campfire passe en arrière-plan.

Cas d'usage exact que Pierre décrit :
- Tu es en visio, tu cliques sur PiP, une vraie mini-fenêtre apparaît avec la grille + contrôles
- Tu navigues dans Campfire (autre room, profil, etc.) → la mini-fenêtre persiste
- Tu cliques dessus → tu reviens dans la room d'appel

### Plan d'implémentation

- Branche : `feat/document-pip`
- Étapes :
  1. Feature-detect `'documentPictureInPicture' in window`
  2. Au clic du bouton PiP, ouvrir une fenêtre Document PiP de taille initiale (ex. 400×300)
  3. **Déplacer** le `<div class="call-grid">` + barre de contrôles dans la fenêtre PiP (pas de copie : transfert DOM)
  4. À la fermeture (clic croix de la fenêtre OS, ou retour dans l'onglet), réintégrer le DOM dans la page
  5. Fallback Safari : garder le PiP `<video>` actuel sur la tuile active-speaker
  6. Indiquer l'état dans le bouton PiP (filled bleu quand actif, comme aujourd'hui)

### Bonus

- Ajouter un raccourci clavier : `P` pour toggle PiP (à valider, conflit potentiel avec Cmd+P navigateur)

---

## 3. Polish Phase 5

### Bugs résiduels notés pendant le test wave-1

| # | Bug | Diag actuel | Statut |
|---|-----|-------------|--------|
| a | Spotlight à 2 personnes : pas de différence visuelle évidente | Outline ajouté en CSS sur `.call-tile--spotlight`, mais à 2 personnes les deux tuiles font déjà toute la largeur — l'effet est invisible | Améliorer : forcer le local en petit overlay quand spotlight actif, comme Meet |
| b | Flou met du temps à apparaître | Normal au 1er chargement (MediaPipe télécharge ~5 MB de modèle WASM) — préchauffer dans le sas | Fix via le sas (point 1) |
| c | Screen share : vidéo de l'émetteur ne se remet pas après stop | Fixé via `LocalTrackUnpublished` handler | Validé, à re-tester |
| d | TypeError Safari `#channelConnected` dans `turbo-rails/channels.js` | Bug upstream, non-bloquant | À watch / report upstream |
| e | Notifs/sonneries hors-room | Voir section 4 | Pending |

### Tâches a11y restantes

- Vérifier que tous les boutons de la barre call ont `aria-label` correct
- Tester focus visible au `Tab` (déjà OK selon Phase 5 36-37)
- Vérifier que la fermeture d'un PiP redonne le focus à un endroit sensé

---

## 4. Notifications d'appel entrant globales

### Problème observé

> "les appels par visio ne poussent aucune notification ni sonnerie. La sonnerie ne marche que si Gérard est sur la bonne room dans laquelle Pierre l'appelle."

La logique actuelle ne diffuse l'événement "call started" que via le canal Turbo Streams de la room → si l'invité n'est pas sur cette room, il ne reçoit rien.

### Solution

- Émettre en plus un **Web Push** spécifique "appel entrant" vers tous les membres connectés/abonnés de la room, avec :
  - Titre : `Pierre vous appelle dans Blabla`
  - Action : "Rejoindre" → ouvre directement la room avec auto-join (ou prompt)
  - Action : "Refuser" → POST sur `/rooms/X/calls/decline`
- Côté UI : un **modal global d'appel entrant** (pas seulement banner in-room) qui sonne et affiche les boutons accept/decline, similaire à un appel WhatsApp/Teams.
- Côté son : utiliser le ringtone déjà configuré sur l'utilisateur (déjà géré dans `call_banner_controller.js` mais conditionnel à la présence dans la room).

### Découpage

- Branche : `feat/incoming-call-push`
- Étapes :
  1. Émettre un Web Push à la création d'un call (`Room::CallsController#create`)
  2. Service worker : afficher la notif avec actions
  3. Composant "incoming call modal" affiché en overlay global (insertion dans `<body>` via Turbo Stream sur un canal user-level)
  4. Sonnerie déclenchée par le modal global, pas par le banner de la room

---

## Découpage en branches (ordre proposé)

| Ordre | Branche | Objectif | Bloquant pour |
|-------|---------|----------|---------------|
| 1 | `feat/prejoin-lobby` | Sas d'entrée pré-join | Reste |
| 2 | `feat/incoming-call-push` | Notif + modal global d'appel | UX globale |
| 3 | `feat/document-pip` | Document PiP cross-tabs | — |
| 4 | `fix/spotlight-2p` | Comportement spotlight à 2 personnes | — |
| 5 | `feat/call-active-speaker` | Mise en avant auto du parleur actif (issu Vague 2 originale) | — |
| 6 | `feat/call-moderation` | Mute/kick admin (issu Vague 2 originale) | — |
| 7 | `feat/call-live-reactions` | Réactions emoji volantes (issu Vague 2 originale) | — |

→ Une branche à la fois, merge avant la suivante, jamais sur main.

---

## Questions ouvertes pour Pierre

1. **Sas d'entrée** : on rend ça obligatoire (toujours afficher la modale avant `connect`) ou optionnel (case "Toujours rejoindre directement" mémorisée) ?
2. **Document PiP** : on accepte de ne pas supporter Safari (pas d'API), avec fallback `<video>` PiP ? Ou on attend que Safari supporte l'API ?
3. **Sonnerie globale** : on la fait sonner sur **tous les onglets** Campfire ouverts, ou seulement le plus récent ?
4. **Modal global d'appel entrant** : on l'affiche aussi si l'utilisateur est déjà dans une autre room en visio (gestion du double appel) ?
5. **Vague 2 originale** : on intègre `preflight-devices` et `active-speaker` dans cette refonte (réponse implicite : oui), et on garde `call-moderation` + `live-reactions` à la fin de cette même vague ?

---

## Récap : ce qui change dans la roadmap

- **Avant** (mémoire `project_dev_roadmap.md`) :
  - Vague 2 = `call-moderation, active-speaker, preflight-devices, live-reactions`
- **Après** :
  - **Vague 2 → "Visio v2"** : `prejoin-lobby, incoming-call-push, document-pip, spotlight-2p, active-speaker, call-moderation, live-reactions`
  - Vagues 3-6 inchangées
