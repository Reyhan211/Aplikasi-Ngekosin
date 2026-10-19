-- Migrasi 013: tabel `vouchers`
-- VOUCHER / KODE PROMO
-- is_public = 1 : kode bisa langsung dipakai siapa saja (mis. NGEKOSBARU)
-- is_public = 0 : harus diklaim dulu lewat POST /vouchers/claim

-- +migrate Up
CREATE TABLE `vouchers` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code`         VARCHAR(30) NOT NULL,
  `title`        VARCHAR(100) NOT NULL,
  `description`  VARCHAR(255) NOT NULL DEFAULT '',
  `discount`     INT UNSIGNED NOT NULL,
  `min_amount`   INT UNSIGNED NOT NULL DEFAULT 0,
  `expires_at`   DATETIME NOT NULL,
  `is_public`    TINYINT(1) NOT NULL DEFAULT 0,
  `is_active`    TINYINT(1) NOT NULL DEFAULT 1,
  `created_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_vouchers_code` (`code`)
) ENGINE=InnoDB;

-- +migrate Down
DROP TABLE IF EXISTS `vouchers`;
