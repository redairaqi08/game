# Sanctuaire des Trois Échos — état du jalon

La carte est construite par `scripts/level.gd`. Elle mesure 112 × 88 m en 3v3, 94 × 74 m en 2v2 et 70 × 56 m en duel. Le sud est +Z ; le nord est −Z. L'attaque apparaît à (0, 35), la défense près de (0, −27), avant adaptation aux dimensions.

Trois itinéraires se recoupent par de larges ouvertures autour de cloisons décalées. L'axe ouest traverse les ateliers puis les cloches ; le centre traverse la cour et la cathédrale ; l'est traverse les cryptes, les canaux peu profonds et le jardin. Deux barrières par flanc et des couverts de hauteurs différentes interrompent les lignes de tir. La cour possède une grande paroi qui empêche un tir direct depuis les positions nord.

Les neuf zones disposent de noms de lieu et de repères : statues à organes auditifs facettés, cloches suspendues, cristal d'archive monumental, tables de résonance, bibliothèque minérale, eau et champignons de pierre. La sélection de surface `get_surface` distingue pierre, métal, eau et surface absorbante ; son exploitation acoustique dépend du service acoustique.

Les sorties sont publiques. A à l'ouest possède un rayon de 3 m et exige 5 s ; B au centre possède un rayon de 3,2 m et exige 7 s ; C à l'est possède un rayon de 3 m et exige 8 s. Les colonnes des portes sont extérieures au rayon de destination. B est remplacée par une porte close visible en duel. Les cercles d'extraction disposent d'un shader animé et de l'API `set_exit_active`.

Les collisions sont explicites, sur la couche monde 1. Le graphe de navigation reçoit les rectangles XZ des volumes au sol. Les débris bas, les incrustations et les anneaux de sol sont décoratifs. Les archives et couverts ont des collisions réelles. Les grandes colonnes ont une enveloppe cylindrique ; leur rectangle de navigation est conservateur.

## Limites assumées

Les galeries et la passerelle du bastion sont des repères élevés décoratifs à ce jalon. Elles ne sont pas encore des itinéraires traversables par le joueur et les bots. La navigation tactique reste sur un étage, Y=0. La verticalité significative avec navigation multiétage reste une exigence ouverte du cahier des charges. Les dimensions réduites sont produites par adaptation de l'architecture ; ce ne sont pas encore trois cartes équilibrées séparément. Aucun taux de victoire ni temps de rotation n'est revendiqué sans simulation mesurée et tests humains.
