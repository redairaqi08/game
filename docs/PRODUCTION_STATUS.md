# État de production — 0.1.0 alpha

État constaté le 13 novembre 2026. **Premier jalon jouable ; le cahier des charges intégral reste en production.** Aucun travail automatique hors de cette session n'est supposé.

## Audit et décision

Le dépôt cible `redairaqi08/game` était vide (aucun commit ni fichier). Le dépôt de référence `redairaqi08/test_game_web` mentionné dans le cahier renvoie404 avec la connexion GitHub disponible ; son contenu n'a pas pu être audité ni importé. Aucun historique ancien n'a été supprimé.

Godot4.6.3 Standard/GDScript a été choisi pour un jeu desktop natif : physique et raycasts fiables, contrôleur partagé, shaders personnalisés, audio3D, interface et exports Windows/Linux intégrés. Le rendu Compatibility permet une base largement compatible ; aucun service ou compte réseau n'est nécessaire. Blender était disponible, mais les assets de ce jalon sont des géométries procédurales originales générées par le projet, sans prétendre à des modèles sculptés/riggés de production.

## Jalon livré

- Fondations de simulation et règles de match : 1v1/2v2/3v3, formats de4/6manches, rôles alternés, score objectif, pause, observation alliée, préparation8secondes, redémarrage et nettoyage des manches.
- Contrôleur FPS commun humain/bots : marche, sprint, saut/réception, accroupissement, slide, vérification du plafond, franchissement bas avec contrôle de collision, deux armes, visée/recul, recharge et dégâts.
- Événements acoustiques structurés, mémoire individuelle et confiance, états0–4, occlusion, ping d'ennemis immobiles, signatures symétriques, contacts d'équipe estimés, reconstruction sans silhouette derrière mur et ondes limitées par obstacles.
- Six gadgets destructibles, placement contrôlé/prévisualisé, diversion sur le vrai canal de perception, pièges, brouillage et balise.
- Sanctuaire de112×88m en3v3, neuf secteurs, trois axes et trois sorties ; formats compacts en1v1/2v2. Architecture, personnages et armes originaux, matériaux et animations procéduraux.
- Navigation A*, profils de bots, mémoire/abandon des faux signaux, réactions et rotation bornées, couverture, ordres et interception des alertes d'extraction sans révélation secrète.
- Tutoriel sécurisé à huit étapes utilisant les vrais systèmes, cible inoffensive non létale, scénario de leurre/enquête et piège/déclenchement, extraction normale.
- Menus français, carte perceptive, résultats, remappage clavier/persistance, AZERTY/QWERTY, réglages de caméra, silhouettes, ondes et profils de rendu appliqués.
-39WAV originaux, audio spatial borné, ambiance/musique, filtrage approximé de l'occlusion. Correction d'une fuite sonore : les impacts sur les personnages restent spatialisés et ne déclenchent plus de son d'interface à distance.

## Validation et distribution

Six suites automatisées totalisent **161 vérifications réussies** : acteur17, acoustique36, IA/navigation27, match50, tutoriel25, audio6. Voir les scénarios et limites dans `TEST_REPORT.md`.

Des parties bot contre bot complètes ont été exécutées dans les trois formats. Des captures natives du menu, des paramètres, du HUD et de la carte ont été inspectées ; les grandes inscriptions qui gênaient la visée ont été corrigées. Les sources et outils de génération sont inclus. Exports desktop Linux/Windows configurés et produits ; Linux est exécuté dans cet environnement, Windows reste à tester sur sa plateforme.

La publication GitHub a été tentée mais refusée403 par Git et par le connecteur. Le dépôt distant est toujours vide. Archives sources/binaires et bundle Git sont préparés localement ; voir `DELIVERY_STATUS.md` pour rétablir l’accès et reprendre la publication. Aucune CI distante ou release publique n’est déclarée exécutée.

## Limites prioritaires

1. **Rythme et équilibre :** plusieurs duels bot contre bot se résolvent en moins de10secondes. Les bots peuvent être trop efficaces à courte portée. Des sidesteps de récupération ont été observés ; aucune preuve de navigation infaillible ou d'équilibre compétitif n'est revendiquée.
2. **Verticalité :** les galeries et passerelles supérieures sont décoratives. La navigation compétitive est planaire ; il faut produire et tester de vrais itinéraires verticaux avec collisions, perception et navigation.
3. **Art/animation :** silhouettes articulées et animations procédurales, hitbox principale simplifiée, pas de rig anatomique complet, de sculptures finales ou de bibliothèque d'animations de production. Lancer de gadget sans trajectoire balistique animée.
4. **Acoustique et audio :** propagation approximée par rayons et matériaux de zone ; pas de graphe complet de portails, de convolution ou d'écoute humaine du mixage au casque.
5. **Finition :** entraînement libre encore limité, pas de profils daltonisme ni volumes séparés, statistiques tactiques incomplètes, pas de doublage/cinématique/campagne. Les confirmations clavier des indications du HUD ne couvrent pas encore tous les textes remappés.
6. **Performances :** captures par rendu logiciel llvmpipe ; aucun engagement60FPS sur une carte graphique cible. Profilage CPU/GPU et optimisation systématique restent à mener.
7. **QA :** aucun essai humain complet sur le plaisir ou le confort, pas de validation Windows native, pas de matrice exhaustive distances×matériaux×postures×rôles.

## Prochaine étape concrète

Faire essayer au casque une session3v3 et une session de duel ; relever les temps de premier contact, précision des bots, routes empruntées, causes des décès et opportunités d'extraction. Régler la perception et les décisions avant d'ajouter du contenu. Puis construire une route verticale réelle et une passe d'art/animation, compléter l'entraînement/accessibilité, et profiler sur une machine graphique identifiée. Préserver toutes les régressions automatisées lors de cette production.

Les versions abouties devront satisfaire les critères qualitatifs de la partie29 ; cette alpha ne les déclare pas acquis.
