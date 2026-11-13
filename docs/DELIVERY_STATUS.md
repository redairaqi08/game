# Livraison préparée — publication distante bloquée

13 novembre2026. Le projet Godot, les ressources, six suites (161 assertions), les captures natives et les exports desktop ont été produits dans l'espace de travail.

## Fichiers préparés

Dans `builds/release/` (ignoré par Git pour éviter de versionner les exécutables) :

- `SONAR-0.1.0-alpha-linux-x86_64.zip` : exécutable embarquant son pack, documentation et licences. Exécution Linux headless et native vérifiée ici.
- `SONAR-0.1.0-alpha-windows-x86_64.zip` : export Windows, documentation et licences. Validation Windows native encore nécessaire.
- `SONAR-0.1.0-alpha-source.zip` : sources versionnées, sans caches ni templates moteur.
- `SONAR-0.1.0-alpha.git.bundle` : historique complet et branche `main`, pour restauration du dépôt.
- `SHA256SUMS.txt` : empreintes des fichiers de livraison.

Les archives ZIP ont été contrôlées par leur CRC ; `git bundle verify` valide l'historique sauvegardé. `tools/package_release.py` permet de recréer les archives binaires après export.

## Blocage observé

Le push vers `https://github.com/redairaqi08/game.git` est refusé403. Une tentative d'initialisation par le connecteur GitHub renvoie aussi403, **Resource not accessible by integration**. Les métadonnées affichent des droits de propriétaire, mais elles ne prouvent pas le droit effectif d'écriture du jeton d'intégration. Le réglage d'actions de ChatGPT autorise déjà GitHub ; ce réglage n'est donc pas la cause à corriger.

Aucun fichier n'a été publié ; une lecture des branches après ces tentatives confirme une collection vide. Aucune release ni exécution CI distante n'est revendiquée.

La connexion GitHub doit être réautorisée avec l'accès en écriture aux contenus du dépôt, ainsi qu'aux workflows si le workflow CI inclus doit être publié. Aucun secret ou jeton ne doit être collé dans la conversation.

## Reprise une fois l'accès rétabli

Depuis le checkout préparé :

```bash
git status
git push -u origin main
```

Vérifier ensuite le commit distant et la CI. Créer une release **préversion alpha** avec les archives et les empreintes, sans qualifier ce jalon de réalisation finale du cahier. Si la branche distante a reçu du contenu entre-temps, l'inspecter et l'intégrer avant tout push ; ne jamais forcer pour écraser ce travail.

Pour restaurer à partir du bundle sur une autre machine :

```bash
git clone SONAR-0.1.0-alpha.git.bundle game
cd game
git remote set-url origin https://github.com/redairaqi08/game.git
```

La conception, les limites et la prochaine étape figurent dans `PRODUCTION_STATUS.md` et `FEATURE_MATRIX.md`.
