# Perception acoustique et dispositifs

État : implémentation jouable Godot 4.6, validée par des régressions automatisées avec de vrais rayons physiques. La propagation reste une approximation de jeu, pas une simulation acoustique complète.

## Quatre couches distinctes

1. La simulation conserve les positions, collisions et identifiants réels.
2. `acoustics.gd` crée des événements immuables : identifiant, heure, famille, position, catégorie, portée, intensité, durée, incertitude et source interne.
3. Chaque observateur possède une mémoire personnelle. L'IA et l'interface lisent une copie des estimations ; elles ne reçoivent pas de référence au personnage ennemi. Un ancien contact ne suit plus la cible.
4. Seul l'observateur actif pilote les silhouettes et les anneaux affichés. Les anneaux utilisent la profondeur et une géométrie radiale coupée par les murs.

`contact_for(observer, id)` et `contacts_for(observer)` exposent `position` au sol, `confidence`, `state` 0 à 4, `age`, `category`, `confirmed`, `visible`, `team` et `updated_at`. Les états 3/4 exigent un signal suffisamment fort et une ligne de vue actuelle. Un mur opaque limite l'information à une estimation incertaine. Les informations radio sont moins précises et ne créent jamais de silhouette à distance.

## Ping

F déclenche une préparation de 0,15 s puis une reconnaissance à environ 42 m/s sur 22 m. La recharge est de 8 s. Un personnage immobile est détectable ; il n'a pas besoin d'émettre un pas. Une reconstruction confirmée dispose d'une fenêtre initiale de 1,25 s avant dissipation. Le ping produit également une signature perceptible par l'adversaire. Le joueur reçoit un retour d'émission, de contacts ou d'absence de contact, puis de disponibilité.

La réception est retardée par la propagation. Une cible sortie de la portée avant l'arrivée de l'impulsion n'est pas confirmée. Les signaux derrière un mur sont atténués et décalés par une incertitude stable calculée à partir de l'événement. Trois échantillons de rayons approximent l'occlusion aux ouvertures ; aucun graphe complet de portails acoustiques ou de diffraction n'est encore implémenté.

La source d'un impact distant est un contact acoustique autonome. Elle ne révèle pas gratuitement le tireur qui a provoqué cet impact.

## Gadgets

Chaque emplacement est utilisable une fois par manche. Maintenir G/T affiche l'emplacement et sa validité ; relâcher déploie le dispositif. Les bots utilisent la même validation directement. Le placement respecte le sol, la portée, les murs et l'occupation par un autre dispositif. Les petits colliders de couche 4 sont destructibles par les tirs et n'obstruent pas la navigation des personnages.

| Faction | Gadget | Comportement implémenté |
| --- | --- | --- |
| Passeurs | Écho errant | 6 s de faux pas de course suivant deux segments bornés par les murs ; mêmes événements et mêmes sons que les vrais pas, sans indicateur de leurre dans la perception. |
| Passeurs | Voile muet | Champ de 6 m durant 5 s ; diminue la confiance et la précision adverses. Le ping et les actions proches conservent une efficacité. |
| Passeurs | Épine d'écoute | Déclenchement unique à 3 m, même sur une cible immobile ; estimation partagée et reconstruction en ligne de vue durant 3 s. |
| Veilleurs | Oreille de pierre | Détecte un infiltrateur dans 4 m après 0,7 s d'armement ; notification d'équipe et révélation limitée par les murs. |
| Veilleurs | Cloche brisée | Déclenchement dans 2,5 m et signature forte pendant 2,5 s, sans dégâts directs. |
| Veilleurs | Chœur de cristal | Pendant 10 s, émet une reconnaissance de 9 m toutes les 2,4 s après 1 s de préparation. |

Les trois pièges vérifient également la ligne de vue entre le dispositif et la cible : un ennemi dans la pièce voisine ne les déclenche pas à travers un mur. Un gadget possédant 35 points de résistance se brise sous les tirs. Les dispositifs sont réinitialisés entre les manches.

Les lancers sont représentés par un déploiement vers un emplacement validé ; leur animation balistique et les sons particuliers de chaque matériau restent à approfondir. Le Chœur partage des estimations, et sa reconstruction exacte dépend toujours de la ligne de vue personnelle de son observateur.

## Réglages et budget

Les portées, la recharge, la vitesse du ping, la durée de confirmation, la dissipation et les paramètres des gadgets se règlent dans `config/balance.json`. `settings.wave_intensity` agit sur l'opacité des effets sans modifier les informations de jeu. Le nombre d'anneaux est plafonné à 28, les journaux à 160 événements et les souvenirs disparaissent après six secondes au maximum. Aucun anneau n'est généré en mode headless.

## Vérification

```sh
godot --headless --path . --script tests/test_acoustics.gd
```

Résultat observé : 36 assertions, 0 échec sous Godot 4.6.3. Les cas couvrent l'immobilité, la symétrie, l'occlusion, la dissipation, les anciennes positions, la recharge proche, la non-révélation des tireurs par leurs impacts distants, les six gadgets, la destruction, les pièges séparés par un mur et le partage d'équipe. Ces tests vérifient les règles ; ils ne prouvent pas encore l'équilibrage ni le plaisir de jeu.
