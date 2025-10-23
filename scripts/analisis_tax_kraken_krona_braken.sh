#!/bin/bash
# ============================================================
#  Pipeline de análisis taxonómico con Kraken2 + Krona + Bracken
#  Autor: Mateo Pulgarín
#  Proyecto: Proyecto Integrador - Bioinformática
#  Versión: 3.7 (Krona con versión detallada por lectura)
# ============================================================

set -euo pipefail  # Detener si ocurre un error o si falta una variable

# ---------- CONFIGURACIÓN DE RUTAS ----------
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IN_DIR="$BASE_DIR/fastq_unmapped"
OUT_DIR="$BASE_DIR/kraken2_results"
DB_DIR="$BASE_DIR/kraken2_db"
DB_PATH="$DB_DIR/minikraken2_v1_8GB"
KRONA_TAX_DIR="$BASE_DIR/taxonomy"

# Crear carpetas si no existen
mkdir -p "$OUT_DIR" "$DB_DIR" "$KRONA_TAX_DIR"

# ---------- 0. DESCARGA AUTOMÁTICA DE LA BASE DE DATOS ----------
echo "🌐 Verificando existencia de la base de datos Minikraken2 v1 (8GB)..."
cd "$DB_DIR"

if [ ! -f "$DB_PATH/taxo.k2d" ]; then
    echo "📦 Base de datos no encontrada. Iniciando descarga..."
    wget -c https://genome-idx.s3.amazonaws.com/kraken/minikraken2_v1_8GB_201904.tgz -O minikraken2_v1_8GB.tgz
    echo "📂 Descomprimiendo la base de datos (esto puede tardar unos minutos)..."
    tar -xvzf minikraken2_v1_8GB.tgz
    echo "🧹 Limpiando archivos temporales..."
    rm -f minikraken2_v1_8GB.tgz
    echo "✅ Base de datos descargada y lista en: $DB_PATH"
else
    echo "✅ Base de datos ya existente y completa en: $DB_PATH"
fi

# ---------- 1. CLASIFICACIÓN TAXONÓMICA (KRAKEN2) ----------
echo "🚀 Iniciando clasificación taxonómica con Kraken2..."
cd "$IN_DIR"

FASTQ_COUNT=$(ls *_R1_nomap.fastq.gz 2>/dev/null | wc -l)
if [ "$FASTQ_COUNT" -eq 0 ]; then
    echo "⚠️  No se encontraron archivos *_R1_nomap.fastq.gz en $IN_DIR"
    exit 1
else
    echo "✅ Se detectaron $FASTQ_COUNT muestras para analizar."
fi

for R1 in *_R1_nomap.fastq.gz; do
    SAMPLE=$(basename "$R1" _R1_nomap.fastq.gz)
    R2="${SAMPLE}_R2_nomap.fastq.gz"

    if [ ! -f "$R2" ]; then
        echo "⚠️  No se encontró el archivo pareado para $R1, se omite esta muestra."
        continue
    fi

    echo "🧬 Procesando muestra: $SAMPLE"
    kraken2 \
        --db "$DB_PATH" \
        --threads 8 \
        --gzip-compressed \
        --paired "$R1" "$R2" \
        --report "$OUT_DIR/${SAMPLE}_kraken_report.txt" \
        --output "$OUT_DIR/${SAMPLE}_kraken_output.txt" \
        2> "$OUT_DIR/${SAMPLE}_kraken.err" || echo "⚠️ Kraken2 falló con $SAMPLE (ver .err)"
done

echo "✅ Clasificación con Kraken2 finalizada."

# ---------- 2. DESCARGA Y USO DE TAXONOMÍA PARA KRONA ----------
echo "🌍 Verificando taxonomía para Krona..."
cd "$BASE_DIR"

if [ ! -d "$KRONA_TAX_DIR" ] || [ -z "$(ls -A "$KRONA_TAX_DIR")" ]; then
    echo "📦 No se encontró taxonomía previa. Descargando desde NCBI..."
    ktUpdateTaxonomy.sh "$KRONA_TAX_DIR"
    echo "✅ Taxonomía descargada exitosamente en: $KRONA_TAX_DIR"
else
    echo "✅ Taxonomía Krona ya existente en: $KRONA_TAX_DIR"
fi

# ---------- 3. VISUALIZACIÓN INTERACTIVA (KRONA - RESUMIDA) ----------
echo "📊 Generando visualizaciones Krona (resumidas por taxón)..."
cd "$OUT_DIR"

for FILE in *_kraken_report.txt; do
    SAMPLE=$(basename "$FILE" _kraken_report.txt)
    if [ -s "$FILE" ]; then
        echo "🌀 Generando visualización Krona (resumen) para: $SAMPLE"
        ktImportTaxonomy -tax "$KRONA_TAX_DIR" "$FILE" -o "${SAMPLE}_krona.html" \
            2> "${SAMPLE}_krona.err" || echo "⚠️ Error generando Krona para $SAMPLE"
    else
        echo "⚠️ El archivo $FILE está vacío, se omite la generación de Krona."
    fi
done

echo "✅ Visualizaciones Krona resumidas generadas exitosamente."

# ---------- 3.1 VISUALIZACIÓN DETALLADA (KRONA con cut -f2,3) ----------
echo "📊 Generando visualizaciones Krona detalladas (por lectura)..."
cd "$OUT_DIR"

for FILE in *_kraken_output.txt; do
    SAMPLE=$(basename "$FILE" _kraken_output.txt)
    if [ -s "$FILE" ]; then
        echo "🔍 Extrayendo columnas 2 y 3 de $FILE..."
        cut -f2,3 "$FILE" > "${SAMPLE}_krona_input.txt"

        echo "🌀 Generando visualización Krona detallada para: $SAMPLE"
        ktImportTaxonomy "${SAMPLE}_krona_input.txt" -o "${SAMPLE}_krona_cut.html" \
            2> "${SAMPLE}_krona_cut.err" || echo "⚠️ Error generando Krona detallada para $SAMPLE"
    else
        echo "⚠️ El archivo $FILE está vacío, se omite la versión detallada de Krona."
    fi
done

echo "✅ Visualizaciones Krona detalladas generadas exitosamente."

# ---------- 4. ABUNDANCIAS CORREGIDAS (BRACKEN) ----------
echo "🔬 Iniciando análisis con Bracken..."
for FILE in "$OUT_DIR"/*_kraken_report.txt; do
    SAMPLE=$(basename "$FILE" _kraken_report.txt)
    echo "🧪 Procesando muestra: $SAMPLE"
    bracken \
        -d "$DB_PATH" \
        -i "$FILE" \
        -o "$OUT_DIR/${SAMPLE}_bracken_species.txt" \
        -r 150 -l S \
        2> "$OUT_DIR/${SAMPLE}_bracken.err" || echo "⚠️ Error en Bracken con $SAMPLE"
done

echo "✅ Clasificación con Bracken completada."

# ---------- 5. RESUMEN FINAL ----------
echo "🎉 Pipeline completado exitosamente."
echo "📁 Resultados disponibles en: $OUT_DIR"
echo "   ├── *_report.txt          (Reporte Kraken2)"
echo "   ├── *_output.txt          (Clasificación detallada por lectura)"
echo "   ├── *_krona.html          (Visualización Krona resumida)"
echo "   ├── *_krona_cut.html      (Visualización Krona detallada por lectura)"
echo "   ├── *_bracken_species.txt (Abundancias corregidas)"
echo "============================================================"
