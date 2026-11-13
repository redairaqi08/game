# Identité sonore et implémentation

Tous les sons de `assets/audio/` sont des synthèses originales produites par `tools/generate_audio.py`. Aucun échantillon téléchargé, enregistrement tiers ou voix clonée n'est utilisé. La génération est déterministe, avec Python standard uniquement.

## Palette

Le fusil combine une impulsion grave, un frottement bruité et des partiels minéraux inharmoniques. Le pistolet est plus court et plus aigu. Le ping descend légèrement autour de 460 Hz, avec des rapports proches d'une quinte et d'une octave pour rester reconnaissable. La confirmation est un bref accord plus haut. Les gadgets, pièges, impacts et portes possèdent leurs propres enveloppes et registres.

Les pas possèdent trois variantes par famille : pierre, métal, cristal, eau, poussière et matière organique. Le rythme réel appartient au contrôleur ; l'audio ne fabrique pas de pas supplémentaires. Les familles sont choisies à partir de la zone nommée du niveau, ce qui constitue une approximation de matériau. Cette version n'effectue pas encore une lecture détaillée de texture physique sous chaque pied.

Le leurre utilise la même catégorie de pas de sprint que le personnage. Aucun timbre spécial n'annonce qu'un contact est faux.

## Chaîne technique

`SonarAcoustics` vérifie l'audibilité, calcule l'atténuation et transmet une origine estimée à `SonarAudio.play_event(category, origin, intensity)`. L'audio spatialise cette origine avec un `AudioStreamPlayer3D`, un maximum de 24 voix et une atténuation par distance. Un filtre atténue les hautes fréquences des origines masquées par le décor. Les contacts faibles ne reçoivent pas une position sonore secrète plus précise que leur estimation.

Une voix disponible est réutilisée ; si le pool est occupé, une ancienne voix de priorité inférieure ou égale peut être remplacée. Les tirs, pièges, pings et portes ont priorité sur les pas. Les sons déjà audibles ne sont pas multipliés par le nombre de bots.

Les signaux d'interface et de confirmation utilisent une voix 2D séparée. Les deux ambiances stéréo bouclent sans interruption : souffle du Creux et thème de la Trame. Le score baisse fortement pendant une manche pour laisser les informations tactiques au premier plan et remonte dans les menus. Le volume principal est configurable.

Les effets sont en PCM mono 16 bits à 22 050 Hz ; les boucles sont stéréo. Le script règle les points de bouclage lors du chargement. Les imports Godot restent standards. En mode headless ou avec pilote audio `Dummy`, le service n'alloue pas de voix et n'essaie pas de démarrer la lecture.

## Limites explicites

Le mixage constitue une première direction sonore originale. Il ne dispose pas encore d'une convolution de salle, d'une propagation acoustique physiquement exacte, d'un HRTF personnalisé, d'une musique adaptative complète ni de dialogues interprétés. Les différences gauche/droite proviennent de la spatialisation Godot ; la précision avant/arrière dépend de la configuration audio et doit être évaluée au casque. Les essais sans rendu ne valident pas la qualité perceptive humaine.

## Recréer les sources

```sh
python3 tools/generate_audio.py
```

L'outil recrée les WAV à l'identique avec la version Python standard utilisée. Après modification des sons, importer le projet avec Godot puis effectuer une écoute humaine à volume modéré et vérifier les rapports entre pas, tirs et pings.
