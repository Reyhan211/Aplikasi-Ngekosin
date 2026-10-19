-- Migrasi 008: tabel `kos_rules`

-- +migrate Up
CREATE TABLE `kos_rules` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `kos_id`      INT UNSIGNED NOT NULL,
  `rule_text`   VARCHAR(255) NOT NULL,
  `sort_order`  INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_kos_rules_kos` (`kos_id`),
  CONSTRAINT `fk_kos_rules_kos` FOREIGN KEY (`kos_id`) REFERENCES `kos` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- +migrate Down
DROP TABLE IF EXISTS `kos_rules`;
