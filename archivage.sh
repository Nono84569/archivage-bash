#!/bin/bash

# ───────────────
# Déplacement sécurisé du /home vers /archives si inactif de +1an (keep hiérarchisation des dossiers/fichiers)
# Auteur : Noay  
# Date : 21/05/2025
# ───────────────

#Répertoire à analyser
SOURCE_BASE="/home"

#Répertoire de destination
ARCHIVE_BASE="/home/partage/archives"

#Liste des fichiers à archiver
LISTE_FICHIERS="/tmp/liste_archivage.txt"

#Fichier de log
LOG="/var/log/archivage.log"

#Fichiers non modifiés depuis AGE
AGE="+365"


echo "[$(date)] Début de l'archivage" | tee -a "$LOG"

#Vérification du montage de la destination
if ! mountpoint -q "$ARCHIVE_BASE"; then
    echo "Erreur: le disque d'archivage n'est pas monté" | tee -a "$LOG" >&2
    exit 1
fi

#Vérification de si rsync est installé
if ! command -v rsync > /dev/null 2>&1; then
    echo "Erreur : rsync n'est pas installé !" | tee -a "$LOG" >&2
    exit 1
fi

#1. Génération de la liste des fichiers
echo "[$(date)] Génération de la liste des fichiers à archiver..." | tee -a "$LOG"

#Exclure le répertoire d'archivage
#Seulement les fichiers, modifiés depuis + de AGE, sans les fichiers cachés
#Affiche les chemins et les enregistre dans le fichier de liste temporaire
find "$SOURCE_BASE" \
  -path "$ARCHIVE_BASE" -prune -o \
  -type f -mtime "$AGE" -not -regex '.*/\..*' \
  -print > "$LISTE_FICHIERS"

#Si liste nulle alors exit success
if [ ! -s "$LISTE_FICHIERS" ]; then
    echo "[$(date)] Aucun fichier à déplacer." | tee -a "$LOG"
    exit 0
fi

echo "[$(date)] $(wc -l < "$LISTE_FICHIERS") fichiers trouvés." | tee -a "$LOG"

#2. Copie avec rsync + log
echo "[$(date)] Début de la copie avec rsync..." | tee -a "$LOG"

#Boucle avec IFS (pour les espaces)
while IFS= read -r filepath; do
    #Création du chemin relatif
    relative_path="${filepath#$SOURCE_BASE/}"
    #Reconstitution du chemin de destination
    dest_path="$ARCHIVE_BASE/$relative_path"
    dest_dir="$(dirname "$dest_path")"
    
    #Création du répertoire de destination potentiel
    mkdir -pv "$dest_dir" | tee -a "$LOG"

    #Copie ET VERIFICATION du fichier avec rsync puis suppression de la source
    if rsync -av --progress "$filepath" "$dest_path" >> "$LOG" 2>&1; then
        echo "[$(date)] Copie réussie : $filepath vers $dest_path"| tee -a "$LOG"
        # Suppression immédiate après copie réussie
        if rm -v "$filepath" >> "$LOG" 2>&1; then
            echo "[$(date)] Suppression réussie : $filepath" | tee -a "$LOG"
        else
            echo "[$(date)] Erreur suppression : $filepath" | tee -a "$LOG" >&2
        fi
    else
        echo "[$(date)] Erreur copie, fichier non supprimé : $filepath" | tee -a "$LOG" >&2
    fi
done < "$LISTE_FICHIERS"

echo "[$(date)] Archivage terminé." | tee -a "$LOG"
