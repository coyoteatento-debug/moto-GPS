#!/bin/bash
# ══════════════════════════════════════════════════════════════
# generate_keystore.sh
# Genera el keystore de firma y lo codifica en base64
# para subirlo como GitHub Secret.
#
# USO:
#   chmod +x scripts/generate_keystore.sh
#   ./scripts/generate_keystore.sh
# ══════════════════════════════════════════════════════════════

set -e  # Detener si cualquier comando falla

echo ""
echo "═══════════════════════════════════════"
echo "  🔑 Generador de Keystore — MotoGPS"
echo "═══════════════════════════════════════"
echo ""

# ── Solicitar datos al usuario ──────────────────────────────
read -p "📛 Nombre de la app (ej: MotoGPS): " APP_NAME
read -p "🏢 Organización (ej: com.tuempresa): " ORGANIZATION
read -p "🔑 Alias de la clave (ej: motogps_key): " KEY_ALIAS
read -sp "🔒 Contraseña del keystore (mínimo 6 chars): " KEYSTORE_PASS
echo ""
read -sp "🔒 Contraseña de la clave (puede ser la misma): " KEY_PASS
echo ""
echo ""

# ── Directorios ─────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
KEYSTORE_PATH="$PROJECT_DIR/android/app/keystore.jks"
KEY_PROPS_PATH="$PROJECT_DIR/android/key.properties"

# ── Generar keystore con keytool ────────────────────────────
echo "🔧 Generando keystore..."
keytool -genkey -v \
  -keystore "$KEYSTORE_PATH" \
  -alias "$KEY_ALIAS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass "$KEYSTORE_PASS" \
  -keypass "$KEY_PASS" \
  -dname "CN=$APP_NAME, OU=Mobile, O=$ORGANIZATION, L=Mexico, S=Mexico, C=MX" \
  2>/dev/null

echo "✅ Keystore generado: $KEYSTORE_PATH"

# ── Crear key.properties local ──────────────────────────────
cat > "$KEY_PROPS_PATH" << EOF
storePassword=$KEYSTORE_PASS
keyPassword=$KEY_PASS
keyAlias=$KEY_ALIAS
storeFile=keystore.jks
EOF

echo "✅ key.properties creado: $KEY_PROPS_PATH"

# ── Codificar keystore en base64 ────────────────────────────
BASE64_OUTPUT="$SCRIPT_DIR/keystore_base64.txt"
base64 "$KEYSTORE_PATH" > "$BASE64_OUTPUT"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  ✅ KEYSTORE GENERADO EXITOSAMENTE"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "📋 AHORA AGREGA ESTOS SECRETS EN GITHUB:"
echo "   Repo → Settings → Secrets and variables → Actions → New secret"
echo ""
echo "  Secret 1: KEYSTORE_BASE64"
echo "  Valor: contenido del archivo: $BASE64_OUTPUT"
echo ""
echo "  Secret 2: KEYSTORE_PASSWORD"
echo "  Valor: $KEYSTORE_PASS"
echo ""
echo "  Secret 3: KEY_ALIAS"
echo "  Valor: $KEY_ALIAS"
echo ""
echo "  Secret 4: KEY_PASSWORD"
echo "  Valor: $KEY_PASS"
echo ""
echo "═══════════════════════════════════════════════════════"
echo ""
echo "⚠️  IMPORTANTE:"
echo "   - NUNCA subas keystore.jks ni key.properties a Git"
echo "   - Guarda el keystore en un lugar seguro (backup)"
echo "   - Si pierdes el keystore, NO podrás actualizar tu app en Play Store"
echo ""

# Verificar que .gitignore los ignora
if grep -q "keystore.jks" "$PROJECT_DIR/.gitignore" 2>/dev/null; then
    echo "✅ .gitignore ya protege keystore.jks y key.properties"
else
    echo "⚠️  Asegúrate de que .gitignore incluya keystore.jks y key.properties"
fi
