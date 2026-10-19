-- Migrasi 007: tabel `kos_facilities`
-- is_highlight = 1 -> tampil di ringkasan kartu kos (maks. 4 per kos)

-- +migrate Up
CREATE TABLE `kos_facilities` (
  `kos_id`        INT UNSIGNED NOT NULL,
  `facility_id`   INT UNSIGNED NOT NULL,
  `is_highlight`  TINYINT(1) NOT NULL DEFAULT 0,
  `sort_order`    INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`kos_id`, `facility_id`),
  CONSTRAINT `fk_kf_kos`      FOREIGN KEY (`kos_id`)      REFERENCES `kos` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_kf_facility` FOREIGN KEY (`facility_id`) REFERENCES `facilities` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- +migrate Down
DROP TABLE IF EXISTS `kos_facilities`;
