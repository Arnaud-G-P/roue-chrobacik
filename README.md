# La roue de Chrobáčik 🌻

> Tu ne choisis pas. La roue choisit.

Une roue en forme de tournesol qui décide quoi manger pour Honey et Chrobáčik, à Los Angeles ou à Paris. Les listes, l'historique des repas et les statistiques sont partagés entre les deux téléphones.

**En ligne :** https://roue-chrobacik.vercel.app

## Utilisation

1. Ouvre le site, et ajoute-le à l'écran d'accueil pour l'utiliser comme une app.
2. La première fois, touche **« 🔗 Entrer le code de la roue partagée »** en bas de la page et tape le code. Le téléphone s'en souvient ensuite.
3. Choisis le lieu (**Los Angeles 🌴** ou **Paris 🥐**) et le mode :
   - **On commande 🛵** : la roue tire une cuisine et propose des restos Uber Eats proches, avec un lien direct vers chacun.
   - **On cuisine 🍳** : la roue tire un plat simple à faire à la maison.
4. **Tourner**, puis :
   - **Veto** (2 par tour) ou **Relancer** ;
   - la petite roue décide **qui paye** (On commande) ou **qui cuisine** (On cuisine) ;
   - **✅ On mange ça !** enregistre le repas pour vous deux.

### Autres fonctions

| Fonction | Ce qu'elle fait |
|---|---|
| Pas de redite | Grise ce que vous avez mangé ces 7 derniers jours |
| Voir les N restos | Liste tous les restos Uber Eats de la cuisine tirée |
| Tout voir sur Uber Eats | Copie la cuisine, ouvre Uber Eats : il reste à la coller dans la recherche |
| Modifier la roue | Ajouter ou retirer des options (commence par un emoji si tu veux) |
| Nos repas 📊 | Les plus mangés, Aux fourneaux, Qui paye, derniers repas |
| Utilisateurs 👥 | Appareils qui utilisent la roue partagée |

## Fonctionnement technique

- **Page** : un seul fichier `index.html` (HTML, CSS et JS inline), sans build ni dépendance. `lieux.js` définit les deux lieux.
- **Hébergement** : Vercel. Chaque push sur la branche `claude/epic-mendel-6kq80l` est mis en ligne automatiquement.
- **Données** : Supabase, via l'API REST.
  - Les données privées (listes, repas, appareils) ne sont accessibles qu'avec le code partagé. Seule l'empreinte SHA-256 du code est stockée, et le code n'est pas dans ce dépôt.
  - Les restos Uber Eats (`ue_stores`) sont en lecture publique.
- **Restos Uber Eats** : récupérés sur les pages publiques de catégories d'Uber Eats (autorisées par leur `robots.txt`), 31 cuisines, filtrés sur les codes postaux proches. 120 restos à LA et 73 à Paris, le 26/09/2026.

Le détail complet (tables, fonctions, clés de stockage local, sources) est dans [`app.json`](app.json).

### Fichiers

```
index.html                  l'application
lieux.js                    Los Angeles / Paris
test-uber.html              test des liens qui ouvrent l'app Uber Eats (Android)
app.json                    description complète de l'application
supabase/migrations/        schéma et fonctions Supabase, outils de scrape
```

### Tester en local

Ouvre `index.html` dans un navigateur. Pour que la copie de texte fonctionne, sers le dossier en local :

```sh
python3 -m http.server 8000
# puis http://localhost:8000
```

### Mettre à jour les restos Uber Eats

Les étapes sont en commentaire dans `supabase/migrations/20260926_ue_stores.sql` :

1. Activer `pg_net`.
2. Lancer `scrape.launch(ville, lieu)` pour chaque ville, puis `scrape.ingest(codes_postaux)`.
3. Vider `net._http_response`, puis désactiver `pg_net`.

## Limites connues

- **Uber Eats** : l'app n'accepte ni recherche ni catégorie depuis un lien. D'où la copie automatique de la cuisine. Sur Android, les liens utilisent le format « intent » pour ouvrir l'app plutôt que le site. `test-uber.html` sert à trouver les formats qui marchent.
- **Couverture Uber Eats partielle** : Uber ne publie qu'une vingtaine de restos populaires par cuisine et par ville.
- **Listes** : le dernier qui modifie gagne. Deux modifications en même temps, et l'une est perdue.
- **Supabase gratuit** : mise en pause après 7 jours sans activité. La page passe alors en « Hors ligne » et garde les dernières données. Pour relancer : bouton « Restore » dans le dashboard Supabase.
