# Trabajo Final — Taller de Pre-procesamiento de Datos

Licenciatura en Ciencia de Datos, Universidad Austral. Hecho en R con Quarto.

## De qué trata
Análisis de **4454 solicitudes de crédito de consumo** (`credit_data` del paquete `modeldata`):

1. **Regresión lineal:** ¿de qué depende el monto que pide una persona?
2. **Regresión logística:** ¿quién termina siendo mal pagador? (con partición train/test, imputación sin fuga de información, ROC/AUC y punto de corte).

Incluye pre-procesamiento completo (faltantes MCAR/MAR/MNAR e imputación kNN, recodificación, variables derivadas, transformaciones, cambio de escala y atípicos), análisis exploratorio, selección de variables, diagnóstico de supuestos, bootstrap y regresión robusta.

## Cómo reproducirlo
**Requisitos:** R (≥ 4.5) y [Quarto](https://quarto.org) (≥ 1.7).

Paquetes de R:

```r
install.packages(c("ggplot2", "dplyr", "tidyr", "patchwork", "corrplot", "GGally", "VIM", "car", "MASS",
                   "leaps", "lmtest", "nortest", "boot", "robustbase", "caret", "pROC",
                   "ResourceSelection", "knitr", "rmarkdown", "modeldata"))
```

Renderizar (desde la carpeta raíz del proyecto):

```bash
quarto render TP_Final.qmd
```

Si Quarto no encuentra R, definir antes `QUARTO_R` con la ruta a `Rscript`. El documento usa `set.seed(2024)`, así que los resultados son reproducibles. Al renderizar se regeneran `TP_Final.html` y `datos/credit_procesado.*`.

## Contenido
| Archivo | Descripción |
|---|---|
| `TP_Final.qmd` | Documento principal (código + texto). |
| `TP_Final.html` | Documento renderizado (índice lateral, código plegado); es el que se usa para exponer. |
| `datos/credit_data_original.csv` | Dataset original, sin modificar. |
| `datos/credit_procesado.rds` / `.csv` | Versión procesada (imputada, recodificada, con variables derivadas). |
| `scripts/00_exportar_datos_originales.R` | Script que exportó el dataset original desde `modeldata`. |
| `guia_defensa.md` | Guía de estudio y defensa: conceptos clave, guion de 15 minutos y preguntas difíciles. |
| `informe_para_claude.md` | Resumen del trabajo para consultar o ensayar la defensa con Claude. |

Los apuntes de la cátedra (`Material/`) no se incluyen en el repositorio.
