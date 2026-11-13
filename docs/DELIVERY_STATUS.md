# Livraison GitHub — alpha 0.1.0

13 novembre 2026. Les sources sont publiées sur la branche `main` du dépôt [redairaqi08/game](https://github.com/redairaqi08/game). Le refus d'écriture403 rencontré lors de la première tentative est résolu. Aucun historique distant n'a été écrasé.

Le projet Godot, les ressources, six suites (161 assertions), les captures natives et les exports desktop constituent un premier jalon jouable. Les limites du cahier complet restent documentées dans `PRODUCTION_STATUS.md` et `FEATURE_MATRIX.md`.

## Téléchargements

La [préversion v0.1.0-alpha](https://github.com/redairaqi08/game/releases/tag/v0.1.0-alpha) regroupe :

- `SONAR-0.1.0-alpha-linux-x86_64.zip` : exécutable embarquant son pack, documentation et licences. Exécution Linux headless et native vérifiée.
- `SONAR-0.1.0-alpha-windows-x86_64.zip` : export Windows, documentation et licences. Validation Windows native encore nécessaire.
- `SONAR-0.1.0-alpha-source.zip` : sources versionnées, sans caches ni templates moteur.
- `SONAR-0.1.0-alpha.git.bundle` : historique complet et branche `main`, pour restauration du dépôt.
- `SHA256SUMS.txt` : empreintes des fichiers de livraison.

Décompressez toute l'archive avant de lancer le jeu. Commencez par Entraînement → Tutoriel. Les archives sont également préparées dans `builds/release/`, dossier ignoré par Git pour ne pas versionner les exécutables.

Les ZIP sont contrôlés par leur CRC ; `git bundle verify` valide l'historique sauvegardé. `tools/package_release.py` permet de recréer les archives binaires après export.

## Sources et vérification

```bash
git clone https://github.com/redairaqi08/game.git
cd game
godot --editor --path .
```

Le workflow [Verify and export SONAR](https://github.com/redairaqi08/game/actions) importe le projet, exécute les régressions et exporte les versions desktop. Son état distant se consulte dans Actions ; les161 assertions locales et leurs preuves sont décrites dans `TEST_REPORT.md`.

Pour restaurer à partir du bundle sur une autre machine :

```bash
git clone SONAR-0.1.0-alpha.git.bundle game
cd game
git remote set-url origin https://github.com/redairaqi08/game.git
```

L'existence de cette préversion ne signifie pas que l'intégralité du cahier des charges est achevée.
