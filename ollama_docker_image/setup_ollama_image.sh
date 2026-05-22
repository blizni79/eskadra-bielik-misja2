#!/bin/bash
# Tworzenie repozytorium Artifact Registry i budowanie obrazu Docker z Ollama.
#
# Skrypt wykonuje kolejno:
#   1. Tworzenie repozytorium w Artifact Registry
#   2. Budowanie i publikowanie dedykowanego obrazu Docker z Ollama
#
# Wymagania: uruchomiony wcześniej `source setup_env.sh` w katalogu głównym projektu.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Przygotowanie obrazu Ollama ==="
echo ""

echo "--- Krok 1/2: Tworzenie repozytorium w Artifact Registry ---"
if gcloud artifacts repositories describe "$OLLAMA_REPO_NAME" \
        --location="$REGION" \
        --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "Repozytorium '$OLLAMA_REPO_NAME' już istnieje w regionie '$REGION' — pomijam tworzenie."
else
    "$SCRIPT_DIR/create_ollama_repo.sh"
fi
echo ""

echo "--- Krok 2/2: Budowanie i publikowanie obrazu Docker ---"
"$SCRIPT_DIR/create_ollama_image.sh"
echo ""

echo "=== Obraz Ollama został zbudowany i opublikowany pomyślnie ==="
