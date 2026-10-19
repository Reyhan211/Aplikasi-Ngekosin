-- Migrasi 010: tabel `reviews`
-- ULASAN  (satu ulasan per user per kos)

-- +migrate Up
CREATE TABLE `reviews` (
  `id`                  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `kos_id`              INT UNSIGNED NOT NULL,
  `user_id`             INT UNSIGNED NOT NULL,
  `cleanliness`         DECIMAL(2,1) NOT NULL,
  `comfort`             DECIMAL(2,1) NOT NULL,
  `safety`              DECIMAL(2,1) NOT NULL,
  `price`               DECIMAL(2,1) NOT NULL,
  `room_facility`       DECIMAL(2,1) NOT NULL,
  `public_facility`     DECIMAL(2,1) NOT NULL,
  `rating_overall`      DECIMAL(2,1) NOT NULL,
  `comment`             TEXT NULL,
  `owner_reply`         TEXT NULL,
  `owner_replied_at`    DATETIME NULL,
  `created_at`          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_reviews_user_kos` (`user_id`, `kos_id`),
  KEY `idx_reviews_kos` (`kos_id`, `created_at`),
  CONSTRAINT `fk_reviews_kos`  FOREIGN KEY (`kos_id`)  REFERENCES `kos` (`id`)   ON DELETE CASCADE,
  CONSTRAINT `fk_reviews_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- +migrate Down
DROP TABLE IF EXISTS `reviews`;
