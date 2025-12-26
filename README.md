fanorona telo by BlackRYE 


#visualisation sur python : 

import matplotlib.pyplot as plt
import numpy as np

def draw_neon_board(ax, positions, title=""):
    # Configuration du style "Néon"
    ax.set_facecolor('#020014') # Fond bleu très sombre (presque noir)
    line_color = '#0066FF'      # Bleu électrique pour la grille
    glow_pink = '#FF1493'       # Rose néon
    glow_blue = '#007FFF'       # Bleu néon

    # 1. Dessiner la grille (Fanorona Telo : 3x3 + diagonales)
    # Lignes horizontales et verticales
    for i in [0, 1, 2]:
        ax.plot([0, 2], [i, i], color=line_color, linewidth=1.5, alpha=0.8) # Horizontales
        ax.plot([i, i], [0, 2], color=line_color, linewidth=1.5, alpha=0.8) # Verticales

    # Diagonales
    ax.plot([0, 2], [0, 2], color=line_color, linewidth=1.5, alpha=0.8)
    ax.plot([0, 2], [2, 0], color=line_color, linewidth=1.5, alpha=0.8)

    # 2. Dessiner les pions avec effet de lueur (Glow)
    # positions est une liste de tuples (x, y, couleur)
    # x, y vont de 0 à 2. couleur : 'pink' ou 'blue'

    for x, y, color_type in positions:
        c = glow_pink if color_type == 'pink' else glow_blue

        # Effet de lueur (plusieurs cercles transparents superposés)
        ax.plot(x, y, 'o', color=c, markersize=35, alpha=0.1) # Grand halo
        ax.plot(x, y, 'o', color=c, markersize=25, alpha=0.3) # Halo moyen
        ax.plot(x, y, 'o', color=c, markersize=15, alpha=1.0) # Centre solide

    # Nettoyage du graphique
    ax.set_xlim(-0.2, 2.2)
    ax.set_ylim(-0.2, 2.2)
    ax.set_xticks([])
    ax.set_yticks([])
    ax.set_aspect('equal')

    # Titre (optionnel)
    # ax.set_title(title, color='white', fontsize=8, pad=10)

# Définition des étapes basées sur votre croquis (Gray -> Pink, Blue -> Blue)
# Coordonnées : (0,0) est en bas à gauche, (2,2) en haut à droite.

steps = [
    # Plateau vide initial
    [],
    # Ligne 1 du croquis
    [ # Étape 1: Init Rose (coin haut gauche)
      (0, 2, 'pink')
    ],
    [ # Étape 2: Rose haut gauche, Bleu haut milieu
      (0, 2, 'pink'), (1, 2, 'blue')
    ],
    [ # Étape 3: Rose haut gauche, Rose centre, Bleu haut milieu
      (0, 2, 'pink'), (1, 1, 'pink'), (1, 2, 'blue')
    ],
    [ # Étape 4: + Bleu bas droite
      (0, 2, 'pink'), (1, 1, 'pink'), (1, 2, 'blue'), (2, 0, 'blue')
    ],
    [ # Étape 5: + Rose bas gauche + Bleu bas milieu
      (0, 2, 'pink'), (1, 1, 'pink'), (0, 0, 'pink'),
      (1, 2, 'blue'), (2, 0, 'blue') # Note: croquis un peu flou ici
    ],

    # Ligne 2 du croquis
    [ # Étape 6: Tous les pions placés (Phase de déplacement commence)
      (0, 2, 'pink'), (0, 1, 'blue'), (0, 0, 'pink'),
      (1, 2, 'blue'), (1, 1, 'pink'), (2, 0, 'blue')
      # Interprétation approximative des positions du croquis
    ],
    [ # Étape 7
      (0, 2, 'pink'), (0, 1, 'blue'), (0, 0, 'pink'),
      (1, 2, 'blue'), (1, 0, 'pink'), (2, 0, 'blue')
    ],
    [ # Étape 8
      (0, 2, 'pink'), (1, 2, 'blue'), (0, 0, 'pink'),
      (1, 1, 'blue'), (1, 0, 'pink'), (2, 0, 'blue')
    ],
    [ # Étape 9
      (0, 1, 'pink'), (1, 2, 'blue'), (0, 0, 'pink'),
      (1, 1, 'blue'), (1, 0, 'pink'), (2, 0, 'blue')
    ],
    [ # Étape 10: Victoire Bleue (Diagonale ou ligne)
      (0, 1, 'pink'), (0, 2, 'blue'), (0, 0, 'pink'), # victoire dignostic
      (1, 1, 'blue'), (1, 0, 'pink'), (2, 0, 'blue')
    ]
]

# Création de la figure globale
fig = plt.figure(figsize=(15, 6), facecolor='#020014')

# Créer une grille de 2 lignes et 5 colonnes
for i, positions in enumerate(steps):
    ax = fig.add_subplot(2, 6, i + 1) # Changed to 2x6 grid for 11 steps
    draw_neon_board(ax, positions)

    # Ajouter des flèches entre les graphiques (sauf le dernier de chaque ligne et le tout dernier)
    if (i + 1) % 6 != 0 and i < len(steps) - 1:
        if i < 6: # First row
            fig.text((i % 6 + 1) * (1/6), 0.75, '→',
                     color='#0066FF', fontsize=20, ha='center', va='center')
        else: # Second row
            fig.text((i % 6 + 1) * (1/6), 0.25, '→',
                     color='#0066FF', fontsize=20, ha='center', va='center')

plt.tight_layout()
plt.show()



#build apk
flutter build apk --split-per-abi 

#build web
flutter build web --release
npx serve build/web