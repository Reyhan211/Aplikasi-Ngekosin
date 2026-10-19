-- Migrasi 001: tabel `users`
-- USERS
-- role         : pencari (default) | pemilik | admin
-- owner_status : status pengajuan jadi pemilik kos

-- +migrate Up
CREATE TABLE `users` (
  `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`             VARCHAR(100) NOT NULL,
  `username`         VARCHAR(30)  NOT NULL,
  `email`            VARCHAR(150) NOT NULL,
  `password_hash`    VARCHAR(255) NOT NULL,
  `phone`            VARCHAR(20)  NULL,
  `role`             ENUM('pencari','pemilik','admin') NOT NULL DEFAULT 'pencari',
  `owner_status`     ENUM('none','pending','approved','rejected') NOT NULL DEFAULT 'none',
  `coins`            INT NOT NULL DEFAULT 0,
  `created_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_users_email` (`email`),
  UNIQUE KEY `uq_users_username` (`username`)
) ENGINE=InnoDB;

-- +migrate Down
DROP TABLE IF EXISTS `users`;
