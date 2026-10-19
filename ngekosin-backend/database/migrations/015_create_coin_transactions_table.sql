-- Migrasi 015: tabel `coin_transactions`
-- KOIN  (amount positif = masuk, negatif = dipakai)

-- +migrate Up
CREATE TABLE `coin_transactions` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`     INT UNSIGNED NOT NULL,
  `title`       VARCHAR(120) NOT NULL,
  `amount`      INT NOT NULL,
  `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_coin_user` (`user_id`, `created_at`),
  CONSTRAINT `fk_coin_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- +migrate Down
DROP TABLE IF EXISTS `coin_transactions`;
