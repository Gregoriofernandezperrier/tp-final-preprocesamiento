# Informe del Trabajo Final — Taller de Pre-procesamiento de Datos (Lic. en Ciencia de Datos, Universidad Austral)

Hola Claude. Te paso un resumen de nuestro trabajo final (en pareja, en R con Quarto) para que me hagas preguntas como si fueras la docente y me ayudes a ensayar la defensa individual de 15 minutos. Solo se usaron contenidos de la materia.

## 1. Datos y objetivos
- **`credit_data`** (paquete `modeldata`): **4454 solicitudes de crédito de consumo**, 14 variables (`Status`, `Seniority`, `Home`, `Time`, `Age`, `Marital`, `Records`, `Job`, `Expenses`, `Income`, `Assets`, `Debt`, `Amount`, `Price`). La fuente no informa moneda ni año.
- **Objetivo lineal:** de qué depende el monto pedido (`Amount`). **Objetivo logístico:** predecir si el solicitante será mal pagador (28,2 %).

## 2. Pre-procesamiento
- **Recodificación:** se agrupan categorías con pocos casos y se fija la categoría de referencia más frecuente.
- **Faltantes:** 415 filas (9,3 %) con algún NA; el problema real es `Income` (381, 8,6 %). Se explican MCAR/MAR/MNAR y se comparan quienes no informan ingreso con quienes sí: 57 % de mal pagadores vs. 25 %, 9 % con empleo fijo vs. 68 %, 28 % con antecedentes vs. 16 %, antigüedad mediana 3 vs. 5. Una regresión logística simple de `Ingreso_faltante` sobre `Status` es mejor que el modelo nulo (`lrtest`, p < 0,001). **Conclusión: no es MCAR; es plausible MAR; MNAR no se puede verificar.** No se borran casos (bajo MAR sesga) y se imputa con **kNN (k = 5)**, sin `Status` ni `Amount`. `mice` se menciona como alternativa. Se crea `Ingreso_faltante` (1 = faltaba) antes de imputar.
- **Derivadas:** `Pct_fin = 100·Amount/Price` (solo en la logística), `Tiene_deuda`.
- **Transformaciones:** log en `Amount`, `Price`, `Income`; `log(1+x)` en `Assets` (y en `Seniority`, solo para la logística). **Escala:** no se estandariza (se interpretan unidades reales). **Atípicos:** no se eliminan (son reales); se evalúa su influencia con Cook.
- **Sin fuga de información en la logística:** partición 75/25 **antes** de imputar; `train` se imputa con `train`; `test` se imputa usando solo `train` como donantes; selección de variables y corte solo con `train`; `test` se usa una sola vez.

## 3. Regresión lineal (respuesta: log del monto)
- Modelo completo (13 candidatas, incl. `Ingreso_faltante`): R² ajustado 0,656; GVIF ajustado < 1,8.
- **Selección:** `stepAIC` backward. AIC descarta solo `Ingreso_faltante`; BIC deja 7 variables (`log_Price`, `Time`, `Seniority`, `Records`, `Job`, `log_Income`, `Tiene_deuda`). Se elige BIC por parsimonia (R² ajustado 0,6535 vs. 0,6555).
- **Supuestos:** fallan homocedasticidad (Breusch-Pagan) y normalidad (Anderson-Darling); Durbin-Watson no aplica; `Time` es curvo (residuos en U invertida) → `Time²` (mejora el BIC en 87 puntos). La asimetría residual viene de los datos (cola de montos muy bajos respecto del precio).
- **Influyentes:** Cook máx. 0,019; 81 casos con |rstudent| > 3; sin ellos los signos se mantienen. **Bootstrap** (1000 remuestras): IC casi idénticos a los clásicos.
- **Final:** R² ajustado 0,66; elasticidad del precio 0,74 (+10 % de precio → +7,3 % de monto); plazo con rendimientos decrecientes (vs. 12 meses: +32 % a 24, +113 % a 60); independiente +9 %, medio tiempo +6 %, antecedentes +4 %, ingreso +10 % → +0,7 %, deuda −4 %, antigüedad −0,2 % por año.

## 4. Regresión logística (malo = 1), sin fuga de información
- *Train* 3341 / *test* 1113 (28 % de malos en ambos).
- **Selección solo con *train*:** `stepAIC` (AIC y BIC). BIC descarta `Age` y `Time` (`lrtest` BIC vs. AIC: p = 0,13). `Ingreso_faltante` queda (`lrtest` contra el mismo modelo sin ella: p < 0,001). Modelo final: 12 variables.
- **`log(1 + Seniority)`:** con `Seniority` lineal, Hosmer-Lemeshow rechazaba (p = 0,024); con el log, p = 0,55 (solo en *train*).
- **Odds ratios:** antecedentes 6,29 · **ingreso no informado 4,01** (señal de cómo se cargó la solicitud, no una causa) · medio tiempo 3,72 · estado civil "otro" 2,67 · deuda previa 1,86 · independiente 1,40 · duplicar el ingreso 0,44 · duplicar (1 + antigüedad) 0,68 · +10 puntos de % financiado 1,42.
- **Capacidad predictiva (test, usado una sola vez):** AUC **0,828** (*train* 0,854).
- **Punto de corte:** **0,27** con `coords(roc, "best", ret = "threshold")` (Unidad 5; criterio conocido como índice de Youden), solo con *train* (con 28 % de malos, el 0,5 detecta solo el 50 % de los malos). En *test* con 0,27: sensibilidad 75 %, especificidad 76 %, VPP 55 %, VPN 88 %, exactitud 75 %, F1 0,63 (con 0,5: exactitud 79 %, F1 0,57).

## 5. Limitaciones declaradas
MNAR no verificable y kNN reduce la variabilidad; la fuente no informa moneda/año/definiciones; asociaciones, no causalidad; residuos del lineal asimétricos y monto acotado por el precio; una sola partición y sin interacciones; el corte depende de costos que asumimos.

## 6. Qué te pido
1. Actuá como docente y hacéme 10 preguntas difíciles sobre estas decisiones (una por una, esperando mi respuesta): tipo de faltante, por qué kNN, fuga de información, por qué log, por qué BIC, por qué `log(1+Seniority)`, Hosmer-Lemeshow, punto de corte, interpretación de un odds ratio, `Ingreso_faltante`.
2. Marcá qué decisión te parece más débil o mal justificada.
3. Ayudame a ensayar la exposición de 15 minutos.
