# Vérification locale — 16 septembre 2026

- Compilation release native ARM64 réussie avec les Command Line Tools et Swift 6.2.1.
- 13 tests fonctionnels réussis (`./scripts/test.sh`) : Unicode, espaces, formats enrichis, RTF seul, contenu vide, images, fichiers Finder, éléments multiples, contenus mixtes, format non pris en charge, raccourci par défaut, validation et persistance des préférences, conflits de raccourci avec conservation de l’enregistrement précédent.
- Fenêtre native inspectée visuellement. Modification du raccourci vers ⌃⌥K, rétablissement de ⇧⌘K et annulation avec Échap vérifiés dans l’interface.
- Bundle signé localement ad hoc ; vérification stricte réussie pour la version installée dans `~/Applications/Texte brut.app` et pour le bundle avant archivage.
- Taille du bundle : environ 430 Ko. Mesure ponctuelle avec les réglages ouverts : 0,0 % CPU, environ 68 Mo de mémoire résidente. Ces mesures dépendent de la version de macOS et ne constituent pas une garantie.
- L’outil de simulation clavier n’a pas déclenché le raccourci global durant le test de bout en bout. Le contenu du presse-papiers précédent a été restauré. Une pression physique sur ⇧⌘K depuis une autre application reste à vérifier ; le test automatisé d’enregistrement et de conflit auprès de macOS passe.

L’app cible macOS 13 ou ultérieur ; aucune validation sur toutes les versions de macOS ni notarisation Developer ID n’a été effectuée.

## Installateur PKG

- `scripts/build-pkg.sh` génère `dist/Texte-brut-1.0.0-Apple-Silicon.pkg` (environ 263 Ko).
- Paquet extrait avec `pkgutil --expand-full` : signature de l’app vérifiée et exécutable identique à la compilation.
- Distribution XML valide : ARM64 uniquement, macOS 13 minimum, installation dans `/Applications`, relocalisation désactivée, aucun script d’installation ni redémarrage.
- Prévalidation macOS avec `installer -showChoicesXML -target /` : paquet sélectionné et installable. Domaine autorisé : `LocalSystem`.
- Assistant ouvert et contrôlé : introduction française et sélection de destination correctes. Aucune installation système effectuée par l’agent durant cette vérification.
- L’app incluse est signée ad hoc ; le paquet n’a pas de signature Developer ID Installer ni de notarisation Apple.

## Mise à jour du 17 septembre 2026 — Get Clean Text 1.0.1

- Nom affiché, menu, fenêtre, bundle et installateur renommés en Get Clean Text.
- Identifiant de bundle conservé pour préserver les préférences existantes.
- Bouton de raccourci : style à hauteur flexible, rendu natif inspecté à 48 points ; texte centré dans le fond.
- 13/13 tests réussis hors sandbox (les services presse-papiers et raccourcis macOS sont inaccessibles dans la sandbox).
- Installateur `dist/Get-Clean-Text-1.0.1-Apple-Silicon.pkg` construit ; signature du payload, exécutable et XML vérifiés.
- Les anciennes copies installées dans `/Applications` et `~/Applications` n’ont pas été modifiées. Le nouveau bundle porte un autre nom de fichier ; retirer les anciennes copies après installation pour éviter de relancer l’ancienne version.

## Distribution DMG par défaut — 17 septembre 2026

- `scripts/build.sh` produit désormais le DMG versionné contenant `Get Clean Text.app` et un lien vers `/Applications`.
- `dist/Get-Clean-Text-1.0.1-Apple-Silicon.dmg` créé et intégrité vérifiée.
- Image montée en lecture seule : signature stricte de l’app valide, exécutable identique à la compilation, cible du lien Applications contrôlée ; volume éjecté après vérification.
- Syntaxe shell et `git diff --check` vérifiés. README mis à jour pour privilégier le glisser-déposer depuis le DMG.

## Présentation du DMG — 17 septembre 2026

- Fenêtre illustrée avec titre, consigne française, flèche centrale, app à gauche et raccourci Applications à droite.
- Fond PNG à la taille logique de la fenêtre pour éviter l’agrandissement des fonds TIFF observé dans Finder sur ce Mac.
- Mise en page enregistrée dans `.DS_Store`, avec volume temporaire au nom unique pour éviter les collisions avec une version déjà montée.
- DMG final ouvert dans Finder et inspecté visuellement : textes entièrement visibles, icônes dans leurs emplacements et flèche alignée.
- Intégrité du disque, signature stricte de l’app, exécutable et lien Applications vérifiés après compression. Syntaxe shell et `git diff --check` valides.

## Version 1.0.2 — simplification visuelle

- Slogan supprimé de la fenêtre de réglages, de la ressource d’accueil PKG et du générateur de fond DMG ; aucune occurrence restante dans Sources, Resources, scripts et README.
- Le DMG utilise désormais un PDF vectoriel interne de 600 × 330 points : texte et flèche nets, fond blanc uniforme, présentation plus compacte. Les cartes et le dégradé ont été retirés.
- Fond vérifié dans Finder à la taille normale et en plein écran : aucune limite visible entre le décor et l’espace ajouté. Retour à la taille normale après contrôle.
- Limite native conservée : Finder ne réorganise pas la disposition quand la fenêtre devient plus petite ; le défilement est nécessaire si des éléments sortent du cadre.
- Release ARM64 1.0.2 construite ; intégrité du DMG, signature stricte du bundle, exécutable et lien Applications vérifiés. Syntaxe shell et `git diff --check` valides.
