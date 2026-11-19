# Guía de defensa y estudio — Trabajo Final (Solicitudes de crédito)

> **Solo para nosotros, no se entrega.** El documento para exponer es `TP_Final.html` (índice a la izquierda, código plegado con "Ver código").
> Los números de esta guía salen del documento renderizado con `set.seed(2024)`. Si se cambia algo, vuelvan a chequearlos contra el HTML.
> Cada uno defiende **todo** el trabajo, no solo "su parte".

## 0. La historia en 30 segundos (para empezar y cerrar)

> "Trabajamos con 4454 solicitudes de crédito de consumo y nos hicimos dos preguntas: **(1) ¿de qué depende el monto que pide una persona?** (regresión lineal) y **(2) ¿quién termina siendo mal pagador?** (regresión logística). El monto lo determinan sobre todo el **precio del bien** y el **plazo**. El riesgo de ser mal pagador sube mucho con tener **antecedentes**, trabajar **medio tiempo**, **no informar el ingreso** y **financiar un porcentaje alto** del bien, y baja con **más ingreso, más antigüedad y más patrimonio**. El modelo logístico discrimina bien (AUC 0,83 en datos de prueba) y evitamos la fuga de información: imputamos después de partir los datos."

---

## 1. Conceptos clave para estudiar

*(Formato: qué es → cómo se lee → en nuestro trabajo. Asumí que no se acuerdan de nada.)*

### 1.1 Los dos modelos
- **Regresión lineal:** predice una variable **numérica** (acá, el monto pedido) como suma de efectos de las predictoras. Cada coeficiente dice "cuánto cambia la respuesta por cada unidad más de esa variable, dejando las demás fijas".
- **Regresión logística:** predice la **probabilidad** de un evento de dos categorías (acá, ser mal pagador). Trabaja con *odds* (chances); el coeficiente se interpreta con un **odds ratio (OR)**.

### 1.2 Datos faltantes: MCAR, MAR, MNAR
- **Qué es:** un dato faltante es una casilla vacía (NA). Lo importante es **por qué falta**:
  - **MCAR** (*completely at random*): falta por puro azar, sin relación con nada. Ej.: una falla informática borra ingresos al azar. Borrar esos casos no sesga (solo pierde precisión).
  - **MAR** (*at random*): la probabilidad de faltar depende de **otras variables que sí observamos**. Ej.: el ingreso falta más en quienes tienen un empleo que no es fijo. Borrar los casos **sí sesga**; se corrige imputando con las variables observadas.
  - **MNAR** (*not at random*): depende **del propio valor que falta**. Ej.: quienes ganan muy poco no lo informan. **No se puede verificar ni corregir solo con los datos.**
- **Cómo lo comprobamos (regresión logística + `lrtest`, Unidad 5):** definimos `Ingreso_faltante` (1 = el ingreso falta, 0 = observado) y, **para cada una de las 13 variables**, ajustamos una **regresión logística simple** con `Ingreso_faltante` como respuesta y esa variable como única predictora. La comparamos con el **modelo nulo** (solo el intercepto) usando el **test de razón de verosimilitud** (`lmtest::lrtest`). Si fuera MCAR, ninguna variable ayudaría a predecir si el ingreso falta, y el modelo con la variable no sería mejor que el nulo. **p chico = la variable sí ayuda a explicar la ausencia = no es MCAR.** Es la misma lógica de la pregunta "¿mejora el ajuste agregar esta variable?" que usamos para comparar modelos anidados.
- **En nuestro trabajo:** `Income` falta en 381 casos (8,6 %). Ayudan a explicar la ausencia **10 de 13** variables (9 con corrección de Bonferroni). Ej.: el 57 % de los que no informan ingreso es mal pagador (vs. 25 %), y solo el 9 % tiene empleo fijo (vs. 68 %). **Conclusión: no es MCAR; es plausible MAR; MNAR no se puede descartar** (limitación).
- **Análisis de casos completos (CCA):** usar solo filas sin NA. Bajo MAR sesga (en la Unidad 6 se vio con datos simulados) y acá perdería el 9,3 % de las filas, justo de mayor riesgo.

### 1.2b Comparaciones múltiples y corrección de Bonferroni
- **Problema:** si hacés muchos tests, aumenta la chance de que alguno dé "significativo" solo por azar. Con α = 0,05 y 13 tests independientes, esperaríamos ~0,65 falsos positivos aunque no hubiera ninguna diferencia real.
- **Bonferroni:** divide el nivel de significación por la cantidad de tests (α/m) para **controlar la tasa de error global**. Es la misma idea de "cuidar la tasa de error global" de las comparaciones múltiples de la Unidad 2 (test de Tukey entre grupos de pingüinos), aplicada a muchos tests en lugar de a pares de grupos. Es conservadora (más difícil rechazar).
- **En nuestro trabajo:** la tabla de faltantes tiene **13 tests** (un `lrtest` por variable). Con Bonferroni el umbral pasa de 0,05 a 0,05/13 ≈ 0,0038. Sin corrección ayudan a explicar la ausencia 10 de 13; **con corrección siguen siendo 9**. Es decir, la conclusión "no es MCAR" no depende de haber hecho muchas pruebas.

### 1.2c Estudiar el mecanismo de los faltantes con regresión logística y `lrtest`
- **Idea:** "¿qué variables predicen que falte el ingreso?" es una pregunta de regresión logística. La respuesta es 0/1 (`Ingreso_faltante`); si alguna variable la predice, la ausencia depende de lo observado (MAR) y no es MCAR.
- **Cómo se hace:** por cada variable `x`: modelo `glm(Ingreso_faltante ~ x, family = binomial)` contra el modelo nulo `glm(Ingreso_faltante ~ 1, family = binomial)`, y `lrtest(nulo, modelo)` (se usan solo las filas donde `x` no es NA). El p del `lrtest` dice si `x` mejora el ajuste más de lo esperable por azar.
- **Qué muestra la tabla:** las columnas descriptivas (% o mediana en cada grupo) muestran *cómo* difieren; el p del `lrtest` dice *si* esa diferencia ayuda a explicar la ausencia. Ej.: `Job`: 9 % de empleo fijo entre quienes no informan vs. 68 % entre quienes sí. `Time` tiene la misma mediana en los dos grupos (48) pero el `lrtest` es significativo: la ausencia se relaciona con la distribución completa del plazo, no solo con su mediana.
- **Ventaja:** usamos la misma herramienta que en la logística (Unidad 5), con lo que no hace falta ningún test adicional.

### 1.3 Imputación: media/mediana, kNN, mice
- **Media/mediana:** reemplaza todos los NA por el mismo número. Rápido pero **subestima la variabilidad** y supone MCAR. En nuestro dato: los 381 ingresos imputados tendrían desvío 0.
- **kNN (k vecinos más cercanos):** para cada fila con NA busca las **k = 5 filas más parecidas** (en las variables completas) y completa con su promedio (o moda si es categórica). Conserva mejor la estructura de los datos, y funciona con numéricas y categóricas a la vez. Lo usamos (`VIM::kNN`). *Límite:* los valores imputados son "promedios de vecinos", con **menos dispersión** que los reales (en nuestro caso: desvío 38 vs. 81 de los observados).
- **mice (imputación múltiple):** genera varios datasets completos (5 por defecto) con un modelo de regresión por variable y combina los resultados, reflejando la incertidumbre de imputar. Es una alternativa válida; **no la implementamos** para mantener el trabajo simple.
- **`Ingreso_faltante`:** variable 0/1 que indica "el ingreso faltaba". La creamos **antes** de imputar, para no perder esa información. Es la variable más llamativa de la logística (OR ≈ 4).

### 1.4 Recodificar, derivar, transformar, escalar, atípicos
- **Recodificar:** agrupar categorías con pocos casos (ej.: `ignore`+`other`) para que los coeficientes no sean inestables. Se fija una **categoría de referencia** (la más frecuente): cada coeficiente se lee "respecto de esa".
- **Variables derivadas:** nuevas variables con sentido: `Pct_fin = 100·Monto/Precio` (qué % del bien se financia), `Tiene_deuda` (0/1), `Ingreso_faltante`.
- **Transformación logarítmica:** achata colas largas (ingreso, precio, monto, activos) y vuelve proporcionales los efectos. `log(1+x)` se usa cuando hay ceros (activos, antigüedad).
- **Cambio de escala (z-score):** `(x − media)/desvío`. Sirve para **comparar** cuánto pesa cada variable. No lo usamos en los modelos finales (los queremos en unidades reales), solo en la tabla de importancia de la logística.
- **Atípicos:** valores extremos (regla del boxplot: más allá de 1,5 veces el rango intercuartílico). **No los eliminamos** porque son reales; evaluamos su influencia (Cook) y usamos métodos robustos.

### 1.5 Logaritmo y elasticidad (interpretación en %)
- Si la **respuesta** está en log y una **predictora no**: el coeficiente `b` significa "cada unidad más cambia el monto en `100·(e^b − 1)` %". Ej.: antecedentes: b = 0,041 → +4,1 %.
- Si **ambas** están en log: `b` es una **elasticidad**: "1 % más de la predictora cambia la respuesta en `b` %". Ej.: precio: b = 0,74 → un bien 10 % más caro, monto ≈ +7,3 %.

### 1.6 Box-Cox
- **Qué es:** busca la potencia λ que mejor "normaliza" la respuesta: λ = 1 no transforma, λ = 0,5 es raíz cuadrada, λ = 0 es logaritmo.
- **En nuestro trabajo:** λ = 0,34, IC 95 % = [0,31; 0,38]. No incluye ni 0 ni 0,5. Aun así **mantenemos el log** (ver pregunta 6 de la sección 3).

### 1.7 Selección de variables: R² ajustado, AIC, BIC, regsubsets, stepAIC
- **R² ajustado:** proporción de variabilidad explicada, "descontando" por la cantidad de variables.
- **AIC y BIC:** miden calidad del modelo **penalizando la complejidad** (menor = mejor). **BIC penaliza más** (usa log(n) en vez de 2): elige modelos más chicos. Con n grande, AIC tiende a conservar variables de efecto muy chico.
- **Cp de Mallows:** otro criterio de selección (cercano al AIC).
- **`regsubsets` (mejor subconjunto):** prueba **todas** las combinaciones de variables y devuelve el mejor modelo de cada tamaño; luego se elige el tamaño con el criterio (R² ajustado, Cp, BIC).
- **`stepAIC`:** va agregando (*forward*), sacando (*backward*) o ambas (*both*) variables, una por vez, según AIC (o BIC con `k = log(n)`).
- **En nuestro trabajo (lineal):** BIC deja 7 variables y coincide con el mejor subconjunto; AIC solo descarta `Ingreso_faltante`.

### 1.6b Multicolinealidad: VIF/GVIF
- Cuando dos predictoras están muy correlacionadas, los coeficientes se vuelven inestables. **VIF** (o **GVIF** si hay categóricas, mirando `GVIF^(1/(2·Df))`) mide ese problema: valores menores a 2–5 son tranquilizadores. Los nuestros son todos < 1,8. Por eso **no hace falta Ridge/Lasso**.

### 1.8 Supuestos de la regresión lineal y sus tests
| Supuesto | Qué significa | Cómo se mira | Resultado nuestro |
|---|---|---|---|
| **Linealidad** | La relación es una recta | Residuos vs. cada predictora con curva suavizada (`geom_smooth`) | `Time` curvo (U invertida) → agregamos `Time²` |
| **Homocedasticidad** | Los residuos tienen la misma dispersión | Residuos vs. ajustados; test de **Breusch-Pagan** | No se cumple (p < 0,001) |
| **Normalidad** | Los residuos son aprox. normales | **QQ-plot**; test de **Anderson-Darling** (o Shapiro) | No se cumple; cola izquierda |
| **Independencia** | Una fila no influye en otra | **Durbin-Watson** (solo si hay orden temporal) | No aplica: sin orden temporal |

- **Qué pasa si fallan:** las estimaciones siguen siendo razonables, pero los errores estándar/IC/p-valores clásicos pueden ser incorrectos. Remedios: transformar, términos polinómicos, **bootstrap** (IC sin supuestos), **regresión robusta**.
- **Por qué los tests rechazan casi siempre con n grande:** con 4454 datos detectan desvíos mínimos; además, por el teorema central del límite la inferencia sobre los coeficientes sigue siendo válida aunque los residuos no sean normales.

### 1.9 Atípicos e influyentes: rstudent, leverage, Cook
- **Residuo studentizado (`rstudent`):** el residuo expresado en "desvíos"; |valor| > 3 = observación mal predicha por el modelo (atípica en la respuesta).
- **Leverage (`hatvalues`):** qué tan "rara" es la fila en las **predictoras** (> 2p/n).
- **Distancia de Cook:** cuánto cambiarían los coeficientes si sacáramos esa fila; combina las dos ideas. Regla: > 4/n mirar; > 1 preocupante. **El máximo nuestro es 0,019**: ninguna fila domina.

### 1.10 Bootstrap
- Se **remuestrea con reposición** las filas del dataset (1000 veces), se reajusta el modelo cada vez y se mira la variación de los coeficientes. Los percentiles 2,5 % y 97,5 % dan un **IC sin supuestos de normalidad ni varianza constante**. En nuestro trabajo coincide casi exacto con el IC clásico.

### 1.11 Regresión robusta (`lmrob`)
- Da **menos peso a las observaciones muy alejadas** (las de "monto muy bajo") en vez de dejar que arrastren la recta. Si los coeficientes son parecidos a los de MCO, las conclusiones son estables. Lo son.

### 1.12 Término cuadrático
- `I(Time^2)` permite que el efecto del plazo **se desacelere** (rendimientos decrecientes). El coeficiente cuadrático es negativo.

### 1.13 Regresión logística: odds, odds ratio, IC
- **Odds (chances)** = P(malo) / P(bueno). Con P = 0,25 → odds = 1/3.
- **Odds ratio (OR)** = cuánto se **multiplican las chances** al pasar a otra categoría o por cada unidad más de la variable. **OR > 1 aumenta el riesgo; OR < 1 lo reduce; OR = 1 no hay efecto.** Si el IC 95 % del OR incluye al 1, el efecto no se distingue de cero.
- Ej.: antecedentes, OR = 6,3 → tener antecedentes **multiplica por 6,3 las chances** de ser mal pagador (no la probabilidad).
- Con una variable en log (ej. ingreso): "duplicar el ingreso multiplica las chances por 2^b".

### 1.14 Test de razón de verosimilitud (`lrtest`)
- Compara dos modelos **anidados** (uno contiene al otro): ¿las variables extra mejoran el ajuste más de lo esperable por azar? p chico = sí mejoran. Con n grande suele dar p chico incluso para mejoras mínimas.

### 1.15 Hosmer-Lemeshow y calibración
- Agrupa a los solicitantes en 10 grupos por riesgo predicho y compara **malos esperados vs. observados** en cada grupo. **H0: el ajuste es bueno.** p > 0,05 = no hay evidencia de mal ajuste (no es "prueba de buen ajuste"); es sensible a cómo se agrupa y al tamaño de la muestra.
- **Calibración:** ¿cuando el modelo dice "30 % de riesgo", se observa ~30 % de malos? El gráfico de calibración lo muestra (puntos sobre la diagonal = bien calibrado).
- **En nuestro trabajo:** en `train` p = 0,55. En `test` p = 0,03 (desajuste leve, sobre todo en el grupo de mayor riesgo, que se sobreestima); el gráfico muestra puntos cerca de la diagonal.

### 1.16 Partición train/test, validación cruzada y fuga de información
- **Train/test (75/25):** el modelo se construye con *train*; *test* se guarda para evaluar con datos que nunca vio. `set.seed` hace que la partición sea reproducible; la partición es **estratificada** (misma proporción de malos).
- **Validación cruzada (10 pliegues):** se parte *train* en 10 pedazos; se entrena con 9 y se evalúa con 1, rotando. Promedia el AUC y mide estabilidad sin usar *test*.
- **Fuga de información (*data leakage*):** que el modelo "vea" de alguna forma datos de *test* durante su construcción (por ejemplo, imputar con todos los datos antes de partir, o elegir el punto de corte mirando *test*). Hace que la evaluación sea **demasiado optimista**. **Cómo la evitamos:** (1) partimos **antes** de imputar; (2) imputamos *train* solo con filas de *train*; (3) imputamos *test* usando **solo filas de *train* como donantes** (cada fila de *test* con NA se agrega sola a *train* y kNN busca vecinos ahí); (4) selección de variables y punto de corte solo con *train*; (5) *test* se usa una sola vez al final.
- En el **modelo lineal** no hay partición: se ajusta con todos los datos, así que imputar con todas las filas no genera fuga.

### 1.17 Matriz de confusión y métricas
Se fija un **punto de corte**: si P(malo) > corte, el modelo dice "malo". Se cruza lo predicho con lo real (positivo = malo):

| | Real: malo | Real: bueno |
|---|---|---|
| **Predicho: malo** | Verdaderos positivos (VP) | Falsos positivos (FP) |
| **Predicho: bueno** | Falsos negativos (FN) | Verdaderos negativos (VN) |

- **Exactitud** = (VP+VN)/total. Engaña con clases desbalanceadas (decir "todos buenos" da 72 %).
- **Sensibilidad** = VP/(VP+FN): de los malos reales, ¿cuántos detecta? (75 %)
- **Especificidad** = VN/(VN+FP): de los buenos reales, ¿cuántos aprueba bien? (76 %)
- **VPP** (precisión) = VP/(VP+FP): de los que marca como malos, ¿cuántos lo son? (55 %)
- **VPN** = VN/(VN+FN): de los que marca como buenos, ¿cuántos lo son? (88 %)
- **F1** = promedio armónico de sensibilidad y VPP (0,63).

### 1.18 ROC y AUC
- **Curva ROC:** muestra sensibilidad vs. (1 − especificidad) para **todos** los puntos de corte posibles. **AUC** = área bajo la curva: probabilidad de que el modelo asigne mayor riesgo a un mal pagador que a un buen pagador elegidos al azar. 0,5 = azar; 1 = perfecto. **Nuestro AUC en prueba: 0,83.**

### 1.19 Punto de corte y criterio de Youden
- El corte por defecto (0,5) funciona mal con pocos eventos (28 % de malos): detecta solo el 50 % de los malos. Usamos `coords(roc, "best", ret = "threshold")` (Unidad 5), que elige **el corte que maximiza a la vez la sensibilidad y la especificidad**; ese criterio se conoce como **índice de Youden** (sensibilidad + especificidad − 1: el punto de la ROC más alejado de la diagonal). Lo calculamos **solo con *train***. Resultado: **0,27**. Justificación de negocio: otorgar un crédito que no se paga cuesta más que rechazar a un buen cliente.

---

## 2. Guion de la exposición (15 minutos)

| Min | Sección del HTML | Qué decir | Qué mostrar |
|---|---|---|---|
| 0:00–1:30 | **1. Introducción** | Dataset (4454 solicitantes, 14 variables, fuente `modeldata`). Los dos objetivos en lenguaje simple. Esquema de datos: `base`, `cred`, `train/test`. | Tabla de variables |
| 1:30–5:00 | **2. Pre-procesamiento** | Las 6 técnicas, **una frase de por qué cada una**. Detenerse en **faltantes**: MCAR/MAR/MNAR, tabla de evidencia (no es MCAR), kNN, por qué no se borran casos, `Ingreso_faltante`. | Tabla de mecanismos; tabla de evidencia; boxplot observados vs. imputados |
| 5:00–6:00 | **3. Exploratorio** | 3 hallazgos: monto depende de precio y plazo; 28 % malos; antecedentes, empleo, ingreso y % financiado se asocian al riesgo. | Barras de % malos |
| 6:00–10:00 | **4–5. Lineal** | Modelo completo (R² aj. 0,66; sin multicolinealidad) → BIC deja 7 variables → supuestos: fallan homocedasticidad y normalidad; `Time` curvo → `Time²` → **¿por qué log si λ = 0,34?** (comparación log/raíz/BC) → influyentes (Cook máx. 0,019) → bootstrap y robusta dan lo mismo → modelo final y 3–4 coeficientes. | Tabla log/raíz/BC; QQ-plots; tabla IC bootstrap |
| 10:00–14:00 | **6. Logística** | Partición **antes** de imputar (fuga de información) → selección con *train* (BIC) → `log(1+Seniority)` por Hosmer-Lemeshow → OR principales (antecedentes, ingreso no informado, medio tiempo) → AUC 0,83 → corte 0,27 por Youden → matriz y métricas → con/sin `Ingreso_faltante`. | Gráfico de OR; ROC; matriz de confusión |
| 14:00–15:00 | **7. Síntesis** | 3 resultados + limitaciones (MNAR, no causalidad, residuos asimétricos, calibración). | Viñetas finales |

**Consejos:** no lean código; hablen del *por qué*. Si se atrasan, resuman el exploratorio, no los supuestos ni la fuga de información (es lo que más se pregunta).

---

## 3. Preguntas difíciles y respuestas

**1. ¿Qué tipo de faltante es el de `Income`? ¿Cómo lo saben?**
No es MCAR: para cada una de 13 variables ajustamos una regresión logística simple con `Ingreso_faltante` como respuesta y la comparamos con el modelo nulo mediante `lrtest`; 10 de 13 ayudan a explicar la ausencia (9 con Bonferroni). Ej.: 57 % mal pagadores vs. 25 %; solo 9 % con empleo fijo vs. 68 %. Es **plausible MAR** (la ausencia se asocia con variables observadas). **MNAR no se puede verificar** con los datos (si los ingresos muy bajos se ocultan, no lo veríamos). Lo declaramos como limitación.

**2. ¿Por qué no eliminaron los casos incompletos?**
Bajo MAR, usar solo casos completos **sesga** las estimaciones (Unidad 6) y perdíamos el 9,3 % de las filas, justo las de mayor riesgo.

**3. ¿Por qué imputaron con kNN y no con la media? ¿Y mice?**
La media pone el mismo valor a todos (desvío 0), subestima la variabilidad y supone MCAR. kNN usa los 5 solicitantes más parecidos según variables observadas, lo que encaja con MAR, y maneja numéricas y categóricas. mice (imputación múltiple) es una alternativa válida y más completa; no la usamos para mantener el trabajo simple. Límite de kNN: los valores imputados varían menos que los reales.

**4. ¿Qué es `Ingreso_faltante` y por qué la crearon?**
Es 1 si el ingreso faltaba y 0 si no. La creamos **antes** de imputar porque la ausencia está asociada al riesgo y la imputación borraría esa información. En el lineal no entra (p = 0,70). En la logística entra con OR ≈ 4: quienes no informaron el ingreso tienen chances 4 veces mayores de ser mal pagadores, a igualdad del resto. Sube el AUC de prueba de 0,822 a 0,828 (modesto pero consistente con la validación cruzada: 0,842 → 0,850). **No es causal**: es una señal del proceso de carga.

**5. ¿Qué es la fuga de información y cómo la evitaron?**
Que el modelo vea datos de *test* al construirse, lo que hace la evaluación demasiado optimista. Partimos 75/25 **antes** de imputar; imputamos *train* solo con *train*; imputamos *test* con donantes solo de *train* (cada fila de *test* se agrega sola al *train* imputado); selección de variables y punto de corte solo con *train*; *test* se usó una sola vez.

**6. El λ de Box-Cox es 0,34 (IC 0,31–0,38), no 0. ¿Por qué usaron log?**
Es cierto que ni 0 (log) ni 0,5 (raíz) están en el IC. Comparamos el modelo final con log, raíz y Box-Cox: R² ajustado parecido (0,661 / 0,649 / 0,657), signos y significancia de **todos** los coeficientes iguales, y los tres siguen sin cumplir normalidad ni homocedasticidad (la asimetría de residuos baja de −1,45 a −0,96 con Box-Cox, pero no desaparece). Mantenemos el log porque (a) permite interpretar en **%** y como **elasticidad**; (b) con n = 4454 los tests de normalidad rechazan desvíos pequeños y la inferencia sobre coeficientes es válida por tamaño de muestra; (c) **bootstrap y regresión robusta** confirman los resultados. Y la asimetría residual **no se debe a la transformación sino a los datos**: hay una cola de solicitantes que piden montos muy bajos respecto del precio.

**7. ¿Qué supuestos fallan en el lineal y qué hicieron?**
Fallan homocedasticidad (Breusch-Pagan) y normalidad (Anderson-Darling, QQ-plot). Linealidad: `Time` es curvo → `Time²`. Independencia: no aplica Durbin-Watson (sin orden temporal). Para lo que persiste: **bootstrap** (IC sin supuestos; casi idénticos a los clásicos) y **regresión robusta** (mismos signos, magnitudes parecidas). Las conclusiones no dependen del método.

**8. ¿Por qué BIC y no AIC?**
BIC penaliza más la complejidad (log(n) vs. 2) y con n grande evita variables de efecto mínimo. En el lineal, AIC solo descarta `Ingreso_faltante`; BIC deja 7 variables y coincide con el mejor subconjunto (`regsubsets`). El R² ajustado baja solo de 0,6555 a 0,6535: perdemos casi nada y ganamos un modelo simple.

**9. Sacaron `Age` en la logística aunque AIC la conserva. ¿Por qué?**
BIC descarta `Age` y `Time`; AIC solo `Time`. El test de razón de verosimilitud entre el modelo BIC y el AIC da p = 0,13: `Age` no mejora el ajuste de forma significativa, y el AUC por validación cruzada es igual (0,850). Elegimos por parsimonia. Con n grande casi cualquier variable da p chico; por eso miramos también la mejora práctica (AUC).

**10. ¿Por qué `log(1 + Seniority)` en la logística?**
El efecto de la antigüedad no es lineal: importa mucho pasar de 0 a pocos años y poco pasar de 20 a 25. Con `Seniority` lineal, Hosmer-Lemeshow rechazaba (p = 0,024); con `log(1+Seniority)` p = 0,55 y mejoran AIC y BIC. Además la variable es asimétrica (1,39) con 401 ceros en *train*, igual que `Assets`. Interpretación: duplicar `1 + años` (de 1 a 3 años, o de 3 a 7) **reduce un 32 %** las chances.

**11. ¿Qué es el Hosmer-Lemeshow y qué resultó?**
Compara malos esperados vs. observados en 10 grupos de riesgo (H0: buen ajuste). En *train* p = 0,55 (no rechaza). En *test* p = 0,03: desajuste leve, sobre todo en el grupo de mayor riesgo (predice 87 %, observa 76 %); con ~111 personas por grupo hay mucho ruido. El gráfico de calibración y el AUC (0,83) muestran un modelo razonablemente calibrado. Es una prueba sensible a n y a la agrupación (con 8 o 12 grupos el p cambia).

**11b. ¿Por qué no corrigieron la mala calibración en test (Hosmer-Lemeshow p ≈ 0,03)?**
Porque corregir el modelo mirando el *test* implicaría usar el *test* para ajustar el modelo, que es justamente la **fuga de información** que evitamos: el *test* se usa una sola vez, al final, y no se retoca nada después de verlo. Además, el modelo **ordena bien a los clientes** (AUC 0,83 en *test*, 0,85 en validación cruzada) y la sobreestimación se concentra en el grupo de mayor riesgo (predice 87 %, observa 76 %, con ~111 personas por grupo y mucho ruido muestral). Está **declarada como limitación**. (En *train*, donde sí se puede diagnosticar, Hosmer-Lemeshow dio p = 0,55 tras transformar `Seniority`.)

**12. ¿Por qué el corte 0,27 y no 0,5?**
Con solo 28 % de malos, 0,5 detecta apenas el 50 % de los malos. Para el banco otorgar un crédito que no se paga cuesta más que rechazar a un buen cliente. Usamos `coords(roc, "best", ret = "threshold")` (Unidad 5): el corte que maximiza a la vez sensibilidad y especificidad (índice de Youden), calculado **solo con *train***. En *test*: sensibilidad 75 %, especificidad 76 %, VPP 55 %, VPN 88 %. Si el banco tuviera costos reales, el corte se ajustaría a ellos.

**13. ¿Qué significa AUC 0,83? ¿Hay sobreajuste?**
Si tomo un mal pagador y un buen pagador al azar, el modelo asigna más riesgo al malo ~83 % de las veces. *Train* 0,854, *test* 0,828, validación cruzada 0,850: diferencia chica, **no hay sobreajuste importante**.

**14. La exactitud baja con el corte elegido (79 % → 75 %). ¿No es peor?**
La exactitud engaña con clases desbalanceadas: "todos buenos" da 72 % y no detecta ningún malo. Priorizamos sensibilidad y F1 (0,57 → 0,63).

**15. Interpreten un OR y el de `Ingreso_faltante`.**
OR de antecedentes = 6,3: tener antecedentes multiplica por 6,3 las **chances** de ser mal pagador (no la probabilidad). `Ingreso_faltante` OR ≈ 4,0: quienes no informan el ingreso tienen chances 4 veces mayores que quienes sí, con el mismo perfil (incluido el ingreso imputado). Es una señal, no una causa.

**16. ¿Por qué `Tiene_deuda` sube el riesgo si en el exploratorio no mostraba diferencia?**
En el exploratorio la comparación es bruta; el modelo **controla** por las demás variables. Quienes tienen deuda tienen más ingreso y patrimonio (que protegen) y eso enmascaraba el efecto; a igualdad de ingresos y activos, tener deuda sí aumenta el riesgo (OR 1,86).

**17. ¿Por qué "independiente" pesa poco en el modelo (OR 1,4) si en el exploratorio tenía bastante más riesgo?**
En el exploratorio los independientes tienen 33 % de mal pagadores contra 21 % de los de empleo fijo, una diferencia bruta. En el modelo el OR es solo 1,4 por un efecto de **confusión**: casi todos los que **no informan ingreso** tienen empleo no fijo, e `Ingreso_faltante` (que tiene un OR ≈ 4) **captura parte de ese efecto**. Al controlar por ella, lo que queda propio del tipo de empleo es menor. Es el mismo fenómeno de "controlar por otras variables" que con `Tiene_deuda`: la comparación bruta mezcla efectos de variables relacionadas entre sí.

**18. ¿Eliminaron outliers? ¿Por qué no?**
No. Son valores reales (ingreso 959, bien de 11140). Medimos su influencia: Cook máximo 0,019 (lejos de 1); 81 casos con |rstudent| > 3. Quitando los casos influyentes los signos se mantienen. Eliminarlos sería perder información y se preguntaría cómo se eligió el criterio; preferimos regresión robusta.

**19. ¿Para qué sirve el VIF? ¿Por qué no Ridge/Lasso?**
Detecta multicolinealidad. Los GVIF ajustados son todos < 1,8: no hay problema. Ridge/Lasso se usan cuando hay colinealidad fuerte o muchas predictoras; acá no aportarían.

**20. Interpreten el coeficiente de `log_Price` y los de `Time`.**
`log_Price` = 0,74: un bien 10 % más caro → monto ≈ +7,3 % (menos que proporcional: se financia proporcionalmente menos). Plazo: con `Time²` el efecto se desacelera; vs. 12 meses, a 24 meses se pide ~32 % más y a 60 meses ~113 % más.

**21. ¿Cómo usaron la regresión logística para estudiar el mecanismo de los faltantes?**
Creamos `Ingreso_faltante` (1/0) y, por cada variable, comparamos una regresión logística simple (`Ingreso_faltante ~ variable`) con el modelo nulo mediante `lrtest` (Unidad 5). Si la variable mejora el ajuste (p chico), ayuda a explicar la ausencia, o sea que no es MCAR. Dio significativo en 10 de 13 variables (9 con Bonferroni). Las columnas descriptivas muestran en qué sentido difieren (ej.: solo 9 % con empleo fijo entre quienes no informan ingreso vs. 68 %).

**22. ¿Por qué imputaron el lineal con todos los datos y la logística separada?**
El lineal no tiene partición ni evaluación en un conjunto de prueba, así que imputar con todas las filas no genera fuga. En la logística sí hay *test*, y ahí hay que imputarlo sin usar información de *test* en el proceso.

**23. ¿Qué limitaciones tiene el trabajo?**
(1) MNAR no verificable y kNN reduce variabilidad; (2) la fuente no informa moneda, año ni definiciones; (3) asociaciones, no causalidad; (4) residuos asimétricos y monto acotado por el precio (quizá convendría modelar la proporción financiada); (5) una sola partición (reforzada con validación cruzada) y sin interacciones; (6) corte basado en un supuesto de costos; (7) calibración en *test* buena pero no perfecta.

---

## 4. Decisiones clave en una frase

| Decisión | Por qué |
|---|---|
| Recodificar primero | La imputación funciona mejor con categorías ya agrupadas |
| Agrupar `ignore`/`other` y `divorced`/`separated`/`widow` | 20–130 casos darían coeficientes inestables |
| Demostrar que Income no es MCAR (logística simple + `lrtest` por variable, Bonferroni) | Justifica no borrar casos e imputar |
| kNN (k = 5) sin `Status` ni `Amount` | Encaja con MAR; no se mete la respuesta en las predictoras |
| `Ingreso_faltante` creada antes de imputar | Conserva la señal de que el ingreso faltaba |
| Partición **antes** de imputar; *test* con donantes de *train* | Evitar fuga de información |
| log en `Amount`, `Price`, `Income`; `log(1+x)` en `Assets` | Asimetría; efectos proporcionales; interpretación en % |
| `log(1+Seniority)` **solo en la logística** | Efecto no lineal (Hosmer-Lemeshow); en el lineal es lineal |
| `Pct_fin` solo en la logística | Contiene a la respuesta lineal |
| Mantener log pese a λ = 0,34 | Misma conclusión con raíz/Box-Cox; interpretación en %; n grande; bootstrap y robusta |
| Modelo BIC (no AIC) | Parsimonia; coincide con `regsubsets` |
| `Time²` en el lineal | Curvatura en residuos vs. `Time`; mejora BIC |
| Bootstrap + regresión robusta | Heterocedasticidad y no normalidad |
| No eliminar atípicos | Son reales; Cook máx. 0,019 |
| Corte 0,27 (Youden en *train*) | Clases desbalanceadas; costos asimétricos |
| z-scores solo para comparar importancia | Modelos finales en unidades reales |

## 5. Números clave

- **Datos:** 4454 solicitantes · 415 filas con NA (9,3 %) · `Income` faltante 381 (8,6 %) · 28,2 % mal pagadores.
- **Faltantes:** `lrtest` significativo en 10/13 variables (9 con Bonferroni) · mal pagadores 57 % vs. 25 % · empleo fijo 9 % vs. 68 % · kNN imputado: media 127, desvío 38 (observados: 142, 81).
- **Lineal:** R² aj. 0,661 · elasticidad precio 0,74 · λ Box-Cox 0,34 [0,31; 0,38] · R² aj. log/raíz/BC: 0,661/0,649/0,657 · asimetría residuos −1,45/−0,67/−0,96 · Cook máx. 0,019 · 81 con |rstudent| > 3.
- **Logística:** *train* 3341 / *test* 1113 · 12 variables, 18 coeficientes · AUC *test* 0,828, *train* 0,854, validación cruzada 0,850 · Hosmer-Lemeshow *train* p = 0,55, *test* p = 0,03 · corte 0,27 · sens. 75 %, esp. 76 %, VPP 55 %, VPN 88 %, F1 0,63 (corte 0,5: sens. 50 %, exactitud 79 %).
- **OR:** antecedentes 6,29 · ingreso no informado 4,01 · medio tiempo 3,72 · soltero 1,34 / otro estado civil 2,67 · independiente 1,40 · deuda 1,86 · duplicar ingreso 0,44 · duplicar (1+antigüedad) 0,68 · +10 puntos de % financiado 1,42.
- **Con/sin `Ingreso_faltante`:** AUC *test* 0,828 vs. 0,822; AUC validación cruzada 0,850 vs. 0,842.
