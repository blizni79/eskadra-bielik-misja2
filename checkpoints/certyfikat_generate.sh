#!/bin/bash
# Certyfikat ukończenia warsztatu — Eskadra Bielik Misja 2
# Weryfikuje obecność wszystkich checkpointów i generuje finalny artefakt certyfikatu
set -euo pipefail
source "$(dirname "$0")/_encrypt.sh"

printf "%s" "$_C_CYAN"
_print_separator
echo " CERTYFIKAT UKOŃCZENIA — Eskadra Bielik Misja 2"
echo " RAG w oparciu o model Bielik i Google Cloud"
_print_separator
printf "%s" "$_C_RESET"

PROJECT_ID=$(gcloud config get-value project 2>/dev/null | tr -d '[:space:]')
ACCOUNT=$(gcloud config get-value account 2>/dev/null | tr -d '[:space:]')
REGION="${REGION:-europe-west1}"
CERT_DIR="$(cd "$(dirname "$0")/.." && pwd)/cert_artifacts"
ERRORS=0
MISSING_CHECKPOINTS=""

if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "(unset)" ]; then
    echo "BŁĄD: Brak skonfigurowanego projektu. Uruchom: source setup_env.sh"
    exit 1
fi

# --- Weryfikacja obecności wszystkich checkpointów ---
echo ""
echo "Weryfikacja checkpointów:"
for i in 1 2 3 4 5 6 7 8; do
    CHECKPOINT_FILE="${CERT_DIR}/checkpoint_${i}.enc"
    if [ -f "$CHECKPOINT_FILE" ]; then
        FILE_SIZE=$(wc -c < "$CHECKPOINT_FILE" | tr -d ' ')
        FILE_MTIME=$(date -r "$CHECKPOINT_FILE" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
                     stat -c "%y" "$CHECKPOINT_FILE" 2>/dev/null | cut -d'.' -f1 | tr ' ' 'T' || echo "UNKNOWN")
        _print_ok "Checkpoint $i — obecny (${FILE_SIZE} bajtów, zapisany: $FILE_MTIME)"
    else
        _print_fail "Checkpoint $i — BRAK pliku checkpoint_${i}.enc"
        MISSING_CHECKPOINTS="${MISSING_CHECKPOINTS} $i"
        ERRORS=$((ERRORS+1))
    fi
done

if [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo "  Brakujące checkpointy:${MISSING_CHECKPOINTS}"
    echo "  Uruchom odpowiednie skrypty:"
    for i in $MISSING_CHECKPOINTS; do
        echo "    ./checkpoints/checkpoint_${i}.sh"
    done
    echo ""
    _print_separator
    echo " Certyfikat nie może być wygenerowany — wykonaj brakujące kroki."
    _print_separator
    exit 1
fi

# --- Pobranie danych uczestnika do certyfikatu ---
_validate_email() {
    local e="$1"
    if echo "$e" | grep -q '[[:space:]]'; then
        return 1
    fi
    if ! echo "$e" | grep -Eq '^.+@.+\..+$'; then
        return 1
    fi
    return 0
}

_trim() {
    echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

echo ""
_print_separator
echo " Dane uczestnika do certyfikatu"
_print_separator
echo " (wpisz 'q' w dowolnym polu, aby zrezygnowac)"

PARTICIPANT_CONFIRMED=""
while [ -z "$PARTICIPANT_CONFIRMED" ]; do
    echo ""
    while true; do
        read -r -p "  Imie       : " FIRST_NAME
        [ "$FIRST_NAME" = "q" ] && { echo "Anulowano."; exit 1; }
        FIRST_NAME=$(_trim "$FIRST_NAME")
        [ -n "$FIRST_NAME" ] && break
        echo "    Imie nie moze byc puste."
    done

    while true; do
        read -r -p "  Nazwisko   : " LAST_NAME
        [ "$LAST_NAME" = "q" ] && { echo "Anulowano."; exit 1; }
        LAST_NAME=$(_trim "$LAST_NAME")
        [ -n "$LAST_NAME" ] && break
        echo "    Nazwisko nie moze byc puste."
    done

    while true; do
        read -r -p "  E-mail     : " EMAIL1
        [ "$EMAIL1" = "q" ] && { echo "Anulowano."; exit 1; }
        if ! _validate_email "$EMAIL1"; then
            echo "    Niepoprawny format (oczekiwano: nazwa@domena.tld, bez spacji)."
            continue
        fi
        read -r -p "  E-mail (potwierdzenie): " EMAIL2
        [ "$EMAIL2" = "q" ] && { echo "Anulowano."; exit 1; }
        if ! _validate_email "$EMAIL2"; then
            echo "    Niepoprawny format (oczekiwano: nazwa@domena.tld, bez spacji)."
            continue
        fi
        EMAIL1_NORM=$(echo "$EMAIL1" | tr '[:upper:]' '[:lower:]')
        EMAIL2_NORM=$(echo "$EMAIL2" | tr '[:upper:]' '[:lower:]')
        if [ "$EMAIL1_NORM" != "$EMAIL2_NORM" ]; then
            echo "    Adresy roznia sie - wpisz oba ponownie."
            continue
        fi
        EMAIL="$EMAIL1_NORM"
        break
    done

    echo ""
    echo "  Dane do certyfikatu:"
    echo "    Imie     : $FIRST_NAME"
    echo "    Nazwisko : $LAST_NAME"
    echo "    E-mail   : $EMAIL"
    echo ""
    read -r -p "  Czy dane sa poprawne? [t/n/q]: " CONFIRM
    case "$CONFIRM" in
        q|Q) echo "Anulowano."; exit 1 ;;
        t|T) PARTICIPANT_CONFIRMED="yes" ;;
        *)   echo "  Wpisz dane ponownie." ;;
    esac
done

# --- Zbieranie sum kontrolnych checkpointów ---
echo ""
echo "Sumy kontrolne artefaktów:"
CHECKPOINT_HASHES=""
for i in 1 2 3 4 5 6 7 8; do
    CHECKPOINT_FILE="${CERT_DIR}/checkpoint_${i}.enc"
    FILE_HASH=$(sha256sum "$CHECKPOINT_FILE" | awk '{print $1}')
    echo "  checkpoint_${i}: ${FILE_HASH:0:16}..."
    CHECKPOINT_HASHES="${CHECKPOINT_HASHES}checkpoint_${i}=${FILE_HASH}\n"
done

# --- Generowanie certyfikatu ---
CERT_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

CONTENT="CERTYFIKAT_UKONCZENIA_WARSZTATU
project_id=${PROJECT_ID}
account=${ACCOUNT}
region=${REGION}
completion_timestamp=${CERT_TIMESTAMP}
participant_first_name=${FIRST_NAME}
participant_last_name=${LAST_NAME}
participant_email=${EMAIL}
all_checkpoints_present=TRUE
checkpoint_hashes:
$(echo -e "$CHECKPOINT_HASHES")
verification=PASSED_ALL_8_CHECKPOINTS"

echo ""
printf "%s%s\n" "$_C_BOLD" "$_C_YELLOW"
cat <<'GRATULACJE'
 ██████╗ ██████╗  █████╗ ████████╗██╗   ██╗██╗      █████╗  ██████╗     ██╗███████╗
██╔════╝ ██╔══██╗██╔══██╗╚══██╔══╝██║   ██║██║     ██╔══██╗██╔════╝     ██║██╔════╝
██║  ███╗██████╔╝███████║   ██║   ██║   ██║██║     ███████║██║          ██║█████╗
██║   ██║██╔══██╗██╔══██║   ██║   ██║   ██║██║     ██╔══██║██║     ██   ██║██╔══╝
╚██████╔╝██║  ██║██║  ██║   ██║   ╚██████╔╝███████╗██║  ██║╚██████╗╚█████╔╝███████╗
 ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚════╝ ╚══════╝
GRATULACJE
printf "%s\n" "$_C_RESET"
_print_separator
echo " Generowanie zaszyfrowanego certyfikatu..."

# Zapisz certyfikat (bez wywolania _checkpoint_save bo to nie jest checkpoint 1-8)
KEY=$(echo -n "${_HEADER_TEXT}|${PROJECT_ID}|${ACCOUNT}" | sha512sum | awk '{print $1}')
CERT_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
ENCRYPTED=$(echo "$CONTENT" | openssl enc -aes-256-cbc -pbkdf2 -iter 100000 \
    -pass "pass:${KEY}" -base64 2>/dev/null)
cat > "${CERT_DIR}/checkpoint_certyfikat.enc" <<ARTIFACT
PROJECT_ID: ${PROJECT_ID}
ACCOUNT: ${ACCOUNT}
FIRST_NAME: ${FIRST_NAME}
LAST_NAME: ${LAST_NAME}
EMAIL: ${EMAIL}
CHECKPOINT: certyfikat
TIMESTAMP: ${CERT_TIMESTAMP}
---BEGIN ENCRYPTED---
${ENCRYPTED}
---END ENCRYPTED---
ARTIFACT

# --- Publikacja danych certyfikatu do prowadzacego (fail-silent) ---
# Nie blokuje wygenerowania pliku lokalnie — w razie bledu uczestnik wysle .enc mailem.
CERT_PUBLISH_STATUS="DISABLED"
TRACKING_PROJECT=""
if [ -f "$_CHECKPOINT_DASHBOARD_FILE" ]; then
    TRACKING_PROJECT=$(awk -F'"' '/"tracking_project"/ {print $4}' "$_CHECKPOINT_DASHBOARD_FILE")
fi
if [ -n "$TRACKING_PROJECT" ] && [ "$TRACKING_PROJECT" != "disabled" ]; then
    CERT_PUBLISH_STATUS="FAILED"
    if CERT_MESSAGE=$(python3 -c '
import json, sys
print(json.dumps({
    "message_type": "certificate_request",
    "account":      sys.argv[1],
    "project_id":   sys.argv[2],
    "first_name":   sys.argv[3],
    "last_name":    sys.argv[4],
    "email":        sys.argv[5],
}))
' "$ACCOUNT" "$PROJECT_ID" "$FIRST_NAME" "$LAST_NAME" "$EMAIL" 2>/dev/null) \
       && gcloud pubsub topics publish \
            "projects/${TRACKING_PROJECT}/topics/checkpoint-events" \
            --message="$CERT_MESSAGE" --quiet >/dev/null 2>&1; then
        CERT_PUBLISH_STATUS="SENT"
    fi
fi

EARNED=$(_get_earned_points)
BAR=$(_draw_progress_bar "$EARNED" "$_TOTAL_POINTS")

echo ""
printf "%s%s" "$_C_BOLD" "$_C_MAGENTA"
echo "======================================================"
echo "      WARSZTAT ESKADRA BIELIK - MISJA 2"
echo "          UKONCZONY POMYSLNIE!"
echo "======================================================"
printf "%s\n" "$_C_RESET"
echo ""
echo "  Uczestnik : $ACCOUNT"
echo "  Projekt   : $PROJECT_ID"
echo "  Czas      : $CERT_TIMESTAMP"
case "$CERT_PUBLISH_STATUS" in
    SENT)     echo "  Dane certyfikatu: wyslane do prowadzacego" ;;
    FAILED)   echo "  Dane certyfikatu: wysylka nieudana - dolacz plik .enc do maila" ;;
    DISABLED) echo "  Dane certyfikatu: tryb offline - dolacz plik .enc do maila" ;;
esac
echo ""
printf "  Wynik: %d / %d pkt\n" "$EARNED" "$_TOTAL_POINTS"
printf "  [%s] 100%%\n" "$BAR"
echo ""
echo "  Checkpointy zaliczone: 8 / 8"
for i in 1 2 3 4 5 6 7 8; do
    pts="${_CHECKPOINT_POINTS[$i]}"
    lbl="${_CHECKPOINT_LABELS[$i]}"
    printf "  [OK]  Krok %d  +%2d pkt  %s\n" "$i" "$pts" "$lbl"
done
echo ""
echo "======================================================"
echo "  Pobierz certyfikat na swoj komputer:"
echo "  cloudshell dl cert_artifacts/checkpoint_certyfikat.enc"
echo ""
echo "  Nastepnie wyslij plik prowadzacemu."
echo "======================================================"

echo ""
printf "%s" "$_C_CYAN"
cat <<'ROCKET'
       *  .  *      *   .    *  .  *      *    *
   .       .             .       *      .        *
              .               *  .         .
       .  *           *      *      *       .     *
                     ____            *
                    /|  |\
                   / |EB| \             .   *
                  /  |  |  \      *
                 /___|__|___\           *  .
                  |        |          .
                  | MISJA  |     *
                  |   2    |   .
                  |        |        *
                  |________|     .
                  /|      |\
                 / |      | \
                /  |      |  \
               /___|______|___\
                  /|      |\
                 / |      | \
                  ▲▲▲▲▲▲▲▲▲
                   ▲▲▲▲▲▲
                    ▲▲▲▲
                     ▲▲
                      ▲
ROCKET
printf "%s\n" "$_C_RESET"
echo ""
printf "%s%s" "$_C_BOLD" "$_C_MAGENTA"
echo "         ESKADRA BIELIK - MISJA 2 - UKONCZONA!"
echo "       Suwerenne AI po polsku - Bielik + Google Cloud"
printf "%s\n" "$_C_RESET"
echo ""
