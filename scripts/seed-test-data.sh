#!/usr/bin/env bash
# =============================================================================
# scripts/seed-test-data.sh
# VEOSIF Dispatch — Test data seeder via REST API
#
# Usage:
#   bash scripts/seed-test-data.sh \
#     --url http://104.131.20.188:8000 \
#     --email contact@veosif.com \
#     --password YOURPASSWORD
#
# What it creates:
#   - 3 Drivers
#   - 3 Vehicles (asiyen ak chofè)
#   - 3 Customers (contacts)
#   - 3 Places (adrès)
#   - 3 Orders (pending, dispatched, completed)
#
# Requirements: curl, jq
# =============================================================================
set -euo pipefail

# ─── Couleur pou output ───────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✔${NC}  $*"; }
err()  { echo -e "${RED}✖${NC}  $*" >&2; }
info() { echo -e "${BLUE}→${NC}  $*"; }
warn() { echo -e "${YELLOW}⚠${NC}  $*"; }

# ─── Parse arguments ─────────────────────────────────────────────────────────
API_URL=""
EMAIL=""
PASSWORD=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --url)      API_URL="$2";    shift 2 ;;
        --email)    EMAIL="$2";      shift 2 ;;
        --password) PASSWORD="$2";   shift 2 ;;
        *) err "Opsyon enkoni: $1"; exit 1 ;;
    esac
done

# ─── Validasyon ──────────────────────────────────────────────────────────────
if [[ -z "$API_URL" || -z "$EMAIL" || -z "$PASSWORD" ]]; then
    err "Itilizasyon: $0 --url <URL> --email <EMAIL> --password <PASSWORD>"
    err "Egzanp: $0 --url http://104.131.20.188:8000 --email contact@veosif.com --password Secret123"
    exit 1
fi

command -v curl >/dev/null 2>&1 || { err "curl pa enstale"; exit 1; }
command -v jq   >/dev/null 2>&1 || { err "jq pa enstale. Enstale l ak: apt install jq"; exit 1; }

BASE="${API_URL}/int/v1"

echo ""
echo "========================================"
echo "  VEOSIF Dispatch — Test Data Seeder"
echo "========================================"
echo "  API: ${API_URL}"
echo "  User: ${EMAIL}"
echo "========================================"
echo ""

# ─── Fonksyon pou rele API ────────────────────────────────────────────────────
api_post() {
    local endpoint="$1"
    local data="$2"
    local token="${3:-}"
    local auth_header=""

    if [[ -n "$token" ]]; then
        auth_header="-H \"Authorization: Bearer ${token}\""
    fi

    curl -s -X POST \
        "${BASE}/${endpoint}" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        ${token:+-H "Authorization: Bearer ${token}"} \
        -d "$data"
}

api_patch() {
    local endpoint="$1"
    local data="$2"
    local token="$3"

    curl -s -X PATCH \
        "${BASE}/${endpoint}" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -H "Authorization: Bearer ${token}" \
        -d "$data"
}

extract() {
    echo "$1" | jq -r "$2" 2>/dev/null
}

# ─── ETAP 1: Login ────────────────────────────────────────────────────────────
info "Koneksyon ak ${EMAIL}..."

LOGIN_RESP=$(api_post "auth/sign-in" "{\"identity\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}")
TOKEN=$(extract "$LOGIN_RESP" '.token // .data.token // empty')

if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
    err "Login echwe. Verifye email/modpas ou."
    err "Repons: $LOGIN_RESP"
    exit 1
fi

ok "Login reyisi. Token jwenn."
echo ""

# ─── ETAP 2: Kreye 3 Drivers ─────────────────────────────────────────────────
info "Kreyasyon Drivers..."

declare -A DRIVER_UUIDS

create_driver() {
    local name="$1"
    local phone="$2"
    local email="$3"

    local payload
    payload=$(jq -n \
        --arg name "$name" \
        --arg phone "$phone" \
        --arg email "$email" \
        '{driver: {name: $name, phone: $phone, email: $email, status: "active"}}')

    local resp
    resp=$(api_post "fleet-ops/drivers" "$payload" "$TOKEN")

    local uuid
    uuid=$(extract "$resp" '.driver.uuid // .data.uuid // empty')

    if [[ -z "$uuid" || "$uuid" == "null" ]]; then
        warn "Driver '${name}' pa kreye. Repons: $resp"
        echo ""
    else
        ok "Driver kreye: ${name} (uuid: ${uuid})"
        echo "$uuid"
    fi
}

D1_UUID=$(create_driver "Pierre Jean"   "+50912000001" "pierre@veosif-test.com")
D2_UUID=$(create_driver "Marie Joseph"  "+50912000002" "marie@veosif-test.com")
D3_UUID=$(create_driver "Paul André"    "+50912000003" "paul@veosif-test.com")

echo ""

# ─── ETAP 3: Kreye 3 Vehicles ────────────────────────────────────────────────
info "Kreyasyon Vehicles..."

create_vehicle() {
    local name="$1"
    local type="$2"
    local plate="$3"
    local driver_uuid="$4"

    local payload
    if [[ -n "$driver_uuid" && "$driver_uuid" != "" ]]; then
        payload=$(jq -n \
            --arg name "$name" \
            --arg type "$type" \
            --arg plate "$plate" \
            --arg driver_uuid "$driver_uuid" \
            '{vehicle: {display_name: $name, trim: $type, plate_number: $plate, driver_uuid: $driver_uuid, status: "active"}}')
    else
        payload=$(jq -n \
            --arg name "$name" \
            --arg type "$type" \
            --arg plate "$plate" \
            '{vehicle: {display_name: $name, trim: $type, plate_number: $plate, status: "active"}}')
    fi

    local resp
    resp=$(api_post "fleet-ops/vehicles" "$payload" "$TOKEN")

    local uuid
    uuid=$(extract "$resp" '.vehicle.uuid // .data.uuid // empty')

    if [[ -z "$uuid" || "$uuid" == "null" ]]; then
        warn "Vehicle '${name}' pa kreye. Repons: $resp"
        echo ""
    else
        ok "Vehicle kreye: ${name} / ${plate} (uuid: ${uuid})"
        echo "$uuid"
    fi
}

V1_UUID=$(create_vehicle "Moto-001"  "Motorcycle" "AA-1001" "$D1_UUID")
V2_UUID=$(create_vehicle "Car-001"   "Sedan"      "AA-1002" "$D2_UUID")
V3_UUID=$(create_vehicle "Truck-001" "Truck"      "AA-1003" "$D3_UUID")

echo ""

# ─── ETAP 4: Kreye 3 Places (adrès) ─────────────────────────────────────────
info "Kreyasyon Places (adrès)..."

create_place() {
    local name="$1"
    local street="$2"
    local city="$3"

    local payload
    payload=$(jq -n \
        --arg name "$name" \
        --arg street "$street" \
        --arg city "$city" \
        '{place: {name: $name, street1: $street, city: $city, country: "HT"}}')

    local resp
    resp=$(api_post "fleet-ops/places" "$payload" "$TOKEN")

    local uuid
    uuid=$(extract "$resp" '.place.uuid // .data.uuid // empty')

    if [[ -z "$uuid" || "$uuid" == "null" ]]; then
        warn "Place '${name}' pa kreye. Repons: $resp"
        echo ""
    else
        ok "Place kreye: ${name} — ${street}, ${city} (uuid: ${uuid})"
        echo "$uuid"
    fi
}

P1_UUID=$(create_place "Depot VEOSIF"          "10 Rue du Centre"       "Port-au-Prince")
P2_UUID=$(create_place "Kliyan Bòs André"      "25 Blvd Toussaint"      "Port-au-Prince")
P3_UUID=$(create_place "Kliyan Madame Claire"  "45 Rue Capois"          "Pétionville")
P4_UUID=$(create_place "Kliyan Monsieur Remy"  "12 Avenue John Brown"   "Delmas")

echo ""

# ─── ETAP 5: Kreye 3 Contacts (kliyan) ───────────────────────────────────────
info "Kreyasyon Contacts (kliyan)..."

create_contact() {
    local name="$1"
    local phone="$2"
    local email="$3"
    local place_uuid="$4"

    local payload
    payload=$(jq -n \
        --arg name "$name" \
        --arg phone "$phone" \
        --arg email "$email" \
        --arg place_uuid "$place_uuid" \
        '{contact: {name: $name, phone: $phone, email: $email, type: "customer", place_uuid: $place_uuid}}')

    local resp
    resp=$(api_post "fleet-ops/contacts" "$payload" "$TOKEN")

    local uuid
    uuid=$(extract "$resp" '.contact.uuid // .data.uuid // empty')

    if [[ -z "$uuid" || "$uuid" == "null" ]]; then
        warn "Contact '${name}' pa kreye. Repons: $resp"
        echo ""
    else
        ok "Contact kreye: ${name} / ${phone} (uuid: ${uuid})"
        echo "$uuid"
    fi
}

C1_UUID=$(create_contact "Bòs André"       "+50913000001" "andre@veosif-test.com"  "$P2_UUID")
C2_UUID=$(create_contact "Madame Claire"   "+50913000002" "claire@veosif-test.com" "$P3_UUID")
C3_UUID=$(create_contact "Monsieur Remy"   "+50913000003" "remy@veosif-test.com"   "$P4_UUID")

echo ""

# ─── ETAP 6: Kreye 3 Orders ───────────────────────────────────────────────────
info "Kreyasyon Orders..."

create_order() {
    local label="$1"
    local pickup_uuid="$2"
    local dropoff_uuid="$3"
    local driver_uuid="$4"
    local status="$5"

    local payload
    payload=$(jq -n \
        --arg pickup "$pickup_uuid" \
        --arg dropoff "$dropoff_uuid" \
        --arg driver "$driver_uuid" \
        --arg status "$status" \
        '{
            order: {
                status: $status,
                driver_assigned_uuid: (if $driver == "" then null else $driver end),
                payload: {
                    pickup_uuid: $pickup,
                    dropoff_uuid: $dropoff
                }
            }
        }')

    local resp
    resp=$(api_post "fleet-ops/orders" "$payload" "$TOKEN")

    local uuid
    uuid=$(extract "$resp" '.order.uuid // .data.uuid // empty')
    local public_id
    public_id=$(extract "$resp" '.order.public_id // .data.public_id // empty')

    if [[ -z "$uuid" || "$uuid" == "null" ]]; then
        warn "Order '${label}' pa kreye. Repons: $resp"
        echo ""
    else
        ok "Order kreye: ${label} — ${public_id:-$uuid} (status: ${status})"
        echo "$uuid"
    fi
}

O1_UUID=$(create_order "Order-Pending (pa asiyen)"      "$P1_UUID" "$P2_UUID" ""         "pending")
O2_UUID=$(create_order "Order-Dispatched (Pierre)"      "$P1_UUID" "$P3_UUID" "$D1_UUID" "dispatched")
O3_UUID=$(create_order "Order-Completed (Marie)"        "$P1_UUID" "$P4_UUID" "$D2_UUID" "completed")

echo ""

# ─── REZIME FINAL ─────────────────────────────────────────────────────────────
echo "========================================"
echo "  Rezime Done Tès"
echo "========================================"
echo ""
echo "  DRIVERS:"
[[ -n "$D1_UUID" ]] && echo "    Pierre Jean   → ${D1_UUID}"  || echo "    Pierre Jean   → ECHWE"
[[ -n "$D2_UUID" ]] && echo "    Marie Joseph  → ${D2_UUID}"  || echo "    Marie Joseph  → ECHWE"
[[ -n "$D3_UUID" ]] && echo "    Paul André    → ${D3_UUID}"  || echo "    Paul André    → ECHWE"
echo ""
echo "  VEHICLES:"
[[ -n "$V1_UUID" ]] && echo "    Moto-001  (Pierre) → ${V1_UUID}"  || echo "    Moto-001  → ECHWE"
[[ -n "$V2_UUID" ]] && echo "    Car-001   (Marie)  → ${V2_UUID}"  || echo "    Car-001   → ECHWE"
[[ -n "$V3_UUID" ]] && echo "    Truck-001 (Paul)   → ${V3_UUID}"  || echo "    Truck-001 → ECHWE"
echo ""
echo "  PLACES:"
[[ -n "$P1_UUID" ]] && echo "    Depot VEOSIF         → ${P1_UUID}" || echo "    Depot VEOSIF → ECHWE"
[[ -n "$P2_UUID" ]] && echo "    Bòs André (livrezon) → ${P2_UUID}" || echo "    Bòs André → ECHWE"
[[ -n "$P3_UUID" ]] && echo "    Madame Claire        → ${P3_UUID}" || echo "    Madame Claire → ECHWE"
[[ -n "$P4_UUID" ]] && echo "    Monsieur Remy        → ${P4_UUID}" || echo "    Monsieur Remy → ECHWE"
echo ""
echo "  CONTACTS:"
[[ -n "$C1_UUID" ]] && echo "    Bòs André     → ${C1_UUID}" || echo "    Bòs André → ECHWE"
[[ -n "$C2_UUID" ]] && echo "    Madame Claire → ${C2_UUID}" || echo "    Madame Claire → ECHWE"
[[ -n "$C3_UUID" ]] && echo "    Monsieur Remy → ${C3_UUID}" || echo "    Monsieur Remy → ECHWE"
echo ""
echo "  ORDERS:"
[[ -n "$O1_UUID" ]] && echo "    Order-001 Pending    → ${O1_UUID}" || echo "    Order-001 → ECHWE"
[[ -n "$O2_UUID" ]] && echo "    Order-002 Dispatched → ${O2_UUID}" || echo "    Order-002 → ECHWE"
[[ -n "$O3_UUID" ]] && echo "    Order-003 Completed  → ${O3_UUID}" || echo "    Order-003 → ECHWE"
echo ""
echo "========================================"
echo "  Verifye done yo nan konsole a:"
echo "  http://104.131.20.188:4200"
echo "========================================"
echo ""
