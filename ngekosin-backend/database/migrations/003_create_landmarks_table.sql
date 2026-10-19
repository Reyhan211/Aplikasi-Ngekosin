-- Migrasi 003: tabel `landmarks`
-- LANDMARKS  (kampus, dll. untuk "Kos Sekitar Kampus")
-- Jarak kos ke landmark dihitung dengan rumus Haversine dari koordinat.

-- +migrate Up
CREATE TABLE `landmarks` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `city_id`     INT UNSIGNED NULL,
  `type`        ENUM('kampus','stasiun','bandara','mall','rumah_sakit','lainnya') NOT NULL DEFAULT 'kampus',
  `short_name`  VARCHAR(30) NOT NULL,
  `name`        VARCHAR(150) NOT NULL,
  `city_label`  VARCHAR(60) NOT NULL DEFAULT '',
  `latitude`    DECIMAL(10,7) NOT NULL,
  `longitude`   DECIMAL(10,7) NOT NULL,
  `is_popular`  TINYINT(1) NOT NULL DEFAULT 1,
  `sort_order`  INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_landmarks_type` (`type`, `is_popular`),
  CONSTRAINT `fk_landmarks_city` FOREIGN KEY (`city_id`) REFERENCES `cities` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB;

-- +migrate Down
DROP TABLE IF EXISTS `landmarks`;
