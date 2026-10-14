-- ============================================================
-- Esquema de datos base (CRUD)
-- Tablas: categories, products, box_models, product_area
--
-- Nota: la generación de los identificadores (id uuid) la realiza
-- la aplicación al registrar cada fila.
-- ============================================================


-- ------------------------------------------------------------
-- categories: catálogo de categorías
-- ------------------------------------------------------------
CREATE TABLE categories (
    id          UUID        PRIMARY KEY,
    name        TEXT        NOT NULL,
    created_at  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_categories_name UNIQUE (name)
);


-- ------------------------------------------------------------
-- products: catálogo de productos
-- ------------------------------------------------------------
CREATE TABLE products (
    code         TEXT        PRIMARY KEY,
    name         TEXT        NOT NULL,
    category_id  UUID        NOT NULL,
    product_type TEXT        NOT NULL,
    created_at   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_products_category
        FOREIGN KEY (category_id) REFERENCES categories (id),
    CONSTRAINT chk_products_type
        CHECK (product_type IN ('UNIT', 'AREA'))
);


-- ------------------------------------------------------------
-- box_models: catálogo de modelos de caja
-- Se usa para autocompletar el detalle de los productos AREA.
-- ------------------------------------------------------------
CREATE TABLE box_models (
    id              UUID          PRIMARY KEY,
    format          TEXT          NOT NULL,
    area_per_box    NUMERIC(12,4) NOT NULL,
    area_per_piece  NUMERIC(12,4) NOT NULL,
    pieces_per_box  INTEGER       NOT NULL,
    created_at      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_box_models_format_pieces UNIQUE (format, pieces_per_box),
    CONSTRAINT chk_box_models_pieces_per_box CHECK (pieces_per_box > 0),
    CONSTRAINT chk_box_models_areas CHECK (area_per_box > 0 AND area_per_piece > 0)
);


-- ------------------------------------------------------------
-- product_area: detalle de productos de tipo AREA (1:1 con products)
-- ------------------------------------------------------------
CREATE TABLE product_area (
    code          TEXT        PRIMARY KEY,
    box_model_id  UUID        NOT NULL,
    created_at    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_product_area_product
        FOREIGN KEY (code) REFERENCES products (code) ON DELETE CASCADE,
    CONSTRAINT fk_product_area_box_model
        FOREIGN KEY (box_model_id) REFERENCES box_models (id)
);


-- ============================================================
-- Esquema operativo
-- Tablas: stock, inventory_counts, vouchers, voucher_items,
--         dispatches, kardex
-- ============================================================


-- ------------------------------------------------------------
-- stock: stock teórico por producto
-- El system_quantity puede ser negativo (faltante a pedir)
-- ------------------------------------------------------------
CREATE TABLE stock (
    code              TEXT        PRIMARY KEY,
    system_quantity   NUMERIC     NOT NULL DEFAULT 0,
    broken_quantity   NUMERIC     NOT NULL DEFAULT 0,
    physical_quantity NUMERIC,
    last_count_at     TIMESTAMP,
    CONSTRAINT fk_stock_product
        FOREIGN KEY (code) REFERENCES products (code) ON DELETE RESTRICT
);


-- ------------------------------------------------------------
-- inventory_counts: histórico de conteos físicos
-- No modifica el stock. La diferencia es counted - system_at_count
-- ------------------------------------------------------------
CREATE TABLE inventory_counts (
    id                        UUID        PRIMARY KEY,
    product_code              TEXT        NOT NULL,
    system_quantity_at_count  NUMERIC     NOT NULL,
    counted_quantity          NUMERIC     NOT NULL,
    difference                NUMERIC     NOT NULL,
    counted_at                TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by                TEXT        NOT NULL,
    notes                     TEXT,
    CONSTRAINT fk_inventory_counts_product
        FOREIGN KEY (product_code) REFERENCES products (code) ON DELETE RESTRICT
);


-- ------------------------------------------------------------
-- vouchers: comprobantes de entrada/salida
-- ------------------------------------------------------------
CREATE TABLE vouchers (
    id             UUID        PRIMARY KEY,
    voucher_number NUMERIC     NOT NULL,
    voucher_type   TEXT        NOT NULL,
    status         TEXT        NOT NULL DEFAULT 'PENDIENTE',
    notes          TEXT,
    created_at     TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_vouchers_type
        CHECK (voucher_type IN ('FACTURA', 'NOTA_ENTREGA', 'TRANSF_INGRESO', 'TRANSF_EGRESO')),
    CONSTRAINT chk_vouchers_status
        CHECK (status IN ('PENDIENTE', 'PARCIAL', 'COMPLETADO', 'ANULADO'))
);


-- ------------------------------------------------------------
-- voucher_items: líneas de cada comprobante
-- pending_quantity = total_quantity - dispatched_quantity (calculado)
-- ------------------------------------------------------------
CREATE TABLE voucher_items (
    id                  UUID        PRIMARY KEY,
    voucher_id          UUID        NOT NULL,
    product_code        TEXT        NOT NULL,
    total_quantity      NUMERIC     NOT NULL,
    dispatched_quantity NUMERIC     NOT NULL DEFAULT 0,
    status              TEXT        NOT NULL DEFAULT 'PENDIENTE',
    CONSTRAINT fk_voucher_items_voucher
        FOREIGN KEY (voucher_id) REFERENCES vouchers (id) ON DELETE RESTRICT,
    CONSTRAINT fk_voucher_items_product
        FOREIGN KEY (product_code) REFERENCES products (code) ON DELETE RESTRICT,
    CONSTRAINT chk_voucher_items_total_quantity
        CHECK (total_quantity > 0),
    CONSTRAINT chk_voucher_items_dispatched_quantity
        CHECK (dispatched_quantity >= 0),
    CONSTRAINT chk_voucher_items_status
        CHECK (status IN ('PENDIENTE', 'PARCIAL', 'COMPLETADO'))
);


-- ------------------------------------------------------------
-- dispatches: despachos realizados por ítem de comprobante
-- Las cantidades se guardan en unidad base (m² o unidades)
-- ------------------------------------------------------------
CREATE TABLE dispatches (
    id               UUID        PRIMARY KEY,
    voucher_item_id  UUID        NOT NULL,
    quantity         NUMERIC     NOT NULL,
    dispatched_at    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_dispatches_voucher_item
        FOREIGN KEY (voucher_item_id) REFERENCES voucher_items (id) ON DELETE RESTRICT,
    CONSTRAINT chk_dispatches_quantity
        CHECK (quantity > 0)
);


-- ------------------------------------------------------------
-- kardex: libro mayor de movimientos de inventario
-- movement_sign + movement_type definen el efecto sobre el stock
-- ------------------------------------------------------------
CREATE TABLE kardex (
    id             UUID        PRIMARY KEY,
    product_code   TEXT        NOT NULL,
    voucher_id     UUID,
    movement_type  TEXT        NOT NULL,
    movement_sign  TEXT        NOT NULL,
    quantity       NUMERIC     NOT NULL,
    created_at     TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_kardex_product
        FOREIGN KEY (product_code) REFERENCES products (code) ON DELETE RESTRICT,
    CONSTRAINT fk_kardex_voucher
        FOREIGN KEY (voucher_id) REFERENCES vouchers (id) ON DELETE SET NULL,
    CONSTRAINT chk_kardex_movement_type
        CHECK (movement_type IN ('TRANSFERENCIA_INGRESO', 'TRANSFERENCIA_EGRESO', 'FACTURACION', 'NOTA_ENTREGA', 'ANULACION')),
    CONSTRAINT chk_kardex_movement_sign
        CHECK (movement_sign IN ('+', '-')),
    CONSTRAINT chk_kardex_quantity
        CHECK (quantity > 0)
);
