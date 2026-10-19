-- Migrasi 014: tabel `user_vouchers`

-- +migrate Up
CREATE TABLE `user_vouchers` (
  `user_id`     INT UNSIGNED NOT NULL,
  `voucher_id`  INT UNSIGNED NOT NULL,
  `claimed_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `used_at`     DATETIME NULL,
  PRIMARY KEY (`user_id`, `voucher_id`),
  CONSTRAINT `fk_uv_user`    FOREIGN KEY (`user_id`)    REFERENCES `users` (`id`)    ON DELETE CASCADE,
  CONSTRAINT `fk_uv_voucher` FOREIGN KEY (`voucher_id`) REFERENCES `vouchers` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- +migrate Down
DROP TABLE IF EXISTS `user_vouchers`;
