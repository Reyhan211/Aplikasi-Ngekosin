-- Migrasi 006: tabel `facilities`
-- FASILITAS
-- category   : kamar | kamar_mandi | umum | parkir
-- short_name : nama singkat untuk kartu kos ("K. Mandi Dalam")

-- +migrate Up
CREATE TABLE `facilities` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`        VARCHAR(80) NOT NULL,
  `short_name`  VARCHAR(40) NULL,
  `category`    ENUM('kamar','kamar_mandi','umum','parkir') NOT NULL DEFAULT 'umum',
  `icon`        VARCHAR(40) NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_facilities_name` (`name`)
) ENGINE=InnoDB;

-- +migrate Down
DROP TABLE IF EXISTS `facilities`;
