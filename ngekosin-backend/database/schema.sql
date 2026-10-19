-- =====================================================================
--  NGEKOS.IN  -  Skema database (MySQL 5.7+ / MySQL 8 / MariaDB 10.3+)
--  Cocok untuk Laragon (default: user root, password kosong, port 3306).
--
--  Cara pakai (pilih salah satu):
--    1. Terminal proyek :  npm run db:setup
--    2. HeidiSQL / phpMyAdmin : buka file ini lalu Run / Import
-- =====================================================================

CREATE DATABASE IF NOT EXISTS `ngekosin`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `ngekosin`;

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- USERS
-- role         : pencari (default) | pemilik | admin
-- owner_status : status pengajuan jadi pemilik kos
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `users` (
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

-- ---------------------------------------------------------------------
-- CITIES  ("Area Kos Populer")
-- image_url : path aset aplikasi ("assets/cities/x.jpg") atau path upload
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `cities` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`        VARCHAR(80) NOT NULL,
  `image_url`   VARCHAR(255) NULL,
  `is_popular`  TINYINT(1) NOT NULL DEFAULT 1,
  `sort_order`  INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_cities_name` (`name`)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- LANDMARKS  (kampus, dll. untuk "Kos Sekitar Kampus")
-- Jarak kos ke landmark dihitung dengan rumus Haversine dari koordinat.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `landmarks` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `city_id`     INT UNSIGNED NULL,
  `type`        ENUM('kampus','stasiun','bandara','mall','rumah_sakit','lainnya') NOT NULL DEFAULT 'kampus',
  `short_name`  VARCHAR(30) NOT NULL,
  `name`        VARCHAR(150) NOT NULL,
  `city_label`  VARCHAR(60) NOT NULL DEFAULT '',
  `latitude`    DECIMAL(10,7) NOT NULL,
  `longitude`   DECIMAL(10,7) NOT NULL,
  `is_popular`  TINYINT(1) NOT NULL DEFAULT 1,
  `sort_order`  INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_landmarks_type` (`type`, `is_popular`),
  CONSTRAINT `fk_landmarks_city` FOREIGN KEY (`city_id`) REFERENCES `cities` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- KOS
-- rating_avg / rating_count / rb_*  : agregat ulasan (diperbarui otomatis
--                                     oleh API setiap ada ulasan baru)
-- promo_label : mis. "Diskon 15%"  (NULL = tidak sedang promo)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `kos` (
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

CREATE TABLE IF NOT EXISTS `kos_images` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `kos_id`      INT UNSIGNED NOT NULL,
  `image_url`   VARCHAR(255) NOT NULL,
  `sort_order`  INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_kos_images_kos` (`kos_id`),
  CONSTRAINT `fk_kos_images_kos` FOREIGN KEY (`kos_id`) REFERENCES `kos` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- FASILITAS
-- category   : kamar | kamar_mandi | umum | parkir
-- short_name : nama singkat untuk kartu kos ("K. Mandi Dalam")
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `facilities` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`        VARCHAR(80) NOT NULL,
  `short_name`  VARCHAR(40) NULL,
  `category`    ENUM('kamar','kamar_mandi','umum','parkir') NOT NULL DEFAULT 'umum',
  `icon`        VARCHAR(40) NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_facilities_name` (`name`)
) ENGINE=InnoDB;

-- is_highlight = 1 -> tampil di ringkasan kartu kos (maks. 4 per kos)
CREATE TABLE IF NOT EXISTS `kos_facilities` (
  `kos_id`        INT UNSIGNED NOT NULL,
  `facility_id`   INT UNSIGNED NOT NULL,
  `is_highlight`  TINYINT(1) NOT NULL DEFAULT 0,
  `sort_order`    INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`kos_id`, `facility_id`),
  CONSTRAINT `fk_kf_kos`      FOREIGN KEY (`kos_id`)      REFERENCES `kos` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_kf_facility` FOREIGN KEY (`facility_id`) REFERENCES `facilities` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `kos_rules` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `kos_id`      INT UNSIGNED NOT NULL,
  `rule_text`   VARCHAR(255) NOT NULL,
  `sort_order`  INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_kos_rules_kos` (`kos_id`),
  CONSTRAINT `fk_kos_rules_kos` FOREIGN KEY (`kos_id`) REFERENCES `kos` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- TIPE KAMAR  (harga per periode; NULL = periode tidak tersedia)
-- stock : jumlah kamar tersedia. Berkurang saat pengajuan sewa dibuat,
--         kembali saat dibatalkan / ditolak / kedaluwarsa.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `room_types` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `kos_id`         INT UNSIGNED NOT NULL,
  `name`           VARCHAR(80) NOT NULL,
  `size_label`     VARCHAR(20) NULL,
  `price_daily`    INT UNSIGNED NULL,
  `price_weekly`   INT UNSIGNED NULL,
  `price_monthly`  INT UNSIGNED NOT NULL,
  `price_yearly`   INT UNSIGNED NULL,
  `deposit`        INT UNSIGNED NOT NULL DEFAULT 0,
  `stock`          INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_room_types_kos` (`kos_id`),
  CONSTRAINT `fk_room_types_kos` FOREIGN KEY (`kos_id`) REFERENCES `kos` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- ULASAN  (satu ulasan per user per kos)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `reviews` (
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

-- ---------------------------------------------------------------------
-- FAVORIT & TERAKHIR DILIHAT
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `favorites` (
  `user_id`     INT UNSIGNED NOT NULL,
  `kos_id`      INT UNSIGNED NOT NULL,
  `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`, `kos_id`),
  CONSTRAINT `fk_fav_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_fav_kos`  FOREIGN KEY (`kos_id`)  REFERENCES `kos` (`id`)   ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `recently_viewed` (
  `user_id`     INT UNSIGNED NOT NULL,
  `kos_id`      INT UNSIGNED NOT NULL,
  `viewed_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`, `kos_id`),
  KEY `idx_rv_user_time` (`user_id`, `viewed_at`),
  CONSTRAINT `fk_rv_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_rv_kos`  FOREIGN KEY (`kos_id`)  REFERENCES `kos` (`id`)   ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- VOUCHER / KODE PROMO
-- is_public = 1 : kode bisa langsung dipakai siapa saja (mis. NGEKOSBARU)
-- is_public = 0 : harus diklaim dulu lewat POST /vouchers/claim
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `vouchers` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code`         VARCHAR(30) NOT NULL,
  `title`        VARCHAR(100) NOT NULL,
  `description`  VARCHAR(255) NOT NULL DEFAULT '',
  `discount`     INT UNSIGNED NOT NULL,
  `min_amount`   INT UNSIGNED NOT NULL DEFAULT 0,
  `expires_at`   DATETIME NOT NULL,
  `is_public`    TINYINT(1) NOT NULL DEFAULT 0,
  `is_active`    TINYINT(1) NOT NULL DEFAULT 1,
  `created_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_vouchers_code` (`code`)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `user_vouchers` (
  `user_id`     INT UNSIGNED NOT NULL,
  `voucher_id`  INT UNSIGNED NOT NULL,
  `claimed_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `used_at`     DATETIME NULL,
  PRIMARY KEY (`user_id`, `voucher_id`),
  CONSTRAINT `fk_uv_user`    FOREIGN KEY (`user_id`)    REFERENCES `users` (`id`)    ON DELETE CASCADE,
  CONSTRAINT `fk_uv_voucher` FOREIGN KEY (`voucher_id`) REFERENCES `vouchers` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- KOIN  (amount positif = masuk, negatif = dipakai)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `coin_transactions` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`     INT UNSIGNED NOT NULL,
  `title`       VARCHAR(120) NOT NULL,
  `amount`      INT NOT NULL,
  `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_coin_user` (`user_id`, `created_at`),
  CONSTRAINT `fk_coin_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- BOOKINGS (pengajuan sewa)
-- status : menunggu_konfirmasi -> menunggu_pembayaran -> dibayar -> aktif -> selesai
--          cabang: ditolak | dibatalkan | kadaluarsa
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `bookings` (
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

-- ---------------------------------------------------------------------
-- PEMBAYARAN
-- method : bca | mandiri | bni | gopay | dana | qris
-- proof_url wajib untuk transfer bank (bca/mandiri/bni)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `payments` (
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

-- ---------------------------------------------------------------------
-- CHAT  (satu room per pasangan pencari + kos)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `chat_rooms` (
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

CREATE TABLE IF NOT EXISTS `chat_messages` (
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
