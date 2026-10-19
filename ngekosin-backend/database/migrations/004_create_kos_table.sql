-- Migrasi 004: tabel `kos`
-- KOS
-- rating_avg / rating_count / rb_*  : agregat ulasan (diperbarui otomatis
--                                     oleh API setiap ada ulasan baru)
-- promo_label : mis. "Diskon 15%"  (NULL = tidak sedang promo)

-- +migrate Up
CREATE TABLE `kos` (
  `id`                  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `owner_id`            INT UNSIGNED NOT NULL,
  `city_id`             INT UNSIGNED NOT NULL,
  `name`                VARCHAR(150) NOT NULL,
  `kos_type`            ENUM('putra','putri','campur') NOT NULL DEFAULT 'campur',
  `district`            VARCHAR(80) NOT NULL DEFAULT '',
  `address`             VARCHAR(255) NOT NULL DEFAULT '',
  `description`         TEXT NULL,
  `latitude`            DECIMAL(10,7) NULL,
  `longitude`           DECIMAL(10,7) NULL,
  `cover_url`           VARCHAR(255) NULL,
  `promo_label`         VARCHAR(40) NULL,
  `rating_avg`          DECIMAL(3,2) NOT NULL DEFAULT 0,
  `rating_count`        INT NOT NULL DEFAULT 0,
  `rb_cleanliness`      DECIMAL(3,2) NOT NULL DEFAULT 0,
  `rb_comfort`          DECIMAL(3,2) NOT NULL DEFAULT 0,
  `rb_safety`           DECIMAL(3,2) NOT NULL DEFAULT 0,
  `rb_price`            DECIMAL(3,2) NOT NULL DEFAULT 0,
  `rb_room_facility`    DECIMAL(3,2) NOT NULL DEFAULT 0,
  `rb_public_facility`  DECIMAL(3,2) NOT NULL DEFAULT 0,
  `is_active`           TINYINT(1) NOT NULL DEFAULT 1,
  `created_at`          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_kos_city` (`city_id`, `is_active`),
  KEY `idx_kos_owner` (`owner_id`),
  KEY `idx_kos_rating` (`rating_avg`),
  CONSTRAINT `fk_kos_owner` FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_kos_city`  FOREIGN KEY (`city_id`)  REFERENCES `cities` (`id`)
) ENGINE=InnoDB;

-- +migrate Down
DROP TABLE IF EXISTS `kos`;
