# Interface SONAR

Interface native Godot en français, composée de couches séparées : menu, HUD, carte tactique, commandes d'équipe, pause et résultats. Les caractères Liberation Sans et Liberation Mono sont livrés sous SIL Open Font License ; leur avis est conservé dans `assets/fonts/LICENSE.txt`.

La palette associe pierre sombre, ivoire, cyan acoustique et ambre d'alerte. Le menu laisse voir le sanctuaire derrière deux panneaux translucides. Chaque navigation possède une page fonctionnelle : configuration de partie, entraînement/tutoriel, matériel, commandes, lore et paramètres. À 1280 × 720, la configuration principale et son bouton de lancement sont visibles sans défilement ; les pages longues disposent d'un ascenseur.

Le HUD garde le centre libre : objectif et état de l'équipe en haut à gauche, temps et score en haut, santé et armes en bas. Les arcs directionnels et les marqueurs de la carte lisent exclusivement les contacts de l'observateur. Ils ne consultent aucune position réelle adverse. La carte affiche les alliés et les informations publiques des sorties. La progression d'extraction est individuelle et normalisée de 0 à 1 ; le temps restant utilise la durée réelle de l'arche.

Maintenir Tab ouvre la carte. Maintenir Alt ouvre les ordres ; les six touches numériques ou un clic envoient l'ordre. Échap relève du contrôleur de match et ouvre une pause réelle de la simulation. Les résultats proposent la manche suivante, rejouer et retourner au menu. Les impacts possèdent un marqueur central et les dégâts reçus une bordure brève.

Le tutoriel comprend huit étapes pilotées conjointement par le HUD et le directeur pédagogique. Les étapes lisent des actions réelles : glissade, contacts, ping, tirs, dispositif utilisé et événement de piège déclenché. La démonstration de pas dure au moins 7,3 secondes ; l'étape de diversion laisse deux secondes à l'investigation du bot. F8 permet de passer une étape manuellement, notamment pour examiner un système dans un ordre différent. Le directeur pédagogique fournit une cible non létale et des démonstrations adaptées à chaque étape.

Les paramètres exposés sont la sensibilité, le champ de vision, le volume, les mouvements de caméra, la qualité graphique et les dispositions AZERTY/QWERTY. Le remappage individuel au clavier est proposé pour les actions principales, le tir, la visée, les armes, la carte, les ordres et la pause. Une touche déjà utilisée par une autre action est refusée ; Échap annule la capture. Les champs sont sauvegardés par le contrôleur de jeu. Le changement arbitraire de bouton souris, les profils de daltonisme et les volumes séparés ne sont pas encore exposés.

## Vérifications effectuées

- Analyse GDScript par Godot 4.6.3 : réussie.
- Smoke test sans rendu : sept pages du menu, HUD, pause, résultat de manche, résultat final, retour au menu ; aucune erreur.
- Captures natives OpenGL llvmpipe sous Xorg : menu, paramètres, HUD et carte inspectés ; correction du bouton principal initialement hors du panneau.
- Les performances matérielles et la lisibilité pendant des combats humains prolongés restent à mesurer.
