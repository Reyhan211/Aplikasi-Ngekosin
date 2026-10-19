-- Migrasi 019: tabel `chat_messages`

-- +migrate Up
CREATE TABLE `chat_messages` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `room_id`     INT UNSIGNED NOT NULL,
  `sender_id`   INT UNSIGNED NOT NULL,
  `body`        TEXT NULL,
  `image_url`   VARCHAR(255) NULL,
  `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_chat_messages_room` (`room_id`, `id`),
  CONSTRAINT `fk_chat_messages_room`   FOREIGN KEY (`room_id`)   REFERENCES `chat_rooms` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_chat_messages_sender` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`)      ON DELETE CASCADE
) ENGINE=InnoDB;

-- +migrate Down
DROP TABLE IF EXISTS `chat_messages`;
