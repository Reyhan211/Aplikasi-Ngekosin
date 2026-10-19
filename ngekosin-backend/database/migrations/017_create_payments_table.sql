-- Migrasi 017: tabel `payments`
-- PEMBAYARAN
-- method : bca | mandiri | bni | gopay | dana | qris
-- proof_url wajib untuk transfer bank (bca/mandiri/bni)

-- +migrate Up
CREATE TABLE `payments` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `booking_id`  INT UNSIGNED NOT NULL,
  `method`      VARCHAR(20) NOT NULL,
  `amount`      INT UNSIGNED NOT NULL,
  `proof_url`   VARCHAR(255) NULL,
  `status`      ENUM('menunggu_verifikasi','berhasil','ditolak') NOT NULL DEFAULT 'menunggu_verifikasi',
  `paid_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_payments_booking` (`booking_id`),
  CONSTRAINT `fk_payments_booking` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- +migrate Down
DROP TABLE IF EXISTS `payments`;
