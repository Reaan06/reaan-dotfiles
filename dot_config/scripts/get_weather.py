import requests
import json
import os
from datetime import datetime, timedelta

# Persistent storage for weather telemetry
CACHE_PATH = os.path.expanduser("~/.cache/weather.json")

def get_weather():
    try:
        # Multi-service IP Geolocation with automatic fallback
        city = "Unknown"
        lat, lon = 19.4326, -99.1332 # Hard default CDMX coords but city name is dynamic

        # Priority 1: ipapi.co
        try:
            loc = requests.get('https://ipapi.co/json/', timeout=4).json()
            if 'city' in loc:
                city = loc['city']
                lat, lon = loc['latitude'], loc['longitude']
        except:
            # Priority 2: ip-api.com
            try:
                loc = requests.get('http://ip-api.com/json/', timeout=4).json()
                if loc.get('status') == 'success':
                    city = loc['city']
                    lat, lon = loc['lat'], loc['lon']
            except:
                pass

        # Load historical cache
        archive = {"city": city, "days": {}}
        if os.path.exists(CACHE_PATH):
            try:
                with open(CACHE_PATH, 'r') as f:
                    archive = json.load(f)
                # If city detection was better in previous run, keep it unless new one is found
                if city == "Unknown" and archive.get("city"):
                    city = archive["city"]
            except:
                pass

        # Fetch APIs (Forecast + Archive)
        forecast_url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&hourly=temperature_2m,relative_humidity_2m,precipitation_probability,weather_code,wind_speed_10m&timezone=auto&forecast_days=8"
        f_resp = requests.get(forecast_url, timeout=7).json()

        past_start = (datetime.now() - timedelta(days=7)).strftime('%Y-%m-%d')
        past_end = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')
        hist_url = f"https://archive-api.open-meteo.com/v1/archive?latitude={lat}&longitude={lon}&start_date={past_start}&end_date={past_end}&hourly=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m&timezone=auto"
        h_resp = requests.get(hist_url, timeout=7).json()

        def ingest(api_data):
            if 'hourly' not in api_data: return
            h = api_data['hourly']
            for i, t_str in enumerate(h['time']):
                dt = datetime.fromisoformat(t_str)
                d_key = dt.strftime('%Y-%m-%d')
                h_key = dt.strftime('%H:00')
                if d_key not in archive['days']: archive['days'][d_key] = []
                
                # Upsert hour
                existing = next((x for x in archive['days'][d_key] if x['hour'] == h_key), None)
                entry = {
                    "hour": h_key,
                    "temp": h['temperature_2m'][i],
                    "humidity": h.get('relative_humidity_2m', [0]*len(h['time']))[i],
                    "rain": h.get('precipitation_probability', [0]*len(h['time']))[i],
                    "wind": h['wind_speed_10m'][i],
                    "code": h['weather_code'][i]
                }
                if existing: existing.update(entry)
                else: archive['days'][d_key].append(entry)
            
            for d in archive['days']: archive['days'][d].sort(key=lambda x: x['hour'])

        ingest(h_resp)
        ingest(f_resp)

        archive.update({
            "city": city if city != "Unknown" else archive.get("city", "Desconocido"),
            "current_time": datetime.now().strftime("%H:%M"),
            "current_date": datetime.now().strftime("%Y-%m-%d")
        })

        output = json.dumps(archive)
        os.makedirs(os.path.dirname(CACHE_PATH), exist_ok=True)
        with open(CACHE_PATH, 'w') as f: f.write(output)
        print(output)

    except Exception as e:
        if os.path.exists(CACHE_PATH):
            with open(CACHE_PATH, 'r') as f: print(f.read())
        else: print(json.dumps({"error": str(e)}))

if __name__ == "__main__":
    get_weather()
