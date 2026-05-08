#!/bin/bash
# Aktualizuje plik dashboard.json — używany przez _encrypt.sh do publikacji eventów checkpointów.
# Narzędzie maintainera (prowadzącego) — uruchamiane przed warsztatem, żeby ustawić nazwę projektu trackingu,
# i po warsztacie, żeby wyłączyć publikację (wartość "disabled").
# Użycie: ./checkpoints/cf_project_change.sh <CF_NAZWA_PROJEKTU>
#         ./checkpoints/cf_project_change.sh disabled    # tryb post-warsztat

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_FILE="${SCRIPT_DIR}/dashboard.json"

CF_NAZWA_PROJEKTU="$1"

# Usuń nawiasy klamrowe jeśli wpisano {bielik-test} zamiast bielik-test
CF_NAZWA_PROJEKTU="${CF_NAZWA_PROJEKTU#\{}"
CF_NAZWA_PROJEKTU="${CF_NAZWA_PROJEKTU%\}}"

if [ -z "$CF_NAZWA_PROJEKTU" ]; then
    echo "Blad: brak argumentu."
    echo "Uzycie: $0 <CF_NAZWA_PROJEKTU>"
    echo "Przyklady:"
    echo "  $0 bielik-warsztat-prowadzacy   # przed warsztatem"
    echo "  $0 disabled                     # po warsztacie (wylacza publikacje)"
    exit 1
fi

cat > "$DASHBOARD_FILE" <<EOF
{
  "tracking_project": "${CF_NAZWA_PROJEKTU}"
}
EOF

echo "OK: dashboard.json zaktualizowany — tracking_project = ${CF_NAZWA_PROJEKTU}"
