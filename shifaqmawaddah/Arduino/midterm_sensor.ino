#include <WiFi.h>
#include <HTTPClient.h>
#include "DHT.h"
#include <ArduinoJson.h>

#define DHTPIN 4
#define DHTTYPE DHT11
#define RELAY_PIN 25

const char* ssid = "myUUM-Guest";
const char* password = "";
const char* serverURL = "https://humancc.site/shifaqmawaddah/backend/insert.php";
const char* thresholdURL = "https://humancc.site/shifaqmawaddah/backend/get_thresholds.php";

// Default thresholds
float tempThreshold = 26.0;
float humThreshold = 70.0;

DHT dht(DHTPIN, DHTTYPE);
unsigned long lastSendTime = 0;
unsigned long lastThresholdFetchTime = 0;

const unsigned long sendInterval = 10000;         // 10 seconds
const unsigned long thresholdFetchInterval = 5000; // 5 seconds

bool lastRelayStatus = false;  // Track previous relay state for change detection

void setup() {
  Serial.begin(115200);
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW);
  dht.begin();

  Serial.print("Connecting to WiFi");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected!");

  // Initial threshold fetch
  fetchThresholds();
}

void loop() {
  unsigned long currentMillis = millis();

  // Fetch updated thresholds every 5 seconds
  if (currentMillis - lastThresholdFetchTime >= thresholdFetchInterval) {
    lastThresholdFetchTime = currentMillis;
    fetchThresholds();
  }

  // Send sensor data every 10 seconds
  if (currentMillis - lastSendTime >= sendInterval) {
    lastSendTime = currentMillis;

    float temp = dht.readTemperature();
    float hum = dht.readHumidity();

    if (!isnan(temp) && !isnan(hum)) {
      // Print current thresholds for debug
      Serial.println("Current Thresholds => Temp: " + String(tempThreshold) + " ¡ÆC, Hum: " + String(humThreshold) + " %");

      // Evaluate relay condition
      bool relayStatus = (temp > tempThreshold || hum > humThreshold);
      digitalWrite(RELAY_PIN, relayStatus ? HIGH : LOW);

      // Print only if relay status changes
      if (relayStatus != lastRelayStatus) {
        Serial.println("Relay: " + String(relayStatus ? "ON" : "OFF"));
        lastRelayStatus = relayStatus;
      }

      Serial.println("Reading => Temp: " + String(temp, 2) + " ¡ÆC, Hum: " + String(hum, 2) + " %");

      if (WiFi.status() == WL_CONNECTED) {
        HTTPClient http;
        http.begin(serverURL);
        http.addHeader("Content-Type", "application/json");

        String payload = "{\"temperature\":" + String(temp, 2) +
                         ",\"humidity\":" + String(hum, 2) +
                         ",\"relay_status\":" + String(relayStatus ? 1 : 0) + "}";

        int httpResponseCode = http.POST(payload);
        Serial.println("POST response: " + String(httpResponseCode));
        Serial.println("Payload: " + payload);
        http.end();
      } else {
        Serial.println("WiFi disconnected. Skipping upload.");
      }
    } else {
      Serial.println("Failed to read from DHT sensor!");
    }
  }
}

void fetchThresholds() {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(thresholdURL);
    int httpResponseCode = http.GET();

    if (httpResponseCode == 200) {
      String response = http.getString();
      Serial.println("Threshold Response: " + response);  // Debug: show raw JSON

      StaticJsonDocument<200> doc;
      DeserializationError error = deserializeJson(doc, response);

      if (!error && doc.containsKey("temp_threshold") && doc.containsKey("humidity_threshold")) {
        // Convert string values to float safely
        tempThreshold = String(doc["temp_threshold"]).toFloat();
        humThreshold = String(doc["humidity_threshold"]).toFloat();

        Serial.println("Updated thresholds:");
        Serial.println("Temp Threshold = " + String(tempThreshold));
        Serial.println("Humidity Threshold = " + String(humThreshold));
      } else {
        Serial.print("JSON parse error: ");
        Serial.println(error.c_str());
        Serial.println("Invalid or missing keys in response.");
      }
    } else {
      Serial.println("Failed to fetch thresholds, HTTP code: " + String(httpResponseCode));
    }
    http.end();
  } else {
    Serial.println("WiFi not connected. Cannot fetch thresholds.");
  }
}
