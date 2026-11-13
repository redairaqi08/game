# SONAR — règles et intention de jeu

Ce document décrit les règles de la version native Godot et la direction du projet. Le cahier des charges intégral reste conservé dans `CAHIER_DES_CHARGES.md`. L'état de livraison, les validations et les limites figurent dans `PRODUCTION_STATUS.md` et `TEST_REPORT.md` ; une règle décrite ici n'est pas à elle seule une preuve de validation.

## Boucle centrale

Écouter, estimer une présence, choisir de se déplacer ou d'émettre, engager un contact reconstruit, puis traverser ou défendre une porte. Le son constitue une information qui peut être perdue ou manipulée. Le décor est toujours lisible ; l'incertitude concerne les adversaires.

Les Passeurs attaquent. Les Veilleurs défendent. Les rôles alternent entre les manches d'une partie standard. Les équipes partagent les mêmes règles physiques, les mêmes armes et le même système de perception. Seuls leurs objectifs, leurs départs et leurs gadgets diffèrent.

## Composition et score

Le mode de référence est le 3v3 : un humain et deux bots alliés contre trois bots. Le 2v2 réduit les équipes à deux ; le 1v1 oppose l'humain à un bot et utilise une carte resserrée. Les modes d'apprentissage et de simulation servent les mêmes systèmes.

Une partie standard compte six manches, ou quatre en partie rapide. Chaque équipe attaque et défend le même nombre de fois. Un Passeur extrait rapporte 100 points à son équipe. Un Passeur éliminé ou encore présent à la fin du temps rapporte 100 points à la défense. Les éliminations restent des statistiques, jamais une seconde règle de score. Une égalité finale est un match nul.

Une vie par manche compétitive. Un personnage mort ou extrait ne peut plus tirer, utiliser un gadget ou s'extraire à nouveau. Le joueur peut observer les alliés survivants avec leur propre perception.

## Information acoustique

Quatre couches restent séparées : vérité physique, événements acoustiques, mémoire individuelle, représentation. Les bots prennent leurs décisions à partir de leur mémoire perceptive, et non des positions secrètes de leurs ennemis.

Les contacts passent par cinq états : aucun contact, suspicion, localisation approximative, reconstruction partielle et contact confirmé. Les signaux répétés augmentent la confiance ; le temps et l'occlusion la diminuent. Une dernière position connue reste une ancienne estimation, sans suivre une cible devenue silencieuse.

Le ping actif porte à 22 m et se recharge en huit secondes. Il peut repérer une cible immobile. Il expose aussi son émetteur. Les murs limitent la propagation et interdisent une silhouette exacte à travers une paroi opaque. Les gadgets et le brouillage modifient la qualité d'information sans changer ce principe.

| Action | Portée initiale |
| --- | ---: |
| Accroupissement | 2,7 m |
| Marche | 8 m |
| Sprint | 20 m |
| Glissade | 22 m |
| Réception | 18 m |
| Recharge | 7 m |
| Tir de fusil | 35 m |
| Tir de pistolet | 27 m |
| Pose de gadget | 8 m |
| Ping actif | 22 m |

Les rythmes de pas sont distincts. Les valeurs ne constituent pas des garanties d'équilibrage définitif : elles sont une base de mesure.

## Mouvement et combat

Marcher, sprinter, s'accroupir, sauter et glisser impliquent des compromis entre vitesse et signature sonore. La visée ralentit le mouvement. Les effets de caméra doivent pouvoir être réduits pour le confort.

Le fusil de résonance est l'arme principale polyvalente : santé initiale 100, chargeur de 20, réserve de 80, dégâts corporels de l'ordre de 25 et rechargement d'environ 1,8 s. Le pistolet d'écho sert de solution secondaire. Les tirs utilisent les collisions réelles ; les silhouettes changent la perception, pas l'existence des hitboxes. Aucune augmentation artificielle des dégâts ne sert à rendre un bot plus difficile.

## Gadgets de faction

| Gadget | Faction | Décision tactique |
| --- | --- | --- |
| Écho errant | Passeurs | Émettre une fausse course pour provoquer une enquête ou détourner un défenseur. Les bruits passent par le même système que les pas réels. |
| Voile muet | Passeurs | Réduire temporairement la précision des signaux dans une zone, sans immunité à courte distance ou au ping. |
| Épine d'écoute | Passeurs | Surveiller une poursuite ou un passage ; l'intrusion d'un Veilleur déclenche une alerte. |
| Oreille de pierre | Veilleurs | Surveiller une intersection et repérer une infiltration, y compris accroupie. |
| Cloche brisée | Veilleurs | Déclencher une forte signature de révélation sans infliger de dégâts directs. |
| Chœur de cristal | Veilleurs | Émettre une série limitée de scans localisés, au prix d'une présence audible. |

Chaque emplacement équipé possède une utilisation par manche. Un dispositif posé peut être détruit. Le choix des deux équipements doit favoriser un plan plutôt qu'une accumulation de capacités.

## Extraction et interception

Un Passeur vivant maintient l'interaction dans le rayon d'une sortie. Sa progression est individuelle, même si plusieurs alliés utilisent la même porte. Quitter la zone, relâcher l'interaction ou effectuer une action incompatible interrompt l'extraction ; une courte conservation précède sa décroissance. Subir un seul dégât ne réinitialise pas systématiquement toute la progression.

L'activation crée une alerte publique sur la porte. Les défenseurs connaissent l'objectif activé, puis utilisent leurs déplacements, leur écoute et leur ping pour localiser le Passeur. Un bot proche doit pouvoir intercepter une extraction sans recevoir la position secrète du personnage.

## Coopération et progression de production

Les ordres alliés, la répartition des routes et les alertes doivent provoquer des décisions collectives. Les bots peuvent investiguer un leurre et abandonner une piste lorsque leur information expire. Les difficultés modifient réaction, précision et décision, pas les règles de perception.

La rejouabilité visée repose sur les itinéraires, le rôle alterné, la difficulté, les gadgets et les situations acoustiques. Il n'y a ni comptes, ni matchmaking, ni multijoueur réseau dans ce jalon. La qualité du plaisir de jeu et l'équilibrage nécessitent des essais humains ; une simulation réussie ne les démontre pas.
