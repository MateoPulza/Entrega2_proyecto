#!/usr/bin/env bash
set -euo pipefail

# ===========================================================
#  Llamado de variantes independiente por evolución
#  Autor: Mate Pulgarín
#  Proyecto: Proyecto Integrador - Bioinformática
# ===========================================================

# --- 1. Variables principales ---
REF="ensamblaje/spades/post/scaffolds.fasta"   # Genoma de referencia (ancestro)
OUTDIR="variantes"                    # Carpeta de salida
SAMPLES=("evol1" "evol2")                      # Identificadores de muestras
BAM_DIR="index_alineamiento"                   # Carpeta donde están los BAMs

mkdir -p "$OUTDIR"

# --- 2. Verificar e indexar referencia ---
if [ ! -f "${REF}.fai" ]; then
    echo "🧩 Creando índice de referencia..."
    samtools faidx "$REF"
fi

# --- 3. Proceso por cada evolución ---
for SAMPLE in "${SAMPLES[@]}"; do
    BAM="${BAM_DIR}/${SAMPLE}_sortrem.bam"
    SAMPLE_OUTDIR="${OUTDIR}/${SAMPLE}"
    mkdir -p "$SAMPLE_OUTDIR"

    echo "============================================"
    echo "🔬 Procesando muestra: $SAMPLE"
    echo "Archivo BAM: $BAM"
    echo "Salida: $SAMPLE_OUTDIR"
    echo "============================================"

    # --- 3.1 Verificar e indexar BAM ---
    if [ ! -f "${BAM}.bai" ]; then
        echo "🧠 Creando índice para $BAM..."
        samtools index "$BAM"
    fi

    # --- 3.2 Llamado de variantes ---
    echo "🚀 Ejecutando llamado de variantes con bcftools..."
    bcftools mpileup -Ou -f "$REF" -q 20 -Q 20 "$BAM" \
    | bcftools call -mv -Oz -o "${SAMPLE_OUTDIR}/${SAMPLE}_raw.vcf.gz"

    # --- 3.3 Indexar VCF ---
    echo "📦 Indexando archivo VCF..."
    bcftools index "${SAMPLE_OUTDIR}/${SAMPLE}_raw.vcf.gz"

    # --- 3.4 Filtrado básico ---
    echo "🧹 Aplicando filtro de calidad y profundidad..."
    bcftools filter -i 'QUAL>30 && DP>=10 && MQ>=40' \
    "${SAMPLE_OUTDIR}/${SAMPLE}_raw.vcf.gz" -Oz -o "${SAMPLE_OUTDIR}/${SAMPLE}_filtrado.vcf.gz"

    bcftools index "${SAMPLE_OUTDIR}/${SAMPLE}_filtrado.vcf.gz"

    # --- 3.5 Estadísticas ---
    echo "📊 Generando estadísticas..."
    bcftools stats "${SAMPLE_OUTDIR}/${SAMPLE}_filtrado.vcf.gz" > "${SAMPLE_OUTDIR}/${SAMPLE}_stats.txt"

    echo "✅ Variantes de $SAMPLE generadas correctamente."
    echo
done

echo "🎉 Proceso completado para todas las muestras."
echo "📁 Resultados disponibles en: $OUTDIR"
