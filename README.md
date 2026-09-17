# Get Clean Text

Une petite application macOS native pour Apple Silicon. **⇧⌘K** remplace le texte copié par sa version sans mise en forme, prête à coller avec **⌘V**.

## Utilisation

1. Ouvrir `dist/Get-Clean-Text-1.0.3-Apple-Silicon.dmg`, glisser **Get Clean Text** sur **Applications**, puis éjecter le disque et lancer l’app depuis **Applications**. Quitter l’app avant de remplacer une version précédente. Pour migrer depuis **Texte brut**, retirer les anciennes copies de ce nom dans `/Applications` et `~/Applications` ; les préférences sont conservées.
2. Copier du texte depuis une application.
3. Appuyer sur **Maj + Commande + K**. Une coche apparaît brièvement dans la barre des menus.
4. Coller normalement avec **⌘V**.

L’icône **Aa** de la barre des menus donne accès au nettoyage manuel, aux réglages et à la commande Quitter. L’app n’apparaît pas dans le Dock. Fermer ses réglages la laisse fonctionner en arrière-plan.

Dans **Réglages…**, cliquer sur le raccourci puis taper la combinaison souhaitée, avec au moins **⌘**, **⌥** ou **⌃**. **Échap** annule la saisie. Le choix est conservé au prochain lancement. **Rétablir ⇧⌘K** restaure le raccourci initial. Si macOS signale un conflit, la combinaison n’est pas enregistrée. Éviter les raccourcis habituels tels que ⌘C ou ⌘V, car une combinaison globale prend la priorité sur les applications.

Pour lancer l’app à chaque ouverture de session, l’ajouter dans **Réglages Système → Général → Ouverture** (le libellé varie selon la version de macOS).

## Comportement

- Retire les représentations riches : gras, italique, police, taille, couleur, liens enrichis et HTML sont supprimés du presse-papiers lorsque leur version textuelle est disponible.
- Préserve exactement le texte : accents, caractères Unicode, espaces, tabulations et retours à la ligne. L’app ne « corrige » pas le contenu et ne supprime pas les caractères de syntaxe Markdown.
- Privilégie la représentation texte fournie par l’application source ; peut aussi extraire du texte RTF/RTFD.
- Réunit plusieurs éléments textuels dans leur ordre, séparés par un retour à la ligne.
- Laisse intacts un presse-papiers vide, une image seule, les fichiers copiés et un ensemble d’éléments comprenant un élément non textuel.
- Le rare cas d’un presse-papiers uniquement HTML, sans texte ni RTF, est laissé intact. Aucun moteur web n’est chargé pour interpréter du HTML.
- Ne colle pas automatiquement et ne modifie pas le document source. L’application de destination peut appliquer son propre style au texte collé.

## Légèreté et confidentialité

Swift + AppKit, sans dépendances externes, serveur, navigateur embarqué, historique ou télémétrie. Aucun contenu du presse-papiers n’est écrit sur disque. Le raccourci global est enregistré auprès de macOS avec `RegisterEventHotKey` : pas de boucle de surveillance, pas de lecture régulière du presse-papiers ni d’enregistrement de frappe. Un délai ponctuel de 1,5 seconde sert seulement à rétablir l’icône après une action.

Cette implémentation ne demande pas d’accès Accessibilité ni de surveillance des entrées pour enregistrer le raccourci. Les éventuelles protections du presse-papiers de la version de macOS restent applicables.

## Compiler et tester

Mac Apple Silicon, macOS 13 ou ultérieur. Pour développer : outils en ligne de commande Xcode avec Swift 6 ou ultérieur, sans nécessité d’installer l’IDE Xcode complet.

```sh
./scripts/test.sh
./scripts/build.sh
open "dist/Get Clean Text.app"
```

Le format de distribution par défaut est le **DMG**. `./scripts/build.sh` produit `dist/Get-Clean-Text-<version>-Apple-Silicon.dmg`, contenant l’app et un raccourci vers **Applications**. La fenêtre présente un fond vectoriel blanc, les deux icônes et une flèche de glisser-déposer. Le fond reste net sur écran Retina et se prolonge sans rupture lors d’un agrandissement. La disposition est fixe, comme dans toute fenêtre Finder : si on réduit trop la fenêtre, il faut défiler pour atteindre les éléments masqués. Aucun assistant d’installation n’est nécessaire.

La génération configure la fenêtre du disque avec Finder et nécessite une session macOS graphique (autoriser le contrôle de Finder si macOS le demande). Le script vérifie l’intégrité du DMG, le monte en lecture seule, contrôle la signature de l’app et compare son exécutable à la compilation, puis éjecte le volume. L’app cible Apple Silicon et macOS 13 minimum.

L’app utilise actuellement une signature locale ad hoc. Pour une distribution publique, prévoir une signature Developer ID et une notarisation Apple. Le dossier `dist/` est ignoré par Git ; la publication des releases utilise exclusivement le `.dmg`.

Le bundle `.app` et une archive ZIP sont également générés. L’ancien script `scripts/build-pkg.sh` reste disponible pour un besoin ponctuel de PKG ; il ne constitue plus le mode de distribution recommandé.

Les tests utilisent des presse-papiers nommés et isolés : ils ne remplacent pas votre presse-papiers habituel. Ils vérifient le retrait des formats, la conservation du texte, les contenus non textuels, les raccourcis persistants et les conflits d’enregistrement.

Le test manuel optionnel `swift -module-cache-path .build/ModuleCache Tests/HotKeySmoke.swift` attend une pression physique sur ⇧⌘K pendant 30 secondes, avec l’app lancée. Il remplace temporairement le presse-papiers par un échantillon puis restaure son ancien contenu, conservé uniquement en mémoire. Si le presse-papiers a été modifié par une autre application pendant le test, il ne l’écrase pas.

## Publier une release

1. Augmenter `CFBundleShortVersionString` et `CFBundleVersion` dans `Resources/Info.plist`.
2. Commiter et pousser les modifications sur GitHub.
3. Exécuter `./scripts/release.sh` dans une session graphique macOS.

La commande teste l’app, reconstruit son DMG et publie la release `v<version>` comme dernière version. Seul le DMG correspondant à la version du bundle est envoyé : aucun PKG ni ancien DMG n’est sélectionné par un motif générique. Elle utilise l’authentification GitHub déjà configurée dans Git, ou `GH_TOKEN`/`GITHUB_TOKEN`.

Le SHA-256 du fichier envoyé est vérifié avant publication. Ensuite, les anciens PKG sont retirés des releases ; leurs fichiers et anciennes descriptions sont sauvegardés dans `.build/release-backups/`. Les anciennes releases concernées renvoient vers la dernière version. Un DMG déjà publié avec un contenu différent exige un nouveau numéro de version : aucun tag existant n’est déplacé.

Pour fournir des notes personnalisées : `./scripts/release.sh --notes-file chemin/notes.md`. Pour publier un DMG déjà construit et vérifié, sans recompilation : `python3 scripts/publish-release.py`.

La publication reste une commande explicite ; un simple `git push` ne crée pas de release. Elle s’effectue localement, car la création de la présentation du DMG utilise Finder.

## Structure

- `Sources/PlainText/ClipboardCleaner.swift` : conversion sûre du presse-papiers.
- `Sources/PlainText/Shortcut.swift` : raccourci global et préférences persistantes.
- `Sources/PlainText/PreferencesWindow.swift` : interface native et saisie du raccourci.
- `Sources/PlainText/AppDelegate.swift` : cycle de vie, menu et retour visuel.
- `scripts/build.sh` : construction du bundle `.app`, de l’icône et du DMG vérifié (ainsi que du ZIP).
- `scripts/build-dmg.sh` : mise en page Finder, compression et vérification du DMG.
- `scripts/make-dmg-background.swift` : dessin du fond et de la flèche.
- `scripts/style-dmg.applescript` : disposition des icônes et dimensions de la fenêtre.
- `scripts/release.sh` : tests, construction et publication du DMG.
- `scripts/publish-release.py` : publication GitHub vérifiée et retrait des anciens PKG.
- `scripts/build-pkg.sh` : ancien format `.pkg`, conservé à titre optionnel.

Références Apple : [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard), [LSUIElement](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/LaunchServicesKeys.html). Le contrat du raccourci est documenté dans `CarbonEvents.h`, fourni par le SDK macOS.
