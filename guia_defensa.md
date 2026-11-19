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
- **Cómo lo comprobamos:** (1) definimos `Ingreso_faltante` (1 = el ingreso falta, 0 = observado) y comparamos los dos grupos en una tabla corta: % de mal pagadores, % con empleo fijo, % con antecedentes y antigüedad mediana. (2) Ajustamos una **regresión logística simple** con `Ingreso_faltante` como respuesta y `Status` como predictora, y la comparamos con el **modelo nulo** (solo intercepto) con el **test de razón de verosimilitud** (`lrtest`, Unidad 5). Si fuera MCAR, `Status` no ayudaría a predecir si el ingreso falta; el p da < 0,001, o sea que **sí ayuda**.
- **En nuestro trabajo:** `Income` falta en 381 casos (8,6 %). Entre quienes no informan ingreso, el 57 % es mal pagador (vs. 25,5 %), solo el 9 % tiene empleo fijo (vs. 68 %), el 28 % tiene antecedentes (vs. 16 %) y la antigüedad mediana es 3 años (vs. 5). **Conclusión: no es MCAR; es plausible MAR; MNAR no se puede descartar** (limitación).
- **Análisis de casos completos (CCA):** usar solo filas sin NA. Bajo MAR sesga (en la Unidad 6 se vio con datos simulados) y acá perdería el 9,3 % de las filas, justo de mayor riesgo.

### 1.3 Imputación: media/mediana, kNN, mice
- **Media/mediana:** reemplaza todos los NA por el mismo número. Rápido pero **subestima la variabilidad** y supone MCAR. En nuestro dato: los 381 ingresos imputados tendrían desvío 0.
- **kNN (k vecinos más cercanos):** para cada fila con NA busca las **k = 5 filas más parecidas** (en las variables completas) y completa con su promedio (o moda si es categórica). Conserva mejor la estructura de los datos y funciona con numéricas y categóricas a la vez. Lo usamos (`VIM::kNN`). *Límite:* los valores imputados son "promedios de vecinos", con **menos dispersión** que los reales (desvío 38 vs. 81 de los observados).
- **mice (imputación múltiple):** genera varios datasets completos (5 por defecto) con un modelo de regresión por variable y combina los resultados, reflejando la incertidumbre de imputar. Es una alternativa válida; **no la implementamos** para mantener el trabajo simple.
- **`Ingreso_faltante`:** variable 0/1 que indica "el ingreso faltaba". La creamos **antes** de imputar, para no perder esa información. Es de las variables más llamativas de la logística (OR ≈ 4).

### 1.4 Recodificar, derivar, transformar, escalar, atípicos
- **Recodificar:** agrupar categorías con pocos casos (ej.: `ignore`+`other`) para que los coeficientes no sean inestables. Se fija una **categoría de referencia** (la más frecuente): cada coeficiente se lee "respecto de esa".
- **Variables derivadas:** nuevas variables con sentido: `Pct_fin = 100·Monto/Precio` (qué % del bien se financia), `Tiene_deuda` (0/1), `Ingreso_faltante`.
- **Transformación logarítmica:** achata colas largas (ingreso, precio, monto, activos) y vuelve proporcionales los efectos. `log(1+x)` se usa cuando hay ceros (activos, antigüedad).
- **Cambio de escala:** **no estandarizamos** (z-score) porque queremos interpretar los coeficientes en unidades reales; comparamos variables con OR por unidad interpretable (ej.: "duplicar el ingreso", "10 puntos más financiados").
- **Atípicos:** valores extremos (regla del boxplot: más allá de 1,5 veces el rango intercuartílico). **No los eliminamos** porque son reales; evaluamos su influencia (Cook).

### 1.5 Logaritmo y elasticidad (interpretación en %)
- Si la **respuesta** está en log y una **predictora no**: el coeficiente `b` significa "cada unidad más cambia el monto en `100·(e^b − 1)` %". Ej.: antecedentes: b = 0,041 → +4,1 %.
- Si **ambas** están en log: `b` es una **elasticidad**: "1 % más de la predictora cambia la respuesta en `b` %". Ej.: precio: b = 0,74 → un bien 10 % más caro, monto ≈ +7,3 %.

### 1.6 Selección de variables: AIC, BIC y stepAIC
- **AIC y BIC:** miden calidad del modelo **penalizando la complejidad** (menor = mejor). **BIC penaliza más** (usa log(n) en vez de 2): elige modelos más chicos. Con n grande, AIC tiende a conservar variables de efecto muy chico.
- **`stepAIC`:** va sacando (*backward*) o agregando y sacando (*both*) variables, una por vez, según AIC (o BIC con `k = log(n)`).
- **En nuestro trabajo (lineal):** `stepAIC` backward; AIC solo descarta `Ingreso_faltante`; BIC deja 7 variables y baja el R² ajustado apenas de 0,6555 a 0,6535. Elegimos BIC por **parsimonia**.

### 1.7 Multicolinealidad: VIF/GVIF
- Cuando dos predictoras están muy correlacionadas, los coeficientes se vuelven inestables. **VIF** (o **GVIF** si hay categóricas, mirando `GVIF^(1/(2·Df))`) mide ese problema: valores menores a 2–5 son tranquilizadores. Los nuestros son todos < 1,8.

### 1.8 Supuestos de la regresión lineal y sus tests
| Supuesto | Qué significa | Cómo se mira | Resultado nuestro |
|---|---|---|---|
| **Linealidad** | La relación es una recta | Residuos vs. cada predictora con curva suavizada (`geom_smooth`) | `Time` curvo (U invertida) → agregamos `Time²` |
| **Homocedasticidad** | Los residuos tienen la misma dispersión | Residuos vs. ajustados; test de **Breusch-Pagan** | No se cumple (p < 0,001) |
| **Normalidad** | Los residuos son aprox. normales | **QQ-plot**; test de **Anderson-Darling** | No se cumple; cola izquierda |
| **Independencia** | Una fila no influye en otra | **Durbin-Watson** (solo si hay orden temporal) | No aplica: sin orden temporal |

- **Qué pasa si fallan:** las estimaciones siguen siendo razonables, pero los errores estándar/IC/p-valores clásicos pueden ser incorrectos. Remedios: transformar, términos polinómicos, **bootstrap** (IC sin supuestos).
- **Por qué los tests rechazan casi siempre con n grande:** con 4454 datos detectan desvíos mínimos; además, por el teorema central del límite la inferencia sobre los coeficientes sigue siendo válida aunque los residuos no sean normales.
- **Causa en nuestro dato:** hay una cola de solicitantes que piden montos muy bajos respecto del precio (financian poco y pagan casi todo de su bolsillo). Es un rasgo de los datos, no algo que se corrija cambiando la forma del modelo.

### 1.9 Atípicos e influyentes: rstudent, leverage, Cook
- **Residuo studentizado (`rstudent`):** el residuo expresado en "desvíos"; |valor| > 3 = observación mal predicha por el modelo.
- **Leverage (`hatvalues`):** qué tan "rara" es la fila en las **predictoras** (> 2p/n).
- **Distancia de Cook:** cuánto cambiarían los coeficientes si sacáramos esa fila; combina las dos ideas. Regla: > 4/n mirar; > 1 preocupante. **El máximo nuestro es 0,019**: ninguna fila domina.

### 1.10 Bootstrap
- Se **remuestrea con reposición** las filas del dataset (1000 veces), se reajusta el modelo cada vez y se mira la variación de los coeficientes. Los percentiles 2,5 % y 97,5 % dan un **IC sin supuestos de normalidad ni varianza constante**. En nuestro trabajo coincide casi exacto con el IC clásico, así que la inferencia es confiable.

### 1.11 Término cuadrático
- `I(Time^2)` permite que el efecto del plazo **se desacelere** (rendimientos decrecientes). El coeficiente cuadrático es negativo.

### 1.12 Regresión logística: odds, odds ratio, IC
- **Odds (chances)** = P(malo) / P(bueno). Con P = 0,25 → odds = 1/3.
- **Odds ratio (OR)** = cuánto se **multiplican las chances** al pasar a otra categoría o por cada unidad más de la variable. **OR > 1 aumenta el riesgo; OR < 1 lo reduce; OR = 1 no hay efecto.** Si el IC 95 % del OR incluye al 1, el efecto no se distingue de cero.
- Ej.: antecedentes, OR = 6,3 → tener antecedentes **multiplica por 6,3 las chances** de ser mal pagador (no la probabilidad).
- Con una variable en log (ej. ingreso): "duplicar el ingreso multiplica las chances por 2^b".

### 1.13 Test de razón de verosimilitud (`lrtest`)
- Compara dos modelos **anidados** (uno contiene al otro): ¿las variables extra mejoran el ajuste más de lo esperable por azar? p chico = sí mejoran. Con n grande suele dar p chico incluso para mejoras mínimas.
- **Usos en el trabajo:** (1) estudiar el mecanismo de los faltantes (`Ingreso_faltante ~ Status` vs. modelo nulo); (2) modelo BIC vs. modelo AIC en la logística; (3) aporte de `Ingreso_faltante` (modelo final vs. el mismo sin ella); (4) modelo final vs. solo intercepto.

### 1.14 Hosmer-Lemeshow
- Agrupa a los solicitantes en 10 grupos por riesgo predicho y compara **malos esperados vs. observados** en cada grupo. **H0: el ajuste es bueno.** p > 0,05 = no hay evidencia de mal ajuste (no es "prueba de buen ajuste"); es sensible al tamaño de la muestra.
- **En nuestro trabajo (solo en *train*):** con `Seniority` lineal p = 0,024 (desajuste); con `log(1+Seniority)` p = 0,55. Por eso usamos el log en la logística.

### 1.15 Partición train/test y fuga de información
- **Train/test (75/25):** el modelo se construye con *train*; *test* se guarda para evaluar con datos que nunca vio. `set.seed` hace que la partición sea reproducible; es **estratificada** (misma proporción de malos).
- **Fuga de información (*data leakage*):** que el modelo "vea" de alguna forma datos de *test* durante su construcción (por ejemplo, imputar con todos los datos antes de partir, o elegir el punto de corte mirando *test*). Hace que la evaluación sea **demasiado optimista**. **Cómo la evitamos:** (1) partimos **antes** de imputar; (2) imputamos *train* solo con filas de *train*; (3) imputamos *test* usando **solo filas de *train* como donantes** (cada fila de *test* con NA se agrega sola a *train* y kNN busca vecinos ahí); (4) selección de variables y punto de corte solo con *train*; (5) *test* se usa una sola vez al final.
- En el **modelo lineal** no hay partición: se ajusta con todos los datos, así que imputar con todas las filas no genera fuga.

### 1.16 Matriz de confusión y métricas
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

### 1.17 ROC y AUC
- **Curva ROC:** muestra sensibilidad vs. (1 − especificidad) para **todos** los puntos de corte posibles. **AUC** = área bajo la curva: probabilidad de que el modelo asigne mayor riesgo a un mal pagador que a un buen pagador elegidos al azar. 0,5 = azar; 1 = perfecto. **Nuestro AUC en prueba: 0,83** (en *train* 0,85: no hay sobreajuste importante).

### 1.18 Punto de corte y criterio de Youden
- El corte por defecto (0,5) funciona mal con pocos eventos (28 % de malos): detecta solo el 50 % de los malos. Usamos `coords(roc, "best", ret = "threshold")` (Unidad 5), que elige **el corte que maximiza a la vez la sensibilidad y la especificidad**; ese criterio se conoce como **índice de Youden** (sensibilidad + especificidad − 1). Lo calculamos **solo con *train***. Resultado: **0,27**. Justificación de negocio: otorgar un crédito que no se paga cuesta más que rechazar a un buen cliente.

---

## 2. Guion de la exposición (15 minutos)

| Min | Sección del HTML | Qué decir | Qué mostrar |
|---|---|---|---|
| 0:00–1:30 | **1. Introducción** | Dataset (4454 solicitantes, 14 variables, fuente `modeldata`). Los dos objetivos en lenguaje simple. Esquema de datos: `base`, `cred`, `train/test`. | Tabla de variables |
| 1:30–5:00 | **2. Pre-procesamiento** | Las 6 técnicas, **una frase de por qué cada una**. Detenerse en **faltantes**: MCAR/MAR/MNAR, tabla descriptiva + `lrtest` (no es MCAR), kNN, por qué no se borran casos, `Ingreso_faltante`. | Tabla de mecanismos; tabla "ingreso faltante vs. observado"; histogramas antes/después del log |
| 5:00–6:00 | **3. Exploratorio** | 3 hallazgos: monto depende de precio y plazo; 28 % malos; antecedentes, empleo, ingreso y % financiado se asocian al riesgo. | Monto vs. precio; barras de % malos |
| 6:00–10:00 | **4–5. Lineal** | Modelo completo (R² aj. 0,66; sin multicolinealidad) → `stepAIC`: BIC deja 7 variables → supuestos: fallan homocedasticidad y normalidad; `Time` curvo → `Time²` → influyentes (Cook máx. 0,019) → bootstrap da lo mismo que el IC clásico → modelo final y 3–4 coeficientes. | Residuos y QQ; residuos vs. predictoras; tabla de coeficientes |
| 10:00–14:00 | **6. Logística** | Partición **antes** de imputar (fuga de información) → selección con *train* (BIC y `lrtest`) → `log(1+Seniority)` por Hosmer-Lemeshow → OR principales (antecedentes, ingreso no informado, medio tiempo) → AUC 0,83 → corte 0,27 (`coords`, Youden) → matriz y métricas con 0,5 vs. 0,27. | Gráfico de OR; ROC; tabla de métricas |
| 14:00–15:00 | **7. Síntesis** | 3 resultados + limitaciones (MNAR, no causalidad, residuos asimétricos). | Viñetas finales |

**Consejos:** no lean código; hablen del *por qué*. Si se atrasan, resuman el exploratorio, no los supuestos ni la fuga de información (es lo que más se pregunta).

---

## 3. Preguntas difíciles y respuestas

**1. ¿Qué tipo de faltante es el de `Income`? ¿Cómo lo saben?**
No es MCAR: quienes no informan ingreso difieren claramente de los demás (57 % mal pagadores vs. 25 %; 9 % con empleo fijo vs. 68 %; más antecedentes; menos antigüedad), y una regresión logística simple de `Ingreso_faltante` sobre `Status` es mejor que el modelo nulo (`lrtest`, p < 0,001). Es **plausible MAR** (la ausencia se asocia con variables observadas). **MNAR no se puede verificar** con los datos (si los ingresos muy bajos se ocultan, no lo veríamos). Lo declaramos como limitación.

**2. ¿Por qué no eliminaron los casos incompletos?**
Bajo MAR, usar solo casos completos **sesga** las estimaciones (Unidad 6) y perdíamos el 9,3 % de las filas, justo las de mayor riesgo.

**3. ¿Por qué imputaron con kNN y no con la media? ¿Y mice?**
La media pone el mismo valor a todos (desvío 0), subestima la variabilidad y supone MCAR. kNN usa los 5 solicitantes más parecidos según variables observadas, lo que encaja con MAR, y maneja numéricas y categóricas. mice (imputación múltiple) es una alternativa válida y más completa; no la usamos para mantener el trabajo simple. Límite de kNN: los valores imputados varían menos que los reales.

**4. ¿Qué es `Ingreso_faltante` y por qué la crearon?**
Es 1 si el ingreso faltaba y 0 si no. La creamos **antes** de imputar porque la ausencia está asociada al riesgo y la imputación borraría esa información. En el lineal no entra (p = 0,70). En la logística entra con OR ≈ 4: quienes no informaron el ingreso tienen chances 4 veces mayores de ser mal pagadores, a igualdad del resto, y su aporte es significativo (`lrtest` contra el mismo modelo sin ella: p < 0,001). **No es causal**: es una señal del proceso de carga.

**5. ¿Qué es la fuga de información y cómo la evitaron?**
Que el modelo vea datos de *test* al construirse, lo que hace la evaluación demasiado optimista. Partimos 75/25 **antes** de imputar; imputamos *train* solo con *train*; imputamos *test* con donantes solo de *train* (cada fila de *test* se agrega sola al *train* imputado); selección de variables y punto de corte solo con *train*; *test* se usó una sola vez.

**6. ¿Por qué usaron logaritmo para el monto?**
Porque el monto, el precio y el ingreso son asimétricos a la derecha (cola larga) y el logaritmo los simetriza; además los efectos del dinero son proporcionales, y el log permite interpretar los coeficientes en **%** y el del precio como **elasticidad**. Con otras potencias los coeficientes quedarían en unidades difíciles de explicar. El logaritmo no arregla todo: quedan heterocedasticidad y residuos asimétricos, pero eso se debe a los **datos** (cola de montos muy bajos respecto del precio), y lo abordamos con `Time²` y bootstrap.

**7. ¿Qué supuestos fallan en el lineal y qué hicieron?**
Fallan homocedasticidad (Breusch-Pagan) y normalidad (Anderson-Darling, QQ-plot). Linealidad: `Time` es curvo → `Time²`. Independencia: no aplica Durbin-Watson (sin orden temporal). Para lo que persiste: **bootstrap** (IC sin supuestos; casi idénticos a los clásicos). Además, con n grande la inferencia es válida por el teorema central del límite.

**8. ¿Por qué BIC y no AIC?**
BIC penaliza más la complejidad (log(n) vs. 2) y con n grande evita variables de efecto mínimo. En el lineal, AIC solo descarta `Ingreso_faltante`; BIC deja 7 variables. El R² ajustado baja solo de 0,6555 a 0,6535: perdemos casi nada y ganamos un modelo simple.

**9. Sacaron `Age` en la logística aunque AIC la conserva. ¿Por qué?**
BIC descarta `Age` y `Time`; AIC solo `Time`. El test de razón de verosimilitud entre el modelo BIC y el AIC da p = 0,13: `Age` no mejora el ajuste de forma significativa. Elegimos por parsimonia. Con n grande casi cualquier variable da p chico, así que es razonable preferir el modelo más simple.

**10. ¿Por qué `log(1 + Seniority)` en la logística?**
El efecto de la antigüedad no es lineal: importa mucho pasar de 0 a pocos años y poco pasar de 20 a 25. Con `Seniority` lineal, Hosmer-Lemeshow rechazaba (p = 0,024); con `log(1+Seniority)` p = 0,55 y mejoran AIC y BIC. Además la variable es asimétrica (1,39) con 401 ceros en *train*, igual que `Assets`. Interpretación: duplicar `1 + años` (de 1 a 3 años, o de 3 a 7) **reduce un 32 %** las chances.

**11. ¿Qué es el Hosmer-Lemeshow y qué resultó?**
Compara malos esperados vs. observados en 10 grupos de riesgo (H0: buen ajuste). Lo evaluamos solo en *train*: p = 0,55 con el modelo final (no rechaza); no rechazar no prueba que el ajuste sea perfecto, solo que no detectamos desajuste.

**12. ¿Por qué el corte 0,27 y no 0,5?**
Con solo 28 % de malos, 0,5 detecta apenas el 50 % de los malos. Para el banco otorgar un crédito que no se paga cuesta más que rechazar a un buen cliente. Usamos `coords(roc, "best", ret = "threshold")` (Unidad 5): el corte que maximiza a la vez sensibilidad y especificidad (índice de Youden), calculado **solo con *train***. En *test*: sensibilidad 75 %, especificidad 76 %, VPP 55 %, VPN 88 %. Si el banco tuviera costos reales, el corte se ajustaría a ellos.

**13. ¿Qué significa AUC 0,83? ¿Hay sobreajuste?**
Si tomo un mal pagador y un buen pagador al azar, el modelo asigna más riesgo al malo ~83 % de las veces. *Train* 0,854 y *test* 0,828: diferencia chica, **no hay sobreajuste importante**.

**14. La exactitud baja con el corte elegido (79 % → 75 %). ¿No es peor?**
La exactitud engaña con clases desbalanceadas: "todos buenos" da 72 % y no detecta ningún malo. Priorizamos sensibilidad y F1 (0,57 → 0,63).

**15. Interpreten un OR y el de `Ingreso_faltante`.**
OR de antecedentes = 6,3: tener antecedentes multiplica por 6,3 las **chances** de ser mal pagador (no la probabilidad). `Ingreso_faltante` OR ≈ 4,0: quienes no informan el ingreso tienen chances 4 veces mayores que quienes sí, con el mismo perfil (incluido el ingreso imputado). Es una señal, no una causa.

**16. ¿Por qué `Tiene_deuda` sube el riesgo si en el exploratorio no mostraba diferencia?**
En el exploratorio la comparación es bruta; el modelo **controla** por las demás variables. Quienes tienen deuda tienen más ingreso y patrimonio (que protegen) y eso enmascaraba el efecto; a igualdad de ingresos y activos, tener deuda sí aumenta el riesgo (OR 1,86).

**17. ¿Por qué "independiente" pesa poco en el modelo (OR 1,4) si en el exploratorio tenía bastante más riesgo?**
En el exploratorio los independientes tienen 33 % de mal pagadores contra 21 % de los de empleo fijo, una diferencia bruta. En el modelo el OR es solo 1,4 por un efecto de **confusión**: casi todos los que **no informan ingreso** tienen empleo no fijo, e `Ingreso_faltante` (que tiene un OR ≈ 4) **captura parte de ese efecto**. Al controlar por ella, lo que queda propio del tipo de empleo es menor. Es el mismo fenómeno de "controlar por otras variables" que con `Tiene_deuda`.

**18. ¿Eliminaron outliers? ¿Por qué no?**
No. Son valores reales (ingreso 959, bien de 11140). Medimos su influencia: Cook máximo 0,019 (lejos de 1); 81 casos con |rstudent| > 3. Quitando los casos influyentes los signos se mantienen. Eliminarlos sería perder información y habría que justificar el criterio.

**19. ¿Para qué sirve el VIF?**
Detecta multicolinealidad. Los GVIF ajustados son todos < 1,8: no hay problema.

**20. Interpreten el coeficiente de `log_Price` y los de `Time`.**
`log_Price` = 0,74: un bien 10 % más caro → monto ≈ +7,3 % (menos que proporcional: se financia proporcionalmente menos). Plazo: con `Time²` el efecto se desacelera; vs. 12 meses, a 24 meses se pide ~32 % más y a 60 meses ~113 % más.

**21. ¿Cómo usaron la regresión logística para estudiar el mecanismo de los faltantes?**
Creamos `Ingreso_faltante` (1/0) y ajustamos una regresión logística simple con esa respuesta y `Status` como predictora; la comparamos con el modelo nulo mediante `lrtest` (Unidad 5). Si `Status` mejora el ajuste (p chico), ayuda a explicar la ausencia, o sea que no es MCAR. Dio p < 0,001. La tabla descriptiva muestra en qué sentido difieren los grupos (ej.: solo 9 % con empleo fijo entre quienes no informan ingreso vs. 68 %).

**22. ¿Por qué imputaron el lineal con todos los datos y la logística separada?**
El lineal no tiene partición ni evaluación en un conjunto de prueba, así que imputar con todas las filas no genera fuga. En la logística sí hay *test*, y ahí hay que imputarlo sin usar información de *test* en el proceso.

**23. ¿Por qué los AIC y BIC del modelo lineal son negativos?**
Porque se calcularon como los muestra `stepAIC`, que omite una constante; por eso pueden dar negativos. No es un error: solo importan las **diferencias entre modelos** (menor = mejor), y esas no cambian (por ejemplo, `Time²` mejora el BIC en 87 puntos). En la logística los valores son los habituales (positivos).

**24. ¿Por qué no estandarizaron las variables?**
Porque queremos interpretar los coeficientes en unidades reales (años, meses, %). Las comparaciones entre variables se hacen con OR por unidad interpretable (duplicar el ingreso, 10 puntos más financiados, etc.), y la regresión no lo necesita (no usamos Ridge/Lasso, que sí son sensibles a la escala).

**25. ¿Qué limitaciones tiene el trabajo?**
(1) MNAR no verificable y kNN reduce variabilidad; (2) la fuente no informa moneda, año ni definiciones; (3) asociaciones, no causalidad; (4) residuos asimétricos y monto acotado por el precio (quizá convendría modelar la proporción financiada); (5) una sola partición y sin interacciones; (6) corte basado en un supuesto de costos.

---

## 4. Decisiones clave en una frase

| Decisión | Por qué |
|---|---|
| Recodificar primero | La imputación funciona mejor con categorías ya agrupadas |
| Agrupar `ignore`/`other` y `divorced`/`separated`/`widow` | 20–130 casos darían coeficientes inestables |
| Mostrar que Income no es MCAR (tabla descriptiva + `lrtest` con `Status`) | Justifica no borrar casos e imputar |
| kNN (k = 5) sin `Status` ni `Amount` | Encaja con MAR; no se mete la respuesta en las predictoras |
| `Ingreso_faltante` creada antes de imputar | Conserva la señal de que el ingreso faltaba |
| Partición **antes** de imputar; *test* con donantes de *train* | Evitar fuga de información |
| log en `Amount`, `Price`, `Income`; `log(1+x)` en `Assets` | Asimetría; efectos proporcionales; interpretación en % |
| `log(1+Seniority)` **solo en la logística** | Efecto no lineal (Hosmer-Lemeshow en *train*); en el lineal es lineal |
| `Pct_fin` solo en la logística | Contiene a la respuesta lineal |
| No estandarizar | Coeficientes en unidades reales |
| `stepAIC` backward y modelo BIC | Parsimonia |
| `Time²` en el lineal | Curvatura en residuos vs. `Time`; mejora BIC |
| Bootstrap | Heterocedasticidad y no normalidad |
| No eliminar atípicos | Son reales; Cook máx. 0,019 |
| Corte 0,27 (`coords`, Youden, en *train*) | Clases desbalanceadas; costos asimétricos |

## 5. Números clave

- **Datos:** 4454 solicitantes · 415 filas con NA (9,3 %) · `Income` faltante 381 (8,6 %) · 28,2 % mal pagadores.
- **Faltantes:** mal pagadores 57 % vs. 25,5 % · empleo fijo 9 % vs. 68 % · antecedentes 28 % vs. 16 % · antigüedad mediana 3 vs. 5 · `lrtest` con `Status` p < 0,001 · kNN imputado: media 127, desvío 38 (observados: 142, 81).
- **Lineal:** R² aj. 0,661 · elasticidad precio 0,74 · BIC deja 7 variables (R² aj. 0,6535 vs. 0,6555 del completo) · mejora de BIC con `Time²`: 87 puntos · Cook máx. 0,019 · 81 con |rstudent| > 3.
- **Logística:** *train* 3341 / *test* 1113 · 12 variables, 18 coeficientes · AUC *test* 0,828, *train* 0,854 · Hosmer-Lemeshow *train* p = 0,55 (0,024 con `Seniority` lineal) · corte 0,27 · sens. 75 %, esp. 76 %, VPP 55 %, VPN 88 %, F1 0,63 (corte 0,5: sens. 50 %, exactitud 79 %).
- **OR:** antecedentes 6,29 · ingreso no informado 4,01 · medio tiempo 3,72 · soltero 1,34 / otro estado civil 2,67 · independiente 1,40 · deuda 1,86 · duplicar ingreso 0,44 · duplicar (1+antigüedad) 0,68 · +10 puntos de % financiado 1,42.
