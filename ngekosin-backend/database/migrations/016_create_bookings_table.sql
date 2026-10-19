-- Migrasi 016: tabel `bookings`
-- BOOKINGS (pengajuan sewa)
-- status : menunggu_konfirmasi -> menunggu_pembayaran -> dibayar -> aktif -> selesai
--          cabang: ditolak | dibatalkan | kadaluarsa

-- +migrate Up
CREATE TABLE `bookings` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code`            VARCHAR(30) NOT NULL,
  `user_id`         INT UNSIGNED NOT NULL,
  `kos_id`          INT UNSIGNED NOT NULL,
  `room_type_id`    INT UNSIGNED NOT NULL,
  `checkin_date`    DATE NOT NULL,
  `checkout_date`   DATE NOT NULL,
  `duration_unit`   ENUM('harian','mingguan','bulanan','tahunan') NOT NULL,
  `duration_count`  INT UNSIGNED NOT NULL,
  `price_per_unit`  INT UNSIGNED NOT NULL,
  `deposit`         INT UNSIGNED NOT NULL DEFAULT 0,
  `admin_fee`       INT UNSIGNED NOT NULL DEFAULT 0,
  `discount`        INT UNSIGNED NOT NULL DEFAULT 0,
  `total_amount`    INT UNSIGNED NOT NULL,
  `occupants`       INT UNSIGNED NOT NULL DEFAULT 1,
  `tenant_name`     VARCHAR(100) NOT NULL,
  `tenant_phone`    VARCHAR(20) NOT NULL,
  `note`            VARCHAR(500) NULL,
  `promo_code`      VARCHAR(30) NULL,
  `status`          ENUM('menunggu_konfirmasi','menunggu_pembayaran','dibayar','aktif',
                         'selesai','ditolak','dibatalkan','kadaluarsa')
                    NOT NULL DEFAULT 'menunggu_konfirmasi',
  `expires_at`      DATETIME NULL,
  `created_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_bookings_code` (`code`),
  KEY `idx_bookings_user` (`user_id`, `created_at`),
  KEY `idx_bookings_kos` (`kos_id`, `status`),
  KEY `idx_bookings_expiry` (`status`, `expires_at`),
  CONSTRAINT `fk_bookings_user` FOREIGN KEY (`user_id`)      REFERENCES `users` (`id`),
  CONSTRAINT `fk_bookings_kos`  FOREIGN KEY (`kos_id`)       REFERENCES `kos` (`id`),
  CONSTRAINT `fk_bookings_room` FOREIGN KEY (`room_type_id`) REFERENCES `room_types` (`id`)
) ENGINE=InnoDB;

-- +migrate Down
DROP TABLE IF EXISTS `bookings`;
