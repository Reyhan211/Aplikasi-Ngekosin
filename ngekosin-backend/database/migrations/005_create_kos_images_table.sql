-- Migrasi 005: tabel `kos_images`

-- +migrate Up
CREATE TABLE `kos_images` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `kos_id`      INT UNSIGNED NOT NULL,
  `image_url`   VARCHAR(255) NOT NULL,
  `sort_order`  INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_kos_images_kos` (`kos_id`),
  CONSTRAINT `fk_kos_images_kos` FOREIGN KEY (`kos_id`) REFERENCES `kos` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- +migrate Down
DROP TABLE IF EXISTS `kos_images`;
