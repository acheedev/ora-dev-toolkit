#!/bin/bash
# =============================================================================
# otk$rest — Oracle Wallet Setup for HTTPS
#
# Creates an Oracle wallet and imports the CA certificate that signed your
# target server's TLS certificate. Run this once per environment on the
# database server as the oracle OS user (or any user with write access to
# the wallet directory).
#
# Usage:
#   chmod +x setup_wallet.sh
#   ./setup_wallet.sh
#
# Prerequisites:
#   - orapki in PATH (ships with Oracle Database / Oracle Client)
#   - The CA certificate file for your target host (see STEP 2 notes below)
# =============================================================================

set -euo pipefail

# --- Configuration -----------------------------------------------------------
WALLET_DIR="/opt/oracle/wallets/rest"     # Directory to create the wallet in
WALLET_PWD="WalletPasswd123"              # Change this or use auto-login (see below)
CA_CERT="/tmp/ca.crt"                     # Path to the CA certificate to import
# -----------------------------------------------------------------------------

echo "=== otk\$rest wallet setup ==="
echo ""

# STEP 1 — Create wallet directory
echo "[1/4] Creating wallet directory: $WALLET_DIR"
mkdir -p "$WALLET_DIR"

# Create wallet with auto-login (cwallet.sso — no password needed at runtime)
# Use this unless your security policy requires a password-protected wallet.
orapki wallet create \
    -wallet "$WALLET_DIR" \
    -pwd "$WALLET_PWD" \
    -auto_login

echo "      Wallet created"
echo ""

# STEP 2 — Import the CA certificate
#
# How to get the CA cert for your target host:
#
#   Option A — Download from the server:
#     openssl s_client -connect api.ansible-tower.company.com:443 \
#         -showcerts </dev/null 2>/dev/null \
#         | openssl x509 -outform PEM > /tmp/ca.crt
#
#   Option B — Export from your browser:
#     Navigate to the HTTPS URL -> click the lock icon
#     -> Certificate -> Details -> Export (PEM format)
#
#   Option C — Use the system CA bundle (covers most public CAs):
#     On RHEL/CentOS: /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
#     On Ubuntu/Debian: /etc/ssl/certs/ca-certificates.crt
#     Note: orapki imports one cert at a time from a bundle — see below.
#
echo "[2/4] Importing CA certificate: $CA_CERT"

if [ ! -f "$CA_CERT" ]; then
    echo "ERROR: CA cert not found at $CA_CERT"
    echo "       See STEP 2 notes above to obtain the certificate"
    exit 1
fi

orapki wallet add \
    -wallet "$WALLET_DIR" \
    -trusted_cert \
    -cert "$CA_CERT" \
    -pwd "$WALLET_PWD"

echo "      Certificate imported"
echo ""

# STEP 3 — Verify wallet contents
echo "[3/4] Wallet contents:"
orapki wallet display -wallet "$WALLET_DIR"
echo ""

# STEP 4 — Set permissions (Oracle process must be able to read)
echo "[4/4] Setting permissions"
chmod 700 "$WALLET_DIR"
chmod 600 "$WALLET_DIR"/*
echo "      Done"
echo ""

echo "=== Setup complete ==="
echo ""
echo "Wallet path for otk\$rest.configure():"
echo "  p_wallet_path => 'file:$WALLET_DIR'"
echo ""
echo "For auto-login wallets (cwallet.sso), omit p_wallet_password."
echo "For password-protected wallets, pass p_wallet_password => '<password>'."
