# Exporta el dataset original (modeldata::credit_data) a datos/credit_data_original.csv, sin modificarlo.
# Ejecutar una sola vez desde la carpeta raíz del proyecto:  Rscript scripts/00_exportar_datos_originales.R
suppressMessages(library(modeldata))
data(credit_data)
dir.create("datos", showWarnings = FALSE)
write.csv(credit_data, "datos/credit_data_original.csv", row.names = FALSE)
cat(nrow(credit_data), "filas exportadas\n")
