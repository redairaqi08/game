# Intelligence artificielle — état réel du jalon 0.1

## Chaîne de décision

Chaque `scripts/bot.gd` contrôle un `SonarActor` par `apply_command`, exactement comme le contrôleur humain : déplacement dans le monde, direction de visée, tir, posture, recharge, ping, gadget et interaction. Le contrôleur reçoit le temps de simulation ; il fonctionne aussi en mode sans rendu. Le match le met à jour à 10 Hz, avec une sélection tactique toutes les 0,13 à 0,22 seconde et des commandes conservées par le personnage entre deux mises à jour.

La priorité est : silhouette confirmée et combat ; mise à couvert si nécessaire ; interception d'une extraction publique ; ordre du joueur ; enquête acoustique bornée ; mission d'attaque ou défense. Une alerte de sortie passe donc avant une enquête sur un bruit ancien. Un défenseur déjà près de la porte réagit à l'alarme et utilise son ping ; il doit toujours obtenir une perception valide avant de viser un personnage.

## Perception et mémoire

Le bot lit uniquement `acoustics.contacts_for(actor)`. Le contrôleur ne recherche jamais les positions réelles des adversaires dans `game.actors`. Ses décisions utilisent la dernière `position` estimée, la confiance, l'âge, l'état de reconstruction, la visibilité et l'identifiant du contact. Les informations physiques de la cible restent dans le système de collisions et dans les validations de tir.

Les contacts de confiance inférieure à 0,17 ou âgés de plus de cinq secondes sont ignorés. Une cible confirmée bénéficie d'une priorité supérieure. Une enquête non confirmée dure au maximum sept secondes ; une recherche à l'endroit estimé dure de 1,8 à 3,2 secondes. La piste abandonnée est ignorée pendant six secondes. Le bot peut donc poursuivre une fausse course, arriver à la mauvaise position, émettre un ping puis reprendre son secteur. Les identifiants négatifs des sources acoustiques ne sont jamais interprétés comme un indicateur de leurre.

Le tir normal exige un contact confirmé, visible, récent, une ligne de vue physique et un alignement suffisant. Après perte du contact, au maximum deux commandes de tir spéculatif sont possibles pendant 0,6 seconde, vers la position mémorisée et avec validation de la ligne de vue. Elles ne récupèrent aucune nouvelle position secrète.

## Navigation

`scripts/navigation.gd` construit un `AStarGrid2D` partagé, avec des cellules d'un mètre. Les obstacles XZ déclarés par le niveau sont agrandis de 0,45 m pour conserver le passage du corps. Les diagonales ne sont autorisées que lorsque les deux côtés sont libres. La simplification des chemins vérifie chaque segment contre les mêmes obstacles agrandis, ce qui empêche les raccourcis dans les coins.

Les origines et objectifs bloqués sont rapprochés d'une cellule valide dans une recherche bornée. Les bots recalculent leurs chemins toutes les 1 à 1,8 seconde et lors d'un changement d'objectif. Le cache partagé est limité à 384 chemins. La séparation locale utilise uniquement les positions des alliés connus ; elle ne divulgue pas les ennemis invisibles.

Un contrôle de progression toutes les 1,2 seconde détecte un déplacement demandé sans progrès. Le bot tente un pas latéral valide, recalcule son chemin et peut changer d'objectif. Il ne modifie jamais directement sa position pour masquer un blocage. Le niveau de ce jalon possède un sol navigable unique ; les arches et passerelles hautes sont du décor. Les étages, escaliers et rampes praticables demanderont une navigation 3D supplémentaire.

## Attaque et défense

En attaque, les sorties sont initialement réparties par index et manche. Le coût de choix combine distance, objectif déjà choisi, sorties des alliés et danger connu. Les éclaireurs se séparent davantage ; les soutiens gardent plus volontiers une route commune. L'objectif est réévalué toutes les 12 à 19 secondes. En fin de manche, la sortie proche prend la priorité. Le bot alterne course et marche, réduit sa signature lorsqu'un contact incertain existe et maintient l'interaction dès qu'il entre dans le rayon de la sortie. Il ne remplace pas l'objectif d'extraction par une recherche systématique du combat.

En défense, les bots patrouillent devant leurs portes assignées et utilisent leurs équipements. Une seule unité proche reçoit normalement une alerte d'extraction ; un autre défenseur conserve son secteur. Une unité située à moins de six mètres de la porte activée intervient aussi pour éviter qu'une attribution distante lui fasse ignorer l'urgence immédiate. Les enquêtes sur les sons sont également réparties par proximité. Les sentinelles poursuivent moins loin.

Cinq profils existent : éclaireur, traqueur, sentinelle, soutien et opportuniste. Ils introduisent des variations modestes de répartition, de poursuite et de prise de risque ; ils ne changent pas les règles de perception.

## Combat, gadgets et commandes

Le bot tourne sa visée à vitesse limitée. Une erreur de visée rééchantillonnée, les déplacements latéraux et la réaction retardée empêchent une précision parfaite. Il recharge à vide ou lorsqu'une accalmie le permet. En difficulté sous pression, il peut rechercher un point de couverture proche qui coupe la ligne de vue depuis la menace estimée ; cette décision n'utilise pas les coordonnées cachées de l'ennemi.

Les gadgets passent par les commandes de l'acteur et respectent les mêmes consommations. Les défenseurs les déposent près des secteurs surveillés ; les attaquants les emploient à l'approche d'une sortie ou d'un contact. Le placement tactique reste heuristique : la reconnaissance visuelle et le contournement explicite des pièges ennemis ne sont pas encore implémentés.

Les ordres `follow`, `hold`, `cover`, `advance`, `retreat` et `extract` sont pris en charge. Le suivi conserve une formation approximative derrière le joueur. Les ordres persistent de 18 à 28 secondes et peuvent être interrompus par un combat confirmé ou une alerte d'extraction prioritaire. Les messages d'équipe sont espacés d'au moins sept secondes par bot.

## Difficultés

| Niveau | Réaction initiale | Rotation maximale | Erreur de direction initiale |
| --- | --- | --- | --- |
| Initiation | 0,70–1,00 s | 2,2 rad/s | 0,115 |
| Normal | 0,36–0,58 s | 3,0 rad/s | 0,064 |
| Difficile | 0,27–0,43 s | 3,8 rad/s | 0,043 |
| Expert | 0,20–0,34 s | 4,5 rad/s | 0,028 |

L'erreur est un petit vecteur ajouté à la direction de visée, pas un multiplicateur de dégâts. Aucun niveau ne change les PV, la vitesse physique ou les dégâts. Les comportements sont reproductibles avec la graine de simulation, l'identifiant de l'acteur et le numéro de manche ; les suites d'entrées identiques restent nécessaires à une répétition exacte.

## Mesures et validation

Chaque bot expose son état, son objectif, son chemin, son nombre de blocages et un dictionnaire `telemetry` : chemins recalculés, tentatives de déblocage, interceptions, enquêtes, recherches abandonnées, engagements, commandes de tir, tirs spéculatifs, pings et gadgets. Le rapport du match peut exploiter ces compteurs.

`tests/test_navigation_ai.gd` exécute 27 assertions :

- Les six spawns de chacun des trois formats sont navigables ; chaque spawn atteint chaque sortie active, avec des segments qui respectent les obstacles agrandis.
- Un mur exige un détour ; les coins et limites du niveau ne sont pas traversés.
- Le défenseur près d'une extraction passe en interception et émet un ping sans inventer de contact ennemi.
- Une fausse source acoustique attire une enquête, ne permet pas de tir précis et finit par être abandonnée.
- Une acquisition confirmée respecte le délai de réaction puis permet le combat.
- La réponse aux alarmes reste répartie ; l'ordre d'attente et l'interaction d'extraction fonctionnent.

Ces assertions ont été exécutées avec Godot 4.6.3 en mode headless et ont toutes réussi. Elles vérifient les règles du contrôleur et la connectivité géométrique, pas l'agrément des parties. Des parties humaines et des séries de simulations plus longues restent nécessaires à l'équilibrage, au placement des gadgets et à l'évaluation des blocages dynamiques entre acteurs.

Une série d'intégration exécutée avec le véritable niveau, les collisions, les personnages, les gadgets et la perception a également terminé 20 manches en quatre manches par match :

| Format | Graine | Score final | Extractions par manche | Durée des manches |
| --- | --- | --- | --- | --- |
| 1v1 | 27013 | 100–300 | 1 / 1 / 0 / 1 | 17,25 / 18,27 / 6,63 / 17,92 s |
| 1v1 | 27014 | 100–300 | 0 / 1 / 0 / 0 | 5,53 / 18,38 / 6,28 / 8,15 s |
| 2v2 | 27013 | 400–400 | 2 / 0 / 0 / 2 | 19,83 / 15,22 / 25,92 / 21,00 s |
| 2v2 | 27014 | 400–400 | 0 / 0 / 1 / 1 | 14,13 / 12,23 / 18,65 / 27,88 s |
| 3v3 | 27013 | 600–600 | 1 / 0 / 1 / 2 | 22,62 / 22,88 / 24,57 / 31,50 s |

Les journaux de ces cinq matchs ne contenaient aucune erreur ni avertissement moteur. Les tentatives locales de déblocage allaient de zéro à deux par bot et manche ; toutes les manches ont terminé par résolution des attaquants avant la limite de 90 secondes utilisée pour ces essais. Cette mesure ne prouve pas l'absence de blocage pour toutes les graines. Les duels de moins de dix secondes et la précision rapprochée des bots indiquent un besoin réel de tests humains et d'ajustement du rythme. Le lancement `--fixed-fps 60` contrôle le temps de simulation ; le chiffre de 60 FPS issu de ce mode ne constitue pas une mesure des performances graphiques.
