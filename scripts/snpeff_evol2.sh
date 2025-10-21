#!/bin/bash
# ======================================================
# 🧬 SnpEff pipeline completo para análisis de EVOL2
# Incluye: creación de base de datos personalizada + anotación del VCF
# Compatible con entorno conda/micromamba
# ======================================================

set -euo pipefail

# ==== VARIABLES ====
BASE_DIR=$(pwd)                         # Directorio base del proyecto
SNPEFF_PATH=~/snpEff
GENOME_NAME=mi_ref
GENOME_LABEL="MiReferencia"
FASTA=$BASE_DIR/ensamblaje/spades/post/scaffolds.fasta
GFF=$BASE_DIR/prokka_resultados_general/anc_prokka_general.gff
INPUT_VCF=$BASE_DIR/variantes/evol2/evol2_filtrado.vcf.gz

# Carpeta donde guardar los resultados
RESULTS_DIR=$BASE_DIR/resultados_snpeff/evol2
mkdir -p "$RESULTS_DIR"

# Archivos de salida
OUTPUT_VCF=$RESULTS_DIR/evol2_snpeff.ann.vcf
REPORT_HTML=$RESULTS_DIR/evol2_snpeff_report.html
LOG_FILE=$RESULTS_DIR/snpeff_evol2.log

# ==== 0. VERIFICACIÓN DE snpEff ====
echo "🧪 Verificando instalación de SnpEff..."
if command -v snpEff &> /dev/null; then
    echo "✅ SnpEff detectado en el entorno: $(which snpEff)"
    SNPEFF_CMD="snpEff"
else
    echo "⚠️  No se encontró snpEff en el entorno. Se usará la versión local."
    SNPEFF_CMD="java -Xmx4g -jar $SNPEFF_PATH/snpEff.jar"
fi

# ==== 1. CREAR BASE DE DATOS PERSONALIZADA ====
echo "🧩 Reconstruyendo base de datos personalizada..."
rm -rf "$SNPEFF_PATH/data/$GENOME_NAME"
mkdir -p "$SNPEFF_PATH/data/$GENOME_NAME"

# Copiar archivos necesarios
cp "$BASE_DIR/prokka_resultados_general/genes.gff" "$SNPEFF_PATH/data/$GENOME_NAME/genes.gff"
cp "$BASE_DIR/prokka_resultados_general/protein.fa" "$SNPEFF_PATH/data/$GENOME_NAME/protein.fa"
cp "$BASE_DIR/prokka_resultados_general/cds.fa" "$SNPEFF_PATH/data/$GENOME_NAME/cds.fa"
cp "$BASE_DIR/ensamblaje/spades/post/scaffolds.fasta" "$SNPEFF_PATH/data/$GENOME_NAME/sequences.fa"

# ==== 2. CONFIGURAR GENOMA EN snpEff.config ====
CONFIG_FILE=$SNPEFF_PATH/snpEff.config

if ! grep -q "$GENOME_NAME.genome" "$CONFIG_FILE"; then
    echo "$GENOME_NAME.genome : $GENOME_LABEL" >> "$CONFIG_FILE"
    echo "✅ Línea de genoma añadida a snpEff.config"
else
    echo "ℹ️  El genoma $GENOME_NAME ya está configurado en snpEff.config"
fi  

# ==== 3. CONSTRUIR BASE DE DATOS ====
echo "🏗️  Construyendo base de datos con SnpEff..."
cd "$SNPEFF_PATH"
$SNPEFF_CMD build -gff3 -v -noCheckProtein -noCheckCds "$GENOME_NAME"

# Volver al directorio base antes de anotar
cd "$BASE_DIR"

# ==== 4. ANOTAR VARIANTES ====
echo "🔍 Ejecutando anotación con SnpEff..."
$SNPEFF_CMD -c "$SNPEFF_PATH/snpEff.config" -dataDir "$SNPEFF_PATH/data" -v "$GENOME_NAME" "$INPUT_VCF" > "$OUTPUT_VCF" 2> "$LOG_FILE"

# ==== 5. GENERAR REPORTE HTML ====
echo "📊 Generando reporte HTML..."
$SNPEFF_CMD -c "$SNPEFF_PATH/snpEff.config" -dataDir "$SNPEFF_PATH/data" -v -stats "$REPORT_HTML" "$GENOME_NAME" "$INPUT_VCF" >> "$LOG_FILE" 2>&1


# ==== 6. FINALIZAR ====
echo "✅ Análisis de EVOL2 completado."
echo "Resultados:"
echo " - Archivo anotado: $OUTPUT_VCF"
echo " - Reporte HTML: $REPORT_HTML"
echo " - Log: $LOG_FILE"
