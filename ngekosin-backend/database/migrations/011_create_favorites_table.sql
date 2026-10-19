-- Migrasi 011: tabel `favorites`
-- FAVORIT & TERAKHIR DILIHAT

-- +migrate Up
CREATE TABLE `favorites` (
  `user_id`     INT UNSIGNED NOT NULL,
  `kos_id`      INT UNSIGNED NOT NULL,
  `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`, `kos_id`),
  CONSTRAINT `fk_fav_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_fav_kos`  FOREIGN KEY (`kos_id`)  REFERENCES `kos` (`id`)   ON DELETE CASCADE
) ENGINE=InnoDB;

-- +migrate Down
DROP TABLE IF EXISTS `favorites`;
