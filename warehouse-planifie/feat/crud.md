# Funcionalidad de gestión de datos base

Este documento describe, en palabras, cómo se administran los datos base del
almacén. Estos datos son los que después alimentarán las entregas y los reportes,
por eso primero se dejan bien definidos y ordenados.

Se trabaja con cuatro conjuntos de datos:

1. **Categorías**
2. **Productos**
3. **Modelos de caja**
4. **Detalle de productos por área**

---

## 1. Categorías

Sirve para clasificar los productos (cerámica, porcelanato, inodoros, accesorios, etc.).

- **Registrar:** se crea una categoría con un nombre.
- **Consultar:** se listan todas las categorías y se puede buscar por nombre.
- **Editar:** se puede cambiar el nombre de una categoría existente.
- **Eliminar:** solo se puede eliminar una categoría que no tenga productos asociados.

**Reglas:**
- El nombre de la categoría no puede repetirse.
- El nombre es obligatorio.

---

## 2. Productos

Es el catálogo de todo lo que se maneja en el almacén.

- **Registrar:** se ingresa el código, el nombre, la categoría y el tipo de producto.
  - La categoría se elige de la lista ya creada (no se escribe a mano).
  - El tipo es **UNIT** (se entrega por unidad) o **AREA** (se entrega por m²).
- **Consultar:** se listan los productos y se puede buscar por código, por nombre o
  filtrar por categoría y por tipo.
- **Editar:** se pueden modificar sus datos.
- **Eliminar:** se puede quitar un producto del catálogo.

**Reglas:**
- El código es único y obligatorio.
- El tipo solo puede ser UNIT o AREA.
- Todo producto debe tener una categoría válida.

---

## 3. Modelos de caja

Es un catálogo de las cajas disponibles, para no escribir las mismas medidas una y otra vez.

Cada modelo guarda:
- El formato (por ejemplo, 45X45).
- Los metros cuadrados que trae una caja.
- Los metros cuadrados que mide una pieza.
- Cuántas piezas trae una caja.

Funcionalidad:
- **Registrar:** se crea un modelo con esos cuatro datos.
- **Consultar:** se listan los modelos y se puede buscar por formato.
- **Editar:** se pueden corregir sus medidas.
- **Eliminar:** solo se puede eliminar un modelo que no esté siendo usado por ningún producto.

**Reglas:**
- La cantidad de piezas por caja debe ser mayor que cero.
- Los metros cuadrados por caja y por pieza deben ser mayores que cero.
- No se repite el mismo modelo (mismo formato con la misma cantidad de piezas).

---

## 4. Detalle de productos por área

Solo aplica a los productos de tipo **AREA**. Aquí se indica qué modelo de caja usa
cada producto.

Funcionalidad:
- **Asignar:** al registrar o editar un producto de tipo AREA, se elige un modelo de
  caja del catálogo. Al seleccionarlo, sus medidas (formato, m² por caja, m² por pieza
  y piezas por caja) se muestran automáticamente en el formulario, sin tener que
  escribirlas.
- **Consultar:** al ver un producto, se ve qué modelo de caja tiene asociado y sus medidas.
- **Cambiar:** se puede reemplazar el modelo de caja asignado.
- **Quitar:** si el producto deja de ser de tipo AREA, se elimina su detalle.

**Reglas:**
- Un producto de tipo AREA tiene exactamente un modelo de caja.
- Un producto de tipo UNIT no tiene modelo de caja.
- El modelo de caja elegido debe existir en el catálogo.
- Las medidas se toman siempre del modelo de caja; no se guardan copias aparte, para
  evitar que un dato quede desactualizado o con diferencias.

---

## Cómo se relacionan los datos

- Una **categoría** puede tener muchos **productos**.
- Un **producto** pertenece a una sola **categoría**.
- Un **producto** de tipo AREA tiene un **detalle de área**.
- Un **detalle de área** apunta a un **modelo de caja**.
- Un **modelo de caja** puede ser usado por muchos **productos**.

Para proteger la información entre ellos:
- No se elimina una categoría que tenga productos.
- No se elimina un modelo de caja que esté en uso.
- Al eliminar un producto, se elimina también su detalle de área.
- No se puede guardar un detalle de área sin un producto y un modelo de caja válidos.

---

## 5. Stock

El stock representa lo que el sistema cree que debe haber por producto.

- **Inicializar:** al crear un producto, se puede registrar su stock inicial (cantidad teórica).
- **Consultar:** se puede ver el stock de cada producto (cantidad teórica). Para productos `AREA` se muestra también su equivalente en cajas y piezas, solo en la visualización (los datos se guardan en m²).
- **Ajustar por movimientos:** el stock teórico cambia solo con movimientos (entradas/salidas). No se modifica al registrar un conteo físico.

**Reglas:**
- El stock puede quedar negativo. Eso indica un **faltante a pedir a otra bodega**.
- La cantidad teórica se mantiene únicamente por movimientos registrados en el kardex.

## 6. Conteos físicos (inventario físico)

Sirven para comparar lo que hay físicamente con lo que el sistema tiene registrado, sin cambiar el stock.

- **Registrar conteo:** por cada producto se registra la cantidad contada físicamente, el momento, quién lo hizo y una observación.
- **Consultar histórico:** se pueden ver los conteos anteriores (quién, cuándo, diferencia).
- **Comparar:** en cada conteo se guarda la cantidad teórica en ese momento y la diferencia (`cantidad contada - cantidad teórica al momento del conteo`).

**Reglas:**
- **No modifica el stock.** Es solo histórico/comparativo.
- La diferencia puede ser positiva (sobrante) o negativa (faltante de conteo).

## 7. Comprobantes (vouchers)

Los comprobantes registran entradas o salidas de mercadería.

- **Registrar:** se crea un comprobante con número, tipo y observaciones.
- **Consultar:** se listan comprobantes y se puede ver su detalle (ítems).
- **Anular:** un comprobante puede pasar a anulado. Al anularlo, se revierten los movimientos que generó para dejar el stock correcto.
- **Tipos:** `FACTURA`, `NOTA_ENTREGA`, `TRANSF_INGRESO`, `TRANSF_EGRESO`.
- **Estados:** `PENDIENTE`, `PARCIAL`, `COMPLETADO`, `ANULADO`.

**Reglas:**
- Al anular un comprobante, se revierten todos sus movimientos en kardex.

## 8. Ítems de comprobante (voucher_items)

Cada comprobante tiene líneas con los productos y las cantidades solicitadas.

- **Agregar ítem:** se agrega un producto y su cantidad total (en unidad base: m² para AREA, unidades para UNIT).
- **Consultar:** se ve por comprobante.
- **Despachar:** la cantidad despachada aumenta conforme se registran despachos parciales.
- **Estados por ítem:** `PENDIENTE`, `PARCIAL`, `COMPLETADO`.

**Reglas:**
- La cantidad total debe ser mayor que cero.
- La cantidad despachada nunca puede ser mayor que la cantidad total.
- La cantidad pendiente se **calcula** como `cantidad total - cantidad despachada` (no se guarda). Nunca es negativa.
- Un ítem pasa a `COMPLETADO` cuando la cantidad despachada iguala a la cantidad total. Mientras quede pendiente, pasa a `PARCIAL`.

## 9. Despachos (dispatches)

Registran cada despacho parcial realizado por ítem de comprobante.

- **Registrar despacho:** se indica cuánta cantidad se despacha (en unidad base). Se guarda la fecha y hora del despacho.
- **Consultar:** se puede ver el historial de despachos por ítem o por comprobante.
- **Reglas:**
  - La cantidad despachada debe ser mayor que cero.
  - No se puede despachar más de lo que queda pendiente por ese ítem.
  - Para productos `AREA`, el cálculo a cajas y piezas se hace al momento de despachar/mostrar, nunca se guarda en base de datos.

## 10. Kardex (movimientos de inventario)

Es el libro de movimientos. Registra todas las entradas y salidas que afectan al stock teórico.

- **Registrar movimiento:** cada operación que modifica el stock crea un movimiento con tipo, signo, cantidad y referencia al comprobante cuando corresponde.
- **Consultar:** se puede consultar el historial por producto o por comprobante.
- **Tipos de movimiento:** `TRANSFERENCIA_INGRESO` (entrada), `TRANSFERENCIA_EGRESO` (salida), `FACTURACION` (salida), `NOTA_ENTREGA` (salida), `ANULACION` (reversión).
- **Signo:** `+` para entradas, `-` para salidas.

**Reglas:**
- El kardex es la **fuente única de verdad** para modificar el `stock teórico`.
- Todo movimiento tiene cantidad positiva (valor absoluto). El efecto lo indica el signo.
- Cuando un comprobante se anula, se generan movimientos de tipo `ANULACION` con signo inverso a los movimientos originales de ese comprobante.
- Cada movimiento vinculado a un comprobante guarda esa referencia para mantener trazabilidad.

## Cómo se relacionan los datos (operativos)

- Un **producto** tiene **stock**.
- Los **conteos físicos** se registran por **producto** (histórico).
- Un **comprobante** tiene uno o varios **ítems de comprobante**.
- Un **ítem de comprobante** genera uno o varios **despachos**.
- Los **movimientos del kardex** afectan a un **producto** y pueden estar vinculados a un **comprobante**.
