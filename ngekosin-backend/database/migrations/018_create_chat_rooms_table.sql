-- Migrasi 018: tabel `chat_rooms`
-- CHAT  (satu room per pasangan pencari + kos)

-- +migrate Up
CREATE TABLE `chat_rooms` (
  `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `kos_id`           INT UNSIGNED NOT NULL,
  `user_id`          INT UNSIGNED NOT NULL,
  `owner_id`         INT UNSIGNED NOT NULL,
  `last_message`     VARCHAR(255) NULL,
  `last_message_at`  DATETIME NULL,
  `user_unread`      INT UNSIGNED NOT NULL DEFAULT 0,
  `owner_unread`     INT UNSIGNED NOT NULL DEFAULT 0,
  `created_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_chat_rooms_pair` (`kos_id`, `user_id`),
  KEY `idx_chat_rooms_user`  (`user_id`),
  KEY `idx_chat_rooms_owner` (`owner_id`),
  CONSTRAINT `fk_chat_rooms_kos`   FOREIGN KEY (`kos_id`)   REFERENCES `kos` (`id`)   ON DELETE CASCADE,
  CONSTRAINT `fk_chat_rooms_user`  FOREIGN KEY (`user_id`)  REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_chat_rooms_owner` FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- +migrate Down
DROP TABLE IF EXISTS `chat_rooms`;
