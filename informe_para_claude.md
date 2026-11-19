# Informe del Trabajo Final — Taller de Pre-procesamiento de Datos (Lic. en Ciencia de Datos, Universidad Austral)

Hola Claude. Te paso un resumen de nuestro trabajo final (en pareja, en R con Quarto) para que lo revises, me hagas preguntas como si fueras la docente y me ayudes a ensayar la defensa individual de 15 minutos. Solo se usaron contenidos de la materia (ggplot2, GGally, corrplot, lm, car::vif, leaps, MASS::stepAIC/boxcox, lmtest, nortest, boot, robustbase, glm, caret, pROC, ResourceSelection, VIM).

## 1. Datos y objetivos
- **`credit_data`** (paquete `modeldata`; fuente: Belanche Muñoz vía `gastonstat/CreditScoring`): **4454 solicitudes de crédito de consumo**, 14 variables (`Status`, `Seniority`, `Home`, `Time`, `Age`, `Marital`, `Records`, `Job`, `Expenses`, `Income`, `Assets`, `Debt`, `Amount`, `Price`). La fuente no informa moneda ni año.
- **Objetivo lineal:** de qué depende el monto pedido (`Amount`). **Objetivo logístico:** predecir si el solicitante será mal pagador (`Status = bad`, 28,2 %).

## 2. Pre-procesamiento (decisiones y justificación)
- **Recodificación:** se agrupan categorías con pocos casos (`ignore`+`other`; `divorced`+`separated`+`widow`) y se fija como referencia la categoría más frecuente.
- **Faltantes (el punto central):** 415 filas (9,3 %) con algún NA; el problema real es `Income` (381, 8,6 %). Se explican **MCAR/MAR/MNAR** y para cada una de 13 variables se ajusta una **regresión logística simple** con `Ingreso_faltante` como respuesta y se la compara con el modelo nulo mediante `lrtest` (Unidad 5): ayudan a explicar la ausencia **10 de 13** (9 con Bonferroni). Ej.: 57 % de mal pagadores vs. 25 %; solo 9 % con empleo fijo vs. 68 %. **Conclusión: no es MCAR; es plausible MAR; MNAR no se puede verificar** (limitación). Por eso no se borran casos (bajo MAR, usar solo casos completos sesga, Unidad 6) y se imputa con **kNN (k = 5)** usando variables completas, sin `Status` ni `Amount`. `mice` se menciona como alternativa, sin implementarla.
- **`Ingreso_faltante`** (1 = ingreso faltaba): creada **antes** de imputar para no perder esa información; candidata en ambos modelos.
- **Derivadas:** `Pct_fin = 100·Amount/Price` (solo en la logística, porque contiene a la respuesta lineal), `Tiene_deuda`.
- **Transformaciones:** log en `Amount`, `Price`, `Income`; `log(1+x)` en `Assets` (y en `Seniority`, solo para la logística). **Escala:** z-scores solo para comparar importancia en la logística. **Atípicos:** no se eliminan (son reales); se evalúa su influencia.
- **Sin fuga de información en la logística:** la partición 75/25 se hace **antes** de imputar; `train` se imputa solo con `train`; `test` se imputa usando **solo `train` como donantes**; selección de variables y punto de corte solo con `train`; `test` se usa una sola vez. En el lineal (sin partición) se imputa con todas las filas.

## 3. Regresión lineal (respuesta: log del monto)
- Modelo completo (13 candidatas, incl. `Ingreso_faltante`): R² ajustado 0,656; GVIF ajustado < 1,8 (sin multicolinealidad, por eso no Ridge/Lasso).
- **Selección:** `regsubsets` y `stepAIC` (forward/backward AIC y BIC). BIC deja 7 variables (`log_Price`, `Time`, `Seniority`, `Records`, `Job`, `log_Income`, `Tiene_deuda`) y coincide con el mejor subconjunto; AIC solo descarta `Ingreso_faltante` (p = 0,70 en el lineal).
- **Supuestos:** fallan homocedasticidad (Breusch-Pagan) y normalidad (Anderson-Darling; asimetría residual −1,45); Durbin-Watson no aplica; `Time` es curvo (residuos en U invertida) → `Time²` (mejora el BIC en unos 87 puntos).
- **Transformación de la respuesta:** Box-Cox da **λ = 0,34, IC 95 % [0,31; 0,38]** (excluye 0 y 0,5). Comparé log / raíz / Box-Cox en el modelo final: R² ajustado 0,661 / 0,649 / 0,657; asimetría residual −1,45 / −0,67 / −0,96; **signo y significancia de todos los coeficientes idénticos**; los tres siguen rechazando normalidad y homocedasticidad. Mantengo el **log** por: (a) interpretación en % y elasticidades; (b) con n = 4454 los tests rechazan desvíos pequeños y la inferencia sobre coeficientes es válida por tamaño de muestra; (c) bootstrap y regresión robusta confirman. La asimetría residual se debe a los **datos** (cola de montos muy bajos respecto del precio), no a la transformación.
- **Influyentes:** Cook máx. 0,019; 81 casos con |rstudent| > 3; quitándolos, los signos se mantienen. **Remedios:** bootstrap (1000 remuestras; IC casi idénticos a los clásicos) y `lmrob` (mismos signos, magnitudes parecidas).
- **Final:** R² ajustado 0,66; elasticidad del precio 0,74 (+10 % de precio → +7,3 % de monto); plazo con rendimientos decrecientes (vs. 12 meses: +32 % a 24, +113 % a 60); independiente +9 %, medio tiempo +6 %, antecedentes +4 %, ingreso +10 % → +0,7 %, deuda −4 %, antigüedad −0,2 % por año.

## 4. Regresión logística (malo = 1), sin fuga de información
- *Train* 3341 / *test* 1113 (28 % de malos en ambos), todo estratificado y con `set.seed(2024)`.
- **Selección solo con *train*:** `stepAIC` (AIC y BIC) comparando AIC, BIC y AUC de validación cruzada de 10 pliegues. BIC descarta `Age` y `Time` (el `lrtest` BIC vs. AIC da p = 0,13). **`Ingreso_faltante` queda en el modelo** (razón de verosimilitud p < 0,001; AUC en validación cruzada 0,842 → 0,850). Modelo final: 12 variables.
- **`log(1 + Seniority)`:** con `Seniority` lineal, Hosmer-Lemeshow rechazaba (p = 0,024); con el log, p = 0,55 en *train* y mejoran AIC y BIC (el efecto de la antigüedad no es lineal).
- **Odds ratios:** antecedentes 6,29 · **ingreso no informado 4,01** (señal de cómo se cargó la solicitud, no una causa) · medio tiempo 3,72 · estado civil "otro" 2,67 · deuda previa 1,86 (aparece al controlar por ingreso y patrimonio) · independiente 1,40 (era 2,2 sin `Ingreso_faltante`) · duplicar el ingreso 0,44 · duplicar (1 + antigüedad) 0,68 · +10 puntos de % financiado 1,42.
- **Capacidad predictiva (test, usado una sola vez):** AUC **0,828**; *train* 0,854; validación cruzada 0,850. Sin `Ingreso_faltante`: 0,822 (mejora modesta pero consistente).
- **Punto de corte:** **0,27** con `coords(roc, "best")` (Unidad 5; criterio conocido como índice de Youden) calculado solo con *train* (con 28 % de malos, el 0,5 detecta solo el 50 % de los malos). En *test*: sensibilidad 75 %, especificidad 76 %, VPP 55 %, VPN 88 %, exactitud 75 %, F1 0,63 (con 0,5: exactitud 79 %, F1 0,57).
- **Calibración:** Hosmer-Lemeshow en *train* p = 0,55; en *test* p = 0,03 (desajuste leve: el grupo de mayor riesgo se sobreestima, 87 % predicho vs. 76 % observado; ~111 personas por grupo). El gráfico de calibración sigue de cerca la diagonal.

## 5. Limitaciones declaradas
MNAR no verificable y kNN reduce la variabilidad; la fuente no informa moneda/año/definiciones; asociaciones, no causalidad; residuos del lineal asimétricos y monto acotado por el precio (quizá convenga modelar la proporción financiada); una sola partición (reforzada con validación cruzada) y sin interacciones; el corte depende de costos que asumimos; calibración en *test* buena pero no perfecta.

## 6. Entregables
`TP_Final.qmd` → `TP_Final.html` (índice lateral, código plegado, español; todos los números del texto salen de código inline), `datos/` (original sin tocar + procesado) y una guía de defensa privada.

## 7. Qué te pido
1. Actuá como docente y hacéme 10 preguntas difíciles sobre estas decisiones (una por una, esperando mi respuesta): tipo de faltante, por qué kNN, fuga de información, por qué log si λ = 0,34, por qué BIC, por qué `log(1+Seniority)`, Hosmer-Lemeshow, punto de corte, interpretación de un odds ratio, `Ingreso_faltante`.
2. Marcá qué decisión te parece más débil o mal justificada.
3. Ayudame a ensayar la exposición de 15 minutos.
