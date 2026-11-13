# Provenance et licences

Cette liste couvre les ressources présentes dans le jalon initial. Le fichier `LICENSE` à la racine définit la licence retenue pour le code du projet, lorsqu'il est présent. La présence de ce document ne remplace pas les licences de dépendances.

| Ressource | Provenance | Conditions |
| --- | --- | --- |
| Code de jeu GDScript, shaders et outils de génération | Écrits pour SONAR dans ce dépôt | Licence du projet indiquée à la racine. |
| Géométrie du Sanctuaire, armes, Vesperides, effets acoustiques | Créations procédurales originales, paramètres et maillages dans les sources | Licence du projet indiquée à la racine. Aucun pack d'assets tiers. |
| WAV dans `assets/audio/` | Synthèse additive et bruit déterministe par `tools/generate_audio.py` | Créations originales. Aucun sample tiers ni voix réelle. |
| Moteur Godot 4.6 | Godot Engine, https://godotengine.org/ | Licence MIT. Le binaire moteur n'est pas une création SONAR. Les exports doivent conserver les mentions requises par Godot et ses composants. Voir https://godotengine.org/license/. |
| Python utilisé par l'outil audio | Python Software Foundation | Dépendance de développement facultative ; les WAV sont déjà inclus. Aucun module tiers nécessaire. |
| Polices incluses | Voir fichiers de licence dans `assets/fonts/` | Les noms et licences exacts sont conservés à côté des fichiers de police. |

Aucun service externe n'est nécessaire pour jouer. Le projet n'embarque ni clé, ni compte, ni télémétrie réseau. Le titre et l'univers proposés sont originaux à ce projet ; aucune vérification d'antériorité de marque n'a été effectuée.
