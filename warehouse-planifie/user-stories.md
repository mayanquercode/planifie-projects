# Historias de Usuario — Bodega (Warehouse Planifie)

## 1. Contexto / Épico

**Épico:** Gestión de bodega de cerámica, porcelanato y accesorios.

**Actor principal:** Encargado de bodega.

**Objetivo:** Despachar, recibir y trasladar mercadería, manteniendo control exacto del stock (existencia, faltantes y sobrantes), con soporte especial para el cálculo de cajas y piezas de productos que se venden por m².

**Tipos de producto:**

| Tipo | Descripción | Ejemplo |
|------|-------------|---------|
| `UNIT` | Se despacha por unidad | inodoros, accesorios, "Empore salmon" |
| `AREA` | Se despacha por m² | cerámica, porcelanato, "Galazy bulis deco" |

---

## 2. Historias de usuario

| ID | Historia | Prioridad |
|----|----------|-----------|
| HU-01 | Despachar factura (con cálculo de cajas/piezas para AREA) | **Alta (core)** |
| HU-02 | Recibir producto desde otra bodega | Alta |
| HU-03 | Enviar/trasladar producto a otra bodega | Alta |
| HU-04 | Mantener facturas pendientes de despacho | Media |
| HU-05 | Consultar existencias de material | Alta |
| HU-06 | Detectar faltantes y sobrantes de material | Alta |

---

### HU-01 — Despachar una factura

> **Como** encargado de bodega,
> **quiero** registrar el despacho de una factura y que el sistema me diga cuántas **cajas** y **piezas** entregar de cada producto por m²,
> **para** entregar la cantidad correcta sin hacer el cálculo a mano ni equivocarme.

**Datos del producto AREA necesarios:**

| Dato | Descripción | Ejemplo |
|------|-------------|---------|
| `areaCaja` | Área por caja (m²) | 2.36 |
| `areaPieza` | Área por pieza (m²) | 0.34 |
| `piezasPorCaja` | Piezas por caja | 7 |

**Regla de cálculo (producto AREA):**

```
cajasCompletas = floor(cantidadSolicitada / areaCaja)
resto          = cantidadSolicitada - (cajasCompletas * areaCaja)
piezas         = ceil(resto / areaPieza)

si piezas >= piezasPorCaja:
    cajasCompletas += floor(piezas / piezasPorCaja)
    piezas          = piezas % piezasPorCaja

areaEntregada  = cajasCompletas * areaCaja + piezas * areaPieza
sobrante       = areaEntregada - cantidadSolicitada
```

**Ejemplo trabajado — "Galazy bulis deco", factura pide 20.34 m²:**

| Paso | Cálculo | Resultado |
|------|---------|-----------|
| Cajas completas | `floor(20.34 / 2.36)` | 8 cajas → 18.88 m² |
| Resto | `20.34 − 18.88` | 1.46 m² |
| Piezas | `ceil(1.46 / 0.34)` | 5 piezas → 1.70 m² |
| **Resultado** | 8 cajas + 5 piezas | **20.58 m²** (0.24 m² de más) |

**Criterios de aceptación:**

```gherkin
Escenario: Producto AREA se convierte a cajas y piezas
  Dado un producto AREA "Galazy bulis deco"
    Y areaCaja = 2.36, areaPieza = 0.34, piezasPorCaja = 7
  Cuando la factura pide 20.34 m²
  Entonces el sistema muestra "8 cajas y 5 piezas"
    Y el área total a entregar es 20.58 m²

Escenario: Producto UNIT se entrega exacto
  Dado un producto UNIT "Empore salmon"
  Cuando la factura pide 2 unidades
  Entonces el sistema muestra "2 unidades"

Escenario: La cantidad cabe exacto en cajas
  Dado un producto AREA con areaCaja = 2.36
  Cuando la factura pide 4.72 m²
  Entonces el sistema muestra "2 cajas y 0 piezas"

Escenario: El resto de piezas completa una caja
  Dado un producto AREA con areaPieza = 0.34 y piezasPorCaja = 7
  Cuando el resto por entregar es >= 2.38 m²
  Entonces el sistema convierte esas piezas en 1 caja adicional

Escenario: Despacho con stock insuficiente deja saldo negativo
  Dado un producto con stock de 2.40 m²
  Cuando la factura pide 4.80 m²
  Entonces el sistema permite el despacho
    Y deja el stock en -2.40 m²
    Y marca un faltante de 2.40 m² a solicitar desde otra bodega

Escenario: Despacho parcial de factura
  Dado una factura con un ítem de 10.00 m² pendiente
  Cuando se despachan 4.00 m²
  Entonces el ítem pasa a estado "PARCIAL"
    Y la factura pasa a estado "PARCIAL"
    Y queda pendiente 6.00 m² (calculado)

Escenario: Despacho completa ítem y cierra factura
  Dado una factura con un ítem de 10.00 m² con 4.00 m² despachados
  Cuando se despachan 6.00 m² restantes
  Entonces el ítem pasa a estado "COMPLETADO"
    Y la factura pasa a estado "COMPLETADO"

Escenario: Despacho registra movimiento en kardex
  Dado una factura que se despacha
  Cuando se confirma el despacho
  Entonces se registra un movimiento en kardex con movement_type "FACTURACION", signo "-" y voucher_id vinculado
```

> ⚠️ En el relevamiento original aparece "Empore salmon" con cantidad **2** en la factura y luego "que es **3** se entrega 3". Se asume error de tipeo; confirmar.

---

### HU-02 — Recibir producto desde otra bodega

> **Como** encargado de bodega,
> **quiero** registrar el ingreso de producto que llega desde otra bodega,
> **para** que mi stock aumente automáticamente.

**Criterios de aceptación:**
- Permite registrar producto, tipo (`UNIT`/`AREA`), cantidad y bodega de origen.
- Para `AREA`, permite ingresar por cajas+piezas **o** por m², y calcula el otro valor.
- Al confirmar, **genera un movimiento en kardex** (`TRANSFERENCIA_INGRESO`, signo `+`) vinculado al comprobante (`voucher_id`).
- El `system_quantity` aumenta únicamente por el kardex (fuente única de verdad).
- Puede usarse para cubrir un faltante previamente generado (saldo negativo vuelve hacia 0).

```gherkin
Escenario: Recepción de producto AREA en m²
  Dado un producto AREA con saldo de -2.40 m²
  Cuando recibo 2.40 m² desde otra bodega
  Entonces el stock queda en 0 m²

Escenario: Recepción genera movimiento en kardex
  Dado una recepción desde otra bodega
  Cuando se confirma
  Entonces existe un registro en kardex con movement_type "TRANSFERENCIA_INGRESO", movement_sign "+", voucher_id no nulo y quantity > 0
```

---

### HU-03 — Enviar producto a otra bodega

> **Como** encargado de bodega,
> **quiero** registrar el envío de producto a otra bodega,
> **para** descontarlo de mi inventario y dejar trazabilidad del movimiento.

**Criterios de aceptación:**
- Descuenta del stock propio y registra la bodega destino.
- Para `AREA`, permite ingresar/deducir por cajas+piezas o por m².
- Registra fecha y usuario del movimiento.
- **Genera movimiento en kardex** (`TRANSFERENCIA_EGRESO`, signo `-`) vinculado al comprobante (`voucher_id`).
- El `system_quantity` disminuye únicamente por el kardex (fuente única de verdad).

---

### HU-04 — Facturas pendientes

> **Como** encargado de bodega,
> **quiero** guardar facturas pendientes y despacharlas después,
> **para** no perder pedidos que no tengo listos al momento.

**Criterios de aceptación:**
- Los comprobantes de tipo `FACTURA` mantienen su estado (`PENDIENTE` / `PARCIAL` / `COMPLETADO` / `ANULADO`).
- El estado de cada ítem (`PENDIENTE` / `PARCIAL` / `COMPLETADO`) se actualiza con cada despacho.
- La cantidad pendiente se **calcula** como `total_quantity - dispatched_quantity` (no se guarda en base de datos).
- Una factura pendiente puede despacharse total o parcialmente.
- Al despachar, se aplica la misma lógica de cálculo de HU-01.
- Cada despacho parcial se registra en `dispatches` con la cantidad despachada (en unidad base).
- Al completar el último ítem, el comprobante pasa a `COMPLETADO`.
- Al anular un comprobante (`ANULADO`), se generan movimientos de `ANULACION` con signo inverso para revertir lo aplicado en kardex.

---

### HU-05 — Consultar existencias

> **Como** encargado de bodega,
> **quiero** saber la cantidad de material que tengo,
> **para** responder rápido qué hay disponible.

**Criterios de aceptación:**
- Para productos `AREA`: muestra el stock en m² **y** su equivalente en cajas/piezas (calculado solo en la vista).
- Para productos `UNIT`: muestra el stock en unidades.
- Permite buscar/filtrar por producto.
- El stock mostrado corresponde a `stock.system_quantity` (derivado únicamente de `kardex`).

```gherkin
Escenario: Stock AREA en m² y en cajas/piezas
  Dado un producto AREA con stock de 20.58 m²
    Y areaCaja = 2.36, areaPieza = 0.34
  Entonces el sistema muestra "20.58 m² (8 cajas + 5 piezas)"
```

---

### HU-06 — Faltantes y sobrantes

> **Como** encargado de bodega,
> **quiero** que el stock pueda quedar en negativo al despachar,
> **para** saber exactamente cuánto material me falta y pedirlo a otra bodega.

**Criterios de aceptación:**
- El despacho **no se bloquea** por falta de stock.
- El stock resultante se muestra como saldo negativo (ej: `-2.40 m²`).
- El faltante operativo = `cantidad solicitada − stock disponible` (señal para pedir a otra bodega).
- El faltante se muestra en **m²** y, para productos `AREA`, su equivalente en **cajas y piezas** (calculado solo en la vista).
- Los productos con saldo negativo aparecen en una lista de "a pedir / reposición".
- El signo indica el estado: `negativo = falta`, `positivo = sobra`.
- La discrepancia de conteo físico no modifica el stock. Se registra en el histórico de conteos (`inventory_counts`) como `difference = cantidad contada − stock teórico al momento del conteo`.

```gherkin
Escenario: Lista de reposición por faltante
  Dado que un producto quedó en -2.40 m²
  Cuando consulto faltantes
  Entonces aparece en la lista como "solicitar a otra bodega"
    Y muestra el faltante en m² y su equivalente en cajas/piezas
```

---

## 3. Reglas de negocio

1. El `areaCaja` es el dato autoritativo; `areaPieza` es referencial (2.36 / 7 ≈ 0.337, redondeado a 0.34).
2. Se permite **abrir cajas** para vender piezas sueltas; por eso el resultado puede entregar un poco de más (redondeo hacia arriba).
3. Los productos `UNIT` se entregan exactos, sin conversión.
4. Toda entrega, recepción o traslado ajusta el stock automáticamente.
5. El stock **puede quedar negativo** al despachar. Un saldo negativo representa un **faltante a solicitar a otra bodega**; un saldo positivo, material disponible.
6. El faltante operativo mostrado es `cantidad solicitada − stock disponible`, en m² (y su equivalente en cajas/piezas para `AREA`, calculado solo en vista).
7. **Kardex es fuente única de verdad:** `stock.system_quantity` se modifica únicamente por movimientos en `kardex`. `dispatches` registra el detalle de lo despachado por línea de comprobante.
8. **Conteo físico no modifica stock:** El registro de conteo va a `inventory_counts` (histórico) con `system_quantity_at_count`, `counted_quantity`, `difference = counted_quantity - system_quantity_at_count`, `counted_at`, `created_by`, `notes`. No actualiza `stock`.
9. **Anulación revierte movimientos:** Al pasar un comprobante a `ANULADO`, se generan movimientos `ANULACION` con signo inverso para cada movimiento asociado a ese comprobante.
10. **Cantidades en BD:** Solo números en unidad base (m² para `AREA`, unidades para `UNIT`). No se guardan cajas/piezas.
11. **Pendiente calculado:** `pending_quantity = total_quantity - dispatched_quantity` se calcula en consulta, nunca se persiste.

---

## 4. Preguntas abiertas

- ¿Las **facturas pendientes reservan stock** o solo quedan anotadas?
- Confirmar posible error de tipeo en "Empore salmon" (factura dice 2, el texto dice 3).
- ¿Existe un stock mínimo por producto para generar alertas de reposición?
