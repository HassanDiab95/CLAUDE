-- =====================================================================
--  Rayy (ري): MySQL / MariaDB database (XAMPP version)
--  Import it in phpMyAdmin: http://localhost/phpmyadmin → Import → this file
--  It creates the database "rayy", all the tables and the starting data.
--  The tables follow the ERD and the relational model of the report (3NF).
-- =====================================================================
SET NAMES utf8mb4;
CREATE DATABASE IF NOT EXISTS rayy CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE rayy;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS api_tokens, play_commands, mood_events, live_status, readings,
                     moods, melodies, plant_settings, plant_access, plants, users;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
--  USER: people who sign in to the web dashboard and the Android app
-- ---------------------------------------------------------------------
CREATE TABLE users (
  user_id        INT AUTO_INCREMENT PRIMARY KEY,
  email          VARCHAR(120) NOT NULL UNIQUE,
  full_name      VARCHAR(100) NOT NULL,
  password_hash  VARCHAR(255) NOT NULL,          -- PHP password_hash() (bcrypt), never plain text
  role           ENUM('admin', 'user') NOT NULL DEFAULT 'user',
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
--  PLANT: one row per ESP32 device
-- ---------------------------------------------------------------------
CREATE TABLE plants (
  plant_id         VARCHAR(20) PRIMARY KEY,      -- same as PLANT_ID in firmware/Rayy/config.h
  name             VARCHAR(50) NOT NULL,
  location         VARCHAR(100) NULL,
  device_key_hash  CHAR(64) NOT NULL             -- SHA-256 of DEVICE_KEY in config.h
) ENGINE = InnoDB;

CREATE TABLE plant_access (
  user_id       INT NOT NULL,
  plant_id      VARCHAR(20) NOT NULL,
  access_level  ENUM('owner', 'viewer') NOT NULL DEFAULT 'owner',
  PRIMARY KEY (user_id, plant_id),
  FOREIGN KEY (user_id)  REFERENCES users(user_id)   ON DELETE CASCADE,
  FOREIGN KEY (plant_id) REFERENCES plants(plant_id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
--  PLANT_SETTINGS: thresholds written by the apps, read by the ESP32
-- ---------------------------------------------------------------------
CREATE TABLE plant_settings (
  plant_id      VARCHAR(20) PRIMARY KEY,
  moisture_min  TINYINT UNSIGNED NOT NULL DEFAULT 30,    -- thirsty below (%)
  moisture_max  TINYINT UNSIGNED NOT NULL DEFAULT 85,    -- too wet above (%)
  temp_min      DECIMAL(4,1) NOT NULL DEFAULT 10.0,      -- cold below (°C)
  temp_max      DECIMAL(4,1) NOT NULL DEFAULT 35.0,      -- hot above (°C)
  lux_min       INT UNSIGNED NOT NULL DEFAULT 200,       -- needs light below (lux)
  quiet_start   TINYINT UNSIGNED NOT NULL DEFAULT 22,    -- silent from (hour)
  quiet_end     TINYINT UNSIGNED NOT NULL DEFAULT 7,     -- silent until (hour)
  muted         BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (plant_id) REFERENCES plants(plant_id) ON DELETE CASCADE,
  CHECK (moisture_min <= 100 AND moisture_max <= 100 AND quiet_start < 24 AND quiet_end < 24)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
--  MELODY and MOOD: fixed reference data
-- ---------------------------------------------------------------------
CREATE TABLE melodies (
  melody_no    TINYINT UNSIGNED PRIMARY KEY,     -- 1..9, same numbers as firmware/Rayy/sound.h
  name_en      VARCHAR(30) NOT NULL,
  name_ar      VARCHAR(30) NOT NULL,
  description  VARCHAR(120) NOT NULL
) ENGINE = InnoDB;

CREATE TABLE moods (
  mood_code  VARCHAR(20) PRIMARY KEY,            -- same names as moodName() in mood.cpp
  name_ar    VARCHAR(30) NOT NULL,
  name_en    VARCHAR(30) NOT NULL,
  emoji      VARCHAR(8)  NOT NULL,
  melody_no  TINYINT UNSIGNED NOT NULL,
  FOREIGN KEY (melody_no) REFERENCES melodies(melody_no)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
--  READING: history, one row every 5 minutes (for the 24-hour chart)
-- ---------------------------------------------------------------------
CREATE TABLE readings (
  reading_id   BIGINT AUTO_INCREMENT PRIMARY KEY,
  plant_id     VARCHAR(20) NOT NULL,
  recorded_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  moisture     DECIMAL(5,1) NULL,
  temperature  DECIMAL(4,1) NULL,
  humidity     DECIMAL(5,1) NULL,
  lux          INT UNSIGNED NULL,
  mood_code    VARCHAR(20) NOT NULL,
  INDEX idx_plant_time (plant_id, recorded_at),
  FOREIGN KEY (plant_id)  REFERENCES plants(plant_id) ON DELETE CASCADE,
  FOREIGN KEY (mood_code) REFERENCES moods(mood_code)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
--  LIVE_STATUS: the latest values, overwritten every 30 s by the ESP32
-- ---------------------------------------------------------------------
CREATE TABLE live_status (
  plant_id     VARCHAR(20) PRIMARY KEY,
  moisture     DECIMAL(5,1) NULL,
  temperature  DECIMAL(4,1) NULL,
  humidity     DECIMAL(5,1) NULL,
  lux          INT UNSIGNED NULL,
  mood_code    VARCHAR(20) NOT NULL,
  soil_raw     SMALLINT UNSIGNED NULL,          -- raw ADC value, for calibration
  rssi         SMALLINT NULL,                   -- Wi-Fi signal (dBm)
  ip           VARCHAR(45) NULL,
  uptime_s     INT UNSIGNED NULL,
  updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (plant_id)  REFERENCES plants(plant_id) ON DELETE CASCADE,
  FOREIGN KEY (mood_code) REFERENCES moods(mood_code)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
--  MOOD_EVENT: the "plant diary" (one row each time the mood changes)
-- ---------------------------------------------------------------------
CREATE TABLE mood_events (
  event_id     BIGINT AUTO_INCREMENT PRIMARY KEY,
  plant_id     VARCHAR(20) NOT NULL,
  mood_code    VARCHAR(20) NOT NULL,
  occurred_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  message      VARCHAR(200) NOT NULL,
  INDEX idx_plant_time (plant_id, occurred_at),
  FOREIGN KEY (plant_id)  REFERENCES plants(plant_id) ON DELETE CASCADE,
  FOREIGN KEY (mood_code) REFERENCES moods(mood_code)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
--  PLAY_COMMAND: "Play" button in the apps → the ESP32 plays the melody
-- ---------------------------------------------------------------------
CREATE TABLE play_commands (
  command_id    BIGINT AUTO_INCREMENT PRIMARY KEY,
  plant_id      VARCHAR(20) NOT NULL,
  user_id       INT NULL,
  melody_no     TINYINT UNSIGNED NOT NULL,
  requested_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status        ENUM('pending', 'played') NOT NULL DEFAULT 'pending',
  played_at     DATETIME NULL,
  INDEX idx_pending (plant_id, status),
  FOREIGN KEY (plant_id)  REFERENCES plants(plant_id) ON DELETE CASCADE,
  FOREIGN KEY (user_id)   REFERENCES users(user_id)   ON DELETE SET NULL,
  FOREIGN KEY (melody_no) REFERENCES melodies(melody_no)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
--  API_TOKENS: login sessions of the web and Android apps (valid 7 days)
-- ---------------------------------------------------------------------
CREATE TABLE api_tokens (
  token_hash  CHAR(64) PRIMARY KEY,               -- SHA-256 of the token sent to the app
  user_id     INT NOT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at  DATETIME NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- =====================================================================
--  Starting data
-- =====================================================================
INSERT INTO melodies (melody_no, name_en, name_ar, description) VALUES
  (1, 'Thirsty',     'عطشانة',        'Sad "help!" notes, played twice'),
  (2, 'Too wet',     'غرقانة',        'Fast bubbling notes'),
  (3, 'Hot',         'حرّانة',        'Alarm beeps'),
  (4, 'Cold',        'بردانة',        'Shivering trill'),
  (5, 'Needs light', 'تحتاج ضوء',     'Rising notes then a low note'),
  (6, 'Happy',       'سعيدة',         'Happy arpeggio'),
  (7, 'Thank you',   'شكراً',         'Joyful melody after watering'),
  (8, 'Good night',  'تصبحون على خير', 'Slow lullaby'),
  (9, 'Hello',       'مرحباً',        'Short start-up melody');

INSERT INTO moods (mood_code, name_ar, name_en, emoji, melody_no) VALUES
  ('happy',      'سعيدة',      'Happy',       '😊', 6),
  ('thirsty',    'عطشانة',     'Thirsty',     '😫', 1),
  ('drowning',   'غرقانة',     'Too wet',     '🥴', 2),
  ('hot',        'حرّانة',     'Too hot',     '🥵', 3),
  ('cold',       'بردانة',     'Cold',        '🥶', 4),
  ('need_light', 'تحتاج ضوء',  'Needs light', '😞', 5),
  ('sleepy',     'نائمة',      'Sleeping',    '😴', 8);

-- The plant. Device key = 'rayy-device-key-2026' (change it here AND in config.h)
INSERT INTO plants (plant_id, name, location, device_key_hash) VALUES
  ('plant01', 'ري 🌿', 'Lab', SHA2('rayy-device-key-2026', 256));

INSERT INTO plant_settings (plant_id) VALUES ('plant01');

-- User: team@rayy.app / password Rayy@2026 (change it after the first login test)
INSERT INTO users (email, full_name, password_hash, role) VALUES
  ('team@rayy.app', 'Rayy Team', '$2y$10$8cCB8IHP5z8vJdECFK.w2uClgv1ruEhKQVEG9BDSXUeu6W1VoWMVy', 'admin');

INSERT INTO plant_access (user_id, plant_id, access_level) VALUES (1, 'plant01', 'owner');
