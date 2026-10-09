-- =====================================================================
--  ري (Rayy): smart farming system: MySQL / MariaDB database (XAMPP)
--  Import it in phpMyAdmin: http://localhost/phpmyadmin → Import → this file
--  It creates the database "rayy", all the tables and the starting data.
--
--  Main idea:
--    * ري manages many CROPS (زراعات): a strawberry field, tomatoes, mint ...
--    * every crop has a CROP TYPE that gives its ideal moisture / temperature / light
--    * a sensor DEVICE (ESP32) is assigned to one crop and can be MOVED to another
--    * USERS sign up from the web or the Android app; ADMINS manage everyone
-- =====================================================================
SET NAMES utf8mb4;
CREATE DATABASE IF NOT EXISTS rayy CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE rayy;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS api_tokens, play_commands, mood_events, live_status, readings, device_assignments,
                     devices, crops, crop_types, moods, melodies, users,
                     plant_settings, plant_access, plants;          -- (tables of the old one-plant version)
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
--  USER: people who use the web dashboard and the Android app
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
--  CROP_TYPE: library of crops with their ideal conditions
--  (used to fill the thresholds of a new crop; the user can still edit them)
-- ---------------------------------------------------------------------
CREATE TABLE crop_types (
  type_code     VARCHAR(20) PRIMARY KEY,
  name_ar       VARCHAR(40) NOT NULL,
  name_en       VARCHAR(40) NOT NULL,
  emoji         VARCHAR(8)  NOT NULL,
  moisture_min  TINYINT UNSIGNED NOT NULL,       -- thirsty below (%)
  moisture_max  TINYINT UNSIGNED NOT NULL,       -- too wet above (%)
  temp_min      DECIMAL(4,1) NOT NULL,           -- cold below (°C)
  temp_max      DECIMAL(4,1) NOT NULL,           -- hot above (°C)
  lux_min       INT UNSIGNED NOT NULL            -- needs light below (lux, daytime)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
--  CROP: a crop / planting managed in ري (e.g. "Strawberry field – greenhouse 1")
--  Its thresholds start from the crop type and can be changed from the apps.
-- ---------------------------------------------------------------------
CREATE TABLE crops (
  crop_id       INT AUTO_INCREMENT PRIMARY KEY,
  owner_id      INT NOT NULL,
  type_code     VARCHAR(20) NOT NULL,
  name          VARCHAR(60) NOT NULL,
  location      VARCHAR(100) NULL,               -- greenhouse, farm, balcony ...
  moisture_min  TINYINT UNSIGNED NOT NULL,
  moisture_max  TINYINT UNSIGNED NOT NULL,
  temp_min      DECIMAL(4,1) NOT NULL,
  temp_max      DECIMAL(4,1) NOT NULL,
  lux_min       INT UNSIGNED NOT NULL,
  quiet_start   TINYINT UNSIGNED NOT NULL DEFAULT 22,    -- buzzer silent from (hour)
  quiet_end     TINYINT UNSIGNED NOT NULL DEFAULT 7,     -- buzzer silent until (hour)
  muted         BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_owner (owner_id),
  FOREIGN KEY (owner_id)  REFERENCES users(user_id) ON DELETE CASCADE,
  FOREIGN KEY (type_code) REFERENCES crop_types(type_code),
  CHECK (moisture_min <= 100 AND moisture_max <= 100 AND quiet_start < 24 AND quiet_end < 24)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
--  DEVICE: a sensor unit (ESP32 + sensors + buzzer). It measures the crop
--  it is assigned to (crop_id) and can be moved to another crop at any time.
-- ---------------------------------------------------------------------
CREATE TABLE devices (
  device_id        VARCHAR(20) PRIMARY KEY,       -- same as DEVICE_ID in firmware/Rayy/config.h
  name             VARCHAR(50) NOT NULL,
  device_key_hash  CHAR(64) NOT NULL,             -- SHA-256 of DEVICE_KEY in config.h
  owner_id         INT NULL,                      -- user who added the device (NULL = not claimed yet)
  crop_id          INT NULL,                      -- crop it measures now (NULL = not assigned)
  last_seen        DATETIME NULL,
  FOREIGN KEY (owner_id) REFERENCES users(user_id) ON DELETE SET NULL,
  FOREIGN KEY (crop_id)  REFERENCES crops(crop_id) ON DELETE SET NULL
) ENGINE = InnoDB;

-- History of which crop each device measured, and when (moving the device)
CREATE TABLE device_assignments (
  assignment_id  BIGINT AUTO_INCREMENT PRIMARY KEY,
  device_id      VARCHAR(20) NOT NULL,
  crop_id        INT NOT NULL,
  assigned_by    INT NULL,
  assigned_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  removed_at     DATETIME NULL,
  INDEX idx_device (device_id, assigned_at),
  FOREIGN KEY (device_id)   REFERENCES devices(device_id) ON DELETE CASCADE,
  FOREIGN KEY (crop_id)     REFERENCES crops(crop_id)     ON DELETE CASCADE,
  FOREIGN KEY (assigned_by) REFERENCES users(user_id)     ON DELETE SET NULL
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
--  READING: history of a crop, one row every 5 minutes (24-hour chart)
-- ---------------------------------------------------------------------
CREATE TABLE readings (
  reading_id   BIGINT AUTO_INCREMENT PRIMARY KEY,
  crop_id      INT NOT NULL,
  device_id    VARCHAR(20) NOT NULL,
  recorded_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  moisture     DECIMAL(5,1) NULL,
  temperature  DECIMAL(4,1) NULL,
  humidity     DECIMAL(5,1) NULL,
  lux          INT UNSIGNED NULL,
  mood_code    VARCHAR(20) NOT NULL,
  INDEX idx_crop_time (crop_id, recorded_at),
  FOREIGN KEY (crop_id)   REFERENCES crops(crop_id)     ON DELETE CASCADE,
  FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE,
  FOREIGN KEY (mood_code) REFERENCES moods(mood_code)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
--  LIVE_STATUS: the latest values of each crop, overwritten every 30 s
-- ---------------------------------------------------------------------
CREATE TABLE live_status (
  crop_id      INT PRIMARY KEY,
  device_id    VARCHAR(20) NOT NULL,
  moisture     DECIMAL(5,1) NULL,
  temperature  DECIMAL(4,1) NULL,
  humidity     DECIMAL(5,1) NULL,
  lux          INT UNSIGNED NULL,
  mood_code    VARCHAR(20) NOT NULL,
  soil_raw     SMALLINT UNSIGNED NULL,          -- raw ADC value, for calibration
  rssi         SMALLINT NULL,                   -- Wi-Fi signal (dBm)
  ip           VARCHAR(45) NULL,
  uptime_s     INT UNSIGNED NULL,
  updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (crop_id)   REFERENCES crops(crop_id)     ON DELETE CASCADE,
  FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE,
  FOREIGN KEY (mood_code) REFERENCES moods(mood_code)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
--  MOOD_EVENT: the "crop diary" (one row each time the mood changes)
-- ---------------------------------------------------------------------
CREATE TABLE mood_events (
  event_id     BIGINT AUTO_INCREMENT PRIMARY KEY,
  crop_id      INT NOT NULL,
  device_id    VARCHAR(20) NOT NULL,
  mood_code    VARCHAR(20) NOT NULL,
  occurred_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  message      VARCHAR(200) NOT NULL,
  INDEX idx_crop_time (crop_id, occurred_at),
  FOREIGN KEY (crop_id)   REFERENCES crops(crop_id)     ON DELETE CASCADE,
  FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE,
  FOREIGN KEY (mood_code) REFERENCES moods(mood_code)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
--  PLAY_COMMAND: "Play" button in the apps → the device of the crop plays it
-- ---------------------------------------------------------------------
CREATE TABLE play_commands (
  command_id    BIGINT AUTO_INCREMENT PRIMARY KEY,
  crop_id       INT NOT NULL,
  device_id     VARCHAR(20) NOT NULL,
  user_id       INT NULL,
  melody_no     TINYINT UNSIGNED NOT NULL,
  requested_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status        ENUM('pending', 'played') NOT NULL DEFAULT 'pending',
  played_at     DATETIME NULL,
  INDEX idx_pending (device_id, status),
  FOREIGN KEY (crop_id)   REFERENCES crops(crop_id)       ON DELETE CASCADE,
  FOREIGN KEY (device_id) REFERENCES devices(device_id)   ON DELETE CASCADE,
  FOREIGN KEY (user_id)   REFERENCES users(user_id)       ON DELETE SET NULL,
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

-- Typical values for growing in Saudi Arabia (greenhouse / home). Adjust them if needed.
INSERT INTO crop_types (type_code, name_ar, name_en, emoji, moisture_min, moisture_max, temp_min, temp_max, lux_min) VALUES
  ('strawberry', 'فراولة',        'Strawberry',       '🍓', 60, 85, 10, 28,  5000),
  ('tomato',     'طماطم',         'Tomato',           '🍅', 50, 80, 15, 32,  8000),
  ('cucumber',   'خيار',          'Cucumber',         '🥒', 60, 85, 18, 32,  6000),
  ('pepper',     'فلفل',          'Pepper',           '🫑', 50, 80, 18, 32,  7000),
  ('lettuce',    'خس',            'Lettuce',          '🥬', 60, 85,  7, 24,  3000),
  ('mint',       'نعناع',         'Mint',             '🌿', 55, 85, 10, 30,  2000),
  ('basil',      'ريحان',         'Basil',            '🌱', 45, 80, 15, 32,  3000),
  ('date_palm',  'نخيل (فسائل)',  'Date palm (young)','🌴', 30, 70, 15, 45, 10000),
  ('rose',       'ورد',           'Rose',             '🌹', 45, 75, 12, 30,  5000),
  ('cactus',     'صبار',          'Cactus',           '🌵', 10, 40, 10, 40,  5000),
  ('indoor',     'نبات داخلي',    'Indoor plant',     '🪴', 40, 80, 15, 30,   200),
  ('other',      'أخرى',          'Other',            '🌾', 30, 85, 10, 35,   200);

-- Admin user: admin@rayy.app / Rayy@2026 (change the password after the first test)
INSERT INTO users (user_id, email, full_name, password_hash, role) VALUES
  (1, 'admin@rayy.app', 'Rayy Admin', '$2y$10$8cCB8IHP5z8vJdECFK.w2uClgv1ruEhKQVEG9BDSXUeu6W1VoWMVy', 'admin');

-- Two example crops of the admin
INSERT INTO crops (crop_id, owner_id, type_code, name, location, moisture_min, moisture_max, temp_min, temp_max, lux_min)
SELECT 1, 1, type_code, 'فراولة البيت المحمي', 'Greenhouse 1', moisture_min, moisture_max, temp_min, temp_max, lux_min
FROM crop_types WHERE type_code = 'strawberry';
INSERT INTO crops (crop_id, owner_id, type_code, name, location, moisture_min, moisture_max, temp_min, temp_max, lux_min)
SELECT 2, 1, type_code, 'نعناع الحديقة', 'Garden', moisture_min, moisture_max, temp_min, temp_max, lux_min
FROM crop_types WHERE type_code = 'mint';

-- The graduation-project device. Key = 'rayy-device-key-2026' (change it here AND in config.h).
-- It starts on the strawberry crop; move it to another crop from the apps.
INSERT INTO devices (device_id, name, device_key_hash, owner_id, crop_id) VALUES
  ('rayy-01', 'Rayy sensor 1', SHA2('rayy-device-key-2026', 256), 1, 1);
INSERT INTO device_assignments (device_id, crop_id, assigned_by) VALUES ('rayy-01', 1, 1);
