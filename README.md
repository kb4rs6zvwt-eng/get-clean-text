# Texte brut

Une petite application macOS native pour Apple Silicon. **⇧⌘K** remplace le texte copié par sa version sans mise en forme, prête à coller avec **⌘V**.

## Utilisation

1. Ouvrir `dist/Texte brut.app`. Pour la conserver, la glisser dans le dossier Applications.
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
open "dist/Texte brut.app"
```

Le script produit l’app ARM64 et `dist/Texte-brut-Apple-Silicon.zip`. Il utilise une signature locale ad hoc. La signature est vérifiée dans un dossier temporaire avant l’archivage : certains dossiers synchronisés ajoutent ensuite des métadonnées Finder au bundle non archivé. Préférer extraire le ZIP dans Applications pour l’installation. Pour diffuser l’app à d’autres personnes sans avertissement Gatekeeper, prévoir une signature Developer ID et une notarisation Apple.

Les tests utilisent des presse-papiers nommés et isolés : ils ne remplacent pas votre presse-papiers habituel. Ils vérifient le retrait des formats, la conservation du texte, les contenus non textuels, les raccourcis persistants et les conflits d’enregistrement.

Le test manuel optionnel `swift -module-cache-path .build/ModuleCache Tests/HotKeySmoke.swift` attend une pression physique sur ⇧⌘K pendant 30 secondes, avec l’app lancée. Il remplace temporairement le presse-papiers par un échantillon puis restaure son ancien contenu, conservé uniquement en mémoire. Si le presse-papiers a été modifié par une autre application pendant le test, il ne l’écrase pas.

## Structure

- `Sources/PlainText/ClipboardCleaner.swift` : conversion sûre du presse-papiers.
- `Sources/PlainText/Shortcut.swift` : raccourci global et préférences persistantes.
- `Sources/PlainText/PreferencesWindow.swift` : interface native et saisie du raccourci.
- `Sources/PlainText/AppDelegate.swift` : cycle de vie, menu et retour visuel.
- `scripts/build.sh` : construction du bundle `.app`, icône et archive.

Références Apple : [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard), [LSUIElement](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/LaunchServicesKeys.html). Le contrat du raccourci est documenté dans `CarbonEvents.h`, fourni par le SDK macOS.
