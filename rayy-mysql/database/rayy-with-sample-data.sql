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

-- =====================================================================
--  SAMPLE DATA (for demos): everything below is extra example data.
--  All times are relative to NOW(), so the 24-hour chart is full on the
--  day you import this file, on any computer.
--
--  Accounts:  admin@rayy.app / Rayy@2026   (admin)
--             sara@rayy.app  / Sara@2026   (user)
--  Devices:   rayy-01  key: rayy-device-key-2026   (strawberry crop, was on the mint crop before)
--             rayy-02  key: rayy-device-key-02     (Sara's tomato crop)
-- =====================================================================
-- Same clock as the PHP API (config.php: APP_TIMEZONE = Asia/Riyadh = UTC+3, no daylight saving)
SET time_zone = '+03:00';

INSERT INTO users (user_id, email, full_name, password_hash, role) VALUES
  (2, 'sara@rayy.app', 'سارة أحمد', '$2y$10$nbM62nlGRhKYfiXld/fiReiHKVS/QkKA5KvT6PoR6qfywsFBWuQJu', 'user');
INSERT INTO crops (crop_id, owner_id, type_code, name, location, moisture_min, moisture_max, temp_min, temp_max, lux_min)
SELECT 3, 2, type_code, 'طماطم السطح', 'السطح', moisture_min, moisture_max, temp_min, temp_max, lux_min FROM crop_types WHERE type_code = 'tomato';
INSERT INTO crops (crop_id, owner_id, type_code, name, location, moisture_min, moisture_max, temp_min, temp_max, lux_min)
SELECT 4, 2, type_code, 'صبار المكتب', 'مكتب الكلية', moisture_min, moisture_max, temp_min, temp_max, lux_min FROM crop_types WHERE type_code = 'cactus';
INSERT INTO devices (device_id, name, device_key_hash, owner_id, crop_id, last_seen) VALUES
  ('rayy-02', 'Rayy sensor 2', '3d03113cac07a8aafb45711fcb0a77b2f5920d261790f9f75d897b7ef15a11df', 2, 3, NOW());
UPDATE devices SET last_seen = NOW() WHERE device_id = 'rayy-01';
UPDATE device_assignments SET assigned_at = NOW() - INTERVAL 750 MINUTE WHERE device_id = 'rayy-01' AND crop_id = 1;
INSERT INTO device_assignments (device_id, crop_id, assigned_by, assigned_at, removed_at) VALUES
  ('rayy-01', 2, 1, NOW() - INTERVAL 1500 MINUTE, NOW() - INTERVAL 750 MINUTE),
  ('rayy-02', 3, 2, NOW() - INTERVAL 1500 MINUTE, NULL);
INSERT INTO readings (crop_id, device_id, recorded_at, moisture, temperature, humidity, lux, mood_code) VALUES
  (2, 'rayy-01', NOW() - INTERVAL 1470 MINUTE, 78.0, 22.0, 61.0, 3500, 'happy'),
  (2, 'rayy-01', NOW() - INTERVAL 1440 MINUTE, 77.9, 22.7, 60.9, 3734, 'happy'),
  (2, 'rayy-01', NOW() - INTERVAL 1410 MINUTE, 76.3, 23.3, 60.6, 3964, 'happy'),
  (2, 'rayy-01', NOW() - INTERVAL 1380 MINUTE, 73.1, 23.9, 60.2, 4186, 'happy'),
  (2, 'rayy-01', NOW() - INTERVAL 1350 MINUTE, 69.5, 24.5, 59.6, 4397, 'happy'),
  (2, 'rayy-01', NOW() - INTERVAL 1320 MINUTE, 67.4, 25.0, 58.9, 4592, 'happy'),
  (2, 'rayy-01', NOW() - INTERVAL 1290 MINUTE, 67.0, 25.5, 58.0, 4769, 'happy'),
  (2, 'rayy-01', NOW() - INTERVAL 1260 MINUTE, 67.1, 26.0, 57.1, 4924, 'happy'),
  (2, 'rayy-01', NOW() - INTERVAL 1230 MINUTE, 66.1, 26.3, 56.1, 5055, 'happy'),
  (2, 'rayy-01', NOW() - INTERVAL 1200 MINUTE, 63.2, 26.6, 55.0, 5160, 'happy'),
  (2, 'rayy-01', NOW() - INTERVAL 1170 MINUTE, 59.5, 26.8, 54.0, 5236, 'happy'),
  (2, 'rayy-01', NOW() - INTERVAL 1140 MINUTE, 56.9, 27.0, 53.0, 5283, 'happy'),
  (2, 'rayy-01', NOW() - INTERVAL 1110 MINUTE, 56.1, 27.0, 52.0, 5299, 'happy'),
  (2, 'rayy-01', NOW() - INTERVAL 1080 MINUTE, 56.2, 27.0, 51.2, 5285, 'happy'),
  (2, 'rayy-01', NOW() - INTERVAL 1050 MINUTE, 55.6, 26.8, 50.4, 5241, 'happy'),
  (2, 'rayy-01', NOW() - INTERVAL 1020 MINUTE, 53.2, 26.6, 49.8, 5167, 'thirsty'),
  (2, 'rayy-01', NOW() - INTERVAL 990 MINUTE, 49.6, 26.3, 49.4, 5065, 'thirsty'),
  (2, 'rayy-01', NOW() - INTERVAL 960 MINUTE, 46.5, 26.0, 49.1, 4936, 'thirsty'),
  (2, 'rayy-01', NOW() - INTERVAL 930 MINUTE, 45.2, 25.6, 49.0, 4783, 'thirsty'),
  (2, 'rayy-01', NOW() - INTERVAL 900 MINUTE, 46.3, 25.1, 49.1, 4608, 'thirsty'),
  (2, 'rayy-01', NOW() - INTERVAL 870 MINUTE, 87.8, 24.5, 49.3, 4414, 'drowning'),
  (2, 'rayy-01', NOW() - INTERVAL 840 MINUTE, 87.7, 24.0, 49.8, 4205, 'drowning'),
  (2, 'rayy-01', NOW() - INTERVAL 810 MINUTE, 86.0, 23.3, 50.4, 3983, 'drowning'),
  (2, 'rayy-01', NOW() - INTERVAL 780 MINUTE, 84.3, 22.7, 51.1, 3754, 'happy'),
  (1, 'rayy-01', NOW() - INTERVAL 720 MINUTE, 80.0, 21.0, 57.0, 6200, 'happy'),
  (1, 'rayy-01', NOW() - INTERVAL 690 MINUTE, 80.1, 21.6, 57.0, 6355, 'happy'),
  (1, 'rayy-01', NOW() - INTERVAL 660 MINUTE, 78.0, 22.1, 56.8, 6510, 'happy'),
  (1, 'rayy-01', NOW() - INTERVAL 630 MINUTE, 74.8, 22.7, 56.7, 6661, 'happy'),
  (1, 'rayy-01', NOW() - INTERVAL 600 MINUTE, 73.1, 23.2, 56.4, 6807, 'happy'),
  (1, 'rayy-01', NOW() - INTERVAL 570 MINUTE, 73.4, 23.7, 56.1, 6946, 'happy'),
  (1, 'rayy-01', NOW() - INTERVAL 540 MINUTE, 73.2, 24.1, 55.7, 7077, 'happy'),
  (1, 'rayy-01', NOW() - INTERVAL 510 MINUTE, 70.8, 24.5, 55.2, 7199, 'happy'),
  (1, 'rayy-01', NOW() - INTERVAL 480 MINUTE, 67.6, 24.9, 54.7, 7310, 'happy'),
  (1, 'rayy-01', NOW() - INTERVAL 450 MINUTE, 66.4, 25.1, 54.2, 7409, 'happy'),
  (1, 'rayy-01', NOW() - INTERVAL 420 MINUTE, 66.7, 25.3, 53.6, 7494, 'happy'),
  (1, 'rayy-01', NOW() - INTERVAL 390 MINUTE, 66.2, 25.4, 53.0, 7566, 'happy'),
  (1, 'rayy-01', NOW() - INTERVAL 360 MINUTE, 63.5, 25.5, 52.4, 7623, 'happy'),
  (1, 'rayy-01', NOW() - INTERVAL 330 MINUTE, 60.6, 25.5, 51.7, 7664, 'happy'),
  (1, 'rayy-01', NOW() - INTERVAL 300 MINUTE, 59.6, 25.4, 51.1, 7690, 'thirsty'),
  (1, 'rayy-01', NOW() - INTERVAL 270 MINUTE, 60.1, 25.2, 50.5, 7699, 'happy'),
  (1, 'rayy-01', NOW() - INTERVAL 240 MINUTE, 59.2, 25.0, 49.9, 7693, 'thirsty'),
  (1, 'rayy-01', NOW() - INTERVAL 210 MINUTE, 56.2, 24.6, 49.4, 7670, 'thirsty'),
  (1, 'rayy-01', NOW() - INTERVAL 180 MINUTE, 53.5, 24.3, 48.9, 7631, 'thirsty'),
  (1, 'rayy-01', NOW() - INTERVAL 150 MINUTE, 53.4, 23.9, 48.4, 7576, 'thirsty'),
  (1, 'rayy-01', NOW() - INTERVAL 120 MINUTE, 55.1, 23.4, 48.0, 7507, 'thirsty'),
  (1, 'rayy-01', NOW() - INTERVAL 90 MINUTE, 79.2, 22.9, 47.7, 7423, 'happy'),
  (1, 'rayy-01', NOW() - INTERVAL 60 MINUTE, 77.5, 22.3, 47.4, 7326, 'happy'),
  (1, 'rayy-01', NOW() - INTERVAL 30 MINUTE, 76.5, 21.8, 47.2, 7217, 'happy'),
  (1, 'rayy-01', NOW() - INTERVAL 0 MINUTE, 77.7, 21.2, 47.1, 7097, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 1440 MINUTE, 66.0, 25.0, 48.0, 9000, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 1410 MINUTE, 66.6, 25.9, 48.0, 9208, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 1380 MINUTE, 67.2, 26.9, 47.9, 9414, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 1350 MINUTE, 67.8, 27.8, 47.9, 9618, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 1320 MINUTE, 68.4, 28.7, 47.8, 9817, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 1290 MINUTE, 69.0, 29.5, 47.6, 10011, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 1260 MINUTE, 69.5, 30.3, 47.4, 10198, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 1230 MINUTE, 70.0, 31.0, 47.2, 10377, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 1200 MINUTE, 70.4, 31.7, 47.0, 10545, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 1170 MINUTE, 70.8, 32.3, 46.8, 10704, 'hot'),
  (3, 'rayy-02', NOW() - INTERVAL 1140 MINUTE, 71.2, 32.8, 46.5, 10850, 'hot'),
  (3, 'rayy-02', NOW() - INTERVAL 1110 MINUTE, 71.5, 33.2, 46.2, 10983, 'hot'),
  (3, 'rayy-02', NOW() - INTERVAL 1080 MINUTE, 71.7, 33.6, 45.9, 11103, 'hot'),
  (3, 'rayy-02', NOW() - INTERVAL 1050 MINUTE, 71.9, 33.8, 45.5, 11208, 'hot'),
  (3, 'rayy-02', NOW() - INTERVAL 1020 MINUTE, 72.0, 34.0, 45.1, 11298, 'hot'),
  (3, 'rayy-02', NOW() - INTERVAL 990 MINUTE, 72.0, 34.0, 44.7, 11372, 'hot'),
  (3, 'rayy-02', NOW() - INTERVAL 960 MINUTE, 72.0, 34.0, 44.3, 11429, 'hot'),
  (3, 'rayy-02', NOW() - INTERVAL 930 MINUTE, 71.9, 33.8, 43.9, 11470, 'hot'),
  (3, 'rayy-02', NOW() - INTERVAL 900 MINUTE, 71.7, 33.6, 43.4, 11493, 'hot'),
  (3, 'rayy-02', NOW() - INTERVAL 870 MINUTE, 71.5, 33.2, 43.0, 11499, 'hot'),
  (3, 'rayy-02', NOW() - INTERVAL 840 MINUTE, 71.2, 32.8, 42.5, 11488, 'hot'),
  (3, 'rayy-02', NOW() - INTERVAL 810 MINUTE, 70.9, 32.3, 42.0, 11459, 'hot'),
  (3, 'rayy-02', NOW() - INTERVAL 780 MINUTE, 70.5, 31.7, 41.6, 11414, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 750 MINUTE, 70.1, 31.0, 41.1, 11351, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 720 MINUTE, 69.6, 30.3, 40.6, 11273, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 690 MINUTE, 69.1, 29.5, 40.1, 11178, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 660 MINUTE, 68.5, 28.7, 39.6, 11069, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 630 MINUTE, 67.9, 27.8, 39.1, 10945, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 600 MINUTE, 67.3, 26.9, 38.6, 10807, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 570 MINUTE, 66.7, 25.9, 38.1, 10657, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 540 MINUTE, 66.1, 25.0, 37.6, 10496, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 510 MINUTE, 65.5, 24.1, 37.1, 10324, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 480 MINUTE, 64.9, 23.1, 36.7, 10143, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 450 MINUTE, 64.3, 22.2, 36.2, 9954, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 420 MINUTE, 63.7, 21.3, 35.8, 9758, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 390 MINUTE, 63.1, 20.5, 35.4, 9557, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 360 MINUTE, 62.6, 19.7, 35.0, 9352, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 330 MINUTE, 62.1, 19.0, 34.6, 9145, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 300 MINUTE, 61.6, 18.3, 34.2, 8937, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 270 MINUTE, 61.2, 17.7, 33.9, 8729, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 240 MINUTE, 60.9, 17.2, 33.6, 8523, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 210 MINUTE, 60.6, 16.8, 33.3, 8320, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 180 MINUTE, 60.3, 16.4, 33.0, 8123, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 150 MINUTE, 60.2, 16.2, 32.8, 7931, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 120 MINUTE, 60.0, 16.0, 32.6, 7746, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 90 MINUTE, 60.0, 16.0, 32.4, 7571, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 60 MINUTE, 60.0, 16.0, 32.3, 7405, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 30 MINUTE, 60.1, 16.2, 32.2, 7250, 'happy'),
  (3, 'rayy-02', NOW() - INTERVAL 0 MINUTE, 60.2, 16.4, 32.1, 7107, 'happy');
INSERT INTO mood_events (crop_id, device_id, mood_code, occurred_at, message) VALUES
  (2, 'rayy-01', 'happy', NOW() - INTERVAL 1470 MINUTE, 'I am happy, everything is perfect!'),
  (2, 'rayy-01', 'thirsty', NOW() - INTERVAL 1020 MINUTE, 'I am thirsty, please water me!'),
  (2, 'rayy-01', 'drowning', NOW() - INTERVAL 870 MINUTE, 'Too much water!'),
  (2, 'rayy-01', 'happy', NOW() - INTERVAL 780 MINUTE, 'I am happy, everything is perfect!'),
  (1, 'rayy-01', 'happy', NOW() - INTERVAL 720 MINUTE, 'I am happy, everything is perfect!'),
  (1, 'rayy-01', 'thirsty', NOW() - INTERVAL 300 MINUTE, 'I am thirsty, please water me!'),
  (1, 'rayy-01', 'happy', NOW() - INTERVAL 270 MINUTE, 'Thank you! I feel great.'),
  (1, 'rayy-01', 'thirsty', NOW() - INTERVAL 240 MINUTE, 'I am thirsty, please water me!'),
  (1, 'rayy-01', 'happy', NOW() - INTERVAL 90 MINUTE, 'Thank you! I feel great.'),
  (3, 'rayy-02', 'happy', NOW() - INTERVAL 1440 MINUTE, 'I am happy, everything is perfect!'),
  (3, 'rayy-02', 'hot', NOW() - INTERVAL 1170 MINUTE, 'It is too hot, I need shade!'),
  (3, 'rayy-02', 'happy', NOW() - INTERVAL 780 MINUTE, 'I am happy, everything is perfect!');
INSERT INTO live_status (crop_id, device_id, moisture, temperature, humidity, lux, mood_code, soil_raw, rssi, ip, uptime_s, updated_at) VALUES
  (1, 'rayy-01', 77.7, 21.2, 47.1, 7097, 'happy', 1850, -58, '192.168.1.23', 43200, NOW()),
  (2, 'rayy-01', 84.3, 22.7, 51.1, 3754, 'happy', 1700, -61, '192.168.1.23', 41000, NOW() - INTERVAL 780 MINUTE),
  (3, 'rayy-02', 60.2, 16.4, 32.1, 7107, 'happy', 1990, -64, '192.168.1.24', 86400, NOW());
