-- Migrasi 009: tabel `room_types`
-- TIPE KAMAR  (harga per periode; NULL = periode tidak tersedia)
-- stock : jumlah kamar tersedia. Berkurang saat pengajuan sewa dibuat,
--         kembali saat dibatalkan / ditolak / kedaluwarsa.

-- +migrate Up
CREATE TABLE `room_types` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `kos_id`         INT UNSIGNED NOT NULL,
  `name`           VARCHAR(80) NOT NULL,
  `size_label`     VARCHAR(20) NULL,
  `price_daily`    INT UNSIGNED NULL,
  `price_weekly`   INT UNSIGNED NULL,
  `price_monthly`  INT UNSIGNED NOT NULL,
  `price_yearly`   INT UNSIGNED NULL,
  `deposit`        INT UNSIGNED NOT NULL DEFAULT 0,
  `stock`          INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_room_types_kos` (`kos_id`),
  CONSTRAINT `fk_room_types_kos` FOREIGN KEY (`kos_id`) REFERENCES `kos` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- +migrate Down
DROP TABLE IF EXISTS `room_types`;
