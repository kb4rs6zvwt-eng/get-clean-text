# Vérification locale — 16 septembre 2026

- Compilation release native ARM64 réussie avec les Command Line Tools et Swift 6.2.1.
- 13 tests fonctionnels réussis (`./scripts/test.sh`) : Unicode, espaces, formats enrichis, RTF seul, contenu vide, images, fichiers Finder, éléments multiples, contenus mixtes, format non pris en charge, raccourci par défaut, validation et persistance des préférences, conflits de raccourci avec conservation de l’enregistrement précédent.
- Fenêtre native inspectée visuellement. Modification du raccourci vers ⌃⌥K, rétablissement de ⇧⌘K et annulation avec Échap vérifiés dans l’interface.
- Bundle signé localement ad hoc ; vérification stricte réussie pour la version installée dans `~/Applications/Texte brut.app` et pour le bundle avant archivage.
- Taille du bundle : environ 430 Ko. Mesure ponctuelle avec les réglages ouverts : 0,0 % CPU, environ 68 Mo de mémoire résidente. Ces mesures dépendent de la version de macOS et ne constituent pas une garantie.
- L’outil de simulation clavier n’a pas déclenché le raccourci global durant le test de bout en bout. Le contenu du presse-papiers précédent a été restauré. Une pression physique sur ⇧⌘K depuis une autre application reste à vérifier ; le test automatisé d’enregistrement et de conflit auprès de macOS passe.

L’app cible macOS 13 ou ultérieur ; aucune validation sur toutes les versions de macOS ni notarisation Developer ID n’a été effectuée.
