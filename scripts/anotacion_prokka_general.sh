#!/bin/bash
# ============================================================
#  Anotación funcional del genoma con Prokka (versión general)
#  Autor: Mate Pulgarín
#  Proyecto: Proyecto Integrador - Bioinformática
# ============================================================

set -euo pipefail

# ---------- CONFIGURACIÓN ----------
BASE_DIR="$HOME/intento_entrega2"

# Archivo ensamblado a anotar
INPUT_FASTA="$BASE_DIR/ensamblaje/spades/post/scaffolds.fasta"

# Carpeta de salida
OUT_DIR="$BASE_DIR/prokka_resultados_general"

# Prefijo para archivos
PREFIX="anc_prokka_general"

mkdir -p "$OUT_DIR"

# ---------- EJECUCIÓN DE PROKKA ----------
echo "🧬 Iniciando anotación funcional general con Prokka..."

prokka \
  --outdir "$OUT_DIR" \
  --prefix "$PREFIX" \
  --cpus 8 \
  --force \
  "$INPUT_FASTA"

# ---------- RENOMBRAR ARCHIVOS PARA SNPEFF ----------
echo "🔧 Preparando archivos para SnpEff..."

cp "$OUT_DIR/${PREFIX}.gff"  "$OUT_DIR/genes.gff"
cp "$OUT_DIR/${PREFIX}.faa"  "$OUT_DIR/protein.fa"
cp "$OUT_DIR/${PREFIX}.ffn"  "$OUT_DIR/cds.fa"

# ---------- RESULTADO ----------
echo "✅ Anotación funcional general completada."
echo "📁 Resultados en: $OUT_DIR"
echo "   ├── genes.gff   (anotaciones GFF3 para SnpEff)"
echo "   ├── protein.fa  (proteínas predichas para SnpEff)"
echo "   ├── cds.fa      (CDS predichos para SnpEff)"
echo "   ├── ${PREFIX}.tsv"
echo "   ├── ${PREFIX}.gbk"
echo "   └── otros archivos de salida de Prokka"

