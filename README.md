# Fanorona Telo (Flutter)

Jeu **Fanorona Telo** (grille 3x3) en Flutter, avec mode 2 joueurs local et mode contre IA.

## 1) Fonctionnalités

- Mode `2 Joueurs`.
- Mode `Contre IA` avec 2 difficultés:
  - `Stratège` (plus intelligent qu'avant, mais volontairement battable).
  - `Maître` (analyse plus profonde et plus agressive).
- Choix du premier joueur après sélection de la difficulté:
  - `Humain commence`
  - `IA commence`
- Interface néon responsive.
- Popup stylé de fin de partie.

## 2) Règles de jeu (implémentées)

Le jeu se joue sur une grille 3x3 avec 3 pièces par joueur.

### Phases

1. **Placement**
- Les joueurs placent chacun 3 pièces à tour de rôle (6 pièces au total).
- Une victoire immédiate est possible pendant le placement si 3 pièces sont alignées.

2. **Mouvement**
- À son tour, un joueur déplace une de ses pièces vers une case adjacente libre (selon la connectivité Fanorona Telo de la grille).
- Victoire si:
  - alignement de 3 pièces,
  - ou adversaire bloqué (aucun coup légal).

## 3) Lancer le projet

### Prérequis

- Flutter SDK installé.
- Un device/emulator Android/iOS/Web/Desktop selon votre cible.

### Commandes

```bash
flutter pub get
flutter run
```

### Vérification statique

```bash
flutter analyze
```

### Build Android APK (split ABI)

```bash
flutter build apk --split-per-abi
```

### Build Web

```bash
flutter build web --release
npx serve build/web
```

## 4) Architecture rapide

```text
lib/
  ai/
    fanorona_ai.dart        # Interface IA + factory
    strategist_ai.dart      # IA intermédiaire
    master_ai.dart          # IA forte
    pattern_recognizer.dart # Détection tactique (menaces, fourchettes, coups gagnants)
  game/
    ai_game_logic.dart      # Minimax, alpha-beta, évaluation, ordering, cache
    game_logic.dart         # Règles métier (placements, mouvements, victoire)
    game_state.dart         # État du jeu
    constants.dart          # Constantes globales
  ui/
    home_page.dart
    ai_selection_page.dart  # Choix difficulté + popup "qui commence"
    game_page.dart          # Ecran de jeu + popup fin de partie
    game_board.dart         # Plateau et interactions
  utils/
    position_utils.dart     # Adjacence et conversion coordonnées
```

## 5) IA: conception globale

### 5.1 Niveaux de difficulté

- **Stratège**
  - Détection tactique locale (gagner/bloquer tout de suite).
  - Minimax + alpha-beta avec profondeur `strategistDepth`.
  - Comportement imparfait contrôlé pour rester battable.

- **Maître**
  - Priorités tactiques strictes (gagner, défendre, créer fourchette).
  - Minimax plus profond (`masterDepth + 1`) avec évaluation agressive.
  - Plus stable et plus performant en attaque/défense.

### 5.2 Pipeline de décision

Pour un coup de mouvement IA:

1. Générer les coups légaux.
2. Vérifier les coups gagnants immédiats.
3. Vérifier les obligations défensives (bloquer la menace adverse).
4. Lancer la recherche Minimax/Alpha-Bêta.
5. Retourner le meilleur coup selon l'évaluation (ou fallback robuste).

## 6) Minimax + Alpha-Bêta (détails)

Fichier principal: `lib/game/ai_game_logic.dart`.

### 6.1 Minimax

- **Max node**: tour de l'IA -> maximiser le score.
- **Min node**: tour adverse -> minimiser le score.
- Condition d'arrêt:
  - profondeur = 0,
  - ou état terminal (victoire/défaite/bloquage).

### 6.2 Alpha-Bêta

- `alpha`: meilleure borne inférieure trouvée pour Max.
- `beta`: meilleure borne supérieure trouvée pour Min.
- Coupure:
  - si `alpha >= beta`, la branche restante est ignorée.

### 6.3 Ordonnancement des coups (move ordering)

Avant la récursion, les coups sont triés pour améliorer les coupures alpha-bêta:

- simulation rapide du coup,
- score heuristique immédiat,
- bonus contextuels (ex: contrôle du centre).

Plus l'ordre est bon, plus le nombre de nœuds explorés baisse.

### 6.4 Table de transposition (cache)

- Un cache mémorise les positions déjà évaluées.
- Clé = phase + joueur courant + statut + profondeur + positions des pièces triées.
- Si la même position réapparaît à profondeur compatible, le score est réutilisé.

Impact:

- évite de recalculer des sous-arbres identiques,
- accélère nettement les recherches sur ce petit jeu combinatoire.

## 7) Fonction d'évaluation

Deux fonctions principales:

- `evaluatePosition(...)` (standard)
- `evaluateAggressivePosition(...)` (plus offensive)

Critères pris en compte:

- Victoire / défaite immédiate.
- Blocage adverse / auto-blocage.
- Menaces de lignes (2 pions + 1 case vide).
- Potentiel de fourchettes.
- Mobilité (différence de coups légaux).
- Valeurs positionnelles (centre, coins, bords).
- Pression tactique sur les lignes gagnantes.

## 8) Rôle de `PatternRecognizer`

`lib/ai/pattern_recognizer.dart` fournit une couche tactique rapide utilisée par les IA:

- `findWinningMoves`: coups gagnants immédiats.
- `findThreatsToBlock`: cases critiques à défendre.
- `findForkMoves`: coups qui créent plusieurs menaces.

Ce module permet d'éviter de dépendre uniquement de la recherche profonde, donc améliore la robustesse pratique.

## 9) Différence Stratège vs Maître (concrète)

### Stratège

- Utilise Minimax depth plus faible.
- Défend et attaque correctement.
- Introduit parfois un 2e/3e meilleur coup pour rester jouable par humain.

### Maître

- Priorités tactiques strictes + recherche plus profonde.
- Évaluation agressive et plus punitive sur les erreurs adverses.
- Moins de compromis, plus de constance, plus dur à battre.

## 10) Choix du premier joueur (UX)

Après sélection `Stratège` ou `Maître`:

- Un popup demande: **qui commence ?**
- Le choix est transmis à `GamePage` via `aiStarts`.
- Si `aiStarts = true`, l'état initial met `currentPlayer = player2` et l'IA joue le premier coup automatiquement.

## 11) Pistes de tuning IA

Pour ajuster la difficulté sans changer l'architecture:

- Modifier `strategistDepth` et `masterDepth` dans `constants.dart`.
- Ajuster les poids d'évaluation (menaces, mobilité, centre, fourchettes).
- Ajuster l'imprécision du niveau Stratège.
- Ajouter des tests unitaires ciblés sur des positions tactiques connues.

---

Projet Flutter de Fanorona Telo, orienté gameplay rapide et IA explicable.
