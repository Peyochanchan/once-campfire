# Scénario test end-to-end — `test/wave-1`

Branche : `test/wave-1` (merge de `chore/push-private-script`, `feat/custom-status-text`, `feat/global-mentions`, `feat/email-notifications`, `feat/room-drafts`, `feat/spotlight-participant`, `feat/pip-video`).

## Setup

- **Browser A** (Chrome navigation **publique**) → **Pierre** (admin)
- **Browser B** (Chrome navigation **privée**) → **Gérard** (member)
- Room non-directe partagée (ex. "Blabla")
- Letter Opener ouvert dans un onglet : <http://localhost:3000/letter_opener>
- `bin/dev` lancé (Bun en `--watch`, worker Resque actif, redis up)

> ⚠️ **Note nav privée** : la nav privée n'enregistre pas de service worker persistant → les **notifications push** (étape 14) risquent de ne pas marcher pour Gérard. Tu peux soit l'ignorer (vérifier juste que le message arrive), soit basculer Gérard sur Firefox/un autre browser pour ce test précis.

---

## ✅ Phase 1 — Profil & statut perso

**Browser A (Pierre)**

1. Va sur `/users/me/profile`
2. Sous le select status, remplis :
   - Emoji : 🏖️
   - Texte : `En vacances jusqu'au 20 mai`
3. Sauve.

**Browser B (Gérard)**

4. Clique sur l'avatar de Pierre dans la sidebar.
5. ✅ Tu dois voir 🏖️ `En vacances jusqu'au 20 mai` entre l'email et la bio sur la fiche Pierre.

### Erreurs Phase 1

- [ ] ✅ ça fonctionne 

---

## ✅ Phase 2 — Brouillons par room

**Browser A**

6. Dans la room "Blabla", tape `coucou je suis en train de rédiger un long mess...` mais **n'envoie pas**.
7. Va dans une autre room (ex. "Maison"), tape `autre chose truc à dire`, n'envoie pas.
8. Reviens dans "Blabla".
   - ✅ Le composer doit afficher `coucou je suis en train de rédiger…`
9. Va sur "Maison".
   - ✅ Doit afficher `truc à dire`
10. Sur "Blabla", envoie le message. Reviens.
    - ✅ Composer vide (draft effacé après envoi).

### Erreurs Phase 2

- [ ] ✅ça fonctionne

---

## ✅ Phase 3 — Mentions globales + modale

**Browser A**

11. Dans "Blabla" (qui a < 10 users), tape `@` →
    - ✅ L'autocomplete affiche `@everyone`, `@here`, `@channel` en tête, puis les users
12. Sélectionne `@everyone` → texte brut inséré : `@everyone`
13. Tape un message complet : `@everyone réunion à 14h`, envoie.
    - ✅ Pas de modale (room < 10 membres)

**Browser B (Gérard)**

14. ✅ Tu dois recevoir une notif push (si abonné) ou voir le message arriver.
15. (Bonus) Si tu as une room avec > 10 membres, refais avec `@everyone` →
    - ✅ Modale `confirm()` "Vous allez notifier X personnes..."

**Browser A (test faux positif)**

16. Tape `mail à foo@here.com hello`, envoie.
    - ✅ Ça ne doit PAS être traité comme `@here` (préfixé par autre chose qu'espace/début)

### Erreurs Phase 3

- [ ] Ok ça fonctionne (pas testé la modale)

---

## ✅ Phase 4 — Notifications email

**Browser B (Gérard)**

17. Va sur `/users/me/profile`. Vérifie que la checkbox "Recevoir des notifications par email quand hors-ligne" est cochée.
18. Ferme entièrement la fenêtre privée du Browser B (ou déconnecte-toi pour simuler offline).

**Browser A (Pierre)**

19. Attends ~70s pour que Gérard soit considéré "disconnected" (TTL 60s).
    - Raccourci si tu veux pas attendre :
      ```bash
      bin/rails runner "Membership.where(user: User.find_by(name: 'Gérard')).update_all(connections: 0, connected_at: 2.hours.ago)"
      ```
20. Dans "Blabla", envoie un message qui mentionne Gérard : `@Gérard tu peux regarder ça ?` (avec autocomplete sur Gérard).
21. Attends 30 secondes (délai du `Room::EmailNotificationJob`).
22. ✅ Letter Opener doit ouvrir un email :
    - Subject : `Pierre mentioned you in Blabla`
    - To : email de Gérard
    - Body avec snippet du message + bouton "Open conversation"
    - URL : `http://localhost:3000/rooms/X`

**Browser A (toggle off)**

23. Désactive la checkbox de Gérard via console Rails :
    ```bash
    bin/rails runner "User.find_by(name: 'Gérard').update!(email_notifications_enabled: false)"
    ```
24. Envoie un nouveau `@Gérard` →
    - ✅ Aucun email cette fois (toggle global respecté)

### Erreurs Phase 4

- [ ] Okay

---

## ✅ Phase 5 — Visio : démarrage + focus + PiP + a11y

Rouvre une fenêtre privée pour Gérard (Browser B), reconnecte-toi. Réactive l'email si besoin :

```bash
bin/rails runner "User.find_by(name: 'Gérard').update!(email_notifications_enabled: true)"
```

**Browser A (Pierre)**

25. Dans "Blabla", clique l'icône téléphone → démarre un appel vidéo.
26. ✅ Tu rentres dans l'appel, ta caméra/mic actifs.

**Browser B (Gérard)**

27. Clique le bouton "Rejoindre" sur le banner d'appel.
28. ✅ Tu rejoins, ta vidéo apparaît dans la grille pour Pierre.

**Browser A — test focus participant**

29. Survole la tuile de Gérard → ✅ bouton pin apparaît en haut à droite.
30. Click → ✅ Gérard prend toute la zone principale, ta vidéo locale reste en bas-droite.
31. Re-click sur le pin (maintenant bleu) → ✅ retour grille normale.

**Browser A — test PiP**

32. Dans la barre de contrôles, clique le bouton picture-in-picture (entre chat et settings).
33. ✅ Fenêtre flottante avec la vidéo de Gérard.
34. Navigue dans Campfire (clique sur "Maison" par ex.) → ✅ le PiP reste flottant.
35. Re-click le bouton PiP → ferme le PiP.

**Browser A — test a11y**

36. `Tab` dans la barre de contrôles → ✅ outline bleu ciel visible sur chaque bouton focusé.
37. Vérifie qu'aucune barre ne disparaît tant que ton focus clavier est dessus.
38. Click sur camera → ✅ état actif = fond bleu accent (pas blanc inversé).
39. Click sur mic off → ✅ icône change (`mic-off` avec barre).

**Cleanup**

40. Pierre raccroche → ✅ écran "Call ended" propre, deux boutons stylés.

### Erreurs Phase 5

- [ ] _à remplir si KO_

---

## Récap features testées

| Feature                                | Phase     |
| -------------------------------------- | --------- |
| custom-status-text                     | 1         |
| room-drafts                            | 2         |
| global-mentions + modale               | 3         |
| email-notifications (mention + toggle) | 4         |
| spotlight-participant                  | 5 (29-31) |
| pip-video                              | 5 (32-35) |
| a11y barre call                        | 5 (36-39) |

## Non couvert (à tester séparément si besoin)

- Email d'**activité** (besoin d'offline ≥ 30 min, fastidieux à simuler)
- Annulation auto du focus quand un **screen share** démarre
- PiP désactivé sur **Firefox**
- Brouillon **multi-device** (impossible avec localStorage)
- Push privé via `bin/push-public` (séparé du test feature)
