-- Migrasi 002: tabel `cities`
-- CITIES  ("Area Kos Populer")
-- image_url : path aset aplikasi ("assets/cities/x.jpg") atau path upload

-- +migrate Up
CREATE TABLE `cities` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`        VARCHAR(80) NOT NULL,
  `image_url`   VARCHAR(255) NULL,
  `is_popular`  TINYINT(1) NOT NULL DEFAULT 1,
  `sort_order`  INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_cities_name` (`name`)
) ENGINE=InnoDB;

-- +migrate Down
DROP TABLE IF EXISTS `cities`;
