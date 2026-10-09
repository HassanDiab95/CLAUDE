#!/usr/bin/env bash
# =====================================================================
#  Automatic test of the ري PHP API (needs bash, curl and php).
#  1) Import database/rayy.sql again (fresh data)   2) start Apache + MySQL
#  3) run:  bash tests/test_api.sh http://localhost/rayy/api
#  Windows: run it in "Git Bash". It prints PASS/FAIL for every check.
# =====================================================================
B=${1:-http://localhost/rayy/api}
KEY="X-Device-Key: rayy-device-key-2026"
pass=0; failn=0
check() {   # check "name" "<json>" "expected text"
  if [[ "$2" == *"$3"* ]]; then pass=$((pass+1)); echo "PASS  $1";
  else failn=$((failn+1)); echo "FAIL  $1"; echo "      got: $2"; fi
}
post() { curl -s -X POST "$B/$1" -H "Content-Type: application/json" ${3:+-H "$3"} -d "$2"; }
get()  { curl -s "$B/$1" ${2:+-H "$2"}; }
json() { php -r '$d=json_decode(stream_get_contents(STDIN),true); echo $d'"$1"';'; }

# --- accounts ---
check "public crop types"        "$(get crop_types.php)" '"type_code":"strawberry"'
check "wrong admin password"     "$(post login.php '{"email":"admin@rayy.app","password":"x"}')" 'Wrong email or password'
ADMIN="X-Auth-Token: $(post login.php '{"email":"admin@rayy.app","password":"Rayy@2026"}' | json "['token']")"
check "admin me"                 "$(get me.php "$ADMIN")" '"role":"admin"'
check "register short password"  "$(post register.php '{"full_name":"Sara","email":"sara@test.com","password":"123"}')" 'at least 8'
R=$(post register.php '{"full_name":"Sara","email":"sara@test.com","password":"Sara12345"}')
check "register new user"        "$R" '"role":"user"'
SARA="X-Auth-Token: $(echo "$R" | json "['token']")"
check "register same email"      "$(post register.php '{"full_name":"Sara","email":"sara@test.com","password":"Sara12345"}')" 'already registered'
check "user cannot list users"   "$(get users.php "$SARA")" 'Only an admin'
check "admin creates user"       "$(post users.php '{"action":"create","full_name":"Huda","email":"huda@test.com","password":"Huda12345","role":"user"}' "$ADMIN")" '"user_id"'
check "admin lists users"        "$(get users.php "$ADMIN")" 'huda@test.com'

# --- crops ---
check "admin sees 2 crops"       "$(get crops.php "$ADMIN" | json "['crops'][1]['config']['type_code']")" 'mint'
check "new user has no crops"    "$(get crops.php "$SARA")" '"crops":[]'
C=$(post crops.php '{"name":"Tomato field","type_code":"tomato","location":"Farm A"}' "$SARA")
check "user adds a crop"         "$C" '"crop_id"'
CROP=$(echo "$C" | json "['crop_id']")
check "crop gets tomato values"  "$(get "live.php?crop=$CROP" "$SARA" | json "['config']['moisture_min']")" '50'
check "user cannot see admin crop" "$(get "live.php?crop=1" "$SARA")" 'another user'
check "change thresholds"        "$(post "crop_update.php?crop=$CROP" '{"moisture_min":55,"muted":true}' "$SARA")" '"moisture_min":55'
check "bad threshold"            "$(post "crop_update.php?crop=$CROP" '{"moisture_min":140}' "$SARA")" 'between 0 and 100'
check "change type → new values" "$(post "crop_update.php?crop=$CROP" '{"type_code":"cactus"}' "$SARA")" '"moisture_min":10'

# --- device on crop 1 (strawberry) ---
check "wrong device key"         "$(post 'device.php?device=rayy-01' '{}' 'X-Device-Key: bad')" 'wrong device key'
D=$(post 'device.php?device=rayy-01' '{"moisture":40,"temperature":24,"humidity":50,"lux":6000,"mood":"thirsty","history":true,"event":{"mood":"thirsty","message":"I am thirsty, please water me!"}}' "$KEY")
check "device → strawberry crop" "$D" '"crop_id":1'
check "strawberry thresholds"    "$D" '"moisture_min":60'
check "live of crop 1"           "$(get 'live.php?crop=1' "$ADMIN")" '"mood":"thirsty"'
check "diary of crop 1"          "$(get 'events.php?crop=1' "$ADMIN")" 'I am thirsty'
check "history of crop 1"        "$(get 'history.php?crop=1' "$ADMIN")" '"moisture":40'
check "play on crop 1"           "$(post 'command.php?crop=1' '{"play":7}' "$ADMIN")" '"ok":true'
check "device gets melody 7"     "$(post 'device.php?device=rayy-01' '{"mood":"happy"}' "$KEY")" '"play":7'
check "play without device"      "$(post 'command.php?crop=2' '{"play":1}' "$ADMIN")" 'No device'

# --- move the device to crop 2 (mint) ---
check "move device to mint"      "$(post device_assign.php '{"device_id":"rayy-01","crop_id":2}' "$ADMIN")" '"ok":true'
D=$(post 'device.php?device=rayy-01' '{"moisture":70,"mood":"happy","history":true}' "$KEY")
check "device now → mint crop"   "$D" '"crop_id":2'
check "mint thresholds"          "$D" '"moisture_min":55'
check "mint has live data"       "$(get 'live.php?crop=2' "$ADMIN")" '"moisture":70'
check "strawberry kept history"  "$(get 'history.php?crop=1' "$ADMIN")" '"moisture":40'
check "devices list"             "$(get devices.php "$ADMIN")" '"crop_id":2'
check "user cannot move admin device" "$(post device_assign.php "{\"device_id\":\"rayy-01\",\"crop_id\":$CROP}" "$SARA")" 'another user'
check "unassign device"          "$(post device_assign.php '{"device_id":"rayy-01","crop_id":null}' "$ADMIN")" '"ok":true'
check "device without crop"      "$(post 'device.php?device=rayy-01' '{"mood":"happy"}' "$KEY")" '"crop":null'

# --- a second device: admin registers it, the user adds it with its key ---
check "user cannot create device" "$(post devices.php '{"device_id":"rayy-02","device_key":"key-rayy-02"}' "$SARA")" 'Ask the admin'
check "admin registers rayy-02"  "$(post devices.php '{"device_id":"rayy-02","device_key":"key-rayy-02","name":"Sensor 2"}' "$ADMIN")" '"created":true'
check "user: wrong device key"   "$(post devices.php '{"device_id":"rayy-02","device_key":"wrong-key"}' "$SARA")" 'Wrong device key'
check "user adds rayy-02"        "$(post devices.php '{"device_id":"rayy-02","device_key":"key-rayy-02","name":"My sensor"}' "$SARA")" '"ok":true'
check "user puts it on own crop" "$(post device_assign.php "{\"device_id\":\"rayy-02\",\"crop_id\":$CROP}" "$SARA")" '"ok":true'
check "user sees own device"     "$(get devices.php "$SARA")" 'My sensor'

# --- clean up ---
check "delete crop"              "$(post "crop_delete.php?crop=$CROP" '{}' "$SARA")" '"ok":true'
check "logout"                   "$(post logout.php '{}' "$SARA")" '"ok":true'
check "token no longer valid"    "$(get crops.php "$SARA")" 'Session expired'

echo; echo "$pass passed, $failn failed"
[ $failn -eq 0 ]
