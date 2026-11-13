# Rapport de validation — alpha0.1.0

Exécution réelle le13novembre2026, Godot4.6.3.stable.official.7d41c59c4, Linux x86_64. Rendu natif Compatibility/OpenGL3 via Xorg dummy et Mesa llvmpipe (rendu logiciel). Les suites utilisent la vraie physique Godot ; certaines décisions d'IA sont isolées dans des fixtures sans rendu. Aucun test humain complet n'a été effectué.

## Régressions automatisées

| Suite | Résultat | Preuve couverte |
| --- | --- | --- |
| `tests/actor_regression.gd` |17/17| Orientation, sprint/bruits, slide/hitbox, tir/mort unique/statistiques, mort sans action, recharge/réserve, deuxième arme, collision invisible, franchissement bas réel, mur haut bloquant, cible de tutoriel non létale. |
| `tests/test_acoustics.gd` |36/36| Cible immobile, recharge ping, symétrie de signature, mur opaque/incertitude, mémoires figées/expiration, recharge proche, impacts sans fuite de source, six gadgets, pièges accroupis/occlus, destruction, brouillage, partage sans silhouette distante, nettoyage. |
| `tests/test_navigation_ai.gd` |27/27| Tous spawns→sorties en1v1/2v2/3v3, segments sans raccourci à travers couvertures, limites du monde, défenseur proche alerté/ping sans contact inventé, leurre enquêté puis abandonné, délai de réaction, répondant réparti, ordre et extraction. |
| `tests/test_match.gd` |50/50| Menu réel, formats et effectifs, pause, préparation sans combat ni consommation de temps, progression/grâce/décroissance indépendante, extraction simultanée, mort exclue, score200/100sans doublon, alternance sur4manches, remise à zéro et retour menu. |
| `tests/test_tutorial.gd` |25/25| Huit exercices sur la scène réelle, cible navigable/inof­fensive, reconstruction pédagogique, ping immobile, plancher25PV sans points, leurre réellement perçu/enquêté, déplacement vers piège réellement déclenché, extraction normale et persistance de fin, nettoyage. |
| `tests/test_audio.gd` |6/6| Aucun signal global d'un coup distant, tir hors portée silencieux, retours légitimes de disponibilité/contact/interface, muet général. |
| **Total** |**161/161**| Les assertions vérifient les scénarios décrits ; elles ne prouvent pas toutes les combinaisons ni l'absence générale de bugs. |

Import du projet et analyse GDScript réalisés sans erreur de script. Les cinq suites initiales puis les régressions tutoriel/audio modifiées ont été exécutées ; `tools/check.sh` regroupe l'import, les six suites et une simulation pour les exécutions suivantes. Les WAV ont été vérifiés :39fichiers PCM16bits22,05kHz, régénération déterministe, pas d'écrêtage et continuité des boucles.

## Simulations complètes

Graines, rôles et statistiques exacts sont conservés dans `docs/validation/`. Ces résultats correspondent aux versions réellement exécutées pendant l'intégration ; une modification ultérieure ou un autre niveau de difficulté peut changer les scores. Les scores ne prouvent pas l'équilibre.

| Format/difficulté | Graine | Manches | Score équipe0:1 | Durées des manches(s) |
| --- | --- | --- | --- | --- |
|1v1/Normal|27013|4|100:300|17,25 /18,27 /6,63 /17,92|
|1v1/Normal|27014|4|100:300|5,53 /18,38 /6,28 /8,15|
|2v2/Normal|27013|4|400:400|19,83 /15,22 /25,92 /21,00|
|2v2/Normal|27014|4|400:400|14,13 /12,23 /18,65 /27,88|
|3v3/Normal|27013|4|600:600|22,62 /22,88 /24,57 /31,50|

Ces20manches ont terminé sans erreur de script ni blocage permanent constaté. Des tentatives de dégagement ont été enregistrées ; `stuck_count` compte ces récupérations, pas uniquement des immobilisations définitives. Les alertes d'extraction ont produit des interceptions dans les manches concernées.

Une dernière exécution groupée du code de livraison en3v3/Normal a également terminé4manches, score600:600, durées22,62/30,58/24,57/31,50s (`release_check_3v3.json`).

Une vérification groupée3v3d'intégration à difficultéInitiation a terminé4manches avec score500:700; un exécutable Linux exporté a terminé une simulation1v1de4manches (score300:100). Les rapports restent inclus séparément. Les simulations à `--fixed-fps60` font avancer une horloge fixe : leur champ `minimum_observed_fps=60` **n'est pas un benchmark matériel**.

## Vérification graphique et exports

Menu principal, paramètres, HUD tutoriel et carte affichés en natif et capturés. Les images du menu, de la vue subjective et de la carte sont conservées dans `docs/screenshots/`. Les shaders du niveau et les polices se chargent. Correction visuelle vérifiée : le bouton de lancement reste accessible en1280×720 ; les inscriptions monumentales ne masquent plus le réticule. Progression d'extraction normalisée corrigée.

L'environnement ne dispose pas de périphérique audio ALSA : le moteur bascule vers Dummy. Les captures n'établissent donc pas une validation d'écoute. Les synthèses et paramètres3D sont vérifiés par code ; le mixage au casque reste à tester.

Exports Linux x86_64 et Windows x86_64 produits avec les templates officiels4.6.3. Le projet et le pack exporté Linux sont lancés ici. Le fichier Windows est construit depuis Linux, **sans exécution Windows native**. Les archives incluent les mentions moteur et polices.

## Problèmes et couverture restante

- Duels parfois inférieurs à10s, efficacité rapprochée des bots à régler.
- Navigation sans étage jouable et états de récupération à observer sur des sessions longues.
- Pas de mesureGPU cible ni de promesse60FPS ; les captures utilisent un moteur logiciel.
- Aucun essai humain au casque, de plaisir, de confort, de lisibilité systématique ou d'équilibre compétitif.
- Pas de matrice exhaustive perception×matériau×distance×posture×rôle, ni d'endurance sur des centaines de manches.
- Détection des dispositifs et destruction volontaire par les bots encore limitée.

Commande de réexécution : `tools/check.sh`. Les scénarios natifs de capture sont dans `tools/capture_ui.gd` et `tools/capture_level.gd`. La CI effectue import, régressions et exports ; son résultat distant doit être constaté après le push, sans le déduire des tests locaux.
