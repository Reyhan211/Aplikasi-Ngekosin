-- Migrasi 012: tabel `recently_viewed`

-- +migrate Up
CREATE TABLE `recently_viewed` (
  `user_id`     INT UNSIGNED NOT NULL,
  `kos_id`      INT UNSIGNED NOT NULL,
  `viewed_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`, `kos_id`),
  KEY `idx_rv_user_time` (`user_id`, `viewed_at`),
  CONSTRAINT `fk_rv_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_rv_kos`  FOREIGN KEY (`kos_id`)  REFERENCES `kos` (`id`)   ON DELETE CASCADE
) ENGINE=InnoDB;

-- +migrate Down
DROP TABLE IF EXISTS `recently_viewed`;
